"###### LICENSE [ {{{ ]
"-
" Copyright 2008 (c) J. McConnell
" All rights reserved.
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.
"###### [ }}} ]

"###### PROLOG [ {{{ ]
try
  if !gatekeeper#Guard("b:sql_chimp", "1.0.0")
    finish
  endif
catch /^Vim\%((\a\+)\)\=:E117/
  if exists("b:sql_chimp_loaded")
    finish
  endif
  let b:sql_chimp_loaded = "1.0.0"
endtry

let s:save_cpo = &cpo
set cpo&vim
"###### [ }}} ]

"###### VARIABLES [ {{{ ]
"###### [ }}} ]

"###### FUNCTIONS [ {{{ ]
"#### Plugs & Mappings [ {{{ ]
function! s:MakePlug(mode, plug, f)
  execute a:mode . "noremap <Plug>SqlChimp" . a:plug
        \ . " :call <SID>" . a:f . "<CR>"
endfunction

function! s:MapPlug(mode, keys, plug)
  if !hasmapto("<Plug>SqlChimp" . a:plug)
    execute a:mode . "map <buffer> <unique> <silent> <LocalLeader>" . a:keys
          \ . " <Plug>SqlChimp" . a:plug
  endif
endfunction
"#### [ }}} ]
"#### Support Functions [ {{{ ]
function! s:SynItem()
  return synIDattr(synID(line("."), col("."), 0), "name")
endfunction

function! s:WithSaved(closure)
  let v = a:closure.get(a:closure.tosafe)
  let r = a:closure.f()
  call a:closure.set(a:closure.tosafe, v)
  return r
endfunction

function! s:WithSavedRegister(reg, closure)
  let a:closure['tosafe'] = a:reg
  let a:closure['get'] = function("getreg")
  let a:closure['set'] = function("setreg")
  return s:WithSaved(a:closure)
endfunction

function! s:WithSavedPosition(closure)
  let a:closure['tosafe'] = "."
  let a:closure['get'] = function("getpos")
  let a:closure['set'] = function("setpos")
  return s:WithSaved(a:closure)
endfunction

function! s:Yank(reg, how)
  let closure = {'register': a:reg, 'yank': a:how}

  function closure.f() dict
    execute self.yank
    return getreg(self.register)
  endfunction

  return s:WithSavedRegister(a:reg, closure)
endfunction
"#### [ }}} ]
"#### Worker Functions [ {{{ ]
function! s:Connect()
  if !exists("s:ChimpId")
    let s:ChimpId = input("Please give Chimp Id: ")
  endif
endfunction

function! s:ResetChimp()
  unlet s:ChimpId
  call s:Connect()
endfunction

function! s:GetBufferNamespaceWorker() dict
  if search('^(\(clojure/\)\=\(in-\)\=ns', "b") == 0
    if search('^(\(clojure/\)\=\(in-\)\=ns') == 0
      return "user"
    endif
  endif

  " Try again if we are in a comment.
  if s:SynItem() == "sqlComment"
    return self.f()
  end

  normal W
  return substitute(s:Yank('l', 'normal "lye'), "^'", "", "")
endfunction

function! s:SendStatement() dict
  call s:Connect()

  if search('[;/]$', 'nW') > 0
    execute 'normal me'
    while search('^\s*\a', 'bW') > 0
      if s:SynItem() == "sqlStatement"
        let st = s:Yank('l', 'normal "ly''e')
        call chimp#SendMessage(s:ChimpId, st)
      endif
    endwhile
  endif
endfunction

function! s:EvalStatement() range
  call s:WithSavedPosition({'f': function("s:SendStatement"), 'flags': ''})
endfunction

function! s:EvalBlock() range
  call s:Connect()

  let b = s:Yank("l", a:firstline . "," . a:lastline . "yank l")

  call chimp#SendMessage(s:ChimpId, b)
endfunction

function! s:EvalFile(fname)
  call s:Connect()
  call s:ChangeNamespaceIfNecessary()

  let closure = {}
  function closure.f() dict
    return s:Yank('l', 'normal ggVG"ly')
  endfunction

  call chimp#SendMessage(s:ChimpId, s:WithSavedPosition(closure))
endfunction
"#### [ }}} ]
"###### [ }}} ]

"###### MAPS [ {{{ ]
if !exists("no_plugin_maps") && !exists("no_sql_chimp_maps")
  call s:MakePlug('n', 'EvalStatement', 'EvalStatement()')
  call s:MakePlug('v', 'EvalBlock', 'EvalBlock()')
  call s:MakePlug('n', 'EvalFile', 'EvalFile()')
  call s:MakePlug('n', 'ResetChimp', 'ResetChimp()')

  call s:MapPlug('n', 'es', 'EvalStatement')
  call s:MapPlug('v', 'eb', 'EvalBlock')
  call s:MapPlug('n', 'ef', 'EvalFile')
  call s:MapPlug('n', 'rc', 'ResetChimp')
endif
"###### [ }}} ]

"###### EPILOG [ {{{ ]
let &cpo = s:save_cpo
"###### [ }}} ]
