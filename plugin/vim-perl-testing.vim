" vim-perl-testing.vim - Utiltities to help you write and run perl tests
" Maintainer:   Manni Heumann <manni@github.com>
" Version:      0.1

if exists('g:loaded_vim_perl_testing') || &cp
  finish
endif
let g:loaded_vim_perl_testing = 1

if !exists('g:vim_perl_testing_use_tmux')
  let g:vim_perl_testing_use_tmux = 0
endif

if !exists('g:vim_perl_testing_use_taglist')
  let g:vim_perl_testing_use_taglist = 0
endif

" Goto_buffer_or_open
"
" Focus buffer or - if it doesn't exist - open it
" with given 'how'-parameter.

function! Goto_buffer_or_open( how, file )
    if bufexists( a:file ) && buflisted( a:file ) && bufloaded( a:file )
        echom "we have a buffer for file " . a:file
        exec "sbuffer " . a:file
    else
        echom "loading new buffer: '" . a:how . " " . a:file . "'"
        exec a:how . " " . a:file
    endif
endfunction

" Find_corresponding_t_file
"
" Find the coresponding test file for a given module file
" Pass in the full path of the module/.pm file

function! Find_corresponding_t_file( module )
    let b:testfile = substitute( substitute( a:module, '.\+\/lib\/', '', '' ), '.pm$', '.t', '' )
    let b:basepath = substitute( a:module, '\/lib\/.\+', '', '' )

    if ( match( b:basepath, 'tools' ) != -1 )
        let b:basepath = substitute( b:basepath, '\/tools', '', '' )
        if ( match( b:testfile, '/' ) == -1 )
            let b:testsubdir = substitute( b:testfile, '.t$', '', '' )
            let b:testfile   = b:testsubdir . '/' . b:testfile
        endif
    endif

    let b:testdir = '/t/'
    if ( ! isdirectory( b:basepath . b:testdir ) )
        let b:testdir = '/tests/perl/'
    endif

    return b:basepath . b:testdir . b:testfile
endfunction

function! Try_lib_or_toolslib( basepath, file )
    let path = a:basepath . '/lib/' . a:file
    if ( filereadable( path ) )
        return '/lib/'
    else
        let path = a:basepath . '/tools/lib/' . a:file
        if ( filereadable( path ) )
            return '/tools/lib/'
        endif
    endif
endfunction

function! Find_corresponding_pm_file( testfile )
    let module   = substitute( substitute( a:testfile, '\v.+(\/tests\/perl\/|/t/)', '', '' ), '.t$', '.pm', '' )
    let basepath = substitute( a:testfile, '\v(\/tests\/perl\/|/t/).+', '', '' )

    let result = Try_lib_or_toolslib( basepath, module )
    if ( result == '' ) 
        let module = substitute( module, '\v(\w+)/\1.', '\1.', '' )
        let result = Try_lib_or_toolslib( basepath, module )
        if ( result != '' ) 
            return basepath . result . module
        else
            return findfile( module, 'lib/**' )
        endif
    else
        return basepath . result . module
    endif
endfunction

function! GetCorresponding()
    let b:current_file = expand( '%:p' )
    if ( match( b:current_file, '.pm$') != -1 )
        return Find_corresponding_t_file( b:current_file )
    elseif ( match( b:current_file, '.t$' ) != -1 )
        return Find_corresponding_pm_file( b:current_file )
    endif
endfunction

function! GotoCorresponding( ... )
    let l:how = 'edit'
    if a:0 > 0
        let l:how = a:1
    endif
    let file = GetCorresponding()
    let module = expand( '%:p' )
    if !empty( file )
        if ( match( file, '.t$' ) != -1 )
            if !filereadable( file )
                let error = system( "make_test_stub " . module . " " . file )
                if ( v:shell_error )
                    echoe "Could not run make_test_stub: " . error
                endif
            endif
        endif
        execute Goto_buffer_or_open( l:how, file )
    else
        echoe "Cannot find corresponding file for: ".module
    endif
endfunction

function! RunTestForCurrentSub()
    let b:current_file = expand( '%:p' )
    let l:current_sub = GetCurrentPerlSub()
    if ( match( b:current_file, '.pm$') != -1 )
        let b:test_file = Find_corresponding_t_file( b:current_file )
        if filereadable( b:test_file )
            if g:vim_perl_testing_use_tmux
                let b:test_command = "perl Space " . b:test_file . " Space test_" . l:current_sub
                let b:tmux_command = "tmux send-keys -t :.+ " . b:test_command . " Enter"
                let error = system( b:tmux_command )
                if ( v:shell_error )
                    echoe "Could not run " b:test_command . ": " . error
                endif
            else
                let l:restore_makeprg = 'setlocal makeprg=' . escape( &l:makeprg, ' ' )
                let b:test_command = 'perl\ ' . b:test_file . '\ test_' . l:current_sub
                execute "setlocal makeprg=" . b:test_command
                execute "make"
                execute l:restore_makeprg
            endif
        endif
    elseif ( match( b:current_file, '.t$' ) != -1 ) 
        if g:vim_perl_testing_use_tmux
            let l:test_command     = "perl Space " . b:current_file . "  Space " . l:current_sub
            let l:tmux_command     = "tmux send-keys -t :.+ " . l:test_command . ' Enter'
            let error = system( l:tmux_command )
            if ( v:shell_error )
                echoe "Could not run " l:tmux_command . ": " . error
            endif
        else
            let l:restore_makeprg = 'setlocal makeprg=' . escape( &l:makeprg, ' ' )
            let b:test_command = 'perl\ ' . b:current_file . '\ ' . l:current_sub
            execute "setlocal makeprg=" . b:test_command
            execute "make"
            execute l:restore_makeprg
        endif
    endif
endfunction

function! GetCurrentPerlSub()
    if g:vim_perl_testing_use_taglist
        return Tlist_Get_Tagname_By_Line()
    else
        perl current_sub()
        return subName
    endif
endfunction

if has( 'perl' )
perl << EOP
    use strict;
    sub current_sub {
        my $curwin = $main::curwin;
        my $curbuf = $main::curbuf;

        my @document = map { $curbuf->Get($_) } 0 .. $curbuf->Count;
        my ( $line_number, $column  ) = $curwin->Cursor;

        my $sub_name = '';
        for my $i ( reverse ( 1 .. $line_number  -1 ) ) {
            my $line = $document[$i];
            if ( $line =~ /^\s*(sub|function|method)\s+(\w+)\b/ ) {
                $sub_name = $2;
                last;
            }
        }
        VIM::DoCommand "let subName='$sub_name'";
    }
EOP
endif

