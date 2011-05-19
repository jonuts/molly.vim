" ============================================================================
" File:        molly.vim
" Description: Speed is key!
" Maintainer:  William Estoque <william.estoque at gmail dot com>
" License:     MIT
"
" ============================================================================
if exists("g:loaded_Molly") || &cp
  finish
endif
let g:loaded_Molly = 1
let s:Molly_version = '0.0.3'
let s:bufferOpen = 0

if !exists("g:MollyMaxSort")
  let g:MollyMaxSort = 750
endif

command -nargs=? -complete=dir Molly call <SID>MollyController()
silent! nmap <unique> <silent> <Leader>x :Molly<CR>

function! s:MollyController()
  if s:bufferOpen
    call s:ShowBuffer()
  else
    let s:bufferOpen = 1
    execute "sp molly"
    call s:BindKeys()
    call s:SetLocals()
    if !exists("s:mollyrunonce")
      call s:MollySetup()
      let s:mollyrunonce = 1
    endif
    call s:WriteToBuffer(s:filteredlist)
  endif
endfunction

function s:MollySetup()
  let s:filelist = split(globpath(".", "**"), "\n")
  call s:ResetGlobals()
endfunction

function s:ResetGlobals()
  let s:query = ""
  let s:badlist = []
  let s:filteredlist = copy(s:filelist)
endfunction

function s:BindKeys()
  let asciilist = range(97,122)
  let asciilist = extend(asciilist, range(32,47))
  let asciilist = extend(asciilist, range(58,90))
  let asciilist = extend(asciilist, [91,92,93,95,96,123,125,126])

  let specialChars = {
    \  '<BS>'    : 'Backspace',
    \  '<Del>'   : 'Delete',
    \  '<CR>'    : 'AcceptSelection',
    \  '<C-t>'   : 'AcceptSelectionTab',
    \  '<C-v>'   : 'AcceptSelectionVSplit',
    \  '<C-CR>'  : 'AcceptSelectionSplit',
    \  '<C-s>'   : 'AcceptSelectionSplit',
    \  '<Tab>'   : 'ToggleFocus',
    \  '<C-c>'   : 'Cancel',
    \  '<Esc>'   : 'Cancel',
    \  '<C-u>'   : 'Clear',
    \  '<C-e>'   : 'CursorEnd',
    \  '<C-a>'   : 'CursorStart',
    \  '<C-n>'   : 'SelectNext',
    \  '<C-j>'   : 'SelectNext',
    \  '<Down>'  : 'SelectNext',
    \  '<C-k>'   : 'SelectPrev',
    \  '<C-p>'   : 'SelectPrev',
    \  '<Up>'    : 'SelectPrev',
    \  '<C-h>'   : 'CursorLeft',
    \  '<Left>'  : 'CursorLeft',
    \  '<C-l>'   : 'CursorRight',
    \  '<Right>' : 'CursorRight',
    \  '<C-r>'   : 'Reload'
  \}

  for n in asciilist
    execute "noremap <buffer> <silent>" . "<Char-" . n . "> :call <sid>HandleKey('" . nr2char(n) . "')<CR>"
  endfor

  for key in keys(specialChars)
    execute "noremap <buffer> <silent>" . key  . " :call <sid>HandleKey" . specialChars[key] . "()<CR>"
  endfor
endfunction

function s:HandleKey(key)
  let s:query = s:query . a:key
  call add(s:badlist, [])

  call s:ExecuteQuery()
endfunction

function s:HandleKeyReload()
  call s:HandleKeyCancel()
  call s:MollySetup()
  call s:MollyController()
endfunction

function s:HandleKeySelectNext()
  call setpos(".", [0, line(".") + 1, 1, 0])
endfunction

function s:HandleKeySelectPrev()
  call setpos(".", [0, line(".") - 1, 1, 0])
endfunction

function s:HandleKeyCursorLeft()
  echo "left"
endfunction

function s:HandleKeyCursorRight()
  echo "right"
endfunction

function s:HandleKeyBackspace()
  if len(s:query) <= 0
    return 0
  endif

  let s:query = strpart(s:query, 0, strlen(s:query) - 1)
  let lastbads = remove(s:badlist, -1)
  let s:filteredlist += lastbads

  call s:ExecuteQuery()
endfunction

function s:HandleKeyCancel()
  call s:ResetGlobals()
  call s:HideBuffer()
endfunction

function s:AcceptSelection(action)
  let filename = getline(".")
  call s:HideBuffer()
  execute a:action . " " . filename
  unlet filename
  call s:ResetGlobals()
endfunction

function s:HandleKeyAcceptSelection()
  call s:AcceptSelection("e")
endfunction

function s:HandleKeyAcceptSelectionVSplit()
  call s:AcceptSelection("vs")
endfunction

function s:HandleKeyAcceptSelectionSplit()
  call s:AcceptSelection("sp")
endfunction

function s:HandleKeyAcceptSelectionTab()
  let filename = getline(".")
  call s:HideBuffer()
  execute "tabnew"
  execute "e " . filename
  unlet filename
  call s:ResetGlobals()
endfunction

function s:SetLocals()
  setlocal bufhidden=hide
  setlocal buftype=nowrite
  setlocal noswapfile
  setlocal nowrap
  setlocal nonumber
  setlocal nolist
  setlocal foldcolumn=0
  setlocal foldlevel=99
  setlocal nospell
  setlocal nobuflisted
  setlocal textwidth=0
  setlocal cursorline
endfunction

function s:ClearBuffer()
  execute ":1,$d"
endfunction

function s:HideBuffer()
  execute ":hid"
endfunction

function s:ShowBuffer()
  execute ":sb molly"
endfunction

function s:ExecuteQuery()
  let querycharlist = split(s:query, '\zs')
  let matcher = join(querycharlist, '.*')
  let filesorter = {}
  let sortedlist = []
  let dosort = len(s:filteredlist) <= g:MollyMaxSort

  " Filter out filenames that do not match
  let index = 0
  for name in s:filteredlist
    if split(name, "\/")[-1] !~# matcher
      call add(s:badlist[-1], name)
      call remove(s:filteredlist, index)
    else
      let index += 1

      if dosort
        let matchkey = 1000 - s:MatchLen(name)

        if has_key(filesorter, matchkey)
          call add(filesorter[matchkey], name)
        else
          let filesorter[matchkey] = [name]
        endif
      end
    endif
  endfor

  if dosort
    for filelist in values(filesorter)
      let sortedlist += sort(filelist)
    endfor

    call s:WriteToBuffer(sortedlist)
  else
    call s:WriteToBuffer(s:filteredlist)
  endif

  unlet sortedlist
  unlet filesorter
  unlet querycharlist

  echo ">> " . s:query
endfunction

function s:MatchLen(input)
  let maxvalue = 0
  let table = []
  let inputlen = len(a:input)
  let matchlen = len(s:query)

  for i in range(0, inputlen)
    call add(table, repeat([0], matchlen))
  endfor

  let input = split(a:input, '\zs')
  let matcher = split(s:query,  '\zs')

  for i in range(1, inputlen-1)
    let hasmatch = 0

    for j in range(1, matchlen-1)
      if input[i] == matcher[j]
        let hasmatch = 1
        let table[i][j] = (table[i-1][j-1] + 1)

        if table[i][j] > maxvalue
          let maxvalue = table[i][j]
        endif
      endif
    endfor

    " Stop searching for maxvalue if it is not possible for it to be any
    " greater.
    if !hasmatch && maxvalue >= inputlen - i - 1
      break
    endif
  endfor

  unlet table
  unlet input
  unlet matcher

  return maxvalue
endfunction

function s:WriteToBuffer(files)
  call s:ClearBuffer()
  call setline(".", a:files)
endfunction
