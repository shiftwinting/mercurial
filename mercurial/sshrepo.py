# sshrepo.py - ssh repository proxy class for mercurial
#
# Copyright 2005, 2006 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

import re
from i18n import _
import util, error, wireproto

class remotelock(object):
    def __init__(self, repo):
        self.repo = repo
    def release(self):
        self.repo.unlock()
        self.repo = None
    def __del__(self):
        if self.repo:
            self.release()

def _serverquote(s):
    '''quote a string for the remote shell ... which we assume is sh'''
    if re.match('[a-zA-Z0-9@%_+=:,./-]*$', s):
        return s
    return "'%s'" % s.replace("'", "'\\''")

class sshrepository(wireproto.wirerepository):
    def __init__(self, ui, path, create=False):
        self._url = path
        self.ui = ui

        u = util.url(path, parsequery=False, parsefragment=False)
        if u.scheme != 'ssh' or not u.host or u.path is None:
            self._abort(error.RepoError(_("couldn't parse location %s") % path))

        self.user = u.user
        if u.passwd is not None:
            self._abort(error.RepoError(_("password in URL not supported")))
        self.host = u.host
        self.port = u.port
        self.path = u.path or "."

        sshcmd = self.ui.config("ui", "ssh", "ssh")
        remotecmd = self.ui.config("ui", "remotecmd", "hg")

        args = util.sshargs(sshcmd, self.host, self.user, self.port)

        if create:
            cmd = '%s %s %s' % (sshcmd, args,
                util.shellquote("%s init %s" %
                    (_serverquote(remotecmd), _serverquote(self.path))))
            ui.note(_('running %s\n') % cmd)
            res = util.system(cmd)
            if res != 0:
                self._abort(error.RepoError(_("could not create remote repo")))

        self.validate_repo(ui, sshcmd, args, remotecmd)

    def url(self):
        return self._url

    def validate_repo(self, ui, sshcmd, args, remotecmd):
        # cleanup up previous run
        self.cleanup()

        cmd = '%s %s %s' % (sshcmd, args,
            util.shellquote("%s -R %s serve --stdio" %
                (_serverquote(remotecmd), _serverquote(self.path))))
        ui.note(_('running %s\n') % cmd)
        cmd = util.quotecommand(cmd)
        self.pipeo, self.pipei, self.pipee = util.popen3(cmd)

        # skip any noise generated by remote shell
        self._callstream("hello")
        r = self._callstream("between", pairs=("%s-%s" % ("0"*40, "0"*40)))
        lines = ["", "dummy"]
        max_noise = 500
        while lines[-1] and max_noise:
            l = r.readline()
            self.readerr()
            if lines[-1] == "1\n" and l == "\n":
                break
            if l:
                ui.debug("remote: ", l)
            lines.append(l)
            max_noise -= 1
        else:
            self._abort(error.RepoError(_('no suitable response from '
                                          'remote hg')))

        self.capabilities = set()
        for l in reversed(lines):
            if l.startswith("capabilities:"):
                self.capabilities.update(l[:-1].split(":")[1].split())
                break

    def readerr(self):
        while True:
            size = util.fstat(self.pipee).st_size
            if size == 0:
                break
            s = self.pipee.read(size)
            if not s:
                break
            for l in s.splitlines():
                self.ui.status(_("remote: "), l, '\n')

    def _abort(self, exception):
        self.cleanup()
        raise exception

    def cleanup(self):
        try:
            self.pipeo.close()
            self.pipei.close()
            # read the error descriptor until EOF
            for l in self.pipee:
                self.ui.status(_("remote: "), l)
            self.pipee.close()
        except:
            pass

    __del__ = cleanup

    def _callstream(self, cmd, **args):
        self.ui.debug("sending %s command\n" % cmd)
        self.pipeo.write("%s\n" % cmd)
        _func, names = wireproto.commands[cmd]
        keys = names.split()
        wireargs = {}
        for k in keys:
            if k == '*':
                wireargs['*'] = args
                break
            else:
                wireargs[k] = args[k]
                del args[k]
        for k, v in sorted(wireargs.iteritems()):
            self.pipeo.write("%s %d\n" % (k, len(v)))
            if isinstance(v, dict):
                for dk, dv in v.iteritems():
                    self.pipeo.write("%s %d\n" % (dk, len(dv)))
                    self.pipeo.write(dv)
            else:
                self.pipeo.write(v)
        self.pipeo.flush()

        return self.pipei

    def _call(self, cmd, **args):
        self._callstream(cmd, **args)
        return self._recv()

    def _callpush(self, cmd, fp, **args):
        r = self._call(cmd, **args)
        if r:
            return '', r
        while True:
            d = fp.read(4096)
            if not d:
                break
            self._send(d)
        self._send("", flush=True)
        r = self._recv()
        if r:
            return '', r
        return self._recv(), ''

    def _decompress(self, stream):
        return stream

    def _recv(self):
        l = self.pipei.readline()
        if l == '\n':
            err = []
            while True:
                line = self.pipee.readline()
                if line == '-\n':
                    break
                err.extend([line])
            if len(err) > 0:
                # strip the trailing newline added to the last line server-side
                err[-1] = err[-1][:-1]
            self._abort(error.OutOfBandError(*err))
        self.readerr()
        try:
            l = int(l)
        except ValueError:
            self._abort(error.ResponseError(_("unexpected response:"), l))
        return self.pipei.read(l)

    def _send(self, data, flush=False):
        self.pipeo.write("%d\n" % len(data))
        if data:
            self.pipeo.write(data)
        if flush:
            self.pipeo.flush()
        self.readerr()

    def lock(self):
        self._call("lock")
        return remotelock(self)

    def unlock(self):
        self._call("unlock")

    def addchangegroup(self, cg, source, url, lock=None):
        '''Send a changegroup to the remote server.  Return an integer
        similar to unbundle(). DEPRECATED, since it requires locking the
        remote.'''
        d = self._call("addchangegroup")
        if d:
            self._abort(error.RepoError(_("push refused: %s") % d))
        while True:
            d = cg.read(4096)
            if not d:
                break
            self.pipeo.write(d)
            self.readerr()

        self.pipeo.flush()

        self.readerr()
        r = self._recv()
        if not r:
            return 1
        try:
            return int(r)
        except ValueError:
            self._abort(error.ResponseError(_("unexpected response:"), r))

instance = sshrepository
