#!perl

use warnings;
use strict;
use Test::More tests => 3;
use File::Spec::Functions qw( splitpath catpath
                              splitdir catdir
                              file_name_is_absolute );
use File::Path qw(mkpath rmtree);
require Cwd;

my @initial_INC;
BEGIN {
    @initial_INC = ( @INC );
}
BEGIN {
    require_ok('lib::tree') || BAIL_OUT("Could not require 'lib::tree'!\n");
}

# We are using the import function directly to emulate someone
# saying 'use lib:tree ( ... );'

my $cwd = Cwd::getcwd();
my $test_lib = catdir($cwd, 'libperl');
if(-e $test_lib) {
    eval { rmtree($test_lib); };
    if($@) {
        BAIL_OUT("There was an error when we attempted to remove the '$test_lib' directory tree: $@ ");
    }
}

{
    lib::tree::import();
    my @test_INC = ( @INC );
    is_deeply(\@test_INC, \@initial_INC, 'import() does not alter the @INC array when there is nothing to add.');
}

eval { mkpath($test_lib); };
if($@) {
    BAIL_OUT("There was an error when we attempted to create the '$test_lib' directory tree: $@ ");
}
if(not -e $test_lib) {
    BAIL_OUT("Could not create the '$test_lib' directory tree.");
}

{
    lib::tree::import();
    my @test_INC = ( @INC );
    my ($path) = grep { $test_lib eq $_ } @test_INC;
use Data::Dumper;
die "\n\n" .
    Data::Dumper->new( [$cwd, $test_lib, $path, \@test_INC],
                       ['cwd', 'test_lib', 'path', 'test_INC']
                     )->Indent(1)->Sortkeys(1)->Useqq(1)->Dump() .
    "\n\n";
    cmp_ok($path, 'eq', $test_lib, 'import() can find the default directory.');
}

=begin COMMENT

END {
    if(-e $test_lib) {
        eval { rmtree($test_lib); };
        if($@) { BAIL_OUT("There was an error when we attempted to remove the '$test_lib' directory tree: $@ "); }
    }
}

=end COMMENT

=cut

