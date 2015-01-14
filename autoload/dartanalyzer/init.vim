scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

" autoload variables
let g:dartanalyzer#init#cmd = g:dartanalyzer_cmd . ' --batch --format=machine'
if exists('b:dartanalyzer_pkgdir') && b:dartanalyzer_pkgdir !=# ''
  let g:dartanalyzer#init#cmd .= ' --package-root ' . b:dartanalyzer_pkgdir
endif
let g:dartanalyzer#init#endline = '>>> TEST '

" Script local variables
let s:vm_started = 0
let s:vm_startup_message = 'Starting DartAnalyzer VM'
let s:startup_count = strlen(s:vm_startup_message)
for n in range(g:dartanalyzer_max_msglen - strlen(s:vm_startup_message) - 1)
  let s:vm_startup_message .= '.'
endfor

" Set autocmds
function! s:enable()
  augroup dartanalyzer
    autocmd! * <buffer>
    autocmd BufLeave,BufWinLeave <buffer> call dartanalyzer#clear_hl()
    autocmd BufEnter,BuFWinEnter <buffer> call dartanalyzer#start_new_analysis()
    autocmd BufWritePost <buffer> call dartanalyzer#start_new_analysis()
    autocmd InsertLeave <buffer> call dartanalyzer#start_new_analysis()
    autocmd CursorHold,CursorHoldI,FocusLost <buffer> call dartanalyzer#start_new_analysis()
    autocmd CursorMoved <buffer> call dartanalyzer#update_message()
    autocmd TextChanged <buffer> call dartanalyzer#start_if_possible()
  augroup END
endfunction

function! s:vm_startup()
  call g:dartanalyzer_pm.touch(g:dartanalyzer_id, g:dartanalyzer#init#cmd)

  call dartanalyzer#run_analysis(b:dartanalyzer_filepath)
  call g:dartanalyzer_pm.read(g:dartanalyzer_id, [g:dartanalyzer#init#endline])

  augroup dartanalyzer_polling
    if !g:dartanalyzer_show_startupmsg
      autocmd CursorMoved,CursorMovedI,TextChanged,TextChangedI <buffer> call s:poll_startup()
    else
      autocmd CursorMoved,CursorMovedI,TextChanged,TextChangedI <buffer> call s:poll_startup_with_msg()
    endif
    " Disable to leave current buffer until VM become enable, to prevent bug
    autocmd BufLeave <buffer> call s:wait_for_startup()
  augroup END
endfunction

function! s:poll_startup()
  if g:dartanalyzer_pm.read_wait(g:dartanalyzer_id, g:dartanalyzer_pm_timeout, ['>>> [^B]'])[2] ==# 'matched'
    call s:end_startup()
    return
  endif
endfunction

function! s:poll_startup_with_msg()
  call s:poll_startup()

  echon s:vm_startup_message[: s:startup_count]
  let s:startup_count = s:startup_count >= g:dartanalyzer_max_msglen - 2
        \ ? s:startup_count : s:startup_count + 1
endfunction

function! s:wait_for_startup()
  echohl Special
  echo "Please wait until dartanalyzer become enable."
  echohl

  while 1
    if s:vm_started
      break
    endif
    call s:poll_startup()
  endwhile
endfunction

function! s:end_startup()
  let s:vm_started = 1

  " Show message
  if g:dartanalyzer_show_startupmsg
    let msg = '--- DartAnalyzer ---'
    for n in range(strlen(msg))
      echo msg[: n]
      sleep 10m
    endfor
    echo msg
    sleep 10m
    echohl
  endif

  " Stop polling
  augroup dartanalyzer_polling
    autocmd!
  augroup END

  " Enable dartanalyzer
  call s:enable()
  execute 'sleep ' . g:dartanalyzer_updatetime . 'm'
  call dartanalyzer#start_new_analysis()
endfunction

function! dartanalyzer#init#enable()
  if !exists('s:vm_started') || s:vm_started == 0
    call s:vm_startup()
  elseif s:vm_started == 0
    call s:poll_startup()
  else
    call s:enable()
  endif
endfunction

function! dartanalyzer#init#disable()
  call g:dartanalyzer_pm.kill(g:dartanalyzer_id)
  let s:vm_started = 0
endfunction

function! dartanalyzer#init#restart()
  call dartanalyzer#init#disable()
  call dartanalyzer#init#enable()
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim set\ fdm=marker\ ts=2\ sts=2\ sw=2\ tw=0\ et
