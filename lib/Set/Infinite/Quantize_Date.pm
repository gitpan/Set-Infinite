package Set::Infinite::Quantize_Date;

# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;

require Exporter;

our @EXPORT = qw();
our @EXPORT_OK = qw();

use Time::Local;
use Set::Infinite qw(type);
use Set::Infinite::Element_Inf qw(inf);

=head2 NAME

Set::Infinite::Quantize_Date - arrays of date intervals to make calendars

=head2 USAGE

	See Set::Infinite

=head2 CHANGES

	- added 'weekyears' to return the year from day 1 of first week to day 7 of last week.
	- uses 'wkst', with default 1 = monday.

		->quantize( unit => weekyears, wkst => 1 )

	- option 'strict' will return intersection($a,quantize). Default: parent set.

	- add a parameter like 'minutes' 15 for 15min intervals.
	- round minute values to 00, 15, 30, 45
	- `foreach' work (find out `$#' in advance)
	- make it work on the `set' instead of `span' (let user choose)

=cut


our $day_size = timegm(0,0,0,2,3,2001) - timegm(0,0,0,1,3,2001);
our $hour_size = $day_size / 24;
our $minute_size = $hour_size / 60;
our $second_size = $minute_size / 60;

our @week_start = ( 0, -1, -2, -3, 3, 2, 1, 0, -1, -2, -3, 3, 2, 1, 0 );

our %subs = (
	weekyears =>	sub {
		my ($self, $index) = @_;
		my $epoch = timegm( 0,0,0, 
			1,0,$self->{date_begin}[5] + $self->{quant} * $index);
		my @time = gmtime($epoch);
		# print " [QT_D:weekyears:$self->{date_begin}[5] + $self->{quant} * $index]\n";
		# year modulo week
		# print " [QT:weekyears: ",$self->{date_begin}[5] + $self->{quant} * $index," epoch=$epoch ]\n";
		# print " [QT:weekyears: time = ",join(";", @time )," ]\n";
		$epoch += ( $week_start[$time[6] + 7 - $self->{wkst}] ) * $day_size;
		# print " [QT:weekyears: week=",join(";", gmtime($epoch) )," wkst=$self->{wkst} tbl[",$time[6] + 7 - $self->{wkst},"]=",$week_start[$time[6] + 7 - $self->{wkst}]," ]\n\n";
		return $epoch;
	},
	years => 	sub {
		my ($self, $index) = @_;
		# print " [QT_D:YEARS:$self->{date_begin}[5] + $self->{quant} * $index]\n";
		return timegm( 0,0,0, 
			1,0,$self->{date_begin}[5] + $self->{quant} * $index); },
	months => 	sub {
		my ($self, $index) = @_;
		my $mon = 	$self->{date_begin}[4] + $self->{quant} * $index; 
		my $year =	$self->{date_begin}[5];
		if ($mon > 11) {
			my $addyear = int($mon / 12);
			$mon = $mon - 12 * $addyear;
			$year += $addyear;
		}
		return timegm( 0,0,0, 
			1, $mon, $year); },
	days => 	sub {
		my ($self, $index) = @_;
		return $self->{first} + $self->{quant} * $index * $day_size; },
	weeks =>	sub {
		my ($self, $index) = @_;
		# print " [QD:fn:weeks: $self->{first} + 7 * $self->{quant} * $index * $day_size ]\n";
		return $self->{first} + 7 * $self->{quant} * $index * $day_size; },
	hours =>	sub {
		my ($self, $index) = @_;
		return $self->{first} + $self->{quant} * $index * $hour_size; },
	minutes =>	sub {
		my ($self, $index) = @_;
		return $self->{first} + $self->{quant} * $index * $minute_size; },
	seconds =>	sub {
		my ($self, $index) = @_;
		return $self->{first} + $self->{quant} * $index * $second_size; },
	one =>   	sub { 
		my ($self, $index) = @_;
		# print " $self->{first} + $self->{quant} * $index \n";
		return $self->{first} + $self->{quant} * $index; },
);

our %init = (
	one =>  	sub {
		my $self = shift;
		# $rest = $self->{date_begin}[0] % $self->{quant};
		# modulo operation - can't use `%'
		my $tmp1 = int($self->{parent}->min / $self->{quant});
		$self->{first} = $tmp1 * $self->{quant};
		$self->{mult} = 1; },
	seconds =>	sub {
		my $self = shift;
		# $rest = $self->{date_begin}[0] % $self->{quant};
		# modulo operation - can't use `%'
		my $tmp1 = int($self->{date_begin}[0] / $self->{quant});
 		my $rest = $self->{date_begin}[0] - $tmp1 * $self->{quant};
		$self->{first} = timegm(
			$self->{date_begin}[0] - $rest,	$self->{date_begin}[1],	$self->{date_begin}[2], 
			$self->{date_begin}[3],	$self->{date_begin}[4],$self->{date_begin}[5]);
		$self->{mult} = $second_size; },
	minutes =>	sub {
		my $self = shift;
		# $rest = $self->{date_begin}[1] % $self->{quant};
		# modulo operation - can't use `%'
		my $tmp1 = int($self->{date_begin}[1] / $self->{quant});
 		my $rest = $self->{date_begin}[1] - $tmp1 * $self->{quant};
		$self->{first} = timegm(
			0,$self->{date_begin}[1] - $rest, $self->{date_begin}[2], 
			$self->{date_begin}[3], $self->{date_begin}[4],$self->{date_begin}[5]);
		$self->{mult} = $minute_size; },
	hours =>	sub {
		my $self = shift;
		$self->{first} = timegm( 0,0,$self->{date_begin}[2], 
			$self->{date_begin}[3],$self->{date_begin}[4],$self->{date_begin}[5]);
		$self->{mult} = $hour_size; },
	days => 	sub {
		my $self = shift;
		$self->{first} = timegm( 0,0,0, 
			$self->{date_begin}[3],$self->{date_begin}[4],$self->{date_begin}[5]);
		$self->{mult} = $day_size; },
	weeks =>	sub {
		my $self = shift;
		$self->{first} = timegm( 0,0,0, 
			$self->{date_begin}[3],$self->{date_begin}[4],$self->{date_begin}[5]);
		$self->{first} -= $self->{date_begin}[6] * $day_size;
		$self->{mult} = 7 * $day_size; },
	months =>	sub {
		my $self = shift;
		$self->{mult} = 31 * $day_size; },
	years =>	sub {
		my $self = shift;
		# print " [QT_D:YEARS_INIT]\n";
		$self->{mult} = 365 * $day_size; },
	weekyears =>	sub {
		my $self = shift;
		# print " [QT_D:WEEKYEARS_INIT]\n";
		$self->{wkst} = 1 if $self->{wkst} eq '';
		# print " [QT:$self->{wkst}] \n";
		$self->{mult} = 365 * $day_size; },
);

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
	# print " [QUANTIZE_DATE $class] \n";
	my ($self) = bless \%rules, $class;
	# print " [ SELF:ISA:", ref($self), "] ";

	# my ($class, $parent, %rules) = @_;
	# my ($self) = bless \%rules, $class;
	# print " [ PARENT:ISA:", ref($parent), "] ";
	# print " [ QT:PARAM: ", join(":", %$self), "] ";

	$self->{unit} = 'one' unless $self->{unit};
	$self->{quant} = 1 unless $self->{quant};

	# parent may be "simple"!
	$parent = Set::Infinite->new($parent) unless $parent->isa('Set::Infinite');
	$self->{parent} = $parent; 
	$self->{cache} = {};   # empty hash
	$self->{strict} = $parent unless exists $self->{strict};
	$self->{type} = $parent->{type};

	my $min = $self->{parent}->min;
	# print " [MIN:$min] \n";
	if (Set::Infinite::Element_Inf->is_null($min)) {
		# print " [NULL!]\n";
		$self->{size} = -1;
		return $self;	
	}
	if (ref($min)) {
		# mode is 'Date' specific
		if (exists $min->{mode}) {
			$self->{mode}  = $min->{mode};
		}
	}

	# $self->{last} = 0;
	# $self->{last_index} = -999;
	# my $rest;

	# print " [Q-DATE:DATES:",$self->{parent}," ",ref( $self->{parent} ),"]\n";
	# print " [Q-DATE:MIN:",$self->{parent}->min," ",ref( $self->{parent}->min ),"]\n";
	# print " [Q-DATE:MIN:",$self->{parent}->{a}," = ",0+ $self->{parent}->{a},"]\n";
	# print " [Q-DATE:MODE:",$self->{mode},"]\n";
	# print " [Q-DATE:",join(";",%$self),"]\n";

	@{$self->{date_begin}} = gmtime( 0 + $min );
	$self->{date_begin}[5] += 1900;

	$self->{first} = $min;

	# $self->{first} = timegm( @{$self->{date_begin}} );
	# $self->{mult} = 1;

	# print " [QD:1:unit:$self->{unit}] ";

	&{ $init{$self->{unit}} } ($self);

	$self->{time2_end} = $self->{parent}->max;
	# print " [time2_end isa ", ref($self->{time2_end}), "] ";

	# print " [QD:SIZE: = 2 + ($self->{time2_end} - $self->{first}) /  ($self->{quant} * $self->{mult})]\n";

	$self->{size}  = 2 + ( $self->{time2_end} - $self->{first} ) / 
				( $self->{quant} * $self->{mult} ) ;

	# print " [QD:$self->{size}] \n";
	# print " [QD:new:end] \n";
	return $self;
}



sub FETCH {
	my ($self) = shift;
	my $index = shift;

	if ($index and (exists $self->{cache}->{$index})) {
		# print "*";
		return $self->{cache}->{$index};
	}

	my ($this, $next);

	# print " [QD:fetch:$index] ";
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
		$self->{cache}->{$index} = Set::Infinite::Simple->simple_null;
		return $self->{cache}->{$index};
	}
	# print " [QD:fetch:new($this,$next)] ";
	my $tmp = Set::Infinite::Simple->new($this,$next, $self->{type} )->open_end(1);
	# my $tmp = Set::Infinite::Simple->fastnew($this,$next)->open_end(1);

	# if ((ref($tmp->{a})) and ($tmp->{a}->can('mode'))) {   
	if (exists $self->{mode}) {
		$tmp->{a}->mode($self->{mode});
		$tmp->{b}->mode($self->{mode});
	}
	# print " [QD:fetch:$tmp] ";

	# $tmp = Set::Infinite::Simple->new($tmp);  # 0.25 ???

	# slower but necessary:
	# print " <qd: ";

	# if ($self->{parent}->intersects($tmp)) {
	if (not $self->{strict} or ($self->{strict}->intersects($tmp))) {
		# print " [QD:INTER:",$self->{parent}->intersects($tmp),"=", $self->{parent}->intersection($tmp),"]\n";
		# print " :ok /qd> ";
		$self->{cache}->{$index} = $tmp;
		return $tmp;
	}
	# print " :null /qd> ";
	$self->{cache}->{$index} = Set::Infinite::Simple->simple_null;
	return $self->{cache}->{$index};
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

sub STORE {
	return @_;
}

sub DESTROY {
}


1;
