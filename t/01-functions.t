use warnings;
use strict;
use Test::More tests => 3;
use lib './t';

BEGIN {
    # Test 1
    use_ok('lib::tree') || BAIL_OUT("Could not use 'lib::tree'!\n");
}
use TestUtils qw(function_present);


{
    # Test 2
    my @data = function_present('import');
    if($data[0]) {
        pass($data[1]);
    }
    else {
        fail($data[1]);
    }
}

{
    # Test 3
    my @data = function_present('unimport');
    if($data[0]) {
        pass($data[1]);
    }
    else {
        fail($data[1]);
    }
}

