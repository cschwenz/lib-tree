package lib::tree;

use warnings;
use strict;
use 5.006001;
use Config '%Config';
use Carp qw( carp croak );
use File::Spec;
use Cwd ();


sub TRUE();
sub TRUE() { 1; }
sub FALSE();
sub FALSE() { 0; }


our $VERSION = '0.04';
our @Original_INC;
our $DEBUG;
our $FS;
BEGIN {
    $lib::tree::VERSION = '0.04';
    @lib::tree::Original_INC = @INC;
    $lib::tree::DEBUG = FALSE;
    $lib::tree::FS = 'File::Spec';
    {
        no warnings 'redefine';
        no strict 'refs';
        *{'lib::tree::_valid_path'} =
            sub {
                my $path = shift;
                return FALSE if(not defined $path);
                # To return true, the given path:
                #     1. Must exist
                #     2. Be either a directory or a PAR archive
                #     3. Be readable by the effective user ID
                my $value = ( (-e $path) &&
                              ( (-d $path) ||
                                ( (-f $path) &&
                                  ($path =~ m/\.par\z/i)
                                )
                              ) &&
                              (-r $path)
                            ) ? TRUE : FALSE;
                return $value;
            };
        *{'lib::tree::_get_path_hash'} =
            sub {
                my $path = shift;
                my %hash = ( 'path' => $path, );
                ($hash{'volume'}, $hash{'directories'}, $hash{'file'}) =
                        $lib::tree::FS->splitpath($hash{'path'}, 1);
                @{$hash{'dirs'}} =
                        $lib::tree::FS->splitdir($hash{'directories'});
                return wantarray ? %hash : \%hash;
            };
        *{'lib::tree::_script_dir'} =
            sub {
                my %cwd = _get_path_hash(Cwd::getcwd());
                my %script = _get_path_hash("$0");
                # If this code was started with an absolute path, use that as
                # our default base directory; otherwise prepend the current
                # working directory to the (relative) code directory.
                my $path =
                    ($lib::tree::FS->file_name_is_absolute($script{'path'}))
                        ? $lib::tree::FS->catdir( $script{'volume'},
                                                  @{$script{'dirs'}} )
                        : $lib::tree::FS->catdir( $cwd{'volume'},
                                                  @{$cwd{'dirs'}},
                                                  @{$script{'dirs'}} );
                my $full_path = undef;
                eval { $full_path = Cwd::realpath($path); };
                if(not $full_path) {
                    $full_path = $path;
                }
                if(not _valid_path($full_path)) {
                    # If the code directory is not a valid path, fall back to
                    # using the current working directory.
                    $path = $lib::tree::FS->catdir( $cwd{'volume'},
                                                    @{$cwd{'dirs'}} );
                    eval { $full_path = Cwd::realpath($path); };
                    if(not $full_path) {
                        $full_path = $path;
                    }
                }
                return $full_path;
            };
    }
}


our %Default;
BEGIN {
    %lib::tree::Default = ( DIRS => [ lib::tree::_script_dir(), ],
                            LIB_DIR => 'libperl',
                            INTERPRETER_DIR => 'PerlInterpreterName',
                          );
}


my $version = $Config{version};
my $perl_version = sprintf('%vd', $^V);
my $major_version = undef;
my $archname = $Config{archname};
my $archname64 = $Config{archname64};
my $osname = $Config{osname};
my $perl_osname = $^O;
my @inc_version_list = reverse split(/[ \t]+/, $Config{inc_version_list});

# Validate the values given by %Config...
if( (not defined $version) || (length($version) < 1) ) {
    carp( "The version reported by Config is empty!" );
}
if( (not defined $perl_version) || (length($perl_version) < 1) ) {
    carp( "The version reported by the perl interpreter is empty!" );
}
if( (not defined $osname) || (length($osname) < 1) ) {
    carp( "The OS name reported by Config is empty!" );
}
if( (not defined $perl_osname) || (length($perl_osname) < 1) ) {
    carp( "The OS name reported by the perl interpreter is empty!" );
}
if( (defined $version) && (length($version) >= 1) &&
    (defined $perl_version) && (length($perl_version) >= 1) ) {
    if( ($perl_version eq $version) &&
        ($version =~ m/\A\s*(\d+(?:\.\d+)?)(?:\.\d+(?:\.\d+)*?)*?\s*\z/) ) {
        $major_version = $1;
    }
    elsif($perl_version ne $version) {
        carp( "The version reported by Config ($version) differs from the " .
              "version reported by the perl interpreter ($perl_version)!" );
    }
}
if( (defined $osname) && (length($osname) >= 1) &&
    (defined $perl_osname) && (length($perl_osname) >= 1) &&
    ($perl_osname ne $osname) ) {
    carp( "The OS name reported by Config ($osname) differs from the " .
          "OS name reported by the perl interpreter ($perl_osname)!" );
}
if( (defined $archname) && (length($archname) >= 1) &&
    (defined $osname) && (length($osname) >= 1) &&
    ($archname !~ m/(?:\b)\Q$osname\E(?:\b)/i) ) {
    carp( "The OS name reported by Config ($osname) was not found in the " .
          "architecture name ($archname)!" );
}
if( (defined $archname64) && (length($archname64) >= 1) &&
    (defined $osname) && (length($osname) >= 1) &&
    ($archname64 !~ m/(?:\b)\Q$osname\E(?:\b)/i) ) {
    carp( "The OS name reported by Config ($osname) was not found in the " .
          "64-bit architecture name ($archname64)!" );
}
if( (defined $archname) && (length($archname) >= 1) &&
    (defined $perl_osname) && (length($perl_osname) >= 1) &&
    ($archname !~ m/(?:\b)\Q$perl_osname\E(?:\b)/i) ) {
    carp( "The OS name reported by the perl interpreter ($perl_osname) was " .
          "not found in the architecture name ($archname)!" );
}
if( (defined $archname64) && (length($archname64) >= 1) &&
    (defined $perl_osname) && (length($perl_osname) >= 1) &&
    ($archname64 !~ m/(?:\b)\Q$perl_osname\E(?:\b)/i) ) {
    carp( "The OS name reported by the perl interpreter ($perl_osname) was " .
          "not found in the 64-bit architecture name ($archname64)!" );
}


# Typically called via "use lib::tree ( ... );"
sub import {
    my $object = shift;
    my $class = ref($object) || $object;
    my %param = _parse_params(@_);
    $DEBUG = ($param{DEBUG}) ? TRUE : FALSE;

    if($param{ORIGINAL}) {
      # Restore the original INC list.
      @INC = _simplify_list(@Original_INC);
    }
    else {
        my @lib_dirs = ();
        if(defined $param{LIB_DIR}) {
            my @dirs = ();
            if((defined $param{DIRS}) && (ref($param{DIRS}) eq 'ARRAY')) {
                @dirs = _find_dirs($param{DIRS});
            }
            @lib_dirs = _find_lib_dirs( $param{LIB_DIR},
                                        $param{DELTA},
                                        $param{DEPTH_FIRST},
                                        $param{HALT_ON_FIND},
                                        \@dirs );
        }
        my @inc_dirs = _find_INC_dirs(\@lib_dirs);
        foreach (@inc_dirs) { unshift(@INC, $_); }
        @INC = _simplify_list(@INC);
    }

    if($DEBUG) {
        print STDERR '' . ('-' x 78) . "\n";
        print STDERR "***DEBUG: The INC array is now:\n  " .
                     join("\n  ", @INC) . "\n";
        print STDERR '' . ('-' x 78) . "\n";
    }

    return;
}


# Typically called via "no lib::tree ( ... );"
sub unimport {
    my $object = shift;
    my $class = ref($object) || $object;
    my %param = _parse_params(@_);
    $DEBUG = ($param{DEBUG}) ? TRUE : FALSE;

    my %remove = ();
    if($param{ORIGINAL}) {
      # Remove the values which were in the original INC list.
      foreach (@Original_INC) { $remove{$_} = 1; }
    }
    else {
        my @lib_dirs = ();
        if(defined $param{LIB_DIR}) {
            my @dirs = ();
            if((defined $param{DIRS}) && (ref($param{DIRS}) eq 'ARRAY')) {
                @dirs = _find_dirs($param{DIRS});
            }
            @lib_dirs = _find_lib_dirs( $param{LIB_DIR},
                                        $param{DELTA},
                                        $param{DEPTH_FIRST},
                                        $param{HALT_ON_FIND},
                                        \@dirs );
        }
        my @remove_dirs = _find_INC_dirs(\@lib_dirs);
        foreach (@remove_dirs) { $remove{$_} = 1; }
    }
    @INC = grep { (not exists $remove{$_}) } @INC;
    @INC = _simplify_list(@INC);

    if($DEBUG) {
        print STDERR '' . ('-' x 78) . "\n";
        print STDERR "***DEBUG: The INC array is now:\n  " .
                     join("\n  ", @INC) . "\n";
        print STDERR '' . ('-' x 78) . "\n";
    }

    return;
}


sub _parse_params {
    my @list = @_;

    my %param = ( DIRS => undef, # Array Reference
                  LIB_DIR => undef, # Scalar
                  ORIGINAL => FALSE, # Boolean
                  DEPTH_FIRST => TRUE, # Boolean
                  HALT_ON_FIND => TRUE, # Boolean
                  DELTA => 0, # Number
                  DEBUG => FALSE, # Boolean
                );

    # If the first value passed is a valid parameter name, then we were passed a
    # hash.
    if( (scalar(@list) >= 2) &&
        (scalar(grep { uc($list[0]) eq $_ } keys(%param)) >= 1) ) {
        for(my $x = 0; $x <= $#list; $x+=2) {
            $param{uc($list[$x])} = $list[$x + 1];
        }
    }
    # If the first value is an array reference, then treat the passed values as
    # a list where order matters.
    elsif(ref($list[0]) eq 'ARRAY') {
        my $array_ref = shift(@list);
        my @temp = ();
        for(my $x = 0; $x <= $#{$array_ref}; $x++) {
            if(defined $array_ref->[$x]) {
                $temp[$x] = $array_ref->[$x];
            }
            else {
                $temp[$x] = _script_dir();
            }
        }
        $param{DIRS} = \@temp;
        if(scalar(@list) >= 1) {
            $param{LIB_DIR} = shift(@list);
        }
        if(scalar(@list) >= 1) {
            $param{DEPTH_FIRST} = shift(@list);
        }
        if(scalar(@list) >= 1) {
            $param{HALT_ON_FIND} = shift(@list);
        }
        if(scalar(@list) >= 1) {
            $param{DELTA} = shift(@list);
        }
        if(scalar(@list) >= 1) {
            $param{DEBUG} = shift(@list);
        }
    }
    # If all else fails, treat the passed values as a simple list of directory
    # names (after parsing out the special command ops; all command ops start
    # with a ':').
    elsif(scalar(@list) >= 1) {
        $param{LIB_DIR} = '';
        $param{HALT_ON_FIND} = FALSE;
        my $no_re = qr/NO[\-\_]/i;
        my %op = ( ORIGINAL =>
                       qr/(?:$no_re)?(?:RESTORE[\-\_])?ORIGINAL(?:[\-\_]INC)?/i,
                   DEPTH_FIRST => qr/(?:$no_re)?DEPTH(?:[\-\_]FIRST)?/i,
                   HALT_ON_FIND => qr/(?:$no_re)?HALT(?:[\-\_]ON[\-\_]FIND)?/i,
                   DEBUG => qr/(?:$no_re)?DEBUG/i,
                 );
        LIST: for(my $x = 0; $x <= $#list; $x++) {
            foreach my $name (keys %op) {
                my $regex = $op{$name};
                if($list[$x] =~ m/\A\s*[:]($regex)\s*\z/) {
                    my $cmd = $1;
                    $param{$name} = ($cmd =~ m/\A\s*$no_re/) ? 0 : 1;
                    splice(@list, $x, 1);
                    $x--;
                    next LIST;
                }
            }
        }
        $param{DIRS} = \@list;
    }

    # If a parameter value was not set, set a default value.  If a parameter
    # value was set to something we were not expecting, try to correct the
    # error; if that fails, set the bad parameter to its default value.
    if(not defined $param{DIRS}) {
        $param{DIRS} = \@{$Default{DIRS}};
    }
    if((defined $param{DIRS}) && (ref($param{DIRS}) ne 'ARRAY')) {
        carp("The DIRS parameter is expecting an array reference.");
        if(ref($param{DIRS}) eq '') {
            carp("The DIRS parameter is fixable, converting from scalar.");
            my @temp = ( $param{DIRS}, );
            $param{DIRS} = \@temp;
        }
        elsif(ref($param{DIRS}) eq 'HASH') {
            carp("The DIRS parameter is fixable, converting from hash.");
            my @temp = sort keys %{$param{DIRS}};
            $param{DIRS} = \@temp;
        }
        else {
            carp("The DIRS parameter is not fixable, reverting to default.");
            $param{DIRS} = \@{$Default{DIRS}};
        }
    }
    if((defined $param{DIRS}) && (ref($param{DIRS}) eq 'ARRAY')) {
        my $bad_dir_param = 0;
        for(my $x = 0; $x <= $#{$param{DIRS}}; $x++) {
            if(not defined $param{DIRS}->[$x]) {
                carp( "Undefined value at position $x " .
                      "in DIRS parameter (zero-based)." );
                $bad_dir_param = 1;
            }
            elsif(ref($param{DIRS}->[$x]) ne '') {
                carp( "Value is not a scalar at position $x " .
                      "in DIRS parameter (zero-based)." );
                $bad_dir_param = 1;
            }
            elsif(length($param{DIRS}->[$x]) < 1) {
                carp( "Empty value at position $x " .
                      "in DIRS parameter (zero-based)." );
                $bad_dir_param = 1;
            }
        }
        if($bad_dir_param) {  # The above errors are not fixable... :-/
            croak("Too many errors in DIRS parameter.");
        }
    }
    if(not defined $param{LIB_DIR}) {
        $param{LIB_DIR} = $Default{LIB_DIR};
    }
    if( (defined $param{ORIGINAL}) &&
        ($param{ORIGINAL} =~ m/\A\s*(?:1|T(?:rue)?)\s*\z/i) ) {
        $param{ORIGINAL} = TRUE;
    }
    else {
        $param{ORIGINAL} = FALSE;
    }
    if( (defined $param{DEPTH_FIRST}) &&
        ($param{DEPTH_FIRST} =~ m/\A\s*(?:0|F(?:alse)?)\s*\z/i) ) {
        $param{DEPTH_FIRST} = FALSE;
    }
    else {
        $param{DEPTH_FIRST} = TRUE;
    }
    if( (defined $param{HALT_ON_FIND}) &&
        ($param{HALT_ON_FIND} =~ m/\A\s*(?:0|F(?:alse)?)\s*\z/i) ) {
        $param{HALT_ON_FIND} = FALSE;
    }
    else {
        $param{HALT_ON_FIND} = TRUE;
    }
    if( (defined $param{DELTA}) &&
        ($param{DELTA} =~ m/\A\s*[\+\-]?\s*(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][\+\-]?\d+)?\s*\z/) ) {
        $param{DELTA} = abs(int($param{DELTA} * 1));
    }
    else {
        $param{DELTA} = 0;
    }
    if( (defined $param{DEBUG}) &&
        ($param{DEBUG} =~ m/\A\s*(?:1|T(?:rue)?)\s*\z/i) ) {
        $param{DEBUG} = TRUE;
    }
    else {
        $param{DEBUG} = FALSE;
    }

    return wantarray ? %param : \%param;
}


sub _find_dirs {
    my $list_ref = shift;

    my @dirs = ();
    foreach my $dir (@{$list_ref}) {
        my @temp = _glob_dir($dir);
        _add_to_list(\@dirs, \@temp);
    }
    if($DEBUG) {
        print STDERR '' . ('-' x 78) . "\n";
        print STDERR "***DEBUG: Found these directories:\n  " .
                     join("\n  ", @dirs) . "\n";
        print STDERR '' . ('-' x 78) . "\n";
    }

    return wantarray ? @dirs : \@dirs;
}


sub _find_lib_dirs
{
    my $lib_dir = shift;
    my $delta = shift;
    my $depth_first = shift;
    my $halt = shift;
    my $dirs_ref = shift;

    my $found_dir = undef;
    my @lib_dirs = ();
    if($depth_first) {
        SEARCH: foreach my $p (@{$dirs_ref}) {
            my %dir = _get_path_hash($p);
            my $d = $FS->catdir($dir{'volume'}, @{$dir{'dirs'}});
            my @up = ();
            my @down = ();
            for(my $x = 0; $x <= $delta; $x++) {
                if($DEBUG && ($x > 0)) {
                    print STDERR "***DEBUG: Searching up/down $x " .
                                 "director" . (($x == 1) ? 'y' : 'ies') .
                                 " from '$d' (searching max of $delta " .
                                 "director" . (($x == 1) ? 'y' : 'ies') .
                                 " up/down).\n";
                }
                my $up_dir = $FS->catdir($d, @up, $lib_dir);
                my @temp_up = _glob_dir($up_dir);
                $found_dir = _add_to_list(\@lib_dirs, \@temp_up, $found_dir);
                my $down_dir = $FS->catdir($d, @down, $lib_dir);
                my @temp_down = _glob_dir($down_dir);
                $found_dir = _add_to_list(\@lib_dirs, \@temp_down, $found_dir);
                push @up, '..';
                push @down, '*';
                if((defined $found_dir) && $halt) {
                    if($DEBUG) {
                        print STDERR "***DEBUG: Found a LIB_DIR, halting " .
                                     "search.\n";
                    }
                    last SEARCH;
                }
            }
        }
    }
    else {
        my @up = ();
        my @down = ();
        SEARCH: for(my $x = 0; $x <= $delta; $x++) {
            foreach my $p (@{$dirs_ref}) {
                my %dir = _get_path_hash($p);
                my $d = $FS->catdir($dir{'volume'}, @{$dir{'dirs'}});
                if($DEBUG && ($x > 0)) {
                    print STDERR "***DEBUG: Searching up/down $x " .
                                 "director" . (($x == 1) ? 'y' : 'ies') .
                                 " from '$d' (searching max of $delta " .
                                 "director" . (($x == 1) ? 'y' : 'ies') .
                                 " up/down).\n";
                }
                my $up_dir = $FS->catdir($d, @up, $lib_dir);
                my @temp_up = _glob_dir($up_dir);
                $found_dir = _add_to_list(\@lib_dirs, \@temp_up, $found_dir);
                my $down_dir = $FS->catdir($d, @down, $lib_dir);
                my @temp_down = _glob_dir($down_dir);
                $found_dir = _add_to_list(\@lib_dirs, \@temp_down, $found_dir);
                if((defined $found_dir) && $halt) {
                    if($DEBUG) {
                        print STDERR "***DEBUG: Found a LIB_DIR, halting " .
                                     "search.\n";
                    }
                    last SEARCH;
                }
            }
            push @up, '..';
            push @down, '*';
        }
    }

    @lib_dirs = _simplify_list(@lib_dirs);
    if($DEBUG) {
        print STDERR '' . ('-' x 78) . "\n";
        print STDERR "***DEBUG: Passed LIB_DIR resulted in finding these " .
                     "directories:\n  " . join("\n  ", @lib_dirs) . "\n";
        if(defined $found_dir) {
            print STDERR "***DEBUG: The first LIB_DIR found was " .
                         "'$found_dir'.\n";
        }
        print STDERR '' . ('-' x 78) . "\n";
    }
    if($halt && (defined $found_dir)) {
        @lib_dirs = ($found_dir);
    }

    return wantarray ? @lib_dirs : \@lib_dirs;
}

sub _find_INC_dirs {
    my $dirs_ref = shift;

    my @inc_dirs = ();
    foreach my $dir (@{$dirs_ref}) {
        next if(not defined $dir);
        next if(not _valid_path($dir));
        push(@inc_dirs, $dir);
        # Add the library tree under each library directory we found to the
        # INC array.
        my @d = _get_dirs($dir);
        foreach (@d) {
            if(_valid_path($_)) {
              push(@inc_dirs, $_);
            }
        }
        my %root = _get_path_hash($dir);
        my $interp_dir = $FS->catdir( $root{'volume'}, @{$root{'dirs'}},
                                      $Default{INTERPRETER_DIR},
                                      _find_perl_type() );
        if(_valid_path($interp_dir)) {
            # If we found a directory which differentiates the Perl library
            # by interpreter type, then add the library tree under the
            # directory which matches our interpreter to the INC array.
            my @d = _get_dirs($interp_dir);
            foreach (@d) {
                if(_valid_path($_)) {
                    push(@inc_dirs, $_);
                }
            }
        }
    }

    return wantarray ? @inc_dirs : \@inc_dirs;
}


sub _get_dirs {
    my $path = shift;

    my %dir = _get_path_hash($path);
    my @lib = ( $FS->catdir( $dir{'volume'}, @{$dir{'dirs'}},
                             'lib' ), );
    my @site_lib = ( $FS->catdir( $dir{'volume'}, @{$dir{'dirs'}},
                                  'site', 'lib' ), );
    foreach my $ver (@inc_version_list) {
        if((defined $ver) && (length($ver) >= 1)) {
            push @lib, $FS->catdir($lib[0], $ver);
            push @site_lib, $FS->catdir($site_lib[0], $ver);
        }
    }
    foreach my $a ($archname, $archname64) {
        if((defined $a) && (length($a) >= 1)) {
            push @lib, $FS->catdir($lib[0], $a);
            push @site_lib, $FS->catdir($site_lib[0], $a);
        }
    }
    foreach my $v ($major_version, $version) {
        if((defined $v) && (length($v) >= 1)) {
            push @lib, $FS->catdir($lib[0], $v);
            push @site_lib, $FS->catdir($site_lib[0], $v);
            foreach my $a ($archname, $archname64) {
                if((defined $a) && (length($a) >= 1)) {
                    push @lib, $FS->catdir($lib[0], $v, $a);
                    push @site_lib, $FS->catdir($site_lib[0], $v, $a);
                }
            }
        }
    }
    my @dirs = (@lib, @site_lib);

    return wantarray ? @dirs : \@dirs;
}


sub _find_perl_type {
    my %perl = _get_path_hash("$^X");
    my $strawberry_re = qr/(?:\b)strawberry[\-]?perl(?:\b)/i;
    my $vanilla_re = qr/(?:\b)vanilla[\-]?perl(?:\b)/i;

    my $perl_type = undef;
    if(`$^X -v` =~ m/(?:\b)Active(?:State|Perl)(?:\b)/) {
        $perl_type = 'ActiveState';
    }
    elsif(scalar(grep { m/$strawberry_re/ } @{$perl{'dirs'}}) >= 1) {
        $perl_type = 'Strawberry';
    }
    elsif(scalar(grep { m/$vanilla_re/ } @{$perl{'dirs'}}) >= 1) {
        $perl_type = 'Vanilla';
    }
    else {
        # When all else fails, use the first one or two directories in the path
        # to the perl interpreter.
        my @clean = grep { (defined $_) && (length($_) >= 1) } @{$perl{'dirs'}};
        $perl_type = '';
        if(defined $clean[0]) { $perl_type .= $clean[0]; }
        if(defined $clean[1]) { $perl_type .= '~' . $clean[1]; }
        if($DEBUG) {
            print STDERR "***DEBUG: The raw Perl type is '$perl_type'.\n";
        }
        $perl_type =~ s/\A\W+//;
        $perl_type =~ s/\W*[0-9\.\-]*?\W+\z//;
        $perl_type = join('', map { ucfirst($_) } split(/\W+/, $perl_type));
    }

    if($perl_type !~ m/Perl\z/) {
        $perl_type = "${perl_type}Perl";
    }
    my $os = $osname;
    if((defined $archname64) && ($os !~ m/64/)) {
        if(($os !~ m/32/) && ($os !~ m/x86/)) {
            $os .= '64';
        }
        elsif($os =~ m/32/) {
            $os =~ s/32/64/;
        }
        elsif($os =~ m/x86(?:_64)?/) {
            $os =~ s/x86(?:_64)?/x64/;
        }
    }
    if($perl_type !~ m/\A\Q$os\E[\-]/) {
        $perl_type = "${os}-${perl_type}";
    }
    if($DEBUG) { print STDERR "***DEBUG: The Perl type is '$perl_type'.\n"; }

    return $perl_type;
}


sub _glob_dir {
    my $dir = shift;

    my @list = grep { _valid_path($_) }
               map { my $p = undef;
                     eval { $p = Cwd::realpath($_); };
                     if(not $p) { $p = $_; }
                     $p; }
               grep { -e $_ } glob($dir);

    return wantarray ? @list : \@list;
}


sub _add_to_list {
    my $list_ref = shift;
    my $dirs_ref = shift;
    my $lib_dir = shift;

    foreach my $dir (@{$dirs_ref}) {
        if(_valid_path($dir)) {
            push @{$list_ref}, $dir;
            if(not defined $lib_dir) {
                $lib_dir = $dir;
            }
        }
    }

    return $lib_dir;
}


sub _simplify_list {
  my @list = @_;

  my @clean = ();
  foreach my $dir (@list)
  {
    if(scalar(grep { $dir eq $_ } @clean) < 1) { push @clean, $dir; }
  }

  return wantarray ? @clean : \@clean;
}


1;
__END__

=pod

=head1 NAME

lib::tree - Add directory trees to the C<@INC> array at compile time.


=head1 VERSION

Version 0.04


=head1 SYNOPSIS

This pragma allows you to specify one or more directories to search for the
given library directory name to be added to the C<@INC> array.  Also, based on
Perl interpreter type and version, this pragma will add the correct
sub-directories within the given library directory (but only if said directories
are found).

    # Called with a hash:
    use lib::tree ( DIRS =>  [ '/some/directory/',
                               'another/directory/',
                               '/yet/another/directory/with/*/globbing/',
                               'more/{dir,directory}/glob?/fun/',
                             ], # Accepts absolute/relative directories, with or
                                # without globbing.  (Defaults to the directory
                                # of the currently running script; i.e., if the
                                # full path to the script which invoked
                                # lib::tree is '/home/foo/scripts/bar.pl' then
                                # the default will be '/home/foo/scripts/')
                    LIB_DIR => 'libName', # This should be *just* the name of
                                          # the directory (i.e., neither a
                                          # relative nor an absolute path;
                                          # defaults to 'libperl')!
                    DEPTH_FIRST => 0, # If this is false, then lib::tree will do
                                      # a breadth-first search of the
                                      # directories listed by the DIRS
                                      # parameter.  (Defaults to 1; this allows
                                      # the order of directories specified in
                                      # the DIRS parameter to be honored)
                    HALT_ON_FIND => 1, # Do we want to stop searching
                                       # directories for the given LIB_DIR when
                                       # we find our first match?  (Defaults to
                                       # 1; normally you do not want multiple
                                       # LIB_DIRs found.)
                    DELTA => 2, # How many directories up and down the directory
                                # tree from a given location in said tree are we
                                # to search for a LIB_DIR?  (Defaults to 0; that
                                # is, we normally do *not* look outside of the
                                # directories listed by the DIRS parameter)
                  );
    
    
    # Called with a list which begins with an array reference:
    use lib::tree ( [ '/some/directory/',
                      'another/directory/',
                      '/yet/another/directory/with/*/globbing/',
                      'more/{dir,directory}/glob?/fun/',
                    ], # The DIRS parameter.
                    'libName', # The LIB_DIR parameter.
                    0, # The DEPTH_FIRST parameter.
                    1, # The HALT_ON_FIND parameter.
                    2, # The DELTA parameter.
                  );
    # PLEASE NOTE:
    #     Order matters! If you want to leave a value at the default setting but
    #     want to change the value of something later in the list, use the
    #     undefined value as a placeholder for the default values you do no want
    #     to change.
    
    
    # Called with a simple list:
    use lib::tree ( '/some/directory/',
                    'another/directory/',
                    '/yet/another/directory/with/*/globbing/',
                    'more/{dir,directory}/glob?/fun/',
                  );
    # PLEASE NOTE:
    #     If lib::tree is called with a simple list, two defaults change:
    #         * LIB_DIR defaults to '' (i.e., everything that matches what is
    #           listed will be added to the @INC array).
    #         * HALT_ON_FIND defaults to 0 (otherwise, only the first matching
    #           directory would be added to the INC array).


=head1 USAGE

Upon finding a directory whose name matches the C<LIB_DIR> parameter in one of
the specified directories, the full path to that directory (i.e.,
F</B<{specified_dir}>/B<{custom_lib}>/>)is added to the C<@INC> array as well as
the following directories (replace F<B<{lib_dir}>> with F<lib> and F<site/lib>)
within the newly added directory (but only if said directories exist and are
readable):

=over

=item *

F<.../B<{lib_dir}>/>

=item *

F<.../B<{lib_dir}>/B<{previous_version(s)}>/>

=item *

F<.../B<{lib_dir}>/B<{archname}>/>

=item *

F<.../B<{lib_dir}>/B<{archname64}>/>

=item *

F<.../B<{lib_dir}>/B<{major_version}>/>

=item *

F<.../B<{lib_dir}>/B<{major_version}>/B<{archname}>/>

=item *

F<.../B<{lib_dir}>/B<{major_version}>/B<{archname64}>/>

=item *

F<.../B<{lib_dir}>/B<{version}>/>

=item *

F<.../B<{lib_dir}>/B<{version}>/B<{archname}>/>

=item *

F<.../B<{lib_dir}>/B<{version}>/B<{archname64}>/>

=back

Additionally, C<lib::tree> looks for a directory named
F<.../B<{custom_lib}>/PerlInterpreterName/B<{os_name}>-B<{perl_type}>/>.  If
such a directory is found, then that directory (as well as any directories
underneath it which match the above list) are added to the C<@INC> array.  This
is done so a single custom library may contain binary Perl modules for different
interpreters.

For example, a single custom library loaded via C<lib::tree>
could support the following Perl interpreters if the associated directories were
present and readable:

=over

=item *

ActiveState Perl on Windows supported via
F<.../B<{custom_lib}>/PerlInterpreterName/MSWin32-ActiveStatePerl/>

=item *

Strawberry Perl on Windows supported via
F<.../B<{custom_lib}>/PerlInterpreterName/MSWin32-StrawberryPerl/>

=item *

Vanilla Perl on Windows supported via
F<.../B<{custom_lib}>/PerlInterpreterName/MSWin32-VanillaPerl/>

=item *

F</usr/bin/perl> on Cygwin supported via
F<.../B<{custom_lib}>/PerlInterpreterName/cygwin-UsrBinPerl/>

=item *

F</usr/local/bin/perl> on Linux supported via
F<.../B<{custom_lib}>/PerlInterpreterName/linux-UsrLocalPerl/>

=item *

F</usr/bin/perl> on Linux supported via
F<.../B<{custom_lib}>/PerlInterpreterName/linux-UsrBinPerl/>

=back

Please note, definitively identifying different Perl interpreters is an ongoing
subject of research (if C<lib::tree> is I<not> correctly identifying your
platform please suggest a method of doing so to the author/maintainer of this
module).  Also, the F<B<{os_name}>-> prefix is needed because of ActiveState's
broken (bordering on brain-damaged) install which does not put binary Perl
modules in the canonical location (that is, in any of the above mentioned
F<.../B<{archname}>/> or F<.../B<{archname64}>/> directories).

Of note is when this module is called with a simple list (that is, a list where
all values are scalars), four configuration commands are honored (all commands
begin with the 'C<:>' character):

=over

=item C<:ORIGINAL>

Restores C<@INC> array to its original condition.  This is provided as an
alternative to saying C<@INC = @lib::tree::Original_INC;> (which some schools of
thought consider to be inelegant).  May be negated by prepending C<NO-> (i.e.,
C<:NO-ORIGINAL>).

Synonyms are:
C<:ORIGINAL-INC>, C<:RESTORE-ORIGINAL>, C<:RESTORE-ORIGINAL-INC>,
C<:ORIGINAL_INC>, C<:RESTORE_ORIGINAL>, C<:RESTORE_ORIGINAL_INC>

=item C<:DEPTH>

Sets the search type to depth-first.  May be negated by prepending C<NO-> (i.e.,
C<:NO-DEPTH>).

Synonyms are: C<:DEPTH-FIRST>, C<:DEPTH_FIRST>

=item C<:HALT>

Sets the search style to halt on the first directory which satisfies the search
criteria.  May be negated by prepending C<NO-> (i.e., C<:NO-HALT>).

Synonyms are: C<:HALT-ON-FIND>, C<:HALT_ON_FIND>

=item C<:DEBUG>

Turns on debugging.  May be negated by prepending C<NO-> (i.e., C<:NO-DEBUG>).

=back

Also, C<lib::tree> uses the C<File::Spec> module methods for all path
manipulation.  As an added bonus, C<lib::tree> allows you to specify which
flavour of C<File::Spec> you want C<lib::tree> to use via the C<$FS> variable
(defaults to C<'File::Spec'>).

Should you want C<lib::tree> to use a specific flavour of C<File::Spec>, use
something like the following code:

    BEGIN {
        require lib::tree;
        $lib::tree::FS = 'File::Spec::Unix';
    }
    use lib::tree ('/some/directory/', 'another/directory/');
    
    #  ~~~ or ~~~  
    
    BEGIN {
        require lib::tree;
        $lib::tree::FS = 'File::Spec::Unix';
        lib::tree->import('/some/directory/', 'another/directory/');
    }


=head1 EXAMPLES

=over

=item B<S<Example 1:>>

    use lib::tree;

The above incantation will look in F</B<{full_path_to_script_directory}>/> (or whatever the C<$lib::tree::Default{DIRS}> array reference is set to) for a directory named F<libperl> (or whatever the C<$lib::tree::Default{LIB_DIR}> scalar value is set to).

=item B<S<Example 2:>>

    use lib::tree ( DIRS =>  [ '/home/cschwenz/foo/',
                               '/home/cschwenz/bar/' ],
                  );

The above incantation will look in F</home/cschwenz/foo/> and
F</home/cschwenz/bar/> for a directory named F<libperl> (or whatever the C<$lib::tree::Default{LIB_DIR}> scalar value is set to).

=item B<S<Example 3:>>

    use lib::tree ( DIRS =>  [ '/home/cschwenz/foo/',
                               '/home/cschwenz/bar/' ],
                    LIB_DIR => 'custom_perl_lib',
                  );

The above incantation will look in F</home/cschwenz/foo/> and
F</home/cschwenz/bar/> for a directory named F<custom_perl_lib>.

=item B<S<Example 4:>>

    use lib::tree ( DIRS =>  [ '/home/cschwenz/foo/',
                               '/home/cschwenz/bar/' ],
                    LIB_DIR => 'custom_perl_lib',
                    DELTA => 3,
                  );

The above incantation will look up/down the directory tree to a max of three
directories from the starting locations of F</home/cschwenz/foo/> and
F</home/cschwenz/bar/> for a directory named F<custom_perl_lib>.

That is, the directories F</home/cschwenz/foo/>, F</home/cschwenz/foo/../>,
F</home/cschwenz/foo/*/>, F</home/cschwenz/foo/../../>,
F</home/cschwenz/foo/*/*/>, F</home/cschwenz/foo/../../../>,
F</home/cschwenz/foo/*/*/*/>, F</home/cschwenz/bar/>, F</home/cschwenz/bar/../>,
F</home/cschwenz/bar/*/>, F</home/cschwenz/bar/../../>,
F</home/cschwenz/bar/*/*/>, F</home/cschwenz/bar/../../../>, and
F</home/cschwenz/bar/*/*/*/> will be searched for a directory named
F<custom_perl_lib> (in that order).  The search will halt upon finding the first
instance of a directory named F<custom_perl_lib>.

=item B<S<Example 5:>>

    use lib::tree ( DIRS =>  [ '/home/cschwenz/foo/',
                               '/home/cschwenz/bar/' ],
                    LIB_DIR => 'custom_perl_lib',
                    DEPTH_FIRST => 0,
                    DELTA => 2,
                  );

The above incantation will look up/down the directory tree to a max of two
directories from the starting locations of F</home/cschwenz/foo/> and
F</home/cschwenz/bar/> for a directory named F<custom_perl_lib>.  But, because
the C<DEPTH_FIRST> parameter is now false, do a breadth-first search instead.

The C<DEPTH_FIRST> parameter change is important because it changes the order
directories are searched (thus potentially changing which F<custom_perl_lib>
gets loaded due to the C<HALT_ON_FIND> parameter defaulting to true).  That is,
the directories F</home/cschwenz/foo/>, F</home/cschwenz/bar/>,
F</home/cschwenz/foo/../>, F</home/cschwenz/bar/../>, F</home/cschwenz/foo/*/>,
F</home/cschwenz/bar/*/>, F</home/cschwenz/foo/../../>,
F</home/cschwenz/bar/../../>, F</home/cschwenz/foo/*/*/>, and
F</home/cschwenz/bar/*/*/> will be searched for a directory named
F<custom_perl_lib> (in that order).  The search will halt upon finding the first
instance of a directory named F<custom_perl_lib>.

=item B<S<Example 6:>>

    use lib::tree ( DIRS =>  [ '/home/cschwenz/foo/',
                               '/home/cschwenz/bar/' ],
                    LIB_DIR => 'custom_perl_lib',
                    HALT_ON_FIND => 0,
                  );

The above incantation will look in F</home/cschwenz/foo/> and
F</home/cschwenz/bar/> for a directory named F<custom_perl_lib>.  But because the C<HALT_ON_FIND> parameter is now false, C<lib::tree> will continue searching regardless of what it finds; if there is a F<custom_perl_lib> directory in both directories, then both F</home/cschwenz/foo/custom_perl_lib/> and
F</home/cschwenz/bar/custom_perl_lib/> will be added to the C<@INC> array.

=item B<S<Example 7:>>

    use lib::tree ( DIRS =>  [ '/home/cschwenz/foo/',
                               '/home/cschwenz/bar/' ],
                    LIB_DIR => '',
                    HALT_ON_FIND => 0,
                  );

The above incantation will add F</home/cschwenz/foo/> and
F</home/cschwenz/bar/> to the C<@INC> array (but only if said directories exist
and are readable).

=item B<S<Example 8:>>

    use lib::tree ( DIRS =>  [ '/home/cschwenz/foo/',
                               '/home/cschwenz/ba[rz]/',
                               '/home/cschwenz/qu*x/' ],
                    LIB_DIR => '',
                    HALT_ON_FIND => 0,
                  );

The above incantation will add F</home/cschwenz/foo/>, any directory matching
the file glob F</home/cschwenz/ba[rz]/> (i.e., F</home/cschwenz/bar/> and/or
F</home/cschwenz/baz/>), and any directory matching the file glob
F</home/cschwenz/qu*x/> to the C<@INC> array (but only if said directories exist
and are readable).

=item B<S<Example 9:>>

    use lib::tree ( DIRS =>  [ '/home/cschwenz/foo/',
                               '/home/cschwenz/ba[rz]/',
                               '/home/cschwenz/qu*x/' ],
                    LIB_DIR => '',
                    HALT_ON_FIND => 0,
                    DEBUG => 1,
                  );

The same as I<B<S<Example 8>>>, but with debugging turned on so you can see what
C<lib::tree> is doing internally.

=item B<S<Example 10:>>

    use lib::tree ( '/home/cschwenz/foo/',
                    '/home/cschwenz/ba[rz]/',
                    '/home/cschwenz/qu*x/',
                    ':DEBUG',
                  );

The same as I<B<S<Example 9>>>, but called in the simple list style.

=back


=head1 SUBROUTINES

=head2 import

Called when you say C<use lib::tree ( ... );>

May be called with a hash, a complex list (that is, a list which starts with an
array reference), or a simple list (where all values are scalars).

To see what C<import()> is doing, set the C<DEBUG> parameter to true.

=head2 unimport

Called when you say C<no lib::tree ( ... );>

May be called with a hash, a complex list (that is, a list which starts with an
array reference), or a simple list (where all values are scalars).

To see what C<unimport()> is doing, set the C<DEBUG> parameter to true.


=head1 PRIVATE SUBROUTINES

These are listed for completeness, as well as to make it easier for future
maintainers to understand the code.

=over

=item B<TRUE>

Used where the code is expecting a boolean value. Returns C<1>.

=item B<FALSE>

Used where the code is expecting a boolean value. Returns C<0>.

=item B<_parse_params>

Parses the C<@_> array, placing relevant data in a returned C<%param> hash.
Supports three different calling conventions: hash, complex list, and simple
list.

=item B<_script_dir>

This is the function which tries to determine the full path to the directory
which holds the currently running program.  Assumes the user has not C<chdir>ed
before C<lib::tree> enters the compile phase.

=item B<_find_dirs>

Given a reference to a list of directories, find the ones which exist, are
readable, and (most importantly) truly are directories.

=item B<_find_lib_dirs>

This subroutine is the heart of C<lib::tree>; it is where we go hunting for the
requested custom library directory.  Takes the library directory name to search
for, how many directories up/down from a given directory to search for said
library directory, whether or not this is a depth-first search, if we halt the
search on the first matching directory, and a reference to a list of directories
to search.

=item B<_find_INC_dirs>

Takes a reference to a list of directories and returns a (nuanced) list of
directories to include on the C<@INC> array.

=item B<_get_path_hash>

Break a given path into is volume, directories, and file; then further divide
the directories segment into individual directory names.  Returns a hash with
keys 'C<volume>', 'C<directories>', 'C<file>', and 'C<dirs>' (and the 'C<dirs>'
key points to an array reference).

=item B<_get_dirs>

Given a path, generate a list of all possible directories to look for based on
this perl interpreter's configuration values (it is the job of the
C<_find_INC_dirs()> subroutine to validate the returned list).

=item B<_find_perl_type>

Return the directory name to look for when searching for this perl's binary
modules (i.e., Perl modules which call out to dynamic libraries, modules which
play well with only one type of perl interpreter, etc.).  This subroutine is the
one most likely to need periodic maintenance.

=item B<_valid_path>

Canonize what constitutes a valid path.  Used in the C<_glob_dir()> and
C<_add_to_list()> subroutines and anywhere else we need to determine if a given
path is valid for our uses.

=item B<_glob_dir>

Take a scalar (presumably one which contains a directory path), run it through
C<glob()> and C<Cwd::realpath()>, then return a list of directories which exist
and are readable.

=item B<_add_to_list>

Given two array references and the optional current first library directory
(used to halt upon finding the first directory match), push the contents of the
second array reference onto the array referenced by the first value.

=item B<_simplify_list>

Given a list, use C<Tie::Indexed::Hash> to maintain order while stripping out duplicates from said list; then return the cleaned list.

=back


=head1 AUTHOR

Calvin Schwenzfeier, C<< <calvin dot schwenzfeier at gmail.com> >>


=head1 BUGS

Please report any bugs or feature requests through GitHub's issue tracker web
interface at L<http://github.com/cschwenz/lib-tree/issues>.

=begin COMMENT

Please report any bugs or feature requests to
C<< <bug-lib-tree at rt.cpan.org> >>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=lib-tree>.  I will be notified,
and then you'll automatically be notified of progress on your bug as I make
changes.

=end COMMENT


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc lib::tree

You can also look for information at:

=over

=item * The C<lib::tree> online docs (hosted on GitHub):

L<http://cschwenz.github.com/lib-tree/lib/tree.html>

=item * GitHub's issue tracker:

L<http://github.com/cschwenz/lib-tree/issues>

=item * The C<lib::tree> wiki (hosted on GitHub):

L<http://wiki.github.com/cschwenz/lib-tree/>

=item * Source code (hosted on GitHub):

L<http://github.com/cschwenz/lib-tree>

=back

=begin COMMENT

=over

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=lib-tree>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/lib-tree>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/lib-tree>

=item * Search CPAN

L<http://search.cpan.org/dist/lib-tree/>

=back

=end COMMENT


=head1 ACKNOWLEDGEMENTS

S<   > And again Jesus spoke to them in parables, saying, E<ldquo>The Kingdom of
Heaven may be compared to a king who gave a wedding feast for his son, and sent
his servants to call those who were invited to the wedding feast, but they
refused to come.S< > So he sent other servants, saying, E<lsquo>Tell those who
are invited: E<laquo>See, I have prepared my banquet; my bulls and my fattened
cattle have been slaughtered, and everything is ready.  Come to the wedding
feast!E<raquo>E<rsquo>S< > But they paid no attention and went off, one to his
farm, another to his business; while the rest seized his servants, mistreated
them, and killed them.S< > The king was furious and sent his soldiers, who
killed those murderers and burned down their city.S< > Then he said to his
servants, E<lsquo>The wedding feast is ready, but the ones who were invited did
not deserve it.S< > So go out to the streetE<8209>corners and invite to the
banquet as many as you find.E<rsquo>S< > The servants went out into the streets
and gathered all the people they could find, both bad and good; and the wedding
hall was filled with guests.S< > But when the king came in to look at the
guests, he saw there a man who was not dressed for a wedding; so he asked him,
E<lsquo>Friend, how did you get in here without wedding clothes?E<rsquo>S< > The
man was speechless.S< > Then the king said to the attendants, E<lsquo>Bind him
hand and foot, and throw him outside into the dark!E<rsquo>S< > In that place
people will wail and grind their teeth; for many are invited, but few are
chosen.E<rdquo>


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Calvin Schwenzfeier.

=begin COMMENT

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

=end COMMENT

This program is free software; you can redistribute it and/or modify it under
the terms of either:

=over

=item a)

the GNU General Public License [L<http://dev.perl.org/licenses/gpl1.html>] as published by the Free Software Foundation [L<http://www.fsf.org/>]; either version 1 [L<http://dev.perl.org/licenses/gpl1.html>], or (at your option) any later version [L<http://www.fsf.org/licensing/licenses/#GNUGPL>], or

=item b)

the "Artistic License" [L<http://dev.perl.org/licenses/artistic.html>].

=back

    
    For those of you that choose to use the GNU General Public License, my
    interpretation of the GNU General Public License is that no Perl script
    falls under the terms of the GPL unless you explicitly put said script under
    the terms of the GPL yourself.
    
    Furthermore, any object code linked with perl does not automatically fall
    under the terms of the GPL, provided such object code only adds definitions
    of subroutines and variables, and does not otherwise impair the resulting
    interpreter from executing any standard Perl script. I consider linking in C
    subroutines in this manner to be the moral equivalent of defining
    subroutines in the Perl language itself. You may sell such an object file as
    proprietary provided that you provide or offer to provide the Perl source,
    as specified by the GNU General Public License. (This is merely an alternate
    way of specifying input to the program.) You may also sell a binary produced
    by the dumping of a running Perl script that belongs to you, provided that
    you provide or offer to provide the Perl source as specified by the GPL.
    (The fact that a Perl interpreter and your code are in the same binary file
    is, in this case, a form of mere aggregation.)
    
    This is my interpretation of the GPL. If you still have concerns or
    difficulties understanding my intent, feel free to contact me. Of course,
    the Artistic License spells all this out for your protection, so you may
    prefer to use that.
    
    -- Larry Wall
    

See L<http://dev.perl.org/licenses/> for more information.

Voir L<http://dev.perl.org/licenses/> pour plus d'information.

Ver L<http://dev.perl.org/licenses/> para más información.

См. L<http://dev.perl.org/licenses/> За дополнительной информацией.

Se L<http://dev.perl.org/licenses/> kwa taarifa zaidi.

Féach L<http://dev.perl.org/licenses/> le haghaidh tuilleadh eolais.

Se L<http://dev.perl.org/licenses/> för mer information.


=cut

