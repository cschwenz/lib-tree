use inc::Module::Install;

name     'lib-tree';
all_from 'lib/lib/tree.pm';
author   q{Calvin Schwenzfeier <calvin.schwenzfeier@gmail.com>};
license  'perl';

build_requires( 'Config',
                'Carp',
                'File::Spec',
                'Cwd',
              );

test_requires( 'Test::More',
               'IO::Handle',
               'File::Path',
             );

auto_install;

WriteAll;

