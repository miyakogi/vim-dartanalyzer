scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

function! dartanalyzer#start_new_analysis()
  if exists('b:dartanalyzer_running') && b:dartanalyzer_running == 1
    call s:poll_process()
    return
  endif

  call g:dartanalyzer_pm.touch(g:dartanalyzer_id, g:dartanalyzer#init#cmd)

  let b:dartanalyzer_message = ''
  if b:dartanalyzer_tempfile != b:dartanalyzer_filepath
    call writefile(getline(1,'$'), b:dartanalyzer_tempfile)
  endif
  if !filereadable(b:dartanalyzer_tempfile)
    echoerr "Can't read tempfile: " . b:dartanalyzer_tempfile
  endif
  call g:dartanalyzer_pm.writeln(g:dartanalyzer_id, b:dartanalyzer_tempfile)

  let b:dartanalyzer_running = 1
  let s:start_time = localtime()

  autocmd dartanalyzer_polling CursorMoved,CursorHold,CursorHoldI <buffer> call s:poll_process()
  if !exists('s:updatetime') || s:updatetime == &updatetime
    let s:updatetime = &updatetime
    let &updatetime = g:dartanalyzer_updatetime
  endif
  call s:poll_process()
endfunction

function! s:poll_process()
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

function! s:parse(messages)
  call dartanalyzer#clear_hl()
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

  let b:dartanalyzer_loclist = []
  let error_lists = s:split_error_lines(message_lines)
  for error_list in error_lists
    let qf_item = s:to_qfformat(error_list)
    let b:dartanalyzer_loclist += [ qf_item ]
  endfor

  call setloclist(0, b:dartanalyzer_loclist, 'r')
  call s:update_hl()
  call dartanalyzer#update_message()

  if g:dartanalyzer_postprocess
    execute g:dartanalyzer_postprocess
  endif

  call s:parse_postprocess()
endfunction

function! s:parse_postprocess()
  let b:dartanalyzer_running = 0
  let &updatetime = s:updatetime
  augroup dartanalyzer_polling
    autocmd! * <buffer>
  augroup END
  if b:dartanalyzer_tempfile != b:dartanalyzer_filepath
    call writefile([''], b:dartanalyzer_tempfile)
  endif
endfunction

function! dartanalyzer#clear_hl()
  if exists('b:dartanalyzer_loclist')
    for qf_item in b:dartanalyzer_loclist
      try
        call matchdelete(qf_item.id)
      catch /^Vim\%((\a\+)\)\=:E\(803\|716\)/
      endtry
    endfor
  endif
endfunction

function! s:update_hl()
  highlight link DartAnalyzerError SpellBad
  highlight link DartAnalyzerWarning SpellCap
  let b:dartanalyzer_errorpos_text = {}
  let b:dartanalyzer_warnpos_text = {}
  if len(b:dartanalyzer_loclist) > 0
    for qf_item in b:dartanalyzer_loclist
      let l = qf_item.lnum
      let c = qf_item.col + 1  " dartanalyzer counts the first column as 0
      if qf_item.type == 'W'
        let b:dartanalyzer_warnpos_text[ qf_item.lnum ] = qf_item.text
        " let qf_item.id = matchadd('DartAnalyzerWarning', '\%' . l . 'l\%' . c . 'c.*$')
        let qf_item.id = matchadd('DartAnalyzerWarning', '^\%' . l . 'l.\{-}\zs\k\+\k\@!\%>' . c . 'c')
      elseif qf_item.type == 'E'
        let b:dartanalyzer_errorpos_text[ qf_item.lnum ] = qf_item.text
        let qf_item.id = matchadd('DartAnalyzerError', '\%' . l . 'l' . '.*$')
      endif
    endfor
  endif
  redraw
endfunction

function! s:show_msg(msg)
  let _winwidth = min([winwidth(0), g:dartanalyzer_max_msglen]) - 5
  let msgwidth = strdisplaywidth(a:msg)
  if msgwidth >= _winwidth
    let msg = a:msg[: _winwidth] . '...'
  else
    let msg = a:msg
  endif
  echo msg
endfunction

function! dartanalyzer#update_message()
  let lnum = line('.')
  if has_key(b:dartanalyzer_errorpos_text, lnum)
    call s:show_msg(b:dartanalyzer_errorpos_text[lnum])
  elseif has_key(b:dartanalyzer_warnpos_text, lnum)
    call s:show_msg(b:dartanalyzer_warnpos_text[lnum])
  else
    call s:show_msg('')
  endif
endfunction

function! s:split_error_lines(message_lines)
  let error_list = []

  for message in a:message_lines
    let _list = split(message, '|')
    if len(_list) == 8
      let error_list += [_list]
    endif
  endfor
  return error_list
endfunction

function! s:to_qfformat(error_list)
  let l:qf_item = {}
  let l:qf_item.bufnr = bufnr('%')
  let l:qf_item.filename = b:dartanalyzer_filepath

  let message = a:error_list[7]
  let l:qf_item.text = message

  let qf_type = ''
  let type = a:error_list[0]
  if type ==# 'ERROR'
    let qf_type = 'E'
  elseif type ==# 'WARNING' || type ==# 'HINT' || type ==# 'INFO'
    let qf_type = 'W'
  else
    echohl ErrorMsg
    echomsg '[dartanalyzer] Unknown error type: ' . type
    echohl
    let qf_type = 'E'
  endif
  let l:qf_item.type = qf_type

  let l:qf_item.lnum = a:error_list[4]
  let l:qf_item.col = a:error_list[5]

  return l:qf_item
endfunction

function! dartanalyzer#start_if_possible()
  if b:dartanalyzer_running == 0
    call dartanalyzer#start_new_analysis()
  endif
endfunction

function! dartanalyzer#count_errors()
  return len(b:dartanalyzer_errorpos_text)
endfunction

function! dartanalyzer#count_warnings()
  return len(b:dartanalyzer_warnpos_text)
endfunction

function! dartanalyzer#count()
  return len(b:dartanalyzer_loclist)
endfunction

function! dartanalyzer#status_line()
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
