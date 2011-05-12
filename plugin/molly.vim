" ============================================================================
" File:        molly.vim
" Description: Speed is key!
" Maintainer:  William Estoque <william.estoque at gmail dot com>
" Last Change: 23 March, 2010
" License:     MIT
"
" ============================================================================
let s:Molly_version = '0.0.2'

if !exists("g:MollyMaxSort")
  let g:MollyMaxSort = 750
endif

command -nargs=? -complete=dir Molly call <SID>MollyController()
silent! nmap <unique> <silent> <Leader>x :Molly<CR>

let s:query = ""

function! s:MollyController()
  execute "sp molly"
  call BindKeys()
  call SetLocals()
  let s:filelist = split(system('find . ! -regex ".*/\..*" -type f -print'), "\n")
  let s:badlist = []
  call WriteToBuffer(s:filelist)
endfunction

function BindKeys()
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
    \  '<Right>' : 'CursorRight'
  \}

  for n in asciilist
    execute "noremap <buffer> <silent>" . "<Char-" . n . "> :call HandleKey('" . nr2char(n) . "')<CR>"
  endfor

  for key in keys(specialChars)
    execute "noremap <buffer> <silent>" . key  . " :call HandleKey" . specialChars[key] . "()<CR>"
  endfor
endfunction

function HandleKey(key)
  let s:query = s:query . a:key
  call add(s:badlist, [])

  call ExecuteQuery()
endfunction

function HandleKeySelectNext()
  call setpos(".", [0, line(".") + 1, 1, 0])
endfunction

function HandleKeySelectPrev()
  call setpos(".", [0, line(".") - 1, 1, 0])
endfunction

function HandleKeyCursorLeft()
  echo "left"
endfunction

function HandleKeyCursorRight()
  echo "right"
endfunction

function HandleKeyBackspace()
  if !len(s:query)
    return 0
  endif

  let s:query = strpart(s:query, 0, strlen(s:query) - 1)
  let lastbads = remove(s:badlist, -1)
  let s:filelist += lastbads

  call ExecuteQuery()
endfunction

function HandleKeyCancel()
  let s:query = ""
  execute "q!"
endfunction

function HandleKeyAcceptSelection()
  let filename = getline(".")
  execute "q!"
  execute "e " . filename
  unlet filename
  let s:query = ""
endfunction

function HandleKeyAcceptSelectionVSplit()
  let filename = getline(".")
  execute "q!"
  execute "vs " . filename
  unlet filename
  let s:query = ""
endfunction

function HandleKeyAcceptSelectionSplit()
  let filename = getline(".")
  execute "q!"
  execute "sp " . filename
  unlet filename
  let s:query = ""
endfunction

function ClearBuffer()
  execute ":1,$d"
endfunction

function SetLocals()
  setlocal bufhidden=wipe
  setlocal buftype=nofile
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

function ExecuteQuery()
  let querycharlist = split(s:query, '\zs')
  let matcher = join(querycharlist, '.*')
  let filesorter = {}
  let sortedlist = []
  let dosort = len(s:filelist) <= g:MollyMaxSort

  " Filter out filenames that do not match
  let index = 0
  for name in s:filelist
    if split(name, "\/")[-1] !~# matcher
      call add(s:badlist[-1], name)
      call remove(s:filelist, index)
    else
      let index += 1

      if dosort
        let matchkey = 1000 - MatchLen(name)

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

    call WriteToBuffer(sortedlist)
  else
    call WriteToBuffer(s:filelist)
  endif

  unlet sortedlist
  unlet filesorter
  unlet querycharlist

  echo ">> " . s:query
endfunction

function MatchLen(input)
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

function WriteToBuffer(files)
  call ClearBuffer()
  call setline(".", a:files)
endfunction
