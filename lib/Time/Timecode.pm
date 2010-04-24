package Time::Timecode;

use strict;
use warnings;
use overload
    '+'   => \&_add,
    '-'   => \&_subtract,
    '*'   => \&_multiply,
    '/'   => \&_divide,
    '""'  => \&to_string;

use Carp;

our $VERSION = '0.01';

our $DEFAULT_FPS = 30;
our $DEFAULT_DROPFRAME = 0;
our $DEFAULT_DELIMITER = ':';
our $DEFAULT_FRAME_DELIMITER = $DEFAULT_DELIMITER;

my $SECONDS_PER_MINUTE = 60;
my $SECONDS_PER_HOUR   = $SECONDS_PER_MINUTE * 60;

my $TIME_PART = qr|[0-5]\d|;
my $DROP_FRAME_DELIMITERS = '.;';
my $FRAME_PART_DELIMITERS = "${DEFAULT_DELIMITER}${DROP_FRAME_DELIMITERS}";
my $TO_STRING_FORMAT = '%02s%s%02s%s%02s%s%02s';

{
  no strict 'refs';

  my @methods = qw|hours minutes seconds frames fps is_dropframe total_frames|;
  my %method_aliases = (
      hours   => ['hh', 'hrs'],
      minutes => ['mm', 'mins'],
      seconds => ['ss', 'secs'],
      frames  => ['ff']
  );

  for my $accessor (@methods) {
      *$accessor = sub { (shift)->{"_$accessor"} };
      *$_ = \&$accessor for @{$method_aliases{$accessor}};
  }
}

sub new
{
    croak 'usage: Time::Timecode->new( TIMECODE [, OPTIONS ] )' if @_ < 2;

    my $class = shift;
    my $options = UNIVERSAL::isa($_[-1], 'HASH') ? pop : {};
    my $self  = bless {	_is_dropframe      => $options->{dropframe},   
			_frame_delimiter   => $options->{frame_delimiter},
			_delimiter         => $options->{delimiter} || $DEFAULT_DELIMITER,       
			_fps               => $options->{fps}       || $DEFAULT_FPS }, $class;

    croak "Invalid fps '$self->{_fps}': fps must be > 0" unless $self->{_fps} =~ /^\d+(?:\.\d+)?$/;

    if(@_ == 1 && $_[0] !~ /^\d+$/) {
	$self->_timecode_from_string( shift );
    }
    else {
	# For string timecodes these can be derrived by their format
	$self->{_is_dropframe} 	  ||= $DEFAULT_DROPFRAME;
	$self->{_frame_delimiter} ||= $DEFAULT_FRAME_DELIMITER;
	    
	if( @_ == 1 ) {
	    $self->_timecode_from_total_frames( shift );
	}
	else {
	    push @_, 0 unless @_ == 4; # Add frames if necessary
	    $self->_set_and_validate_time(@_);
	}
    }

    $self;
}

sub to_string
{
    my $self = shift;

    #TODO: timecode suffix if string arg to constructor had one
    sprintf($TO_STRING_FORMAT,
	    $self->hours,
	    $self->{_delimiter},
	    $self->minutes,
	    $self->{_delimiter},
	    $self->seconds,
	    $self->{_frame_delimiter},
	    $self->frames);
}

sub convert
{
    my ($self, $fps, $options) = @_;

    $options ||= {};
    $options->{fps} = $fps;
    $options->{dropframe} ||= 0;
    $options->{delimiter} ||= $self->{_delimiter};
    $options->{frame_delimiter} ||= $self->{_frame_delimiter};

    Time::Timecode->new($self->to_non_dropframe->total_frames, $options);
}

sub to_dropframe
{
    my $self = shift;
    return $self if $self->is_dropframe;

    my $options = $self->_dup_options;
    $options->{dropframe} = 1;

    Time::Timecode->new($self->total_frames, $options);
}

sub to_non_dropframe
{
    my $self = shift;
    return $self unless $self->is_dropframe;

    my $options = $self->_dup_options;
    $options->{dropframe} = 0;

    Time::Timecode->new($self->total_frames, $options);
}


sub _add
{
    _handle_binary_overload(@_, sub {
	$_[0] + $_[1];
    });
}

sub _subtract
{
    _handle_binary_overload(@_, sub {
	$_[0] - $_[1];
    });
}

sub _multiply
{
    _handle_binary_overload(@_, sub {
	$_[0] * $_[1];
    });
}

sub _divide
{
    _handle_binary_overload(@_, sub {
	int($_[0] / $_[1]);
    });
}

sub _handle_binary_overload
{
    my ($lhs, $rhs, $reversed, $fx) = @_;

    $rhs = Time::Timecode->new($rhs) unless UNIVERSAL::isa($rhs, 'Time::Timecode');
    ($lhs, $rhs) = ($rhs, $lhs) if $reversed;

    Time::Timecode->new($fx->($lhs->total_frames, $rhs->total_frames), $lhs->_dup_options);
}

sub _dup_options
{
    my $self = shift;
    { fps       => $self->fps,
      dropframe => $self->is_dropframe,
      delimiter => $self->{_delimiter},
      frame_delimiter => $self->{_frame_delimiter} };
}

# We work with 10 minute blocks of frames to accommodate dropframe calculations.
# Dropframe timecodes call for 2 frames to be added every minute except on the 10th minute.
# See REFERENCES in the below POD.  

sub _frames_per_hour
{
    my $self = shift;
    my $fph = $self->_rounded_fps * $SECONDS_PER_HOUR;

    $fph -= 108 if $self->is_dropframe;
    $fph;
}

sub _frames_per_minute
{
    my $self = shift;
    my $fpm = $self->_rounded_fps * $SECONDS_PER_MINUTE;

    $fpm -= 2 if $self->is_dropframe;
    $fpm;
}

sub _frames_per_ten_minutes
{
    my $self = shift;
    my $fpm = $self->_rounded_fps * $SECONDS_PER_MINUTE * 10;

    $fpm -= 18 if $self->is_dropframe;
    $fpm;
}

sub _frames
{
    my ($self, $frames) = @_;
    $self->_frames_without_ten_minute_intervals($frames) % $self->_frames_per_minute % $self->_rounded_fps;
}

sub _rounded_fps
{
    my $self = shift;
    $self->{_rounded_fps} ||= sprintf("%.0f", $self->fps);
}

sub _hours_from_frames
{
    my ($self, $frames) = @_;
    int($frames / $self->_frames_per_hour);
}

sub _minutes_from_frames
{
    my ($self, $frames) = @_;
    my $minutes = int($frames % $self->_frames_per_hour);
    int($self->_frames_without_ten_minute_intervals($frames) / $self->_frames_per_minute) + int($minutes / $self->_frames_per_ten_minutes) * 10;
}

# Needed to handle dropframe calculations
sub _frames_without_ten_minute_intervals
{
    my ($self, $frames) = @_;
    int($frames % $self->_frames_per_hour % $self->_frames_per_ten_minutes);
}

sub _seconds_from_frames
{
    my ($self, $frames) = @_;
    int($self->_frames_without_ten_minute_intervals($frames) % $self->_frames_per_minute / $self->_rounded_fps);
}

sub _valid_frames
{
    my ($part, $frames, $max) = @_;
    croak "Invalid frames '$frames': frames must be between 0 and $max" unless $frames =~ /^\d+$/ && $frames >= 0 && $frames <= $max;
}

sub _valid_time_part
{
    my ($part, $value) = @_;
    croak "Invalid $part '$value': $part must be between 0 and 59" if !defined($value) || $value < 0 || $value > 59;
}

sub _set_and_validate_time_part
{
    my ($self, $part, $value, $validator) = @_;
    $validator->($part, $value, $self->fps);
    $self->{"_$part"} = int($value); # Can be a string with a 0 prefix: 01, 02, etc...
}

sub _set_and_validate_time
{
    my ($self, $hh, $mm, $ss, $ff) = @_;

    $self->_set_and_validate_time_part('frames', $ff, \&_valid_frames);
    $self->_set_and_validate_time_part('seconds', $ss, \&_valid_time_part);
    $self->_set_and_validate_time_part('minutes', $mm, \&_valid_time_part);
    $self->_set_and_validate_time_part('hours', $hh, \&_valid_time_part);

    my $total = $self->frames;
    $total += $self->seconds * $self->_rounded_fps;

    # These 2 statements are used for calculating dropframe timecodes. They do not affect non-dropframe calculations.
    $total += int($self->minutes / 10) * $self->_frames_per_ten_minutes;
    $total += $self->minutes % 10 * $self->_frames_per_minute;   

    $total += $self->hours * $self->_frames_per_hour;

    croak "Invalid dropframe timecode: '$self'" unless $self->_valid_dropframe_timecode;  
    $self->{_total_frames} = $total;
}

sub _valid_dropframe_timecode
{
    my $self = shift;
    !($self->is_dropframe && $self->seconds == 0 && ($self->frames == 0 || $self->frames == 1) && ($self->minutes % 10 != 0));
}

sub _set_timecode_from_frames
{
    my ($self, $frames) = @_;

    $self->_set_and_validate_time_part('frames', $self->_frames($frames), \&_valid_frames);
    $self->_set_and_validate_time_part('seconds', $self->_seconds_from_frames($frames), \&_valid_time_part);
    $self->_set_and_validate_time_part('minutes', $self->_minutes_from_frames($frames), \&_valid_time_part);
    $self->_set_and_validate_time_part('hours', $self->_hours_from_frames($frames), \&_valid_time_part);

    #Bump up to valid drop frame... ever?
    $self->_set_timecode_from_frames($frames + 2) unless $self->_valid_dropframe_timecode
}

sub _timecode_from_total_frames
{
    my ($self, $frames) = @_;
    $self->{_total_frames} = $frames;
    $self->_set_timecode_from_frames($frames);
}

# Close your eyes, it's about to get ugly...
sub _timecode_from_string
{
    my ($self, $timecode) = @_;
    my $delim = '[' . quotemeta("$self->{_delimiter}$DEFAULT_DELIMITER") . ']';
    my $frame_delim = $FRAME_PART_DELIMITERS;

    $frame_delim .= $self->{_frame_delimiter} if defined $self->{_frame_delimiter};
    $frame_delim = '[' . quotemeta("$frame_delim") . ']';

    if($timecode =~ /^\s*($TIME_PART)$delim($TIME_PART)$delim($TIME_PART)($frame_delim)([0-5]\d)\s*([NDPF])?\s*$/) {
	#TODO: Use suffix after frames to determine drop/non-drop -and possibly other things
	$self->{_is_dropframe} = 1 unless defined $self->{_is_dropframe} || index($DROP_FRAME_DELIMITERS, $4) == -1;
	$self->{_frame_delimiter} = $4 unless defined $self->{_frame_delimiter};

	$self->_set_and_validate_time($1, $2, $3, $5);
    }
    else {
	croak "Can't create timecode from '$timecode'";
    }
}

1;

__END__

=head1 NAME

Time::Timecode - Video timecode class

=head1 SYNOPSIS

 use Time::Timecode;

 my $tc1 = Time::Timecode->new(2, 0, 0, 12); # hh, mm, ss, ff
 print $tc1->fps;			     # $DEFAULT_FPS
 print $tc1;				     # 02:00:00:12
 print $tc1->hours;			     # 2
 print $tc1->hh;			     # shorthanded version

 my $tc2 = Time::Timecode->new('00:10:30:00', { fps => 25 } );
 print $tc2->total_frames;		     # 15750
 print $tc2->fps;			     # 25

 $tc2 = Time::Timecode->new(1800); 	     # Total frames
 print $tc1 + $tc2; 			     # 02:01:00:12

 $tc1 = Time::Timecode->new('00:01:00;04');  # Dropframe ( see the ";" )
 print $tc1->is_dropframe;		     # 1

 my $diff = $tc1 - 1800;		     # Subtract 1800 frames
 print $tc1->is_dropframe;		     # Maintains LHS' opts
 print $diff;				     # 00:00:02;00

 my $opts = { delimiter => ',', frame_delimiter => '+' };
 $Time::Timecode::DEFAULT_FPS = 23.976;      
 $tc2 = Time::Timecode->new('00,10,30+00', $opts); 
 print $tc2->fps			     # 23.976
 print $tc2->minutes;			     # 10
 print $tc2->seconds;			     # 30

 # Conversions
 my $pal  = $tc->convert(25);
 my $ntsc = $pal->convert(30), { dropframe => 1 });
 my $ndf  = $ntsc->to_non_dropframe;
 
=head1 DESCRIPTION

C<Time::Timecode> supports any frame rate, drop/non-drop frame counts, basic arithmetic, 
and conversion between frame rates and drop/non-drop frame counts. The only 
requirements are that the timecode be between 00:00:00:00 and 99:99:99:99, 
inclusive, and frames per second (fps) are greater than zero. This means that 
you can create nonstandard timecodes (feature or bug? :^). Dropframe rules will still 
apply.

C<Time::Timecode> instances can be created from a a variety of representations, 
see L</CONSTRUCTOR>. 

C<Time::Timecode> instances are immutable.

=head1 CONSTRUCTOR

=over 2

=item C<new( TIMECODE [, OPTIONS ] )>

Creates an immutable instance for C<TIMECODE> with the given set of C<OPTIONS>. 
If no C<OPTIONS> are given the L<"package defaults"|/DEFAULTS> are used.

=back

=head2 TIMECODE 

C<TIMECODE> can be one of the following:

=over 4

=item * A list denoting hours, minutes, seconds, and/or frames:

 $tc1 = Time::Timecode->new(1, 2, 3)
 $tc1 = Time::Timecode->new(1, 2, 3, 0)   #same as above

=item * Frame count:

 $tc1 = Time::Timecode->new(1800)   # 00:01:00:00 @ 30 fps

=item * Timecode string:

 $tc1 = Time::Timecode->new('00:02:00:25')

B<Timecode strings with dropframe frame delimiters>
 
In the video encoding world timecodes with a frame delimiter of '.' or ';' are 
dropframe. If either of these characters are used in the timecode string passed to C<new()>
the resulting instance will dropframe.

This can be overridden by setting the L<"dropframe argument"|/OPTIONS> to false. 

=back

=head2 OPTIONS

C<OPTIONS> must be a hash reference containg any of the following:

=over 4

B<fps>: Frames per second, must be greater than 0. Decimal values 
are rounded 0 places when performing calculations: 29.976 becomes 30.
Defaults to C<$Time::Timecode::DEFAULT_FPS>

B<dropframe>: A boolean value denoting wheather or not the timecode 
is dropframe. Defaults to C<$Time::Timecode::DEFAULT_DROPFRAME>.

B<delimiter>: The character used to delimit the timecode's hours, minutes, 
and seconds. Use the B<frame_delimiter> option for delimiting the frames.
Defaults to C<$Time::Timecode::DEFAULT_DELIMITER>.

B<frame_delimiter>: The character used to delimit the timecode's frames. 
Use the B<delimiter> option for delimiting the rest of the timecode.
Defaults to C<$Time::Timecode::DEFAULT_FRAME_DELIMITER>.

=back

=head1 METHODS

All time part accessors return an integer.

=over 2

=item C<hours()>

=item C<hrs()>

=item C<hh()>

Returns the hour part of the timecode 

=item C<minutes()>

=item C<mins()>

=item C<mm()>

Returns the mintue part of the timecode

=item C<seconds()>

=item C<secs()>

=item C<ss()>

Returns the second part of the timecode

=item C<frames()>

=item C<ff()>

Returns the frame part of the timecode

=item C<fps()>

Returns the frames per second

=item C<to_string()>

Returns the timecode as string in a HH:MM:SS:FF format.

The delimiter used to separate each portion of the timecode can vary.
If the C<delimiter> or C<frame_delimiter> options were provided they 
will be used here. If the timecode was created from a timecode string
that representation will be reconstructed.

This method is overloaded. Using a C<Time::Timecode> instance in a scalar
context results in a call to C<to_string()>.

=item C<is_dropframe()>

Returns a boolean value denoting whether or not the timecode is dropframe.

=item C<to_non_dropframe()>

Converts the timecode to non-dropframe and returns a new C<Time::Timecode> instance.
The framerate is not changed.

If the current timecode is non-dropframe C<$self> is returned.

=item C<to_dropframe()>

Converts the timecode to dropframe and returns a new C<Time::Timecode> instance.
The framerate is not changed.

If the current timecode is dropframe C<$self> is returned.

=item C<convert( FPS [, OPTIONS ] )>

Converts the timecode to C<FPS> and returns a new instance.

C<OPTIONS> are the same as L<those allowed by the CONSTRUCTOR|/OPTIONS>. Any unspecified options 
are taken from the calling instance.

The converted timecode will be non-dropframe.

=back

=head1 ARITHMATIC

=over 2

=item Addition

=item Subtraction

=item Multiplacation

=item Division

All results get their options from the left hand side (LHS) of the expression. If LHS 
is a literal, options will be taken from RHS.

=back

=head1 DEFAULTS

These can be overridden L<when creating a new instance|/CONSTRUCTOR>.

C<$DEFAULT_FPS = 29.97>

C<$DEFAULT_DROPFRAME = 0>

C<$DEFAULT_DELIMITER = ':'>

C<$DEFAULT_FRAME_DELIMITER = ':'>

=head1 AUTHOR

Skye Shaw (sshaw AT lucas.cis.temple.edu)

=head1 REFERENCES

For information about dropframe timecodes see:
L<http://dropframetimecode.org/>, L<http://en.wikipedia.org/wiki/SMPTE_time_code#Drop_frame_timecode>

=head1 COPYRIGHT

Copyright (c) 2009-2010 Skye Shaw. All rights reserved. This program
is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.
