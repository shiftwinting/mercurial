#require killdaemons

#if windows
  $ hg clone http://localhost:$HGPORT/ copy
  abort: * (glob)
  [255]
#else
  $ hg clone http://localhost:$HGPORT/ copy
  abort: error: Connection refused
  [255]
#endif
  $ test -d copy
  [1]

This server doesn't do range requests so it's basically only good for
one pull

  $ cat > dumb.py <<EOF
  > import BaseHTTPServer, SimpleHTTPServer, os, signal, sys
  > 
  > def run(server_class=BaseHTTPServer.HTTPServer,
  >         handler_class=SimpleHTTPServer.SimpleHTTPRequestHandler):
  >     server_address = ('localhost', int(os.environ['HGPORT']))
  >     httpd = server_class(server_address, handler_class)
  >     httpd.serve_forever()
  > 
  > signal.signal(signal.SIGTERM, lambda x, y: sys.exit(0))
  > fp = file('dumb.pid', 'wb')
  > fp.write(str(os.getpid()) + '\n')
  > fp.close()
  > run()
  > EOF
  $ python dumb.py 2>/dev/null &

Cannot just read $!, it will not be set to the right value on Windows/MinGW

  $ cat > wait.py <<EOF
  > import time
  > while True:
  >     try:
  >         if '\n' in file('dumb.pid', 'rb').read():
  >             break
  >     except IOError:
  >         pass
  >     time.sleep(0.2)
  > EOF
  $ python wait.py
  $ cat dumb.pid >> $DAEMON_PIDS
  $ hg init remote
  $ cd remote
  $ echo foo > bar
  $ echo c2 > '.dotfile with spaces'
  $ hg add
  adding .dotfile with spaces
  adding bar
  $ hg commit -m"test"
  $ hg tip
  changeset:   0:02770d679fb8
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     test
  
  $ cd ..
  $ hg clone static-http://localhost:$HGPORT/remote local
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 2 changes to 2 files
  updating to branch default
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd local
  $ hg verify
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
  2 files, 1 changesets, 2 total revisions
  $ cat bar
  foo
  $ cd ../remote
  $ echo baz > quux
  $ hg commit -A -mtest2
  adding quux

check for HTTP opener failures when cachefile does not exist

  $ rm .hg/cache/*
  $ cd ../local
  $ echo '[hooks]' >> .hg/hgrc
  $ echo "changegroup = python \"$TESTDIR/printenv.py\" changegroup" >> .hg/hgrc
  $ hg pull
  pulling from static-http://localhost:$HGPORT/remote
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  changegroup hook: HG_NODE=4ac2e3648604439c580c69b09ec9d93a88d93432 HG_SOURCE=pull HG_URL=http://localhost:$HGPORT/remote
  (run 'hg update' to get a working copy)

trying to push

  $ hg update
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo more foo >> bar
  $ hg commit -m"test"
  $ hg push
  pushing to static-http://localhost:$HGPORT/remote
  abort: destination does not support push
  [255]

trying clone -r

  $ cd ..
  $ hg clone -r doesnotexist static-http://localhost:$HGPORT/remote local0
  abort: unknown revision 'doesnotexist'!
  [255]
  $ hg clone -r 0 static-http://localhost:$HGPORT/remote local0
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 2 changes to 2 files
  updating to branch default
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved

test with "/" URI (issue747) and subrepo

  $ hg init
  $ hg init sub
  $ touch sub/test
  $ hg -R sub commit -A -m "test"
  adding test
  $ hg -R sub tag not-empty
  $ echo sub=sub > .hgsub
  $ echo a > a
  $ hg add a .hgsub
  $ hg -q ci -ma
  $ hg clone static-http://localhost:$HGPORT/ local2
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 3 changes to 3 files
  updating to branch default
  cloning subrepo sub from static-http://localhost:$HGPORT/sub
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 2 changesets with 2 changes to 2 files
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd local2
  $ hg verify
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
  3 files, 1 changesets, 3 total revisions
  $ cat a
  a
  $ hg paths
  default = static-http://localhost:$HGPORT/

test with empty repo (issue965)

  $ cd ..
  $ hg init remotempty
  $ hg clone static-http://localhost:$HGPORT/remotempty local3
  no changes found
  updating to branch default
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd local3
  $ hg verify
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
  0 files, 0 changesets, 0 total revisions
  $ hg paths
  default = static-http://localhost:$HGPORT/remotempty

test with non-repo

  $ cd ..
  $ mkdir notarepo
  $ hg clone static-http://localhost:$HGPORT/notarepo local3
  abort: 'http://localhost:$HGPORT/notarepo' does not appear to be an hg repository!
  [255]
  $ "$TESTDIR/killdaemons.py" $DAEMON_PIDS
