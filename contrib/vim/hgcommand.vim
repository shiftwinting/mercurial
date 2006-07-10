" vim600: set foldmethod=marker:
"
" Vim plugin to assist in working with HG-controlled files.
"
" Last Change:   2006/02/22
" Version:       1.76
" Maintainer:    Mathieu Clabaut <mathieu.clabaut@gmail.com>
" License:       This file is placed in the public domain.
" Credits: {{{1
"                Bob Hiestand <bob.hiestand@gmail.com> for the fabulous
"                cvscommand.vim from which this script was directly created by
"                means of sed commands and minor tweaks.

" Section: Documentation {{{1
"
" Provides functions to invoke various HG commands on the current file
" (either the current buffer, or, in the case of an directory buffer, the file
" on the current line).  The output of the commands is captured in a new
" scratch window.  For convenience, if the functions are invoked on a HG
" output window, the original file is used for the hg operation instead after
" the window is split.  This is primarily useful when running HGCommit and
" you need to see the changes made, so that HGDiff is usable and shows up in
" another window.
"
" Command documentation {{{2
"
" HGAdd           Performs "hg add" on the current file.
"
" HGAnnotate      Performs "hg annotate" on the current file.  If an
"                  argument is given, the argument is used as a revision
"                  number to display.  If not given an argument, it uses the
"                  most recent version of the file on the current branch.
"                  Additionally, if the current buffer is a HGAnnotate buffer
"                  already, the version number on the current line is used.
"
"                  If the 'HGCommandAnnotateParent' variable is set to a
"                  non-zero value, the version previous to the one on the
"                  current line is used instead.  This allows one to navigate
"                  back to examine the previous version of a line.
"
" HGCommit[!]     If called with arguments, this performs "hg commit" using
"                  the arguments as the log message.
"
"                  If '!' is used, an empty log message is committed.
"
"                  If called with no arguments, this is a two-step command.
"                  The first step opens a buffer to accept a log message.
"                  When that buffer is written, it is automatically closed and
"                  the file is committed using the information from that log
"                  message.  The commit can be abandoned if the log message
"                  buffer is deleted or wiped before being written.
"
" HGDiff          With no arguments, this performs "hg diff" on the current
"                  file.  With one argument, "hg diff" is performed on the
"                  current file against the specified revision.  With two
"                  arguments, hg diff is performed between the specified
"                  revisions of the current file.  This command uses the
"                  'HGCommandDiffOpt' variable to specify diff options.  If
"                  that variable does not exist, then 'wbBc' is assumed.  If
"                  you wish to have no options, then set it to the empty
"                  string.
"
" HGGotoOriginal  Returns the current window to the source buffer if the
"                  current buffer is a HG output buffer.
"
" HGLog           Performs "hg log" on the current file.
"
" HGRevert        Replaces the modified version of the current file with the
"                  most recent version from the repository.
"
" HGReview        Retrieves a particular version of the current file.  If no
"                  argument is given, the most recent version of the file on
"                  the current branch is retrieved.  The specified revision is
"                  retrieved into a new buffer.
"
" HGStatus        Performs "hg status" on the current file.
"
" HGUpdate        Performs "hg update" on the current file.
"
" HGVimDiff       With no arguments, this prompts the user for a revision and
"                  then uses vimdiff to display the differences between the
"                  current file and the specified revision.  If no revision is
"                  specified, the most recent version of the file on the
"                  current branch is used.  With one argument, that argument
"                  is used as the revision as above.  With two arguments, the
"                  differences between the two revisions is displayed using
"                  vimdiff.
"
"                  With either zero or one argument, the original buffer is used
"                  to perform the vimdiff.  When the other buffer is closed, the
"                  original buffer will be returned to normal mode.
"
"                  Once vimdiff mode is started using the above methods,
"                  additional vimdiff buffers may be added by passing a single
"                  version argument to the command.  There may be up to 4
"                  vimdiff buffers total.
"
"                  Using the 2-argument form of the command resets the vimdiff
"                  to only those 2 versions.  Additionally, invoking the
"                  command on a different file will close the previous vimdiff
"                  buffers.
"
"
" Mapping documentation: {{{2
"
" By default, a mapping is defined for each command.  User-provided mappings
" can be used instead by mapping to <Plug>CommandName, for instance:
"
" nnoremap ,ca <Plug>HGAdd
"
" The default mappings are as follow:
"
"   <Leader>hga HGAdd
"   <Leader>hgn HGAnnotate
"   <Leader>hgc HGCommit
"   <Leader>hgd HGDiff
"   <Leader>hgg HGGotoOriginal
"   <Leader>hgG HGGotoOriginal!
"   <Leader>hgl HGLog
"   <Leader>hgr HGReview
"   <Leader>hgs HGStatus
"   <Leader>hgu HGUpdate
"   <Leader>hgv HGVimDiff
"
" Options documentation: {{{2
"
" Several variables are checked by the script to determine behavior as follow:
"
" HGCommandAnnotateParent
"   This variable, if set to a non-zero value, causes the zero-argument form
"   of HGAnnotate when invoked on a HGAnnotate buffer to go to the version
"   previous to that displayed on the current line.  If not set, it defaults
"   to 0.
"
" HGCommandCommitOnWrite
"   This variable, if set to a non-zero value, causes the pending hg commit
"   to take place immediately as soon as the log message buffer is written.
"   If set to zero, only the HGCommit mapping will cause the pending commit
"   to occur.  If not set, it defaults to 1.
"
" HGCommandDeleteOnHide
"   This variable, if set to a non-zero value, causes the temporary HG result
"   buffers to automatically delete themselves when hidden.
"
" HGCommandDiffOpt
"   This variable, if set, determines the options passed to the diff command
"   of HG.  If not set, it defaults to 'wbBc'.
"
" HGCommandDiffSplit
"   This variable overrides the HGCommandSplit variable, but only for buffers
"   created with HGVimDiff.
"
" HGCommandEdit
"   This variable controls whether the original buffer is replaced ('edit') or
"   split ('split').  If not set, it defaults to 'edit'.
"
" HGCommandEnableBufferSetup
"   This variable, if set to a non-zero value, activates HG buffer management
"   mode.  This mode means that two buffer variables, 'HGRevision' and
"   'HGBranch', are set if the file is HG-controlled.  This is useful for
"   displaying version information in the status bar.
"
" HGCommandInteractive
"   This variable, if set to a non-zero value, causes appropriate functions (for
"   the moment, only HGReview) to query the user for a revision to use
"   instead of the current revision if none is specified.
"
" HGCommandNameMarker
"   This variable, if set, configures the special attention-getting characters
"   that appear on either side of the hg buffer type in the buffer name.
"   This has no effect unless 'HGCommandNameResultBuffers' is set to a true
"   value.  If not set, it defaults to '_'.  
"
" HGCommandNameResultBuffers
"   This variable, if set to a true value, causes the hg result buffers to be
"   named in the old way ('<source file name> _<hg command>_').  If not set
"   or set to a false value, the result buffer is nameless.
"
" HGCommandSplit
"   This variable controls the orientation of the various window splits that
"   may occur (such as with HGVimDiff, when using a HG command on a HG
"   command buffer, or when the 'HGCommandEdit' variable is set to 'split'.
"   If set to 'horizontal', the resulting windows will be on stacked on top of
"   one another.  If set to 'vertical', the resulting windows will be
"   side-by-side.  If not set, it defaults to 'horizontal' for all but
"   HGVimDiff windows.
"
" Event documentation {{{2
"   For additional customization, hgcommand.vim uses User event autocommand
"   hooks.  Each event is in the HGCommand group, and different patterns
"   match the various hooks.
"
"   For instance, the following could be added to the vimrc to provide a 'q'
"   mapping to quit a HG buffer:
"
"   augroup HGCommand
"     au HGCommand User HGBufferCreated silent! nmap <unique> <buffer> q :bwipeout<cr> 
"   augroup END
"
"   The following hooks are available:
"
"   HGBufferCreated           This event is fired just after a hg command
"                              result buffer is created and filled with the
"                              result of a hg command.  It is executed within
"                              the context of the new buffer.
"
"   HGBufferSetup             This event is fired just after HG buffer setup
"                              occurs, if enabled.
"
"   HGPluginInit              This event is fired when the HGCommand plugin
"                              first loads.
"
"   HGPluginFinish            This event is fired just after the HGCommand
"                              plugin loads.
"
"   HGVimDiffFinish           This event is fired just after the HGVimDiff
"                              command executes to allow customization of,
"                              for instance, window placement and focus.
"
" Section: Plugin header {{{1

" loaded_hgcommand is set to 1 when the initialization begins, and 2 when it
" completes.  This allows various actions to only be taken by functions after
" system initialization.

if exists("loaded_hgcommand")
   finish
endif
let loaded_hgcommand = 1

if v:version < 602
  echohl WarningMsg|echomsg "HGCommand 1.69 or later requires VIM 6.2 or later"|echohl None
  finish
endif

" Section: Event group setup {{{1

augroup HGCommand
augroup END

" Section: Plugin initialization {{{1
silent do HGCommand User HGPluginInit

" Section: Script variable initialization {{{1

let s:HGCommandEditFileRunning = 0
unlet! s:vimDiffRestoreCmd
unlet! s:vimDiffSourceBuffer
unlet! s:vimDiffBufferCount
unlet! s:vimDiffScratchList

" Section: Utility functions {{{1

" Function: s:HGResolveLink() {{{2
" Fully resolve the given file name to remove shortcuts or symbolic links.

function! s:HGResolveLink(fileName)
  let resolved = resolve(a:fileName)
  if resolved != a:fileName
    let resolved = s:HGResolveLink(resolved)
  endif
  return resolved
endfunction

" Function: s:HGChangeToCurrentFileDir() {{{2
" Go to the directory in which the current HG-controlled file is located.
" If this is a HG command buffer, first switch to the original file.

function! s:HGChangeToCurrentFileDir(fileName)
  let oldCwd=getcwd()
  let fileName=s:HGResolveLink(a:fileName)
  let newCwd=fnamemodify(fileName, ':h')
  if strlen(newCwd) > 0
    execute 'cd' escape(newCwd, ' ')
  endif
  return oldCwd
endfunction

" Function: s:HGGetOption(name, default) {{{2
" Grab a user-specified option to override the default provided.  Options are
" searched in the window, buffer, then global spaces.

function! s:HGGetOption(name, default)
  if exists("s:" . a:name . "Override")
    execute "return s:".a:name."Override"
  elseif exists("w:" . a:name)
    execute "return w:".a:name
  elseif exists("b:" . a:name)
    execute "return b:".a:name
  elseif exists("g:" . a:name)
    execute "return g:".a:name
  else
    return a:default
  endif
endfunction

" Function: s:HGEditFile(name, origBuffNR) {{{2
" Wrapper around the 'edit' command to provide some helpful error text if the
" current buffer can't be abandoned.  If name is provided, it is used;
" otherwise, a nameless scratch buffer is used.
" Returns: 0 if successful, -1 if an error occurs.

function! s:HGEditFile(name, origBuffNR)
  "Name parameter will be pasted into expression.
  let name = escape(a:name, ' *?\')

  let editCommand = s:HGGetOption('HGCommandEdit', 'edit')
  if editCommand != 'edit'
    if s:HGGetOption('HGCommandSplit', 'horizontal') == 'horizontal'
      if name == ""
        let editCommand = 'rightbelow new'
      else
        let editCommand = 'rightbelow split ' . name
      endif
    else
      if name == ""
        let editCommand = 'vert rightbelow new'
      else
        let editCommand = 'vert rightbelow split ' . name
      endif
    endif
  else
    if name == ""
      let editCommand = 'enew'
    else
      let editCommand = 'edit ' . name
    endif
  endif

  " Protect against useless buffer set-up
  let s:HGCommandEditFileRunning = s:HGCommandEditFileRunning + 1
  try
    execute editCommand
  finally
    let s:HGCommandEditFileRunning = s:HGCommandEditFileRunning - 1
  endtry

  let b:HGOrigBuffNR=a:origBuffNR
  let b:HGCommandEdit='split'
endfunction

" Function: s:HGCreateCommandBuffer(cmd, cmdName, statusText, filename) {{{2
" Creates a new scratch buffer and captures the output from execution of the
" given command.  The name of the scratch buffer is returned.

function! s:HGCreateCommandBuffer(cmd, cmdName, statusText, origBuffNR)
  let fileName=bufname(a:origBuffNR)

  let resultBufferName=''

  if s:HGGetOption("HGCommandNameResultBuffers", 0)
    let nameMarker = s:HGGetOption("HGCommandNameMarker", '_')
    if strlen(a:statusText) > 0
      let bufName=a:cmdName . ' -- ' . a:statusText
    else
      let bufName=a:cmdName
    endif
    let bufName=fileName . ' ' . nameMarker . bufName . nameMarker
    let counter=0
    let resultBufferName = bufName
    while buflisted(resultBufferName)
      let counter=counter + 1
      let resultBufferName=bufName . ' (' . counter . ')'
    endwhile
  endif

  let hgCommand = s:HGGetOption("HGCommandHGExec", "hg") . " " . a:cmd
  echomsg "DBG :".hgCommand
  let hgOut = system(hgCommand)
  " HACK:  diff command does not return proper error codes
  if v:shell_error && a:cmdName != 'hgdiff'
    if strlen(hgOut) == 0
      echoerr "HG command failed"
    else
      echoerr "HG command failed:  " . hgOut
    endif
    return -1
  endif
  if strlen(hgOut) == 0
    " Handle case of no output.  In this case, it is important to check the
    " file status, especially since hg edit/unedit may change the attributes
    " of the file with no visible output.

    echomsg "No output from HG command"
    checktime
    return -1
  endif

  if s:HGEditFile(resultBufferName, a:origBuffNR) == -1
    return -1
  endif

  set buftype=nofile
  set noswapfile
  set filetype=

  if s:HGGetOption("HGCommandDeleteOnHide", 0)
    set bufhidden=delete
  endif

  silent 0put=hgOut

  " The last command left a blank line at the end of the buffer.  If the
  " last line is folded (a side effect of the 'put') then the attempt to
  " remove the blank line will kill the last fold.
  "
  " This could be fixed by explicitly detecting whether the last line is
  " within a fold, but I prefer to simply unfold the result buffer altogether.

  if has('folding')
    normal zR
  endif

  $d
  1

  " Define the environment and execute user-defined hooks.

  let b:HGSourceFile=fileName
  let b:HGCommand=a:cmdName
  if a:statusText != ""
    let b:HGStatusText=a:statusText
  endif

  silent do HGCommand User HGBufferCreated
  return bufnr("%")
endfunction

" Function: s:HGBufferCheck(hgBuffer) {{{2
" Attempts to locate the original file to which HG operations were applied
" for a given buffer.

function! s:HGBufferCheck(hgBuffer)
  let origBuffer = getbufvar(a:hgBuffer, "HGOrigBuffNR")
  if origBuffer
    if bufexists(origBuffer)
      return origBuffer
    else
      " Original buffer no longer exists.
      return -1 
    endif
  else
    " No original buffer
    return a:hgBuffer
  endif
endfunction

" Function: s:HGCurrentBufferCheck() {{{2
" Attempts to locate the original file to which HG operations were applied
" for the current buffer.

function! s:HGCurrentBufferCheck()
  return s:HGBufferCheck(bufnr("%"))
endfunction

" Function: s:HGToggleDeleteOnHide() {{{2
" Toggles on and off the delete-on-hide behavior of HG buffers

function! s:HGToggleDeleteOnHide()
  if exists("g:HGCommandDeleteOnHide")
    unlet g:HGCommandDeleteOnHide
  else
    let g:HGCommandDeleteOnHide=1
  endif
endfunction

" Function: s:HGDoCommand(hgcmd, cmdName, statusText) {{{2
" General skeleton for HG function execution.
" Returns: name of the new command buffer containing the command results

function! s:HGDoCommand(cmd, cmdName, statusText)
  let hgBufferCheck=s:HGCurrentBufferCheck()
  if hgBufferCheck == -1 
    echo "Original buffer no longer exists, aborting."
    return -1
  endif

  let fileName=bufname(hgBufferCheck)
  if isdirectory(fileName)
    let fileName=fileName . "/" . getline(".")
  endif
  let realFileName = fnamemodify(s:HGResolveLink(fileName), ':t')
  let oldCwd=s:HGChangeToCurrentFileDir(fileName)
  try
     " TODO
    "if !filereadable('HG/Root')
      "throw fileName . ' is not a HG-controlled file.'
    "endif
    let fullCmd = a:cmd . ' "' . realFileName . '"'
    "echomsg "DEBUG".fullCmd
    let resultBuffer=s:HGCreateCommandBuffer(fullCmd, a:cmdName, a:statusText, hgBufferCheck)
    return resultBuffer
  catch
    echoerr v:exception
    return -1
  finally
    execute 'cd' escape(oldCwd, ' ')
  endtry
endfunction


" Function: s:HGGetStatusVars(revision, branch, repository) {{{2
"
" Obtains a HG revision number and branch name.  The 'revisionVar',
" 'branchVar'and 'repositoryVar' arguments, if non-empty, contain the names of variables to hold
" the corresponding results.
"
" Returns: string to be exec'd that sets the multiple return values.

function! s:HGGetStatusVars(revisionVar, branchVar, repositoryVar)
  let hgBufferCheck=s:HGCurrentBufferCheck()
  if hgBufferCheck == -1 
    return ""
  endif
  let fileName=bufname(hgBufferCheck)
  let realFileName = fnamemodify(s:HGResolveLink(fileName), ':t')
  let oldCwd=s:HGChangeToCurrentFileDir(fileName)
  try
     ""TODO
    "if !filereadable('HG/Root')
      "return ""
    "endif
    let hgCommand = s:HGGetOption("HGCommandHGExec", "hg") . " status -mardui " . fileName
    let statustext=system(hgCommand)
    if(v:shell_error)
      return ""
    endif
    if match(statustext, '^[?I]') >= 0 
      let revision="NEW"
    elseif match(statustext, '^[R]') >= 0 
      let revision="REMOVED"
    elseif match(statustext, '^[D]') >= 0 
      let revision="DELETED"
    elseif match(statustext, '^[A]') >= 0 
      let revision="ADDED"
    endif

    let hgCommand = s:HGGetOption("HGCommandHGExec", "hg") . " parents -b  " 
    let statustext=system(hgCommand)
    if(v:shell_error)
        return ""
    endif
    if exists('revision')
      let returnExpression = "let " . a:revisionVar . "='" . revision . "'"
    else
      let revision=substitute(statustext, '^changeset:\s*\(\d\+\):.*\_$\_.*$', '\1', "")
      let returnExpression = "let " . a:revisionVar . "='" . revision . "'"
    endif

    if a:branchVar != "" && match(statustext, '^\_.*\_^branch:') >= 0
      let branch=substitute(statustext, '^\_.*\_^branch:\s*\(\S\+\)\n\_.*$', '\1', "")
      let returnExpression=returnExpression . " | let " . a:branchVar . "='" . branch . "'"
    endif
    if a:repositoryVar != ""
      let hgCommand = s:HGGetOption("HGCommandHGExec", "hg") . " root  " 
      let roottext=system(hgCommand)
      let repository=substitute(roottext,'^.*/\([^/\n\r]*\)\n\_.*$','\1','')
      let returnExpression=returnExpression . " | let " . a:repositoryVar . "='" . repository . "'"
    endif



    return returnExpression
  finally
    execute 'cd' escape(oldCwd, ' ')
  endtry
endfunction

" Function: s:HGSetupBuffer() {{{2
" Attempts to set the b:HGBranch, b:HGRevision and b:HGRepository variables.

function! s:HGSetupBuffer()
  if (exists("b:HGBufferSetup") && b:HGBufferSetup)
    " This buffer is already set up.
    return
  endif

  if !s:HGGetOption("HGCommandEnableBufferSetup", 0)
        \ || @% == ""
        \ || s:HGCommandEditFileRunning > 0
        \ || exists("b:HGOrigBuffNR")
    unlet! b:HGRevision
    unlet! b:HGBranch
    unlet! b:HGRepository
    return
  endif

  if !filereadable(expand("%"))
    return -1
  endif

  let revision=""
  let branch=""
  let repository=""

  exec s:HGGetStatusVars('revision', 'branch', 'repository')
  "echomsg "DBG ".revision."#".branch."#".repository
  if revision != ""
    let b:HGRevision=revision
  else
    unlet! b:HGRevision
  endif
  if branch != ""
    let b:HGBranch=branch
  else
    unlet! b:HGBranch
  endif
  if repository != ""
     let b:HGRepository=repository
  else
     unlet! b:HGRepository
  endif
  silent do HGCommand User HGBufferSetup
  let b:HGBufferSetup=1
endfunction

" Function: s:HGMarkOrigBufferForSetup(hgbuffer) {{{2
" Resets the buffer setup state of the original buffer for a given HG buffer.
" Returns:  The HG buffer number in a passthrough mode.

function! s:HGMarkOrigBufferForSetup(hgBuffer)
  checktime
  if a:hgBuffer != -1
    let origBuffer = s:HGBufferCheck(a:hgBuffer)
    "This should never not work, but I'm paranoid
    if origBuffer != a:hgBuffer
      call setbufvar(origBuffer, "HGBufferSetup", 0)
    endif
  endif
  return a:hgBuffer
endfunction

" Function: s:HGOverrideOption(option, [value]) {{{2
" Provides a temporary override for the given HG option.  If no value is
" passed, the override is disabled.

function! s:HGOverrideOption(option, ...)
  if a:0 == 0
    unlet! s:{a:option}Override
  else
    let s:{a:option}Override = a:1
  endif
endfunction

" Function: s:HGWipeoutCommandBuffers() {{{2
" Clears all current HG buffers of the specified type for a given source.

function! s:HGWipeoutCommandBuffers(originalBuffer, hgCommand)
  let buffer = 1
  while buffer <= bufnr('$')
    if getbufvar(buffer, 'HGOrigBuffNR') == a:originalBuffer
      if getbufvar(buffer, 'HGCommand') == a:hgCommand
        execute 'bw' buffer
      endif
    endif
    let buffer = buffer + 1
  endwhile
endfunction

" Section: Public functions {{{1

" Function: HGGetRevision() {{{2
" Global function for retrieving the current buffer's HG revision number.
" Returns: Revision number or an empty string if an error occurs.

function! HGGetRevision()
  let revision=""
  exec s:HGGetStatusVars('revision', '', '')
  return revision
endfunction

" Function: HGDisableBufferSetup() {{{2
" Global function for deactivating the buffer autovariables.

function! HGDisableBufferSetup()
  let g:HGCommandEnableBufferSetup=0
  silent! augroup! HGCommandPlugin
endfunction

" Function: HGEnableBufferSetup() {{{2
" Global function for activating the buffer autovariables.

function! HGEnableBufferSetup()
  let g:HGCommandEnableBufferSetup=1
  augroup HGCommandPlugin
    au!
    au BufEnter * call s:HGSetupBuffer()
  augroup END

  " Only auto-load if the plugin is fully loaded.  This gives other plugins a
  " chance to run.
  if g:loaded_hgcommand == 2
    call s:HGSetupBuffer()
  endif
endfunction

" Function: HGGetStatusLine() {{{2
" Default (sample) status line entry for HG files.  This is only useful if
" HG-managed buffer mode is on (see the HGCommandEnableBufferSetup variable
" for how to do this).

function! HGGetStatusLine()
  if exists('b:HGSourceFile')
    " This is a result buffer
    let value='[' . b:HGCommand . ' ' . b:HGSourceFile
    if exists('b:HGStatusText')
      let value=value . ' ' . b:HGStatusText
    endif
    let value = value . ']'
    return value
  endif

  if exists('b:HGRevision')
        \ && b:HGRevision != ''
        \ && exists('b:HGBranch')
        \ && b:HGBranch != ''
        \ && exists('b:HGRepository')
        \ && b:HGRepository != ''
        \ && exists('g:HGCommandEnableBufferSetup')
        \ && g:HGCommandEnableBufferSetup
   return '[HG ' . b:HGRepository . '/' . b:HGBranch .'/' . b:HGRevision . ']'
  else
    return ''
  endif
endfunction

" Section: HG command functions {{{1

" Function: s:HGAdd() {{{2
function! s:HGAdd()
  return s:HGMarkOrigBufferForSetup(s:HGDoCommand('add', 'hgadd', ''))
endfunction

" Function: s:HGAnnotate(...) {{{2
function! s:HGAnnotate(...)
  if a:0 == 0
    if &filetype == "HGAnnotate"
      " This is a HGAnnotate buffer.  Perform annotation of the version
      " indicated by the current line.
      let revision = substitute(getline("."),'\(^[0-9]*\):.*','\1','')
      if s:HGGetOption('HGCommandAnnotateParent', 0) != 0 && revision > 0
        let revision = revision - 1
      endif
    else
      let revision=HGGetRevision()
      if revision == ""
        echoerr "Unable to obtain HG version information."
        return -1
      endif
    endif
  else
    let revision=a:1
  endif

  if revision == "NEW"
    echo "No annotatation available for new file."
    return -1
  endif

  let resultBuffer=s:HGDoCommand('annotate -ndu -r ' . revision, 'hgannotate', revision) 
  echomsg "DBG: ".resultBuffer
  if resultBuffer !=  -1
    set filetype=HGAnnotate
  endif

  return resultBuffer
endfunction

" Function: s:HGCommit() {{{2
function! s:HGCommit(...)
  " Handle the commit message being specified.  If a message is supplied, it
  " is used; if bang is supplied, an empty message is used; otherwise, the
  " user is provided a buffer from which to edit the commit message.
  if a:2 != "" || a:1 == "!"
    return s:HGMarkOrigBufferForSetup(s:HGDoCommand('commit -m "' . a:2 . '"', 'hgcommit', ''))
  endif

  let hgBufferCheck=s:HGCurrentBufferCheck()
  if hgBufferCheck ==  -1
    echo "Original buffer no longer exists, aborting."
    return -1
  endif

  " Protect against windows' backslashes in paths.  They confuse exec'd
  " commands.

  let shellSlashBak = &shellslash
  try
    set shellslash

    let messageFileName = tempname()

    let fileName=bufname(hgBufferCheck)
    let realFilePath=s:HGResolveLink(fileName)
    let newCwd=fnamemodify(realFilePath, ':h')
    if strlen(newCwd) == 0
      " Account for autochdir being in effect, which will make this blank, but
      " we know we'll be in the current directory for the original file.
      let newCwd = getcwd()
    endif

    let realFileName=fnamemodify(realFilePath, ':t')

    if s:HGEditFile(messageFileName, hgBufferCheck) == -1
      return
    endif

    " Protect against case and backslash issues in Windows.
    let autoPattern = '\c' . messageFileName

    " Ensure existance of group
    augroup HGCommit
    augroup END

    execute 'au HGCommit BufDelete' autoPattern 'call delete("' . messageFileName . '")'
    execute 'au HGCommit BufDelete' autoPattern 'au! HGCommit * ' autoPattern

    " Create a commit mapping.  The mapping must clear all autocommands in case
    " it is invoked when HGCommandCommitOnWrite is active, as well as to not
    " invoke the buffer deletion autocommand.

    execute 'nnoremap <silent> <buffer> <Plug>HGCommit '.
          \ ':au! HGCommit * ' . autoPattern . '<CR>'.
          \ ':g/^HG:/d<CR>'.
          \ ':update<CR>'.
          \ ':call <SID>HGFinishCommit("' . messageFileName . '",' .
          \                             '"' . newCwd . '",' .
          \                             '"' . realFileName . '",' .
          \                             hgBufferCheck . ')<CR>'

    silent 0put ='HG: ----------------------------------------------------------------------'
    silent put =\"HG: Enter Log.  Lines beginning with `HG:' are removed automatically\"
    silent put ='HG: Type <leader>cc (or your own <Plug>HGCommit mapping)'

    if s:HGGetOption('HGCommandCommitOnWrite', 1) == 1
      execute 'au HGCommit BufWritePre' autoPattern 'g/^HG:/d'
      execute 'au HGCommit BufWritePost' autoPattern 'call s:HGFinishCommit("' . messageFileName . '", "' . newCwd . '", "' . realFileName . '", ' . hgBufferCheck . ') | au! * ' autoPattern
      silent put ='HG: or write this buffer'
    endif

    silent put ='HG: to finish this commit operation'
    silent put ='HG: ----------------------------------------------------------------------'
    $
    let b:HGSourceFile=fileName
    let b:HGCommand='HGCommit'
    set filetype=hg
  finally
    let &shellslash = shellSlashBak
  endtry

endfunction

" Function: s:HGDiff(...) {{{2
function! s:HGDiff(...)
  if a:0 == 1
    let revOptions = '-r' . a:1
    let caption = a:1 . ' -> current'
  elseif a:0 == 2
    let revOptions = '-r' . a:1 . ' -r' . a:2
    let caption = a:1 . ' -> ' . a:2
  else
    let revOptions = ''
    let caption = ''
  endif

  let hgdiffopt=s:HGGetOption('HGCommandDiffOpt', 'w')

  if hgdiffopt == ""
    let diffoptionstring=""
  else
    let diffoptionstring=" -" . hgdiffopt . " "
  endif

  let resultBuffer = s:HGDoCommand('diff ' . diffoptionstring . revOptions , 'hgdiff', caption)
  if resultBuffer != -1 
    set filetype=diff
  endif
  return resultBuffer
endfunction


" Function: s:HGGotoOriginal(["!]) {{{2
function! s:HGGotoOriginal(...)
  let origBuffNR = s:HGCurrentBufferCheck()
  if origBuffNR > 0
    let origWinNR = bufwinnr(origBuffNR)
    if origWinNR == -1
      execute 'buffer' origBuffNR
    else
      execute origWinNR . 'wincmd w'
    endif
    if a:0 == 1
      if a:1 == "!"
        let buffnr = 1
        let buffmaxnr = bufnr("$")
        while buffnr <= buffmaxnr
          if getbufvar(buffnr, "HGOrigBuffNR") == origBuffNR
            execute "bw" buffnr
          endif
          let buffnr = buffnr + 1
        endwhile
      endif
    endif
  endif
endfunction

" Function: s:HGFinishCommit(messageFile, targetDir, targetFile) {{{2
function! s:HGFinishCommit(messageFile, targetDir, targetFile, origBuffNR)
  if filereadable(a:messageFile)
    let oldCwd=getcwd()
    if strlen(a:targetDir) > 0
      execute 'cd' escape(a:targetDir, ' ')
    endif
    let resultBuffer=s:HGCreateCommandBuffer('commit -F "' . a:messageFile . '" "'. a:targetFile . '"', 'hgcommit', '', a:origBuffNR)
    execute 'cd' escape(oldCwd, ' ')
    execute 'bw' escape(a:messageFile, ' *?\')
    silent execute 'call delete("' . a:messageFile . '")'
    return s:HGMarkOrigBufferForSetup(resultBuffer)
  else
    echoerr "Can't read message file; no commit is possible."
    return -1
  endif
endfunction

" Function: s:HGLog() {{{2
function! s:HGLog(...)
  if a:0 == 0
    let versionOption = ""
    let caption = ''
  else
    let versionOption=" -r" . a:1
    let caption = a:1
  endif

  let resultBuffer=s:HGDoCommand('log' . versionOption, 'hglog', caption)
  if resultBuffer != ""
    set filetype=rcslog
  endif
  return resultBuffer
endfunction

" Function: s:HGRevert() {{{2
function! s:HGRevert()
  return s:HGMarkOrigBufferForSetup(s:HGDoCommand('revert', 'hgrevert', ''))
endfunction

" Function: s:HGReview(...) {{{2
function! s:HGReview(...)
  if a:0 == 0
    let versiontag=""
    if s:HGGetOption('HGCommandInteractive', 0)
      let versiontag=input('Revision:  ')
    endif
    if versiontag == ""
      let versiontag="(current)"
      let versionOption=""
    else
      let versionOption=" -r " . versiontag . " "
    endif
  else
    let versiontag=a:1
    let versionOption=" -r " . versiontag . " "
  endif

  let resultBuffer = s:HGDoCommand('cat' . versionOption, 'hgreview', versiontag)
  if resultBuffer > 0
    let &filetype=getbufvar(b:HGOrigBuffNR, '&filetype')
  endif

  return resultBuffer
endfunction

" Function: s:HGStatus() {{{2
function! s:HGStatus()
  return s:HGDoCommand('status', 'hgstatus', '')
endfunction


" Function: s:HGUpdate() {{{2
function! s:HGUpdate()
  return s:HGMarkOrigBufferForSetup(s:HGDoCommand('update', 'update', ''))
endfunction

" Function: s:HGVimDiff(...) {{{2
function! s:HGVimDiff(...)
  let originalBuffer = s:HGCurrentBufferCheck()
  let s:HGCommandEditFileRunning = s:HGCommandEditFileRunning + 1
  try
    " If there's already a VimDiff'ed window, restore it.
    " There may only be one HGVimDiff original window at a time.

    if exists("s:vimDiffSourceBuffer") && s:vimDiffSourceBuffer != originalBuffer
      " Clear the existing vimdiff setup by removing the result buffers.
      call s:HGWipeoutCommandBuffers(s:vimDiffSourceBuffer, 'vimdiff')
    endif

    " Split and diff
    if(a:0 == 2)
      " Reset the vimdiff system, as 2 explicit versions were provided.
      if exists('s:vimDiffSourceBuffer')
        call s:HGWipeoutCommandBuffers(s:vimDiffSourceBuffer, 'vimdiff')
      endif
      let resultBuffer = s:HGReview(a:1)
      if resultBuffer < 0
        echomsg "Can't open HG revision " . a:1
        return resultBuffer
      endif
      let b:HGCommand = 'vimdiff'
      diffthis
      let s:vimDiffBufferCount = 1
      let s:vimDiffScratchList = '{'. resultBuffer . '}'
      " If no split method is defined, cheat, and set it to vertical.
      try
        call s:HGOverrideOption('HGCommandSplit', s:HGGetOption('HGCommandDiffSplit', s:HGGetOption('HGCommandSplit', 'vertical')))
        let resultBuffer=s:HGReview(a:2)
      finally
        call s:HGOverrideOption('HGCommandSplit')
      endtry
      if resultBuffer < 0
        echomsg "Can't open HG revision " . a:1
        return resultBuffer
      endif
      let b:HGCommand = 'vimdiff'
      diffthis
      let s:vimDiffBufferCount = 2
      let s:vimDiffScratchList = s:vimDiffScratchList . '{'. resultBuffer . '}'
    else
      " Add new buffer
      try
        " Force splitting behavior, otherwise why use vimdiff?
        call s:HGOverrideOption("HGCommandEdit", "split")
        call s:HGOverrideOption("HGCommandSplit", s:HGGetOption('HGCommandDiffSplit', s:HGGetOption('HGCommandSplit', 'vertical')))
        if(a:0 == 0)
          let resultBuffer=s:HGReview()
        else
          let resultBuffer=s:HGReview(a:1)
        endif
      finally
        call s:HGOverrideOption("HGCommandEdit")
        call s:HGOverrideOption("HGCommandSplit")
      endtry
      if resultBuffer < 0
        echomsg "Can't open current HG revision"
        return resultBuffer
      endif
      let b:HGCommand = 'vimdiff'
      diffthis

      if !exists('s:vimDiffBufferCount')
        " New instance of vimdiff.
        let s:vimDiffBufferCount = 2
        let s:vimDiffScratchList = '{' . resultBuffer . '}'

        " This could have been invoked on a HG result buffer, not the
        " original buffer.
        wincmd W
        execute 'buffer' originalBuffer
        " Store info for later original buffer restore
        let s:vimDiffRestoreCmd = 
              \    "call setbufvar(".originalBuffer.", \"&diff\", ".getbufvar(originalBuffer, '&diff').")"
              \ . "|call setbufvar(".originalBuffer.", \"&foldcolumn\", ".getbufvar(originalBuffer, '&foldcolumn').")"
              \ . "|call setbufvar(".originalBuffer.", \"&foldenable\", ".getbufvar(originalBuffer, '&foldenable').")"
              \ . "|call setbufvar(".originalBuffer.", \"&foldmethod\", '".getbufvar(originalBuffer, '&foldmethod')."')"
              \ . "|call setbufvar(".originalBuffer.", \"&scrollbind\", ".getbufvar(originalBuffer, '&scrollbind').")"
              \ . "|call setbufvar(".originalBuffer.", \"&wrap\", ".getbufvar(originalBuffer, '&wrap').")"
              \ . "|if &foldmethod=='manual'|execute 'normal zE'|endif"
        diffthis
        wincmd w
      else
        " Adding a window to an existing vimdiff
        let s:vimDiffBufferCount = s:vimDiffBufferCount + 1
        let s:vimDiffScratchList = s:vimDiffScratchList . '{' . resultBuffer . '}'
      endif
    endif

    let s:vimDiffSourceBuffer = originalBuffer

    " Avoid executing the modeline in the current buffer after the autocommand.

    let currentBuffer = bufnr('%')
    let saveModeline = getbufvar(currentBuffer, '&modeline')
    try
      call setbufvar(currentBuffer, '&modeline', 0)
      silent do HGCommand User HGVimDiffFinish
    finally
      call setbufvar(currentBuffer, '&modeline', saveModeline)
    endtry
    return resultBuffer
  finally
    let s:HGCommandEditFileRunning = s:HGCommandEditFileRunning - 1
  endtry
endfunction

" Section: Command definitions {{{1
" Section: Primary commands {{{2
com! HGAdd call s:HGAdd()
com! -nargs=? HGAnnotate call s:HGAnnotate(<f-args>)
com! -bang -nargs=? HGCommit call s:HGCommit(<q-bang>, <q-args>)
com! -nargs=* HGDiff call s:HGDiff(<f-args>)
com! -bang HGGotoOriginal call s:HGGotoOriginal(<q-bang>)
com! -nargs=? HGLog call s:HGLog(<f-args>)
com! HGRevert call s:HGRevert()
com! -nargs=? HGReview call s:HGReview(<f-args>)
com! HGStatus call s:HGStatus()
com! HGUpdate call s:HGUpdate()
com! -nargs=* HGVimDiff call s:HGVimDiff(<f-args>)

" Section: HG buffer management commands {{{2
com! HGDisableBufferSetup call HGDisableBufferSetup()
com! HGEnableBufferSetup call HGEnableBufferSetup()

" Allow reloading hgcommand.vim
com! HGReload unlet! loaded_hgcommand | runtime plugin/hgcommand.vim

" Section: Plugin command mappings {{{1
nnoremap <silent> <Plug>HGAdd :HGAdd<CR>
nnoremap <silent> <Plug>HGAnnotate :HGAnnotate<CR>
nnoremap <silent> <Plug>HGCommit :HGCommit<CR>
nnoremap <silent> <Plug>HGDiff :HGDiff<CR>
nnoremap <silent> <Plug>HGGotoOriginal :HGGotoOriginal<CR>
nnoremap <silent> <Plug>HGClearAndGotoOriginal :HGGotoOriginal!<CR>
nnoremap <silent> <Plug>HGLog :HGLog<CR>
nnoremap <silent> <Plug>HGRevert :HGRevert<CR>
nnoremap <silent> <Plug>HGReview :HGReview<CR>
nnoremap <silent> <Plug>HGStatus :HGStatus<CR>
nnoremap <silent> <Plug>HGUpdate :HGUpdate<CR>
nnoremap <silent> <Plug>HGVimDiff :HGVimDiff<CR>
nnoremap <silent> <Plug>HGWatchers :HGWatchers<CR>
nnoremap <silent> <Plug>HGWatchAdd :HGWatchAdd<CR>
nnoremap <silent> <Plug>HGWatchOn :HGWatchOn<CR>
nnoremap <silent> <Plug>HGWatchOff :HGWatchOff<CR>
nnoremap <silent> <Plug>HGWatchRemove :HGWatchRemove<CR>

" Section: Default mappings {{{1
if !hasmapto('<Plug>HGAdd')
  nmap <unique> <Leader>hga <Plug>HGAdd
endif
if !hasmapto('<Plug>HGAnnotate')
  nmap <unique> <Leader>hgn <Plug>HGAnnotate
endif
if !hasmapto('<Plug>HGClearAndGotoOriginal')
  nmap <unique> <Leader>hgG <Plug>HGClearAndGotoOriginal
endif
if !hasmapto('<Plug>HGCommit')
  nmap <unique> <Leader>hgc <Plug>HGCommit
endif
if !hasmapto('<Plug>HGDiff')
  nmap <unique> <Leader>hgd <Plug>HGDiff
endif
if !hasmapto('<Plug>HGGotoOriginal')
  nmap <unique> <Leader>hgg <Plug>HGGotoOriginal
endif
if !hasmapto('<Plug>HGLog')
  nmap <unique> <Leader>hgl <Plug>HGLog
endif
if !hasmapto('<Plug>HGRevert')
  nmap <unique> <Leader>hgq <Plug>HGRevert
endif
if !hasmapto('<Plug>HGReview')
  nmap <unique> <Leader>hgr <Plug>HGReview
endif
if !hasmapto('<Plug>HGStatus')
  nmap <unique> <Leader>hgs <Plug>HGStatus
endif
if !hasmapto('<Plug>HGUpdate')
  nmap <unique> <Leader>hgu <Plug>HGUpdate
endif
if !hasmapto('<Plug>HGVimDiff')
  nmap <unique> <Leader>hgv <Plug>HGVimDiff
endif

" Section: Menu items {{{1
silent! aunmenu Plugin.HG
amenu <silent> &Plugin.HG.&Add        <Plug>HGAdd
amenu <silent> &Plugin.HG.A&nnotate   <Plug>HGAnnotate
amenu <silent> &Plugin.HG.&Commit     <Plug>HGCommit
amenu <silent> &Plugin.HG.&Diff       <Plug>HGDiff
amenu <silent> &Plugin.HG.&Log        <Plug>HGLog
amenu <silent> &Plugin.HG.Revert      <Plug>HGRevert
amenu <silent> &Plugin.HG.&Review     <Plug>HGReview
amenu <silent> &Plugin.HG.&Status     <Plug>HGStatus
amenu <silent> &Plugin.HG.&Update     <Plug>HGUpdate
amenu <silent> &Plugin.HG.&VimDiff    <Plug>HGVimDiff
amenu <silent> &Plugin.HG.&Watchers   <Plug>HGWatchers
amenu <silent> &Plugin.HG.WatchAdd    <Plug>HGWatchAdd
amenu <silent> &Plugin.HG.WatchOn     <Plug>HGWatchOn
amenu <silent> &Plugin.HG.WatchOff    <Plug>HGWatchOff
amenu <silent> &Plugin.HG.WatchRemove <Plug>HGWatchRemove

" Section: Autocommands to restore vimdiff state {{{1
function! s:HGVimDiffRestore(vimDiffBuff)
  let s:HGCommandEditFileRunning = s:HGCommandEditFileRunning + 1
  try
    if exists("s:vimDiffSourceBuffer")
      if a:vimDiffBuff == s:vimDiffSourceBuffer
        " Original file is being removed.
        unlet! s:vimDiffSourceBuffer
        unlet! s:vimDiffBufferCount
        unlet! s:vimDiffRestoreCmd
        unlet! s:vimDiffScratchList
      elseif match(s:vimDiffScratchList, '{' . a:vimDiffBuff . '}') >= 0
        let s:vimDiffScratchList = substitute(s:vimDiffScratchList, '{' . a:vimDiffBuff . '}', '', '')
        let s:vimDiffBufferCount = s:vimDiffBufferCount - 1
        if s:vimDiffBufferCount == 1 && exists('s:vimDiffRestoreCmd')
          " All scratch buffers are gone, reset the original.
          " Only restore if the source buffer is still in Diff mode

          let sourceWinNR=bufwinnr(s:vimDiffSourceBuffer)
          if sourceWinNR != -1
            " The buffer is visible in at least one window
            let currentWinNR = winnr()
            while winbufnr(sourceWinNR) != -1
              if winbufnr(sourceWinNR) == s:vimDiffSourceBuffer
                execute sourceWinNR . 'wincmd w'
                if getwinvar('', "&diff")
                  execute s:vimDiffRestoreCmd
                endif
              endif
              let sourceWinNR = sourceWinNR + 1
            endwhile
            execute currentWinNR . 'wincmd w'
          else
            " The buffer is hidden.  It must be visible in order to set the
            " diff option.
            let currentBufNR = bufnr('')
            execute "hide buffer" s:vimDiffSourceBuffer
            if getwinvar('', "&diff")
              execute s:vimDiffRestoreCmd
            endif
            execute "hide buffer" currentBufNR
          endif

          unlet s:vimDiffRestoreCmd
          unlet s:vimDiffSourceBuffer
          unlet s:vimDiffBufferCount
          unlet s:vimDiffScratchList
        elseif s:vimDiffBufferCount == 0
          " All buffers are gone.
          unlet s:vimDiffSourceBuffer
          unlet s:vimDiffBufferCount
          unlet s:vimDiffScratchList
        endif
      endif
    endif
  finally
    let s:HGCommandEditFileRunning = s:HGCommandEditFileRunning - 1
  endtry
endfunction

augroup HGVimDiffRestore
  au!
  au BufUnload * call s:HGVimDiffRestore(expand("<abuf>"))
augroup END

" Section: Optional activation of buffer management {{{1

if s:HGGetOption('HGCommandEnableBufferSetup', 0)
  call HGEnableBufferSetup()
endif

" Section: Plugin completion {{{1

let loaded_hgcommand=2
silent do HGCommand User HGPluginFinish
" vim:se expandtab sts=2 sw=2:
