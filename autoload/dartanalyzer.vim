scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

function! dartanalyzer#run_analysis(...) abort
  if len(a:000) > 0
    let file_path = a:1
  else
    let file_path = expand('%:p')
  endif

  if !filereadable(l:file_path)
    echoerr "Can't read file: " . l:file_path
  endif
  call g:dartanalyzer_pm.writeln(g:dartanalyzer_id, l:file_path)
endfunction

function! dartanalyzer#start_new_analysis() abort
  if exists('b:dartanalyzer_running') && b:dartanalyzer_running == 1
    call s:poll_process()
    return
  endif

  call g:dartanalyzer_pm.touch(g:dartanalyzer_id, g:dartanalyzer#init#cmd)
  let b:dartanalyzer_message = ''
  call g:dartanalyzer#run_analysis(b:dartanalyzer_filepath)

  let b:dartanalyzer_running = 1
  let s:start_time = localtime()

  autocmd dartanalyzer_polling CursorMoved,CursorHold,CursorHoldI <buffer> call s:poll_process()
  if !exists('s:updatetime') || s:updatetime == &updatetime
    let s:updatetime = &updatetime
    let &updatetime = g:dartanalyzer_updatetime
  endif
  call s:poll_process()
endfunction

function! s:poll_process() abort
  let response = g:dartanalyzer_pm.read_wait(g:dartanalyzer_id, g:dartanalyzer_pm_timeout, [g:dartanalyzer#init#endline])
  let b:dartanalyzer_message .= response[0]

  if response == ['', '', 'timedout']
    " let b:dartanalyzer_running = 0
  elseif response[2] ==# 'matched'
    call s:parse(b:dartanalyzer_message)
  endif

  " Check timedout
  if localtime() - s:start_time > g:dartanalyzer_read_timeout
    call s:parse_postprocess()
    return
  endif
endfunction

function! s:parse(messages) abort
  if !g:dartanalyzer_disable_highlight
    call dartanalyzer#clear_hl()
  endif

  let message_lines = split(a:messages, '\n')
  let status = message_lines[-1]

  if match(status, '\v\c^PASS') > -1
    let b:dartanalyzer_prev_status = 'PASS'
  elseif match(status, '\v\c^FAIL') > -1
    let b:dartanalyzer_prev_status = 'FAIL'
  elseif match(status, '\v\c^CRASH') > -1
    let b:dartanalyzer_prev_status = 'CRASH'
    echoerr 'VM CRASHED. Restart DartAnalyzer.'
    call dartanalyzer#init#restart()
  else
    echoerr 'Unknown end-status: ' . status
  endif

  let b:dartanalyzer_qflist = []
  let b:dartanalyzer_errorpos_text = {}
  let b:dartanalyzer_warnpos_text = {}
  let error_lists = s:split_error_lines(message_lines)
  for error_list in error_lists
    let error_item = s:to_qfformat(error_list)
    let b:dartanalyzer_qflist += [ error_item ]
  endfor

  call setqflist(b:dartanalyzer_qflist)
  if !g:dartanalyzer_disable_highlight
    call s:update_hl()
  elseif exists('g:loaded_hier')
    execute 'HierUpdate'
  endif

  if !g:dartanalyzer_disable_message
    call dartanalyzer#update_message()
  elseif exists('g:loaded_quickfixstatus')
    execute 'QuickfixStatusEnable'
  endif

  execute g:dartanalyzer_postprocess

  call s:parse_postprocess()
endfunction

function! s:parse_postprocess() abort
  let b:dartanalyzer_running = 0
  let &updatetime = s:updatetime
  augroup dartanalyzer_polling
    autocmd! * <buffer>
  augroup END
endfunction

function! dartanalyzer#clear_hl() abort
  if exists('b:dartanalyzer_qflist')
    for qf_item in b:dartanalyzer_qflist
      try
        call matchdelete(qf_item.id)
      catch /^Vim\%((\a\+)\)\=:E\(803\|716\)/
      endtry
    endfor
  endif
endfunction

function! s:update_hl() abort
  if len(b:dartanalyzer_qflist) > 0
    for qf_item in b:dartanalyzer_qflist
      if qf_item.filename !=# b:dartanalyzer_filepath
        continue
      endif
      let l = qf_item.lnum
      let c = qf_item.col + 1  " dartanalyzer counts the first column as 0
      if qf_item.type == 'W'
        let qf_item.id = matchadd('DartAnalyzerWarning', '^\%' . l . 'l.\{-}\zs\k\+\k\@!\%>' . c . 'c')
      elseif qf_item.type == 'E'
        let qf_item.id = matchadd('DartAnalyzerError', '\%' . l . 'l' . '.*$')
      endif
    endfor
  endif
  redraw
endfunction

function! s:show_msg(msg) abort
  let _winwidth = min([&columns, g:dartanalyzer_max_msglen]) - 10
  let msgwidth = strdisplaywidth(a:msg)
  if msgwidth >= _winwidth
    let msg = a:msg[: _winwidth] . '...'
  else
    let msg = a:msg
  endif
  echo msg
endfunction

function! dartanalyzer#update_message() abort
  if g:dartanalyzer_disable_message
    return
  endif

  let lnum = line('.')
  if has_key(b:dartanalyzer_errorpos_text, lnum)
    call s:show_msg(b:dartanalyzer_errorpos_text[lnum])
  elseif has_key(b:dartanalyzer_warnpos_text, lnum)
    call s:show_msg(b:dartanalyzer_warnpos_text[lnum])
  endif
endfunction

function! s:split_error_lines(message_lines) abort
  let error_list = []

  for message in a:message_lines
    let _list = split(message, '|')
    if len(_list) == 8
      let error_list += [_list]
    endif
  endfor
  return error_list
endfunction

function! s:to_qfformat(error_list) abort
  let l:qf_item = {}
  let l:qf_item.bufnr = bufnr('%')
  let l:qf_item.filename = a:error_list[3]
  let l:qf_item.lnum = a:error_list[4]
  let l:qf_item.col = a:error_list[5]

  let message = a:error_list[7]
  let l:qf_item.text = message

  let type = a:error_list[0]
  if type ==# 'ERROR'
    let l:qf_item.type = 'E'
    if has_key(b:dartanalyzer_errorpos_text, qf_item.lnum)
      let b:dartanalyzer_errorpos_text[ qf_item.lnum ] .= ', ' . qf_item.text
    else
      let b:dartanalyzer_errorpos_text[ qf_item.lnum ] = qf_item.text
    endif
  elseif type ==# 'WARNING' || type ==# 'HINT' || type ==# 'INFO'
    let l:qf_item.type = 'W'
    if has_key(b:dartanalyzer_warnpos_text, qf_item.lnum)
      let b:dartanalyzer_warnpos_text[ qf_item.lnum ] .= ', ' . qf_item.text
    else
      let b:dartanalyzer_warnpos_text[ qf_item.lnum ] = qf_item.text
    endif
  else
    echohl ErrorMsg
    echomsg '[dartanalyzer] Unknown error type: ' . type
    echohl
    let l:qf_item.type = 'E'
  endif

  return l:qf_item
endfunction

function! dartanalyzer#start_if_possible() abort
  if b:dartanalyzer_running == 0
    call dartanalyzer#start_new_analysis()
  endif
endfunction

function! s:count_qfitems(type) abort
  let n = 0
  for qf_item in b:dartanalyzer_qflist
    if qf_item.type ==# a:type
      let n += 1
    endif
  endfor
  return n
endfunction

function! dartanalyzer#count_errors() abort
  return s:count_qfitems('E')
endfunction

function! dartanalyzer#count_warnings() abort
  return s:count_qfitems('W')
endfunction

function! dartanalyzer#count() abort
  return len(b:dartanalyzer_qflist)
endfunction

function! dartanalyzer#status_line() abort
  let text = 'Errors: '
        \ . printf('%d', dartanalyzer#count_errors())
        \ . ', '
        \ . 'Warnings: '
        \ . printf('%d', dartanalyzer#count_warnings())
  return text
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim set\ fdm=marker\ ts=2\ sts=2\ sw=2\ tw=0\ et
