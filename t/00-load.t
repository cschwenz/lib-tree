#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'lib::tree' ) || print "Bail out!
";
}

diag( "Testing lib::tree $lib::tree::VERSION, Perl $], $^X" );
