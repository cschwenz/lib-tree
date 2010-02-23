use warnings;
use strict;
use Test::More tests => 1;
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
my $cwd = Cwd::getcwd();
my $test_lib = catdir($cwd, 'libperl');

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
## We are calling the unimport function as a method to emulate someone
## saying 'no lib:tree ( ... );'
###########################################################################


# Make sure we are starting with a clean slate.
destroy_test_lib();

END {
    destroy_test_lib();
}

