#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

Set::Infinite::Date - a 'date' scalar

=head1 SYNOPSIS

	use Set::Infinite::Date;

	$a = Set::Infinite::Date->new("10:00");

	This module requires HTTP:Date and Time::Local

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

	('10', '11') or
	('10:00', '11:00') or
	('10:00:00', '11:00:00') 
		means from 10:00:00 to 11:00:00; day is not specified

String conversion functions:
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
		1 (beginning in 00:00:00) or 
		2 (absolute dates like 2001-01-01 00:00:00)

=head1 TODO

	$time_format for mode=1
	understand input using date_format/time_format

=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

require Exporter;
package Set::Infinite::Date;
$VERSION = "0.009";

my $package = 'Set::Infinite::Date';
@EXPORT = qw();
@EXPORT_OK = qw(
	time2date date2time time2hour hour2time  
);

use strict;
use HTTP::Date qw(str2time);
use Time::Local;

use overload
	'<=>' => \&spaceship,
	'cmp' => \&cmp,
	'-' => \&sub,
	'+' => \&add,
	qw("" as_string);

our $day_size = timelocal(0,0,0,2,3,2001) - timelocal(0,0,0,1,3,2001);
our $hour_size = $day_size / 24;
our $minute_size = $hour_size / 60;
our $second_size = $minute_size / 60;

our $date_format = "year-month-day hour:min:sec";

sub date_format {
	$date_format = shift if @_;
	return $date_format;
}

# export time2date and date2time
sub time2date (;$)  { 
	my $tmp = shift;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($tmp);
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
	return $tmp;
}

sub date2time ($;$) { return HTTP::Date::str2time (shift) }

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
	my ($tmp, $tmp_min, $tmp_sec) = split(":", $a, 3);
	return $tmp * $hour_size + $tmp_min * $minute_size + $tmp_sec * $second_size;
}

sub sub {
	my ($tmp1, $tmp2, $inverted) = @_;
	$tmp2 = Set::Infinite::Date->new($tmp2) unless ref($tmp2) eq 'Set::Infinite::Date';
	if ($inverted) {
		return Set::Infinite::Date->new( $tmp2->{a} - $tmp1->{a} );
	}
	return Set::Infinite::Date->new( $tmp1->{a} - $tmp2->{a} );
}

sub add {
	my ($tmp1, $tmp2, $inverted) = @_;
	$tmp2 = Set::Infinite::Date->new($tmp2) unless ref($tmp2) eq 'Set::Infinite::Date';
	return Set::Infinite::Date->new( $tmp1->{a} + $tmp2->{a} );
}

sub spaceship {
	my ($tmp1, $tmp2, $inverted) = @_;
	$tmp2 = Set::Infinite::Date->new($tmp2) unless ref($tmp2) eq 'Set::Infinite::Date';
	if ($inverted) {
		return ( $tmp2->{a} <=> $tmp1->{a} );
	}
	return ( $tmp1->{a} <=> $tmp2->{a} );
}

sub cmp {
	return spaceship @_;
}

sub new {
	my ($self) = bless {}, shift;
	my $tmp = shift;
	if ($tmp =~ /\d[\/\.\-]\d/) {
		$self->{a} = date2time($tmp);
		$self->{mode} = 2;
	}
	elsif ($tmp =~ /\d\:\d/) {
		$self->{a} = hour2time($tmp);
		$self->{mode} = 1;
	}
	else {
		$self->{a} = $tmp;
		$self->{mode} = 0;
	}
	return $self;
}

sub mode {
	my ($self) = shift;
	$self->{mode} = shift;
	return $self;
}

sub as_string {
	my ($self) = shift;

	if (not defined($self->{a})) {
		return '';
	}
	elsif ($self->{mode} == 0) {
		return ($self->{a}) ;
	}
	elsif ($self->{mode} == 1) {
		return time2hour($self->{a}) ;
	}
	return time2date($self->{a}) ;
}

# TIE

sub TIESCALAR {
	my $class = shift;
	my $self = $class->new(@_);
	return $self;
}

sub FETCH {
	my ($self) = shift;
	return $self->as_string;
}

sub STORE {
	my ($self) = shift;
	$self = new(@_);
	return @_;
}

sub DESTROY {
}

1;
