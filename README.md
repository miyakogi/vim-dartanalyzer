vim-dartanalyzer
================

Vim plugin for running dartanalyzer asynchronously.

![ScreenCast](https://raw.githubusercontent.com/wiki/miyakogi/vim-dartanalyzer/images/screencast1.gif)

This plugin is tested only on Linux (Ubuntu 14.04 64-bit).

Requirements
------------

- `dartanalyzer` (included in [dart-sdk](https://www.dartlang.org/tools/sdk/))
- Vim plugins
    - [Shougo/vimproc.vim](https://github.com/Shougo/vimproc.vim)
    - [jceb/vim-hier](https://github.com/jceb/vim-hier) [*optilnal*]
    - [dannyob/quickfixstatus](https://github.com/dannyob/quickfixstatus) [*optilnal*]

Usage
-----

Install this plugin and open `*.dart` file in vim.
This plugin will automatically start dartanalyzer in background (at the first time, this process will take a few seconds).
Then syntax errors and warnings will be highlighted.

Errors and warnings are set in vim's quickfix list.
By using `:copen` command, you can see all positions of errors/warnings, and you can jump to the line.

If `filetype` is not set automatically, try [dart-lang/dart-vim-plugin](https://github.com/dart-lang/dart-vim-plugin).
Otherwise, add the following line in your `.vimrc`.

```vim
autocmd BufNewFile,BufRead *.dart set filetype=dart
```

Configuration
-------------

See `:help dartanalyzer`.
