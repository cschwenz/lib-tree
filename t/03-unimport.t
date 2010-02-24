use warnings;
use strict;
use Test::More tests => 2;
use File::Spec::Functions qw( splitpath catpath catfile
                              splitdir catdir
                              canonpath file_name_is_absolute );
use File::Path qw(mkpath rmtree);
require Cwd;
use lib './t';

my @initial_INC;
BEGIN {
    @initial_INC = ( @INC );
}
BEGIN {
    # Test 1
    require_ok('lib::tree') || BAIL_OUT("Could not require 'lib::tree'!\n");
}
use TestUtils qw( create_test_lib destroy_test_lib
                  dir_equal cleanup_tests TRUE FALSE
                  PASS FAIL WARN ERROR );

my $cwd = $TestUtils::cwd;
my $test_lib = $TestUtils::test_lib;




###########################################################################
## We are calling the unimport function as a method to emulate someone
## saying 'no lib:tree ( ... );'
###########################################################################


# Make sure we are starting with a clean slate.
{
    my @data = destroy_test_lib();
    if($data[0] == ERROR) {
        BAIL_OUT($data[1]);
    }
}


# The unimport() function does not alter the @INC array when there is nothing
# to remove.
{
    lib::tree->unimport();
    my @test_INC = ( @INC );
    # Test 2
    is_deeply( \@test_INC, \@initial_INC,
               'The unimport() function does not alter the @INC array when ' .
               'there is nothing to remove.' );
}


END {
    my @data = cleanup_tests();
    if(($data[0] == WARN) || ($data[0] == FAIL)) {
        diag($data[1]) if($data[1] !~ m/\A\s*Unknown\s+error\b/i);
    }
    elsif($data[0] == ERROR) {
        BAIL_OUT($data[1]);
    }
}

