  $ echo "graphlog=" >> $HGRCPATH
  >     hg glog --template '{rev}:{node|short} {author} {date|hgdate} - {branch} - {desc|firstline}\n'
  $ hg import --bypass --import-branch ../test.diff
  $ python -c 'file("a", "wb").write("a\r\n")'
  $ hg import -m 'should fail because of eol' --bypass ../test.diff