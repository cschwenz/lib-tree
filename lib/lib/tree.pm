package lib::tree;

use warnings;
use strict;
use Config '%Config';
use Carp qw(carp croak);
use File::Spec;
use Tie::Indexed::Hash;
require Cwd;


our $VERSION = '0.01';
our @Original_INC = @INC;	


my $DEBUG = 0;
my $version = $Config{version};
my $perl_version = sprintf('%vd', $^V);
my $major_version = undef;
my $archname = $Config{archname};
my $archname64 = $Config{archname64};
my $osname = $Config{osname};
my $perl_osname = $^O;
my @inc_version_list = reverse split(/[ \t]+/, $Config{inc_version_list});

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
    elsif($perl_version ne $version) ) {
        carp( "The version reported by Config ($version) differs from the " .
              "version reported by the perl interpreter ($perl_version)!" );
    }
}
if( (defined $version) && (length($version) >= 1) &&
    (defined $perl_version) && (length($perl_version) >= 1) &&
    ($perl_version eq $version) &&
    ($version =~ m/\A\s*(\d+(?:\.\d+)?)(?:\.\d+(?:\.\d+)*?)*?\s*\z/) ) {
    $major_version = $1;
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


sub splitpath { File::Spec->splitpath(@_); }
sub catpath { File::Spec->catpath(@_); }
sub splitdir { File::Spec->splitdir(@_); }
sub catdir { File::Spec->catdir(@_); }
sub file_name_is_absolute { File::Spec->file_name_is_absolute(@_); }


sub import {
    my $object = shift;
    my $class = ref($object) || $object;
    my %param = _parse_params(@_);
    $DEBUG = ($param{DEBUG}) ? 1 : 0;

    my @lib_dirs = ();
    if(defined $param{LIB_DIR}) {
        my @dirs = ();
        if((defined $param{DIRS}) && (ref($param{DIRS}) eq 'ARRAY')) {
            @dirs = _find_dirs($param{DIRS});
        }
        @lib_dirs = _find_lib_dirs( $param{LIB_DIR}, $param{DELTA},
                                    $param{DEPTH_FIRST}, $param{HALT_ON_FIND},
                                    \@dirs );
    }
    _update_INC_array(\@lib_dirs);

    if($DEBUG) {
      print STDERR '' . ('-' x 78) . "\n";
      print STDERR "***DEBUG: The INC array is now:\n  " .
                   join("\n  ", @INC) . "\n";
      print STDERR '' . ('-' x 78) . "\n";
    }

    return;
}


sub unimport {
    my $object = shift;
    my $class = ref($object) || $object;
    my %param = _parse_params(@_);
    $DEBUG = ($param{DEBUG}) ? 1 : 0;

    return;
}


sub _parse_params {
    my @list = @_;

    my %param = ( DIRS => undef,
                  LIB_DIR => undef,
                  DEPTH_FIRST => 1,
                  HALT_ON_FIND => 1,
                  DELTA => 0,
                  DEBUG => 0,
                );
    if(scalar(grep { uc($list[0]) eq $_ } keys(%param)) >= 1) {
        for(my $x = 0; $x <= $#list; $x+=2) {
            $param{uc($list[$x])} = $list[$x + 1];
        }
    }
    elsif(ref($list[0]) eq 'ARRAY') {
        my $array_ref = shift(@list);
        my @temp = ();
        for(my $x = 0; $x < $#{$array_ref}; $x++) {
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
    else {
        $param{DIRS} = \@list;
        $param{LIB_DIR} = '';
        $param{HALT_ON_FIND} = 0;
    }

    if(not defined $param{DIRS}) {
        $param{DIRS} = [ _script_dir() ];
    }
    if((defined $params{DIRS}) && (ref($param{DIRS}) ne 'ARRAY'))
    {
        carp("The DIRS parameter is expecting an array reference!");
        if(ref($params{DIRS}) eq '') {
            my @temp = ( $params{DIRS}, );
            $params{DIRS} = \@temp;
        }
        elsif(ref($params{DIRS}) eq 'HASH') {
            my @temp = sort keys %{$param{DIRS}};
            $param{DIRS} = \@temp;
        }
        else {
            $param{DIRS} = [ _script_dir() ];
        }
    }
    if((defined $param{DIRS}) && (ref($param{DIRS}) eq 'ARRAY')) {
        for(my $x = 0; $x <= $#{$param{DIRS}}; $x++) {
            if(not $param{DIRS}->[$x]) {
                carp( "Empty value in DIRS parameter at position $x " .
                      "(zero-based)!" );
                next;
            }
        }
    }
    if(not defined $param{LIB_DIR}) {
        $param{LIB_DIR} = 'libperl';
    }
    if( (defined $param{DEPTH_FIRST}) &&
        ($param{DEPTH_FIRST} =~ m/\A\s*(?:0|F(?:alse)?)\s*\z/i) ) {
        $param{DEPTH_FIRST} = 0;
    else {
        $param{DEPTH_FIRST} = 1;
    }
    if( (defined $param{HALT_ON_FIND}) &&
        ($param{HALT_ON_FIND} =~ m/\A\s*(?:0|F(?:alse)?)\s*\z/i) ) {
        $param{HALT_ON_FIND} = 0;
    else {
        $param{HALT_ON_FIND} = 1;
    }
    if( (defined $param{DELTA}) &&
        ($param{DELTA} =~ m/\A\s*[\+\-]?\s*(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][\+\-]?\d+)?\s*\z/) ) {
        $param{DELTA} = abs(int($param{DELTA} * 1));
    else {
        $param{DELTA} = 0;
    }
    if( (defined $param{DEBUG}) &&
        ($param{DEBUG} =~ m/\A\s*(?:1|T(?:rue)?)\s*\z/i) ) {
        $param{DEBUG} = 1;
    else {
        $param{DEBUG} = 0;
    }

    return wantarray ? %param : \%param;
}


sub _script_dir {
    my %cwd = ( 'path' => Cwd::getcwd(), );
    ($cwd{'volume'}, $cwd{'directories'}, $cwd{'file'}) =
            splitpath($cwd{'path'}, 1);
    @{$cwd{'dirs'}} = splitdir($cwd{'directories'});

    my %script = ( 'path' => "$0", );
    ($script{'volume'}, $script{'directories'}, $script{'file'}) =
            splitpath($script{'path'});
    @{$script{'dirs'}} = splitdir($script{'directories'});

    my $path = (file_name_is_absolute($script{'path'}))
                   ? catpath( $script{'volume'},
                              catdir(@{$script{'dirs'}}),
                              '' )
                   : catpath( $cwd{'volume'},
                              catdir(@{$cwd{'dirs'}}, @{$script{'dirs'}}),
                              '' );
    my $full_path = Cwd::realpath($path);
    if(not $full_path) {
        $full_path = $path;
    }
    if((not -e $full_path) || (not -d $full_path) || (not -r $full_path)) {
        $path = catdir($cwd{'volume'}, @{$cwd{'dirs'}});
        $full_path = Cwd::realpath($path);
        if(not $full_path) {
            $full_path = $path;
        }
    }

    return $full_path;
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
        SEARCH: foreach my $d (@{$dirs_ref}) {
            my %dir = ( 'path' => $d, );
            ($dir{'volume'}, $dir{'directories'}, $dir{'file'}) =
                    splitpath($dir{'path'}, 1);
            @{$dir{'dirs'}} = splitdir($dir{'directories'});
            my $d = catdir($dir{'volume'}, @{$dir{'dirs'}});
            my @up = ();
            my @down = ();
            for(my $x = 0; $x <= $delta; $x++) {
                if($DEBUG && ($x > 0)) {
                    print STDERR "***DEBUG: Searching up/down $x " .
                                 "director" . (($x == 1) ? 'y' : 'ies') .
                                 " from '$dir' (searching max of $delta " .
                                 "director" . (($x == 1) ? 'y' : 'ies') .
                                 " up/down).\n";
                }
                my $up_dir = catdir($d, @up, $lib_dir);
                my @temp_up = _glob_dir($up_dir);
                $found_dir = _add_to_list(\@lib_dirs, \@temp_up, $found_dir);
                my $down_dir = catdir($d, @down, $lib_dir);
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
            foreach my $d (@{$dirs_ref}) {
                my %dir = ( 'path' => $d, );
                ($dir{'volume'}, $dir{'directories'}, $dir{'file'}) =
                        splitpath($dir{'path'}, 1);
                @{$dir{'dirs'}} = splitdir($dir{'directories'});
                my $d = catdir($dir{'volume'}, @{$dir{'dirs'}});
                if($DEBUG && ($x > 0)) {
                    print STDERR "***DEBUG: Searching up/down $x " .
                                 "director" . (($x == 1) ? 'y' : 'ies') .
                                 " from '$dir' (searching max of $delta " .
                                 "director" . (($x == 1) ? 'y' : 'ies') .
                                 " up/down).\n";
                }
                my $up_dir = catdir($d, @up, $lib_dir);
                my @temp_up = _glob_dir($up_dir);
                $found_dir = _add_to_list(\@lib_dirs, \@temp_up, $found_dir);
                my $down_dir = catdir($d, @down, $lib_dir);
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


sub _update_INC_array {
    my $dirs_ref = shift;

    foreach my $dir (@{$dirs_ref}) {
        next if(not defined $dir);
        next if((not -e $dir) || (not -d $dir) || (not -r $dir));

        unshift(@INC, $dir);
        my @d = _get_dirs($dir);
        foreach (@d) {
            if((-e $_) && (-d $_) && (-r $_)) {
              unshift(@INC, $_);
            }
        }

        my %root = ( 'path' => $dir, );
        ($root{'volume'}, $root{'directories'}, $root{'file'}) =
                splitpath($root{'path'}, 1);
        @{$root{'dirs'}} = splitdir($root{'directories'});
        my $r = catdir($root{'volume'}, @{$root{'dirs'}});
        my $interpreter_dir = catdir( $r, 'PerlInterpreterName',
                                      _find_perl_type() );
        if( (-e $interpreter_dir) &&
            (-d $interpreter_dir) &&
            (-r $interpreter_dir) ) {
            my @d = _get_dirs($interpreter_dir);
            foreach (@d) {
                if((-e $_) && (-d $_) && (-r $_)) {
                    unshift(@INC, $_);
                }
            }
        }
    }
    @INC = _simplify_list(@INC);

    return;
}


sub _get_dirs {
    my $path = shift;

    my %dir = ( 'path' => $path, );
    ($dir{'volume'}, $dir{'directories'}, $dir{'file'}) =
            splitpath($dir{'path'}, 1);
    @{$dir{'dirs'}} = splitdir($dir{'directories'});
    my $d = catdir($dir{'volume'}, @{$dir{'dirs'}});
    my @lib = ( catdir($d, 'lib'), );
    my @site_lib = ( catdir($d, 'site', 'lib'), )
    if((defined $archname) && (length($archname) >= 1)) {
        push @lib, catdir($d, 'lib', $archname);
        push @site_lib, catdir($d, 'site', 'lib', $archname);
    }
    if((defined $archname64) && (length($archname64) >= 1)) {
        push @lib, catdir($d, 'lib', $archname64);
        push @site_lib, catdir($d, 'site', 'lib', $archname64);
    }
    if((defined $version) && (length($version) >= 1)) {
        push @lib, catdir($d, 'lib', $version);
        push @site_lib, catdir($d, 'site', 'lib', $version);
        if((defined $archname) && (length($archname) >= 1)) {
            push @lib, catdir($d, 'lib', $version, $archname);
            push @site_lib, catdir($d, 'site', 'lib', $version, $archname);
        }
        if((defined $archname64) && (length($archname64) >= 1)) {
            push @lib, catdir($d, 'lib', $version, $archname64);
            push @site_lib, catdir($d, 'site', 'lib', $version, $archname64);
        }
    }
    my @dirs = (@lib, @site_lib);

    return wantarray ? @dirs : \@dirs;
}


sub _find_perl_type {
    my %perl = ( 'path' => $^X, );
    ($perl{'volume'}, $perl{'directories'}, $perl{'file'}) =
            splitpath($perl{'path'});
    @{$perl{'dirs'}} = splitdir($perl{'directories'});
    my $strawberry_re = qr/(?:\b)strawberry[\-]?perl(?:\b)/i;
    my $vanilla_re = qr/(?:\b)vanilla[\-]?perl(?:\b)/i;

    my $perl_type = undef
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
        $perl_type .= 'Perl';
    }
    if($DEBUG) { print STDERR "***DEBUG: The Perl type is '$perl_type'.\n"; }

    return $perl_type;
}


sub _glob_dir {
    my $dir = shift;

    my @list = grep { (-e $_) && (-d $_) && (-r $_) }
               map { my $p = Cwd::realpath($_);
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
        if((-e $dir) && (-d $dir) && (-r $dir)) {
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

  tie(my %hash, 'Tie::Indexed::Hash');
  %hash = ();
  foreach my $dir (@list) {
      $hash{"$dir"} = 1;
  }
  @list = keys(%hash);

  return wantarray ? @list : \@list;
}


1;
__END__

=pod

=head1 NAME

lib::tree - Add directory trees to the C<@INC> array at compile time.

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

This pragma allows you to specify one or more directories to search for the
given library directory name to be added to the C<@INC> array.  Also, based on Perl
interpreter type and version, this pragma will add the correct sub-directories
within the given library directory (but only if said directory is found).

  # Called with a hash:
  use lib::tree ( DIRS =>  [ '/some/directory/',
                             'another/directory/',
                             '/yet/another/directory/with/*/globbing/',
                             'more/{dir,directory}/glob?/fun/',
                           ], # Accepts absolute/relative directories, with or
                              # without globbing.  (Defaults to the directory of
                              # the currently running script; i.e., if the full
                              # path to the script which invoked lib::tree is
                              # '/home/foo/scripts/bar.pl' then the default
                              # will be '/home/foo/scripts/')
                  LIB_DIR => 'customLibDirName', # This should be *just* the
                                                 # name of the directory (i.e.,
                                                 # neither a relative nor an
                                                 # absolute path; defaults to
                                                 # 'libperl')!
                  DEPTH_FIRST => 0, # If this is false, then lib::tree will do a
                                    # breadth-first search of the directories
                                    # listed by the DIRS parameter.  (Defaults
                                    # to 1; this allows the order of directories
                                    # specified in the DIRS parameter to be
                                    # honored)
                  HALT_ON_FIND => 1, # Do we want to stop searching directories
                                     # for the given LIB_DIR when we find our
                                     # first match?  (Defaults to 1; normally
                                     # you do not want multiple LIB_DIRs found.)
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
                  'customLibDirName', # The LIB_DIR parameter.
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

For example:

  use lib::tree ( DIRS =>  [ '/home/cschwenz/foo/',
                             '/home/cschwenz/bar/' ],
                  LIB_DIR => 'custom_perl_lib',
                );

The above incantation will look in F</home/cschwenz/foo/> and
F</home/cschwenz/bar/> for a directory named F<custom_perl_lib>.  If said directory is found (i.e., F</home/cschwenz/foo/custom_perl_lib/>), then C<lib::tree> will add the directory to the C<@INC> array and look for a directory named F<PerlInterpreterName> inside the recently added directory.

=head1 SUBROUTINES

=head2 import

Called when you say C<use lib::tree ( ... );>

=head2 unimport

Called when you say C<no lib::tree ( ... );>

=head1 AUTHOR

Calvin Schwenzfeier, C<< <calvin.schwenzfeier at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<< <bug-lib-tree at rt.cpan.org> >>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=lib-tree>.  I will be notified,
and then you'll automatically be notified of progress on your bug as I make
changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc lib::tree

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=lib-tree>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/lib-tree>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/lib-tree>

=item * Search CPAN

L<http://search.cpan.org/dist/lib-tree/>

=back


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

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

=pod

=begin COMMENT

.../lib/
.../lib/${archname}/
.../lib/${archname64}/
.../lib/${version}/
.../lib/${version}/${archname}/
.../lib/${version}/${archname64}/
.../site/lib/
.../site/lib/${archname}/
.../site/lib/${archname64}/
.../site/lib/${version}/
.../site/lib/${version}/${archname}/
.../site/lib/${version}/${archname64}/

.../{custom_lib}/
.../{custom_lib}/PerlInterpreterName/ActiveStatePerl/
.../{custom_lib}/PerlInterpreterName/StrawberryPerl/
.../{custom_lib}/PerlInterpreterName/VanillaPerl/
.../{custom_lib}/PerlInterpreterName/UsrBinPerl/
.../{custom_lib}/PerlInterpreterName/UsrLocalPerl/

=end COMMENT

=cut

