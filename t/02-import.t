use warnings;
use strict;
use Test::More tests => 15;
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
## We are calling the import function as a method to emulate someone
## saying 'use lib:tree ( ... );'
###########################################################################


# Make sure we are starting with a clean slate.
{
    my @data = destroy_test_lib();
    if($data[0] != PASS) {
        BAIL_OUT($data[1]);
    }
}


# The import() function does not alter the @INC array when there is nothing
# to add.
{
    lib::tree->import();
    my @test_INC = ( @INC );
    # Test 2
    is_deeply( \@test_INC, \@initial_INC,
               'The import() function does not alter the @INC array when ' .
               'there is nothing to add.' );
}


# The import() function can find the default directory.
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

    {
        my @data = destroy_test_lib();
        if($data[0] != PASS) {
            BAIL_OUT($data[1]);
        }
    }
    lib::tree->import(':ORIGINAL');
    @test_INC = ( @INC );
    # Test 4
    is_deeply( \@test_INC, \@initial_INC,
               'The import() function can reset the @INC array back to its ' .
               'original content via \':ORIGINAL\'.' );
}


# The import() function can find a custom named directory.
{
    my $custom_name = 'custom-perl-lib';
    my $custom_lib = undef;
    {
        my @data = create_test_lib($custom_name);
        if($data[0] != PASS) {
            BAIL_OUT($data[1]);
        }
        elsif($data[0] == PASS) {
            $custom_lib = $data[1];
        }
    }

    lib::tree->import(LIB_DIR => $custom_name);
    my @test_INC = ( @INC );
    my ($path) = grep { dir_equal($custom_lib, $_) == 1 } @test_INC;
    # Test 5
    cmp_ok( canonpath($path), 'eq', canonpath($custom_lib),
            'The import() function can find a custom named directory.' );

    {
        my @data = destroy_test_lib($custom_lib);
        if($data[0] != PASS) {
            BAIL_OUT($data[1]);
        }
    }
    lib::tree->import(':RESTORE-ORIGINAL');
    @test_INC = ( @INC );
    # Test 6
    is_deeply( \@test_INC, \@initial_INC,
               'The import() function can reset the @INC array back to its ' .
               'original content via \':RESTORE-ORIGINAL\'.' );
}


# Multiple import() function tests.
{
    my @alpha = ('a' .. 'z', '0' .. '9');
    my $base_dir_name = 'td_' .
                        $alpha[int(rand(scalar(@alpha)))] .
                        $alpha[int(rand(scalar(@alpha)))] .
                        $alpha[int(rand(scalar(@alpha)))] .
                        $alpha[int(rand(scalar(@alpha)))] .
                        $alpha[int(rand(scalar(@alpha)))];
    my $base_dir = undef;
    {
        my @data = create_test_lib($base_dir_name);
        if($data[0] != PASS) {
            BAIL_OUT($data[1]);
        }
        elsif($data[0] == PASS) {
            $base_dir = $data[1];
        }
    }
    my $custom_name = 'custom-perl';
    my @custom_libs = (undef, undef);
    {
        my @data = create_test_lib(catdir($base_dir_name, 'libperl'));
        if($data[0] != PASS) {
            BAIL_OUT($data[1]);
        }
        elsif($data[0] == PASS) {
            $custom_libs[0] = canonpath($data[1]);
        }
        @data = create_test_lib(catdir($base_dir_name, $custom_name));
        if($data[0] != PASS) {
            BAIL_OUT($data[1]);
        }
        elsif($data[0] == PASS) {
            $custom_libs[1] = canonpath($data[1]);
        }
    }

    lib::tree->import(DIRS => [$base_dir]);
    my @test_INC = ( @INC );
    my ($path) = grep { dir_equal($custom_libs[0], $_) == 1 } @test_INC;
    # Test 7
    cmp_ok( canonpath($path), 'eq', canonpath($custom_libs[0]),
            'The import() function can find the default directory in a ' .
            'different directory via DIRS parameter.' );

    lib::tree->import(':ORIGINAL');
    lib::tree->import(DELTA => 1);
    @test_INC = ( @INC );
    ($path) = grep { dir_equal($custom_libs[0], $_) == 1 } @test_INC;
    # Test 8
    cmp_ok( canonpath($path), 'eq', canonpath($custom_libs[0]),
            'The import() function can find the default directory in a ' .
            'different directory via DELTA parameter.' );

    lib::tree->import(':ORIGINAL');
    lib::tree->import([$base_dir], $custom_name);
    @test_INC = ( @INC );
    ($path) = grep { dir_equal($custom_libs[1], $_) == 1 } @test_INC;
    # Test 9
    cmp_ok( canonpath($path), 'eq', canonpath($custom_libs[1]),
            'The import() function can find a custom named directory in a ' .
            'different directory via a complex list with only the library ' .
            'directory name given.' );

    lib::tree->import(':ORIGINAL');
    lib::tree->import([$cwd], $custom_name, undef, undef, 1);
    @test_INC = ( @INC );
    ($path) = grep { dir_equal($custom_libs[1], $_) == 1 } @test_INC;
    # Test 10
    cmp_ok( canonpath($path), 'eq', canonpath($custom_libs[1]),
            'The import() function can find a custom named directory in a ' .
            'different directory via a complex list with the delta set.' );

    lib::tree->import(':ORIGINAL');
    lib::tree->import( DIRS => [$custom_libs[0], $custom_libs[1]],
                       LIB_DIR => '',
                       HALT_ON_FIND => 0 );
    @test_INC = ( @INC );
    my @custom_path = ();
    ($custom_path[0]) = map { canonpath($_) }
                        grep { dir_equal($custom_libs[0], $_) == 1 } @test_INC;
    ($custom_path[1]) = map { canonpath($_) }
                        grep { dir_equal($custom_libs[1], $_) == 1 } @test_INC;
    # Test 11
    is_deeply( \@custom_path, \@custom_libs,
               'The import() function can load multiple directories when ' .
               'called with a hash.' );

    {
        use IO::Handle;
        lib::tree->import(':ORIGINAL');
        my $redirect_STDERR = FALSE;
        my $temp_FILE_FH = FALSE;
        local *FILE_FH;
        local *ORIG_STDERR;
        {
            my $temp_filename = catfile($base_dir, "${base_dir_name}.err");
            my $file_status = open(FILE_FH, '>', $temp_filename);
            if($file_status) {
                $temp_FILE_FH = TRUE;
                open(ORIG_STDERR, ">&STDERR");
                print FILE_FH 'Redirecting STDERR during testing...\n\n';
                my $redirect_status = STDERR->fdopen(\*FILE_FH,  'w');
                if($redirect_status) {
                    $redirect_STDERR = TRUE;
                }
                print ORIG_STDERR "# Redirecting STDERR to '$temp_filename' " .
                                  "so the output of lib::tree in debug mode " .
                                  "does not clutter the screen.\n";
            }
        }
        lib::tree->import($custom_libs[0], $custom_libs[1], ':DEBUG');
        @test_INC = ( @INC );
        @custom_path = ();
        ($custom_path[0]) = map { canonpath($_) }
                            grep { dir_equal($custom_libs[0], $_) == 1 } @test_INC;
        ($custom_path[1]) = map { canonpath($_) }
                            grep { dir_equal($custom_libs[1], $_) == 1 } @test_INC;
        # Test 12
        is_deeply( \@custom_path, \@custom_libs,
                   'The import() function can load multiple directories when ' .
                   'called with a simple list.' );
        # Test 13
        cmp_ok( ${lib::tree::DEBUG}, '==', TRUE,
                'The import() function can set the debug flag to TRUE.' );
        lib::tree->import(':NO-DEBUG');
        # Test 14
        cmp_ok( ${lib::tree::DEBUG}, '==', FALSE,
                'The import() function can set the debug flag to FALSE.' );
        if($temp_FILE_FH) {
            close(FILE_FH);
        }
        if($redirect_STDERR) {
            close(STDERR);
            open(STDERR, ">&ORIG_STDERR");
            print STDERR "# The STDERR handle is now restored.\n";
        }
    }

    {
        my @data = destroy_test_lib($base_dir);
        if($data[0] != PASS) {
            BAIL_OUT($data[1]);
        }
    }
    lib::tree->import(':RESTORE-ORIGINAL-INC');
    @test_INC = ( @INC );
    # Test 15
    is_deeply( \@test_INC, \@initial_INC,
               'The import() function can reset the @INC array back to its ' .
               'original content via \':RESTORE-ORIGINAL-INC\'.' );
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

