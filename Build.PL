use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'lib::tree',
    license             => 'perl',
    dist_author         => q{Calvin Schwenzfeier <calvin.schwenzfeier@gmail.com>},
    dist_version_from   => 'lib/lib/tree.pm',
    build_requires => {
        'Carp' => 0,
        'Config' => 0,
        'Cwd' => 0,
        'File::Spec' => 0,
    },
    test_requires => {
        'File::Path' => 0,
        'IO::Handle' => 0,
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'lib-tree-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
