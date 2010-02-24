use inc::Module::Install;

name     'lib-tree';
all_from 'lib/lib/tree.pm';
author   q{Calvin Schwenzfeier <calvin.schwenzfeier@gmail.com>};
license  'perl';

build_requires( 'Test::More',
                'Config',
                'Carp',
                'File::Spec',
                'File::Spec::Functions',
                'File::Path',
                'IO::Handle',
                'Cwd',
              );

auto_install;

WriteAll;

