#!perl -T

use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
    use_ok('lib::tree') || BAIL_OUT("Could not use 'lib::tree'!\n");
}

diag("Testing lib::tree $lib::tree::VERSION under Perl $] (using '$^X')");

