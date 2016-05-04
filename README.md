# erlang_ctags
Extended ctag generator for Erlang

1/ Generate an autonomous executable from the Erlang script:
You need Erlang to be installed, and also escript (on Debian, escript is in the erlang package)
To compile:
    make

This shall create an autonomous escript file: erlang_ctags
Take care that this executable file is in your PATH.

2/ Configure Vim/Tagbar to use erlang_ctags:
For Vim, update the Tagbar configurationtagbar.vim, for the Erlang language:

" Erlang {{{3
    let type_erlang = s:TypeInfo.New()
    let type_erlang.ctagstype = 'erlang'
    let type_erlang.kinds     = [
        \ {'short' : 'm', 'long' : 'modules',            'fold' : 0, 'stl' : 1},
        \ {'short' : 'b', 'long' : 'behaviour',          'fold' : 0, 'stl' : 1},
        \ {'short' : 'e', 'long' : 'exports',            'fold' : 1, 'stl' : 1},
        \ {'short' : 'i', 'long' : 'includes',           'fold' : 0, 'stl' : 1},
        \ {'short' : 'd', 'long' : 'macro definitions',  'fold' : 1, 'stl' : 1},
        \ {'short' : 'r', 'long' : 'record definitions', 'fold' : 1, 'stl' : 1},
        \ {'short' : 'f', 'long' : 'functions',          'fold' : 0, 'stl' : 1}
    \ ]
    let type_erlang.sro        = ':' " Not sure, is nesting even possible?
    let type_erlang.kind2scope = {
        \ 'm' : 'module',
        \ 'b' : 'behaviour'
    \ }
    let type_erlang.scope2kind = {
        \ 'module' : 'm',
        \ 'behaviour' : 'b'
    \ }
    
" MGU : use this custom ctags tool for erlang language
    let type_erlang.ctagsbin = 'erlang_ctags'
    let type_erlang.ctagsargs = ''


    let s:known_types.erlang = type_erlang


Launch Vim, open an Erlang file, open your Tagbar panel, and appreciate.

Note: functions with a green "+" are exported. If they are preceeded by a red "-", then it is not exported.
<<<<<<< HEAD
 

![Alt text](/erlang_tagbar.png?raw=true "Tagbar for Erlang")
=======
>>>>>>> d60e6cf1b57aa890312d77192326b8bb4fe10bb9

