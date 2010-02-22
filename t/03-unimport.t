use warnings;
use strict;
use Test::More tests => 1;
use File::Spec::Functions qw( splitpath catpath
                              splitdir catdir
                              canonpath file_name_is_absolute );
use File::Path qw(mkpath rmtree);
require Cwd;

BEGIN {
    require_ok('lib::tree') || BAIL_OUT("Could not require 'lib::tree'!\n");
}




# We are using the unimport function directly to emulate someone
# saying 'no lib:tree ( ... );'

my $cwd = Cwd::getcwd();
my $test_lib = catdir($cwd, 'libperl');
if(-e $test_lib) {
    eval { rmtree($test_lib); };
    if($@) {
        BAIL_OUT( "There was an error when we attempted to remove the " .
                  "'$test_lib' directory tree: $@ " );
    }
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

