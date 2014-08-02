" Unit tests for the functions that find correspondig files

let s:testdir = expand( '%:p:h' )
let s:currdir = getcwd()

let s:tc = unittest#testcase#new( 'Find_corresponding_t_file' )

function! s:tc.SETUP()
    exe 'cd' s:testdir
endfunction

function! s:tc.TEARDOWN()
    exe 'cd' s:currdir
endfunction


function! s:tc.test_Find_correponding_t_file_t_exists()
    call mkdir( s:testdir . '/t' )

    let retval = Find_corresponding_t_file( './lib/Foo/Bar/Baz.pm' )
    call self.assert_equal( './t/Foo/Bar/Baz.t', retval, 'works with a relative path' )

    let fullpath = s:testdir . '/lib/Foo/Bar/Baz.pm'
    let retval = Find_corresponding_t_file( fullpath )
    call self.assert_equal( s:testdir . '/t/Foo/Bar/Baz.t', retval , 'works with an absolute path')

    let retval = Find_corresponding_t_file( './tools/lib/Bar/Baz.pm' )
    call self.assert_equal( './t/Bar/Baz.t', retval, 'relative path for module in tools/lib' )

    execute( '!rm -rf ' . s:testdir . '/t' )
endfunction

function! s:tc.test_Find_correponding_t_file_tests_exists()
    call mkdir( s:testdir . '/tests' )
    call mkdir( s:testdir . '/tests/perl' )

    let retval = Find_corresponding_t_file( './lib/Foo/Bar/Baz.pm' )
    call self.assert_equal( './tests/perl/Foo/Bar/Baz.t', retval, 'works with a relative path' )

    let fullpath = s:testdir . '/lib/Foo/Bar/Baz.pm'
    let retval = Find_corresponding_t_file( fullpath )
    call self.assert_equal( s:testdir . '/tests/perl/Foo/Bar/Baz.t', retval , 'works with an absolute path')

    execute( '!rm -rf ' . s:testdir . '/tests' )
endfunction

