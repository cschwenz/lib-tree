use warnings;
use strict;
use Test::More tests => 7;
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


# The unimport() function can remove the default directory.
{
    my $lib_dir = undef;
    {
        my @data = create_test_lib();
        if($data[0] != PASS) {
            BAIL_OUT($data[1]);
        }
        elsif($data[0] == PASS) {
            $lib_dir = $data[1];
        }
    }

    lib::tree->import();
    my @test_INC = ( @INC );
    my ($path) = grep { dir_equal($lib_dir, $_) == 1 } @test_INC;
    # Test 3
    cmp_ok( canonpath($path), 'eq', canonpath($lib_dir),
            'The import() function can find the default directory.' );

    lib::tree->unimport();
    @test_INC = ( @INC );
    ($path) = grep { dir_equal($lib_dir, $_) == 1 } @test_INC;
    my $undef_path = (defined $path) ? "defined ($path)" : 'undef';
    # Test 4
    cmp_ok( $undef_path, 'eq', 'undef',
            'The unimport() function can remove the default directory.' );

    {
        my @data = destroy_test_lib();
        if($data[0] != PASS) {
            BAIL_OUT($data[1]);
        }
    }
    lib::tree->import(':ORIGINAL');
    @test_INC = ( @INC );
    # Test 5
    is_deeply( \@test_INC, \@initial_INC,
               'The import() function can reset the @INC array back to its ' .
               'original content via \':ORIGINAL\'.' );
}


# The unimport() function can remove the original @INC array values.
{
    lib::tree->unimport(':ORIGINAL');
    my @test_INC = ( @INC );
    my @empty = ();
    # Test 6
    is_deeply( \@test_INC, \@empty,
               'The unimport() function can remove the original @INC ' .
               'array values.' );

    lib::tree->import(':ORIGINAL');
    @test_INC = ( @INC );
    # Test 7
    is_deeply( \@test_INC, \@initial_INC,
               'The import() function can reset the @INC array back to its ' .
               'original content via \':ORIGINAL\'.' );
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

