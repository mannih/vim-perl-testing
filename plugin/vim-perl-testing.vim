" vim-perl-testing.vim - Utiltities to help you write and run perl tests
" Maintainer:   Manni Heumann <manni@github.com>
" Version:      0.1

if exists('g:loaded_vim_perl_testing') || &cp
  finish
endif
let g:loaded_vim_perl_testing = 1

function! Find_corresponding_t_file( module )
    let b:testfile = substitute( substitute( a:module, '.\+\/lib\/', '', '' ), '.pm$', '.t', '' )
    let b:basepath = substitute( a:module, '\/lib\/.\+', '', '' )

    if ( match( b:basepath, '/tools' ) != -1 )
        let b:basepath   = substitute( b:basepath, 'tools', '', '' )
        if ( match( b:testfile, '/' ) == -1 )
            let b:testsubdir = substitute( b:testfile, '.t$', '', '' )
            let b:testfile   = b:testsubdir . '/' . b:testfile
        endif
    endif

    let b:testdir = '/t/'
    if ( ! isdirectory( '.' . b:testdir ) )
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

function! GotoCorresponding()
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
        execute "tab drop " . file
    else
        echoe "Cannot find corresponding file for: ".module
    endif
endfunction

function! RunTestForCurrentSub()
    let b:current_file = expand( '%:p' )
    if ( match( b:current_file, '.pm$') != -1 )
        let b:test_file = Find_corresponding_t_file( b:current_file )
        if filereadable( b:test_file )
            let b:test_command = "perl Space " . b:test_file . " Space test_" . GetCurrentPerlSub()
            let b:tmux_command = "tmux send-keys -t :.+ " . b:test_command . " Enter"
            let error = system( b:tmux_command )
            if ( v:shell_error ) 
                echoe "Could not run " b:test_command . ": " . error
            endif
        endif
    elseif ( match( b:current_file, '.t$' ) != -1 ) 
        " todo
    endif
endfunction

function! GetCurrentPerlSub()
    perl current_sub()
    return subName
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

