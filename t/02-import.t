use warnings;
use strict;
use Test::More tests => 3;
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
    require_ok('lib::tree') || BAIL_OUT("Could not require 'lib::tree'!\n");
}


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




# We are using the import function directly to emulate someone
# saying 'use lib:tree ( ... );'


my $cwd = Cwd::getcwd();
my $test_lib = catdir($cwd, 'libperl');
if(-e $test_lib) {
    eval { rmtree($test_lib); };
    if($@) {
        BAIL_OUT( "There was an error when we attempted to remove the " .
                  "'$test_lib' directory tree: $@ " );
    }
}


# The import() function does not alter the @INC array when there is nothing
# to add.
{
    lib::tree::import();
    my @test_INC = ( @INC );
    is_deeply( \@test_INC, \@initial_INC,
               'The import() function does not alter the @INC array when ' .
               'there is nothing to add.' );
}


eval { mkpath($test_lib); };
if($@) {
    BAIL_OUT( "There was an error when we attempted to create the " .
              "'$test_lib' directory tree: $@ " );
}
if(not -e $test_lib) {
    BAIL_OUT("Could not create the '$test_lib' directory tree.");
}


# The import() function can find the default directory.
{
    lib::tree::import();
    my @test_INC = ( @INC );
    my ($path) = grep { dir_equal($test_lib, $_) == 1 } @test_INC;
    cmp_ok( canonpath($path), 'eq', canonpath($test_lib),
            'The import() function can find the default directory.' );
}


END {
    if(-e $test_lib) {
        eval { rmtree($test_lib); };
        if($@) {
            BAIL_OUT( "There was an error when we attempted to remove the " .
                      "'$test_lib' directory tree: $@ " );
        }
    }
}

