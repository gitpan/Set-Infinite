#/bin/perl -w
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

Set::Infinite::Date - date scalar. Deprecated. use Date::Set instead.

=head1 SYNOPSIS

This module is obsolete - use DateTime::Set instead

	use Set::Infinite::Date;

	$a = Set::Infinite::Date->new("10:00");

	This module requires Time::Local

=head1 DESCRIPTION

This module is obsolete - use DateTime::Set instead

=head1 USAGE

	$a = Set::Infinite::Date->new();
	$a = Set::Infinite::Date->new('2001-02-30 10:00:00');
	$a = Set::Infinite::Date->new('2001-02-30');
	$a = Set::Infinite::Date->new('10:00:00');
	$a = Set::Infinite::Date->new($b);

Perl:

	@b = sort @a;
	print $a;

Date input format:
	All HTTP::Date formats, plus:

	('2001-02-30 10:00', '11:00')
	('2001-02-30 10:00:00', '11:00:00')
		means day 2001-02-30, from 10:00:00 to 11:00:00

	('10:00', '11:00') or
	('10:00:00', '11:00:00') 
		means from 10:00:00 to 11:00:00; day is not specified

	(10000, 11888) 
		time-number format (seconds since epoch)

String conversion functions:

	0 + $s	returns the Date as a time-number (epoch).
			This is faster than	date2time or hour2time.

	time2date 
	date2time 
	time2hour 
	hour2time

	date_format($s) 
		$s is a string containing any combination of the words:
		'year' 'month' 'day' 'hour' 'min' 'sec'
		examples: 
			"year-month-day hour:min:sec" (default)
			"month/day"
			"min:sec"
	date_format returns the date format string.

Internal functions:
	$a->mode($b);
		mode can be 
		0 - epoch
		1 - beginning in 00:00:00 
		2 - absolute dates like 2001-01-01 00:00:00

=head1 TODO

	$time_format for mode=1
	understand input using date_format/time_format

=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

require Exporter;
package Set::Infinite::Date;

my $DEBUG = 1;
@EXPORT = qw();
@EXPORT_OK = qw(
	time2date date2time time2hour hour2time 
);

use strict;
# use warnings;
use Carp;
use Time::Local;
# use Set::Infinite::Element_Inf;

#--- THIS FUNCTION IS (HEAVILY) MODIFIED FROM HTTP::Date -- Copyright 1995-1999, Gisle Aas

sub str2time {
    my $str = shift;    # '1996-02-29 12:00:00' 
    my @d = $str =~ 
	/(\d{4})-(\d\d?)-(\d\d?)
     (?:
	       (?:\s+)  # separator before clock
	    (\d\d?):?(\d\d)    # hour:min
	    (?::?(\d\d(?:\.\d*)?))?  # optional seconds (and fractional)
	 )?                    # optional clock
	/x; 
    $d[0] -= 1900;  # year
    $d[1]--;        # month
    $d[3] = 0 unless $d[3];
    $d[4] = 0 unless $d[4];
    $d[5] = 0 unless $d[5];
	# print " # $str == ", join(";",@d), " \n";
    return timegm(reverse @d);
}

#--- END CODE DERIVED FROM HTTP::Date

use overload
	'0+' => sub { return $_[0]->{a} },
	'<=>' => \&spaceship,
	'-' => \&sub,
	'+' => \&add,
	'/' => \&div,
	qw("" as_string);

use vars qw( $day_size $hour_size $minute_size $second_size $date_format %date_cache %time2date_cache );
$day_size = timegm(0,0,0,2,3,2001) - timegm(0,0,0,1,3,2001);
$hour_size = $day_size / 24;
$minute_size = $hour_size / 60;
$second_size = $minute_size / 60;

$date_format = "year-month-day hour:min:sec";

%date_cache = ();
%time2date_cache = ();

sub date_format {
	$date_format = pop if @_;
	# %date_cache = ();
	%time2date_cache = ();
	return $date_format;
}

# export time2date and date2time

sub time2date (;$)  { 
	my $a = shift;
	if (exists $time2date_cache{$a}) { 
		# print "*"; 
		return $time2date_cache{$a} 
	};
	# print " [ttd:$a] ";

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($a);
	$year += 1900;
	$mon++;
	foreach ($sec,$min,$hour,$mday,$mon,$year) {
		$_ = '0' . $_ if $_ < 10;
	}
	my $tmp = $date_format;
	$tmp =~ s/year/$year/;
	$tmp =~ s/month/$mon/;
	$tmp =~ s/day/$mday/;
	$tmp =~ s/sec/$sec/;
	$tmp =~ s/min/$min/;
	$tmp =~ s/hour/$hour/;
	$time2date_cache{$a} = $tmp;
	return $tmp;
}

sub date2time ($;$) { return str2time (shift) }

sub time2hour {
	my $a = shift;

	my $tmp = int($a / $hour_size);
	$a -= ($tmp * $hour_size);
	my $tmp_min = int($a / $minute_size);
	$a -= ($tmp_min * $minute_size);
	my $tmp_sec = int($a / $second_size);

	return sprintf("%02d:%02d:%02d", $tmp, $tmp_min, $tmp_sec);
}

sub hour2time {
	#  00, 00:00, or 00:00:00
	my $a = shift;
	# my ($tmp, $tmp_min, $tmp_sec) = (0,0,0);
	my ($tmp, $tmp_min, $tmp_sec) = split(":", $a . ":0:0"); # , 3);
	return $tmp * $hour_size + $tmp_min * $minute_size + $tmp_sec * $second_size;
}

# div() returns (epoch / x)
sub div {
	my ($tmp1, $tmp2) = @_;
	return $tmp1->{a} / $tmp2;
}

sub sub {
	# TODO: (since 0.21) keep format ("mode") in result (see: "Date::add")
	my ($tmp1, $tmp2, $inverted) = @_;
	my $result;
	$tmp2 = Set::Infinite::Date->new($tmp2) unless ref($tmp2) and (ref($tmp2) eq __PACKAGE__);
	if ($inverted) {
		return - $tmp1 if $tmp2->is_null;
		$result = Set::Infinite::Date->new( $tmp2->{a} - $tmp1->{a} );
		$result->{mode} = $tmp2->{mode};
	}
	return $tmp1 unless defined($tmp2);
	$result = Set::Infinite::Date->new( $tmp1->{a} - $tmp2->{a} );
	$result->{mode} = $tmp1->{mode};
	return $result;
}

sub add {
	my ($tmp1, $tmp2, $inverted) = @_;
	return $tmp1 unless defined($tmp2);
	# print " [DATE::ADD $tmp1 $tmp2] ";
	$tmp2 = Set::Infinite::Date->new($tmp2) unless ref($tmp2) eq __PACKAGE__;
	my $result = Set::Infinite::Date->new( $tmp1->{a} + $tmp2->{a} );
	if ($inverted) {
		$result->{mode} = $tmp2->{mode};
	}
	else {
		$result->{mode} = $tmp1->{mode};
	}
	return $result;
}

sub spaceship {
	my ($tmp1, $tmp2, $inverted) = @_;
	if ($inverted) {
		return ( $tmp2 <=> $tmp1->{a} );
	}

        # my @caller = caller(1);
        # print " [",$caller[1],":",$caller[2]," <=> $tmp1 $tmp2 ]\n" ;

	return ( $tmp1->{a} <=> $tmp2 );
}

sub new {
	my $class = shift;
	my $self;
	if (ref($class)) {
		$self = bless { mode => $class->{mode} }, ref($class);
	}
	else {
		$self = bless {}, $class;
	}
	my $tmp = shift;

	if ((not defined $tmp) or ($tmp eq '')) {
		# print " [date:new:null] ";
		return undef;  # Set::Infinite::Element_Inf->null ;
	}

	if (exists $date_cache{$tmp}) {
		# print "*";
        ### TODO: this breaks t/date_select_offset.t test #12
        ###    because it is mixing modes 0 and 2
		### return $date_cache{$tmp};
	}
	# print "N";
	$tmp = '' unless defined $tmp;
	$self->{string} = '';
	if ($tmp =~ /\d[\/\.\-]\d/) {
		# $self->{string} = $tmp;
		$self->{a} = date2time($tmp);
		$self->{mode} = 2 unless $self->{mode};
	}
	elsif ($tmp =~ /\d\:\d/) {
		# $self->{string} = $tmp;
		$self->{a} = hour2time($tmp);
		$self->{mode} = 1 unless $self->{mode};
	}
	else {
		# $self->{string} = $tmp;
		$self->{a} = $tmp;
		$self->{mode} = 0 unless $self->{mode};
	}
	$date_cache{$tmp} = $self;
	return $self;
}

sub mode {
	my ($self) = shift;
	$self->{mode} = shift;
	$self->{string} = '';
	return $self;
}

sub as_string {
	my ($self) = shift;

	#return '' unless defined($self);
	#print " [ $self->{string} ] " ;
	# $self->{string} = '';

	if ($self->{string} ne '') {
		# done
		#print "1 ";
	}
	elsif (not defined($self->{a})) {
		$self->{string} = '';
		#print "2 ";
	}
	elsif ($self->{mode} == 0) {
		$self->{string} = $self->{a};
		#print "3 ";
	}
	elsif ($self->{mode} == 1) {
		$self->{string} = time2hour($self->{a});
	}
	else {
		$self->{string} = time2date($self->{a});
	}
	return $self->{string};
}

1;
