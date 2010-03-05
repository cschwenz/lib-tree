use inc::Module::Install;

name     'lib-tree';
all_from 'lib/lib/tree.pm';
author   q{Calvin Schwenzfeier <calvin.schwenzfeier@gmail.com>};
license  'perl';

build_requires( 'Config',
                'Carp',
                'File::Spec',
                'File::Spec::Functions',
                'File::Path',
                'Cwd',
              );

test_requires( 'Test::More',
               'IO::Handle',
             );

auto_install;

WriteAll;

