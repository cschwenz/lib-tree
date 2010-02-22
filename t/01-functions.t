#!perl -T

use warnings;
use strict;
use Test::More tests => 3;

BEGIN {
    use_ok('lib::tree') || BAIL_OUT("Could not use 'lib::tree'!\n");
}

sub function_present {
    my $name = shift;
    eval "lib::tree::${name}();";
    if($@) { fail("Function $name is NOT present!"); }
    else { pass("Function $name is present."); }
}

function_present('import');
function_present('unimport');

