package Set::Infinite::Quantize_Date;

# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;

require Exporter;
our $VERSION = "0.19";

my $package = 'Set::Infinite::Quantize_Date';
our @EXPORT = qw();
our @EXPORT_OK = qw();

use Time::Local;
use Set::Infinite qw(type);

=head2 NAME

Set::Infinite::Quantize_Date - arrays of date intervals to make calendars

=head2 USAGE

	See Set::Infinite

=head2 TODO

	week(year, week_number); => DATE_SET

=head2 CHANGES

	- add a parameter like 'minutes' 15 for 15min intervals.
	- round minute values to 00, 15, 30, 45
	- `foreach' work (find out `$#' in advance)
	- make it work on the `set' instead of `span' (let user choose)

=cut

our $day_size = timelocal(0,0,0,2,3,2001) - timelocal(0,0,0,1,3,2001);
our $hour_size = $day_size / 24;
our $minute_size = $hour_size / 60;
our $second_size = $minute_size / 60;

our %subs = (
	years => 	\&years,
	months => 	\&months,
	days => 	\&days,
	weeks =>	\&weeks,
	hours =>	\&hours,
	minutes =>	\&minutes,
	seconds =>	\&seconds,
);

# list of full years in a date set
sub years {
	my ($self, $index) = @_;
	return timelocal(
		0,0,0, 
		1,0,$self->{date_begin}[5] + $self->{quant} * $index);
}

# list of full months in a date set
sub months {
	my ($self, $index) = @_;

	my $mon = 	$self->{date_begin}[4] + $self->{quant} * $index; 
	my $year =	$self->{date_begin}[5];
	if ($mon > 11) {
		my $addyear = int($mon / 12);
		$mon = $mon - 12 * $addyear;
		$year += $addyear;
	}
	return timelocal(
		0,0,0, 
		1, $mon, $year);
}

# list of full days in a date set
sub days {
	my ($self, $index) = @_;
	return $self->{first} + $self->{quant} * $index * $day_size;
}

# list of full weeks in a date set
sub weeks {
	my ($self, $index) = @_;
	return $self->{first} + 7 * $self->{quant} * $index * $day_size;
}

# list of full hours in a date set
sub hours {
	my ($self, $index) = @_;
	return $self->{first} + $self->{quant} * $index * $hour_size;
}

# list of full minutes in a date set
sub minutes {
	my ($self, $index) = @_;
	return $self->{first} + $self->{quant} * $index * $minute_size;
}

# list of full seconds in a date set
sub seconds {
	my ($self, $index) = @_;
	return $self->{first} + $self->{quant} * $index * $second_size;
}

sub new {
	my ($class, $parent, %rules);
	if ($#_ == 2) {
		# old syntax (non-hash):  new(1) "one day"  
		($class, $parent, $rules{quant}) = @_;
	}
	elsif ( ($#_ == 3) and (exists ($subs{$_[2]}) ) ) {  
		# old syntax (non-hash):  new('days', 1) "one day"  
		($class, $parent, $rules{unit}, $rules{quant}) = @_;
	}
	else {
		($class, $parent, %rules) = @_;
	}
	my ($self) = bless \%rules, $class;

	# my ($class, $parent, %rules) = @_;
	# my ($self) = bless \%rules, $class;
	# print " [ PARENT:ISA:", ref($parent), "] ";

	$self->{unit} = 'days' unless $self->{unit};
	$self->{quant} = 1 unless $self->{quant};

	# may be "simple"!
	$parent = Set::Infinite->new($parent) unless $parent->isa('Set::Infinite');
	$self->{dates} = $parent;  # date

	$self->{mode}  = $self->{dates}->min->{mode};

	#$self->{last} = 0;
	#$self->{last_index} = -999;

	my $rest;

	# print " [Q-DATE:MIN:",$self->{dates}->{a}," = ",0+ $self->{dates}->{a},"]\n";
	# print " [Q-DATE:MODE:",$self->{mode},"]\n";

	@{$self->{date_begin}} = localtime( 0 + $self->{dates}->min );
	$self->{date_begin}[5] += 1900;

	$self->{first} = timelocal( @{$self->{date_begin}} );
	$self->{mult} = 1;

	if ($self->{unit} eq 'seconds') {

		# $rest = $self->{date_begin}[0] % $self->{quant};
		# modulo operation - can't use `%'
		my $tmp1 = int($self->{date_begin}[0] / $self->{quant});
 		$rest = $self->{date_begin}[0] - $tmp1 * $self->{quant};

		$self->{first} = timelocal(
			$self->{date_begin}[0] - $rest,	$self->{date_begin}[1],	$self->{date_begin}[2], 
			$self->{date_begin}[3],	$self->{date_begin}[4],$self->{date_begin}[5]);
		$self->{mult} = $second_size;
	}
	elsif ($self->{unit} eq 'minutes') {
		# $rest = $self->{date_begin}[1] % $self->{quant};
		# modulo operation - can't use `%'
		my $tmp1 = int($self->{date_begin}[1] / $self->{quant});
 		$rest = $self->{date_begin}[1] - $tmp1 * $self->{quant};

		$self->{first} = timelocal(
			0,$self->{date_begin}[1] - $rest, $self->{date_begin}[2], 
			$self->{date_begin}[3], $self->{date_begin}[4],$self->{date_begin}[5]);
		$self->{mult} = $minute_size;
	}
	elsif ($self->{unit} eq 'hours') {
		$self->{first} = timelocal(
			0,0,$self->{date_begin}[2], 
			$self->{date_begin}[3],$self->{date_begin}[4],$self->{date_begin}[5]);
		$self->{mult} = $hour_size;
	}
	elsif ($self->{unit} eq 'days') {
		$self->{first} = timelocal(
			0,0,0, 
			$self->{date_begin}[3],$self->{date_begin}[4],$self->{date_begin}[5]);
		$self->{mult} = $day_size;
	}
	elsif ($self->{unit} eq 'weeks') {
		$self->{first} = timelocal(
			0,0,0, 
			$self->{date_begin}[3],$self->{date_begin}[4],$self->{date_begin}[5]);
		$self->{first} -= $self->{date_begin}[6] * $day_size;
		$self->{mult} = 7 * $day_size;
	}
	elsif ($self->{unit} eq 'months') {
		$self->{mult} = 31 * $day_size;
	}
	elsif ($self->{unit} eq 'years') {
		$self->{mult} = 365 * $day_size;
	}


	$self->{time2_end} = 0 + $self->{dates}->max;

	# print " [QUANT: = 2 + ($self->{time2_end} - $self->{first}) /  ($self->{quant} * $self->{mult})]\n";

	$self->{size}  = 2 + ( $self->{time2_end} - $self->{first} ) / 
				( $self->{quant} * $self->{mult} ) ;

	return $self;
}

# TIE

sub TIEARRAY {
	my $class = shift;
	my $self = $class->new(@_);
	return $self;
}

sub FETCHSIZE {
	my ($self) = shift;
	return $self->{size}; 
}

sub STORESIZE {
	return @_;
}

sub CLEAR {
	my ($self) = shift;
	return @_;
}

sub EXTEND {
	return @_;
}

sub FETCH {
	my ($self) = shift;
	my $index = shift;

	my ($this, $next);

	$this = &{ $subs{$self->{unit}} } ($self, $index);

	# test cache
	#if (($index + 1) == $self->{last_index}) {
	#	$next = $self->{last};
	#}
	#else {
		$next = &{ $subs{$self->{unit}} } ($self, $index + 1);
	#}

	# add to cache
	#$self->{last} = $next;
	#$self->{last_index} = $index + 1;

	if ($this > $self->{time2_end}) {
		$self->{size} = $index if $self->{size} > $index;
		return Set::Infinite::Simple->simple_null;
	}
	my $tmp = Set::Infinite::Simple->new($this,$next)->open_end(1);
	$tmp->{a}->mode($self->{mode});
	$tmp->{b}->mode($self->{mode});
	$tmp = Set::Infinite::Simple->new($tmp);
	# slower but necessary:
	if ($self->{dates}->intersects($tmp)) {
		# print " [QD:INTER:",$self->{dates}->intersects($tmp),"=",	$self->{dates}->intersection($tmp),"]\n";
		return $tmp;
	}
	return Set::Infinite::Simple->simple_null;
}

sub STORE {
	return @_;
}

sub DESTROY {
}


1;
