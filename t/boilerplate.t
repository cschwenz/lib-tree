#!perl -T

use strict;
use warnings;
use Test::More;

unless($ENV{RELEASE_TESTING}) {
    plan(skip_all => "Author tests not required for installation");
}

plan(tests => 3);

sub not_in_file_ok {
    my %data = ( @_ );
    foreach my $filename (sort keys %data)
    {
        my %regex = %{$data{$filename}};
        open(my $fh, '<', $filename) or die "ERROR: Could not open '$filename' for reading: $! ";

        my %violated = ();
        while (my $line = <$fh>) {
            while (my ($desc, $regex) = each %regex) {
                if ($line =~ $regex) {
                    push @{$violated{$desc}||=[]}, $.;
                }
            }
        }

        if(scalar(keys(%violated)) >= 1) {
            diag("'$_' appears on lines @{$violated{$_}}") foreach (sort keys %violated);
            fail("$filename contains boilerplate text");
        } else {
            pass("$filename contains no boilerplate text");
        }
    }
}

sub module_boilerplate_ok {
    foreach my $module (@_)
    {
        not_in_file_ok(
            "$module" => {
              'the great new lib::tree' => qr/ - The great new /,
              'boilerplate description' => qr/Quick summary of what the module/,
              'stub function definition' => qr/function[12]/,
            }
        );
    }
}

not_in_file_ok(
    README => {
        "Default README paragraph 1 found!" => qr/(?:\b)The README is used to introduce the module and provide instructions on(?:\b)/,
        "Default README paragraph 2 found!" => qr/(?:\b)file from a module distribution so that people browsing the archive(?:\b)/,
    }
);

not_in_file_ok(
    Changes => {
      "placeholder date/time" => qr(Date/time),
    }
);

module_boilerplate_ok('lib/lib/tree.pm');

