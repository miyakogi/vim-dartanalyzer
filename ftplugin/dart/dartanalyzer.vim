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
  " Set default values {{{
  if !exists('g:dartanalyzer_cmd')
    let g:dartanalyzer_cmd = 'dartanalyzer'
  endif
  if !exists('g:dartanalyzer_id')
    let g:dartanalyzer_id = 'dartanalyzer_process'
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
  if !exists('g:dartanalyzer_disable_highlight')
    let g:dartanalyzer_disable_highlight = 0
  endif
  if !exists('g:dartanalyzer_disable_message')
    let g:dartanalyzer_disable_message = 0
  endif
  " This plugin executes this var after running dartanalyzer and parsing results
  if !exists('g:dartanalyzer_postprocess')
    let g:dartanalyzer_postprocess = ''
  endif "}}}

if !exists('s:initialized')
  " Check dartanalyzer and version of vim {{{
  if !executable(g:dartanalyzer_cmd)
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

  function! s:disable_global() "{{{
    " Delete autocmd in dartanalyzer in all buffers.
    call dartanalyzer#clear_hl()
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
let b:dartanalyzer_qflist = []
let b:dartanalyzer_filepath = expand('%:p')
let b:dartanalyzer_tempfile = s:make_tempfile()
"}}}

command! -buffer DartAnalyzerRun call dartanalyzer#start_new_analysis()

if !g:dartanalyzer_disable_autostart
  call dartanalyzer#init#enable()
endif

let &cpo = s:save_cpo
unlet s:save_cpo

" vim set\ fdm=marker\ ts=2\ sts=2\ sw=2\ tw=0\ et
