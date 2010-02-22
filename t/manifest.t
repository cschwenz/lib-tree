#!perl -T

use strict;
use warnings;
use Test::More;
require Cwd;

unless($ENV{RELEASE_TESTING}) {
    plan(skip_all => "Author tests not required for installation");
}

eval "use Test::CheckManifest 0.9";
plan(skip_all => "Test::CheckManifest 0.9 required") if($@);
my $sep_re = qr/[\\\/\:]/;
ok_manifest({ filter => [ qr/(?:$sep_re)\.git(?:$sep_re|\b)/,
                          qr/(?:$sep_re)\.svn(?:$sep_re|\b)/,
                          qr/(?:$sep_re)inc(?:$sep_re|\b)/,
                        ],
            });

