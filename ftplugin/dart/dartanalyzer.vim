scriptencoding utf-8

" Dart filetype plugin for running dartanalyzer
" Maintainer:   https://github.com/miyakogi
" URL:          https://github.com/miyakogi/vim-dartanalyzer

if exists('b:loaded_dartanalyzer')
  finish
endif
let b:loaded_dartanalyzer = 1

let s:save_cpo = &cpo
set cpo&vim

" ======== Global startup ======== {{{
if !exists('s:initialized')
  " Check dartanalyzer and version of vim {{{
  if !executable('dartanalyzer')
    echohl ErrorMsg
    echomsg '[dartanalyzer] `dartanalyzer` is not executable!'
    echohl
    finish
  endif
  if !exists('*matchadd')
    echohl ErrorMsg
    echomsg '[dartanalyzer] This VIM does not support `matchadd`. Please upgrade vim to a newer version.'
    echohl
    finish
  endif "}}}

  " Set default values {{{
  if !exists('g:dartanalyzer_id')
    let g:dartanalyzer_id = 'dartanalyzer_precess'
  endif
  if !exists('g:dartanalyzer_max_msglen')
    let g:dartanalyzer_max_msglen = 80
  endif
  if !exists('g:dartanalyzer_updatetime')
    let g:dartanalyzer_updatetime = 100   " [msec]
  endif
  if !exists('g:dartanalyzer_pm_timeout')
    let g:dartanalyzer_pm_timeout = 0.01  " [sec]
  endif
  if !exists('g:dartanalyzer_read_timeout')
    let g:dartanalyzer_read_timeout = 10  " [sec]
  endif
  if !exists('g:dartanalyzer_disable_autostart')
    let g:dartanalyzer_disable_autostart = 0
  endif
  if !exists('g:dartanalyzer_show_startupmsg')
    let g:dartanalyzer_show_startupmsg = 0
  endif
  " This plugin executes this var after running dartanalyzer and parsing results
  if !exists('g:dartanalyzer_postprocess')
    let g:dartanalyzer_postprocess = ''
  endif "}}}

  " Vital startup {{{
  let s:V = vital#of('dartanalyzer')
  let g:dartanalyzer_pm = s:V.import('ProcessManager')
  if !g:dartanalyzer_pm.is_available()
    echoerr 'vimproc is required'
    finish
  endif "}}}

  " Make augroup for polling {{{
  augroup dartanalyzer_polling
    autocmd! *
  augroup END
  "}}}

  function! g:DartAnalyzerRun() "{{{
    call dartanalyzer#start_new_analysis()
  endfunction "}}}

  function! s:disable_global() "{{{
    " Delete autocmd in dartanalyzer in all buffers.
    augroup dartanalyzer
      autocmd! *
    augroup END
  endfunction "}}}

  " Use tempfile as cache if possible (Only available in *nix)
  function! s:make_tempfile() "{{{
    if filewritable('/dev/shm') == 2
      let tempfile = '/dev/shm/dartanalyzer_' . reltimestr(reltime()) . '.dart'
    elseif filewritable('/tmp') == 2
      let tempfile = system('tempfile')
    else
      " make tempfile in the same directory (for Windows)
      let tempfile = b:dartanalyzer_filepath . '.temp'
    endif
    return tempfile
  endfunction "}}}

  " Define commands {{{
  command! DartAnalyzerRun call dartanalyzer#start_new_analysis()
  command! DartAnalyzerEnable call dartanalyzer#init#enable()
  command! DartAnalyzerDisable call s:disable_global()
  "}}}

  let s:initialized = 1
endif"}}}

" ======== Initialize buffer ========"{{{
let b:dartanalyzer_prev_status = ''
let b:dartanalyzer_errorpos_text = {}
let b:dartanalyzer_warnpos_text = {}
let b:dartanalyzer_running = 0
let b:dartanalyzer_loclist = []
let b:dartanalyzer_loclist_pre = []
let b:dartanalyzer_filepath = expand('%:p')
let b:dartanalyzer_tempfile = s:make_tempfile()
"}}}

if !g:dartanalyzer_disable_autostart
  call dartanalyzer#init#enable()
endif

let &cpo = s:save_cpo
unlet s:save_cpo

" vim set\ fdm=marker\ ts=2\ sts=2\ sw=2\ tw=0\ et