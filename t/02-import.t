use warnings;
use strict;
use Test::More tests => 9;
use File::Spec::Functions qw( splitpath catpath
                              splitdir catdir
                              canonpath file_name_is_absolute );
use File::Path qw(mkpath rmtree);
require Cwd;

my @initial_INC;
BEGIN {
    @initial_INC = ( @INC );
}
BEGIN {
    # Test 1
    require_ok('lib::tree') || BAIL_OUT("Could not require 'lib::tree'!\n");
}
my $cwd = Cwd::getcwd();
my $test_lib = catdir($cwd, 'libperl');

sub dir_equal {
    my $dir_a = shift;
    my $dir_b = shift;

    my @list_a = splitpath($dir_a);
    {
      my $pos = 1;
      my @list_a_dirs = splitdir($list_a[$pos]);
      splice(@list_a, $pos, 1, @list_a_dirs);
    }
    my @list_b = splitpath($dir_b);
    {
      my $pos = 1;
      my @list_b_dirs = splitdir($list_b[$pos]);
      splice(@list_b, $pos, 1, @list_b_dirs);
    }
    return 0 if(scalar(@list_a) != scalar(@list_b));

    my $max = scalar(@list_a);
    for(my $x = 0; $x < $max; $x++) {
        return 0 if(lc($list_a[$x]) ne lc($list_b[$x]));
    }

    return 1;
}

sub create_test_lib {
    my $dir = shift;
    my $lib_dir = ((defined $dir) && (length($dir) >= 1))
                      ? catdir($cwd, $dir)
                      : $test_lib;
    if(not -d $lib_dir) {
        eval { mkpath($lib_dir); };
        if($@) {
            BAIL_OUT( "There was an error when we attempted to create the " .
                      "'$lib_dir' directory tree: $@ " );
        }
    }
    if(not -d $lib_dir) {
        BAIL_OUT("Could not create the '$lib_dir' directory tree.");
    }
    elsif((defined $dir) && (length($dir) >= 1)) {
        return $lib_dir;
    }
    return;
}

sub destroy_test_lib {
    my $dir = shift;
    my $lib_dir = ((defined $dir) && (length($dir) >= 1))
                      ? catdir($cwd, $dir)
                      : $test_lib;
    if(-d $lib_dir) {
        eval { rmtree($lib_dir); };
        if($@) {
            BAIL_OUT( "There was an error when we attempted to remove the " .
                      "'$lib_dir' directory tree: $@ " );
        }
    }
    return;
}

sub create_dir {
    my $name = shift;
    my $dir = ((defined $name) && (length($name) >= 1))
                      ? catdir($cwd, $name)
                      : catdir($cwd, 'foo');
    if(not -d $dir) {
        eval { mkpath($dir); };
        if($@) {
            BAIL_OUT( "There was an error when we attempted to create the " .
                      "'$dir' directory tree: $@ " );
        }
    }
    if(not -d $dir) {
        BAIL_OUT("Could not create the '$dir' directory tree.");
    }
    elsif((defined $name) && (length($name) >= 1)) {
        return $dir;
    }
    return;
}




###########################################################################
## We are calling the import function as a method to emulate someone
## saying 'use lib:tree ( ... );'
###########################################################################


# Make sure we are starting with a clean slate.
destroy_test_lib();


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
    create_test_lib();

    lib::tree->import();
    my @test_INC = ( @INC );
    my ($path) = grep { dir_equal($test_lib, $_) == 1 } @test_INC;
    # Test 3
    cmp_ok( canonpath($path), 'eq', canonpath($test_lib),
            'The import() function can find the default directory.' );

    destroy_test_lib();
    lib::tree->import(':ORIGINAL');
    @test_INC = ( @INC );
    # Test 4
    is_deeply( \@test_INC, \@initial_INC,
               'The import() function can reset the @INC array back to its ' .
               'original content via \':ORIGINAL\'.' );
}


# The import() function can find a custom named directory.
{
    my $custom_dir = 'custom-perl-lib';
    my $custom_lib = create_test_lib($custom_dir);

    lib::tree->import(LIB_DIR => $custom_dir);
    my @test_INC = ( @INC );
    my ($path) = grep { dir_equal($custom_lib, $_) == 1 } @test_INC;
    # Test 5
    cmp_ok( canonpath($path), 'eq', canonpath($custom_lib),
            'The import() function can find a custom named directory.' );

    destroy_test_lib($custom_dir);
    lib::tree->import(':RESTORE-ORIGINAL');
    @test_INC = ( @INC );
    # Test 6
    is_deeply( \@test_INC, \@initial_INC,
               'The import() function can reset the @INC array back to its ' .
               'original content via \':RESTORE-ORIGINAL\'.' );
}


# The import() function can find the default directory in a different directory.
{
    my @alpha = ('a' .. 'z', 'A' .. 'Z', '0' .. '9');
    my $base_dir_name = 'dir_' .
                        $alpha[int(rand(scalar(@alpha)))] .
                        $alpha[int(rand(scalar(@alpha)))] .
                        $alpha[int(rand(scalar(@alpha)))] .
                        $alpha[int(rand(scalar(@alpha)))];
    my $base_dir = create_test_lib($base_dir_name);
    my $custom_lib = create_test_lib(catdir($base_dir_name, 'libperl'));

    lib::tree->import(DIRS => [$base_dir]);
    my @test_INC = ( @INC );
    my ($path) = grep { dir_equal($custom_lib, $_) == 1 } @test_INC;
    # Test 7
    cmp_ok( canonpath($path), 'eq', canonpath($custom_lib),
            'The import() function can find the default directory in a ' .
            'different directory via DIRS parameter.' );

    lib::tree->import(':ORIGINAL');
    lib::tree->import(DELTA => 1);
    @test_INC = ( @INC );
    ($path) = grep { dir_equal($custom_lib, $_) == 1 } @test_INC;
    # Test 8
    cmp_ok( canonpath($path), 'eq', canonpath($custom_lib),
            'The import() function can find the default directory in a ' .
            'different directory via DELTA parameter.' );

    destroy_test_lib($base_dir);
    lib::tree->import(':RESTORE-ORIGINAL-INC');
    @test_INC = ( @INC );
    # Test 9
    is_deeply( \@test_INC, \@initial_INC,
               'The import() function can reset the @INC array back to its ' .
               'original content via \':RESTORE-ORIGINAL-INC\'.' );
}


END {
    destroy_test_lib();
}

