package TestUtils;

use warnings;
use strict;
use File::Spec;
use File::Path qw(mkpath rmtree);
require Cwd;
require lib::tree;
require Exporter;

sub TRUE();
sub TRUE() { 1; }
sub FALSE();
sub FALSE() { 0; }

sub PASS();
sub PASS() { 1; }
sub FAIL();
sub FAIL() { 0; }
sub WARN();
sub WARN() { -1; }
sub ERROR();
sub ERROR() { -2; }

our @ISA = ('Exporter');
our @EXPORT = ();
our @EXPORT_OK = ( 'function_present', 'dir_equal',
                   'create_test_lib', 'create_test_lib_tree',
                   'destroy_test_lib', 'cleanup_tests',
                   'TRUE', 'FALSE', 'PASS', 'FAIL', 'WARN', 'ERROR' );
our $VERSION = '1.00';


our $FS = 'File::Spec';
our $cwd = Cwd::getcwd();
our $test_lib = $FS->catdir($cwd, 'libperl');




sub function_present {
    my $name = shift;

    my @data = (FAIL, "Unknown error!");
    eval "&lib::tree::${name}();";
    if($@) {
        @data = (FAIL, "Function $name is NOT present!  (Error: $@ )");
    }
    else {
        @data = (PASS, "Function $name is present.");
    }

    return @data;
}


sub dir_equal {
    my $dir_a = shift;
    my $dir_b = shift;

    my @list_a = $FS->splitpath($dir_a);
    {
      my $pos = 1;
      my @list_a_dirs = $FS->splitdir($list_a[$pos]);
      splice(@list_a, $pos, 1, @list_a_dirs);
    }
    my @list_b = $FS->splitpath($dir_b);
    {
      my $pos = 1;
      my @list_b_dirs = $FS->splitdir($list_b[$pos]);
      splice(@list_b, $pos, 1, @list_b_dirs);
    }
    return 0 if(scalar(@list_a) != scalar(@list_b));

    my $max = scalar(@list_a);
    for(my $x = 0; $x < $max; $x++) {
        return 0 if(lc($list_a[$x]) ne lc($list_b[$x]));
    }

    return 1;
}


sub create_test_lib {
    my $dir = shift;

    my $lib_dir = ((defined $dir) && (length($dir) >= 1))
                      ? $FS->catdir($cwd, $dir)
                      : $test_lib;
    my @data = (FAIL, "Unknown error!");
    if((not -e $lib_dir) || (not -d $lib_dir)) {
        $! = 0;
        my $num = undef;
        eval { $num = mkpath([$lib_dir], 0, 0777); };
        if($@) {
            @data = ( ERROR,
                      "There was an error when we attempted to create the " .
                      "'$lib_dir' directory tree: $@ " );
        }
        if((defined $num) && ($num >= 1)) {
            chmod(0777, $lib_dir);
            @data = (PASS, $lib_dir);
        }
        else {
            @data = (FAIL, "Could not mkpath(): $! ");
        }
    }
    if(-d $lib_dir) {
        chmod(0777, $lib_dir);
        @data = (PASS, $lib_dir);
    }

    return @data;
}


sub create_test_lib_tree {
    my $dir = shift;

    my @data = (FAIL, "Unknown error!");
    my $status = undef;
    my $lib_dir = undef;
    {
        use Config;
        my $version = $Config{version};
        my $archname = $Config{archname};
        my $archname64 = $Config{archname64};
        my @inc_ver_list = reverse split(/[ \t]+/, $Config{inc_version_list});

        @data = create_test_lib($dir);
        if($data[0] != PASS) {
            return @data;
        }
        elsif($data[0] == PASS) {
            $status = $data[0];
            $lib_dir = $data[1];
        }
        @data = create_test_lib($FS->catdir($dir, 'lib'));
        if($data[0] != PASS) {
            return @data;
        }
        @data = create_test_lib($FS->catdir($dir, 'site', 'lib'));
        if($data[0] != PASS) {
            return @data;
        }
        foreach my $d (@inc_ver_list, $archname, $archname64, $version) {
            next if(not $d);
            @data = create_test_lib($FS->catdir($dir, 'lib', $d));
            if($data[0] != PASS) {
                return @data;
            }
            @data = create_test_lib($FS->catdir($dir, 'site', 'lib', $d));
            if($data[0] != PASS) {
                return @data;
            }
            if($d eq $version) {
                foreach my $a ($archname, $archname64) {
                    next if(not $a);
                    @data = create_test_lib($FS->catdir($dir, 'lib', $d, $a));
                    if($data[0] != PASS) {
                        return @data;
                    }
                    @data = create_test_lib($FS->catdir( $dir, 'site', 'lib',
                                                         $d, $a ));
                    if($data[0] != PASS) {
                        return @data;
                    }
                }
            }
        }
        my $pin = 'PerlInterpreterName';
        @data = create_test_lib($FS->catdir($dir, $pin));
        if($data[0] != PASS) {
            return @data;
        }
        my @ptd = ( 'MSWin32-ActiveStatePerl', 'MSWin64-ActiveStatePerl',
                    'MSWin32-StrawberryPerl', 'MSWin64-StrawberryPerl',
                    'MSWin32-VanillaPerl', 'MSWin64-VanillaPerl',
                    'cygwin-UsrBinPerl', 'cygwin64-UsrBinPerl',
                    'cygwin-UsrLocalPerl', 'cygwin64-UsrLocalPerl',
                    'linux-UsrBinPerl', 'linux64-UsrBinPerl',
                    'linux-UsrLocalPerl', 'linux64-UsrLocalPerl',
                    'linux-ActiveStatePerl', 'linux64-ActiveStatePerl', );
        if(scalar(grep { lib::tree::_find_perl_type() eq $_ } @ptd) < 1) {
            push @ptd, lib::tree::_find_perl_type();
        }
        foreach my $pd (@ptd) {
            @data = create_test_lib($FS->catdir($dir, $pin, $pd));
            if($data[0] != PASS) {
                return @data;
            }
            @data = create_test_lib($FS->catdir($dir, $pin, $pd, 'lib'));
            if($data[0] != PASS) {
                return @data;
            }
            @data = create_test_lib($FS->catdir( $dir, $pin, $pd,
                                                 'site', 'lib' ));
            if($data[0] != PASS) {
                return @data;
            }
            foreach my $d (@inc_ver_list, $archname, $archname64, $version) {
                next if(not $d);
                @data = create_test_lib($FS->catdir( $dir, $pin, $pd,
                                                     'lib', $d ));
                if($data[0] != PASS) {
                    return @data;
                }
                @data = create_test_lib($FS->catdir( $dir, $pin, $pd,
                                                     'site', 'lib', $d ));
                if($data[0] != PASS) {
                    return @data;
                }
                if($d eq $version) {
                    foreach my $a ($archname, $archname64) {
                        next if(not $a);
                        @data = create_test_lib($FS->catdir( $dir, $pin, $pd,
                                                             'lib', $d, $a ));
                        if($data[0] != PASS) {
                            return @data;
                        }
                        @data = create_test_lib($FS->catdir( $dir, $pin, $pd,
                                                             'site', 'lib',
                                                             $d, $a ));
                        if($data[0] != PASS) {
                            return @data;
                        }
                    }
                }
            }
        }
    }
    @data = ($status, $lib_dir);

    return @data;
}


sub destroy_test_lib {
    my $dir = shift;

    my $lib_dir = ((defined $dir) && (length($dir) >= 1))
                      ? $FS->catdir($cwd, $dir)
                      : $test_lib;
    my @data = (FAIL, "Unknown error!");
    if((-e $lib_dir) && (-d $lib_dir)) {
        $! = 0;
        my $num = undef;
        eval { $num = rmtree([$lib_dir], 0, 1); };
        if($@) {
            @data = ( ERROR,
                      "There was an error when we attempted to remove the " .
                      "'$lib_dir' directory tree: $@ " );
        }
        if((defined $num) && ($num >= 1)) {
            @data = (PASS, $lib_dir);
        }
        else {
            @data = (FAIL, "Could not rmtree(): $! ");
        }
    }
    if(not -d $lib_dir) {
        @data = (PASS, $lib_dir);
    }

    return @data;
}


sub cleanup_tests {
    my @data = (FAIL, "Unknown error!");
    my @list = (undef, 'libperl', 'custom-perl-lib', 'custom-perl');
    my $status = opendir(my $DIR_FH, $cwd);
    if($status) {
        my @temp = grep { (-e $FS->catdir($cwd, $_)) &&
                          (-d $FS->catdir($cwd, $_)) }
                   grep { $_ =~ m/\A\s*td_[a-zA-Z0-9]{5}\s*\z/ }
                   readdir($DIR_FH);
        if(scalar(@temp) >= 1) {
            push @list, @temp;
        }
        closedir($DIR_FH);
    }
    else {
        @data = (WARN, "WARNING: Could not open directory '$cwd': $! ");
    }
    foreach my $l (@list) {
        my @temp = destroy_test_lib($l);
        if($temp[0] <= $data[0]) {
            @data = @temp;
        }
    }

    return @data;
}


1;
__END__

