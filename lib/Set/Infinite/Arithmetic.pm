package Set::Infinite::Arithmetic;
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;
require Exporter;
use Set::Infinite::Function;
# use Set::Infinite;
use Carp;
use Time::Local;

our @EXPORT = qw();
our @EXPORT_OK = qw( %subs_offset2 %subs_offset1 %subs_offset1_init );

our $inf = 10**10**10;    # $Set::Infinite::inf;  doesn't work! (why?)
# carp " INF $inf ".&Set::Infinite::inf;

=head2 NAME

Set::Infinite::Arithmetic - Internal scalar operations used by quantization and offset

=head2 SYNOPSIS

TODO

=head2 CHANGES

20020111 - Created from Offset.pm and Quantize_Date.pm data

=head2 AUTHOR

Flavio Soibelmann Glock - fglock@pucrs.br

=cut

 
our $day_size =    timegm(0,0,0,2,3,2001) - timegm(0,0,0,1,3,2001);
our $hour_size =   $day_size / 24;
our $minute_size = $hour_size / 60;
our $second_size = $minute_size / 60;

=head2 %subs_offset2($object, $offset1, $offset2)

	&{ $subs_offset2{$unit} } ($object, $offset1, $offset2);

A hash of functions that return 

	($object+$offset1, $object+$offset2, $object+$offset1 <=> $object+$offset2)

in $unit context.

Returned $object+$offset1, $object+$offset2 may be scalars or objects.

=cut

our %subs_offset2 = (
	weekdays =>	sub {
		# offsets to week-day specified
		# 0 = first sunday from today (or today if today is sunday)
		# 1 = first monday from today (or today if today is monday)
		# 6 = first friday from today (or today if today is friday)
		# 13 = second friday from today 
		# -1 = last saturday from today (not today, even if today were saturday)
		# -2 = last friday
		my ($self, $index1, $index2) = @_;
		return ($self, $self, 0) if $self == $inf;
		# my $class = ref($self);
		my @date = gmtime( $self ); 
		my $wday = $date[6];
		my ($tmp1, $tmp2);

		$tmp1 = $index1 - $wday;
		if ($index1 >= 0) { 
			$tmp1 += 7 if $tmp1 < 0; # it will only happen next week 
		}
		else {
			$tmp1 += 7 if $tmp1 < -7; # if will happen this week
		} 

		$tmp2 = $index2 - $wday;
		if ($index2 >= 0) { 
			$tmp2 += 7 if $tmp2 < 0; # it will only happen next week 
		}
		else {
			$tmp2 += 7 if $tmp2 < -7; # if will happen this week
		} 

		# print " [ OFS:weekday $self $tmp1 $tmp2 ] \n";
		# $date[3] += $tmp1;
		$tmp1 = $self + $tmp1 * $day_size;
		# $date[3] += $tmp2 - $tmp1;
		$tmp2 = $self + $tmp2 * $day_size;

		my $cmp = $tmp1 <=> $tmp2;
		($tmp1, $tmp2, $cmp);
	},
	years => 	sub {
		my ($self, $index, $index2) = @_;
		return ($self, $self, 0) if $self == $inf;
		# my $class = ref($self);
		# print " [ofs:year:$self -- $index]\n";
		my @date = gmtime( $self ); 
		$date[5] +=	1900 + $index;
		my $tmp = timegm(@date);

		$date[5] +=	$index2 - $index;
		my $tmp2 = timegm(@date);

		my $cmp = $index <=> $index2;

		($tmp, $tmp2, $cmp);
	},
	months => 	sub {
		my ($self, $index, $index2) = @_;
		# carp " [ofs:month:$self -- $index -- $inf]";
		return ($self, $self, 0) if $self == $inf;
		# my $class = ref($self);
		my @date = gmtime( $self );

		my $mon = 	$date[4] + $index; 
		my $year =	$date[5] + 1900;
		# print " [OFS: month: from $year$mon ]\n";
		if (($mon > 11) or ($mon < 0)) {
			my $addyear = $mon >= 0 ? int($mon / 12) : int($mon/12) - 1;
			$mon = $mon - 12 * $addyear;
			$year += $addyear;
		}

		my $mon2 = 	$date[4] + $index2; 
		my $year2 =	$date[5] + 1900;
		if (($mon2 > 11) or ($mon2 < 0)) {
			my $addyear2 = $mon2 >= 0 ? int($mon2 / 12) : int($mon2 / 12) - 1;
			$mon2 = $mon2 - 12 * $addyear2;
			$year2 += $addyear2;
		}

		# print " [OFS: month: to $year $mon ]\n";

		$date[4] = $mon;
		$date[5] = $year;
		my $tmp = timegm(@date);

		$date[4] = $mon2;
		$date[5] = $year2;
		my $tmp2 = timegm(@date);

		my $cmp = $index <=> $index2;

		($tmp, $tmp2, $cmp);
	},
	days => 	sub { 
		( $_[0] + $_[1] * $day_size,
		  $_[0] + $_[2] * $day_size,
		  $_[1] <=> $_[2]	)
	},
	weeks =>	sub { 
		( $_[0] + $_[1] * (7 * $day_size),
		  $_[0] + $_[2] * (7 * $day_size),
		  $_[1] <=> $_[2]	)
	},
	hours =>	sub { 
		( $_[0] + $_[1] * $hour_size,
		  $_[0] + $_[2] * $hour_size,
		  $_[1] <=> $_[2]	)
	},
	minutes =>	sub { 
		( $_[0] + $_[1] * $minute_size,
		  $_[0] + $_[2] * $minute_size,
		  $_[1] <=> $_[2]	)
	},
	seconds =>	sub { 
		( $_[0] + $_[1] * $second_size, 
		  $_[0] + $_[2] * $second_size, 
		  $_[1] <=> $_[2]	)
	},
	one =>  	sub { 
		( $_[0] + $_[1], 
		  $_[0] + $_[2], 
		  $_[1] <=> $_[2]	)
	},
);


our @week_start = ( 0, -1, -2, -3, 3, 2, 1, 0, -1, -2, -3, 3, 2, 1, 0 );

=head2 %subs_offset1($object, $offset)

=head2 %subs_offset1_init($object)

	&{ $subs_offset1{$unit} } ($object, $offset);

	&{ $subs_offset1_init{$unit} } ($object);

A hash of functions that return ( int($object) + $offset ) in $unit context.

subs_offset1_init subroutines must be called before using subs_offset1 functions.

int(object)+offset is a scalar.

subs_offset1 is optimized for calling it multiple times on the same object,
with different offsets. That's why there is a separate initialization
subroutine.

$self->{offset} is created on initialization. It is an index used 
by the memoization cache.

=cut

our %subs_offset1 = (
	weekyears =>	sub {
		my ($self, $index) = @_;
		my $epoch = timegm( 0,0,0, 
			1,0,$self->{date_begin}[5] + $self->{quant} * $index);
		my @time = gmtime($epoch);
		# print " [QT_D:weekyears:$self->{date_begin}[5] + $self->{quant} * $index]\n";
		# year modulo week
		# print " [QT:weekyears: time = ",join(";", @time )," ]\n";
		$epoch += ( $week_start[$time[6] + 7 - $self->{wkst}] ) * $day_size;
		# print " [QT:weekyears: week=",join(";", gmtime($epoch) )," wkst=$self->{wkst} tbl[",$time[6] + 7 - $self->{wkst},"]=",$week_start[$time[6] + 7 - $self->{wkst}]," ]\n\n";
		$epoch;
	},
	years => 	sub {
		my ($self, $index) = @_;
		# print " [QT_D:YEARS:$self->{date_begin}[5] + $self->{quant} * $index]\n";
		timegm( 0,0,0,
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
		timegm( 0,0,0,
			1, $mon, $year); },
	days => 	sub {
		my ($self, $index) = @_;
		$self->{first} + $self->{quant} * $index * $day_size; },
	weeks =>	sub {
		my ($self, $index) = @_;
		# print " [QD:fn:weeks: $self->{first} + 7 * $self->{quant} * $index * $day_size ]\n";
		$self->{first} + 7 * $self->{quant} * $index * $day_size; },
	hours =>	sub {
		my ($self, $index) = @_;
		$self->{first} + $self->{quant} * $index * $hour_size; },
	minutes =>	sub {
		my ($self, $index) = @_;
		$self->{first} + $self->{quant} * $index * $minute_size; },
	seconds =>	sub {
		my ($self, $index) = @_;
		$self->{first} + $self->{quant} * $index * $second_size; },
	one =>   	sub { 
		my ($self, $index) = @_;
		# print " $self->{first} + $self->{quant} * $index \n";
		$self->{first} + $self->{quant} * $index; },
);

our %subs_offset1_init = (
	one =>  	sub {
		my $self = shift;
		# $rest = $self->{date_begin}[0] % $self->{quant};
		# modulo operation - can't use `%'
		my $tmp1 = int($self->{parent}->min / $self->{quant});
		$self->{first} = $tmp1 * $self->{quant};
		$self->{offset} = $tmp1;
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
		$self->{offset} = $self->{first} / $self->{quant} / $second_size;
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
		$self->{offset} = $self->{first} / $self->{quant} / $minute_size;
		$self->{mult} = $minute_size; },
	hours =>	sub {
		my $self = shift;
		$self->{first} = timegm( 0,0,$self->{date_begin}[2], 
			$self->{date_begin}[3],$self->{date_begin}[4],$self->{date_begin}[5]);
		$self->{offset} = $self->{first} / $self->{quant} / $hour_size;
		$self->{mult} = $hour_size; },
	days => 	sub {
		my $self = shift;
		$self->{first} = timegm( 0,0,0, 
			$self->{date_begin}[3],$self->{date_begin}[4],$self->{date_begin}[5]);
		$self->{offset} = $self->{first} / $self->{quant} / $day_size;
		$self->{mult} = $day_size; },
	weeks =>	sub {
		my $self = shift;
		$self->{first} = timegm( 0,0,0, 
			$self->{date_begin}[3],$self->{date_begin}[4],$self->{date_begin}[5]);
		$self->{first} -= $self->{date_begin}[6] * $day_size;
		$self->{offset} = ($self->{first} - 3 * $day_size) / $self->{quant} / 7 / $day_size;
		$self->{mult} = 7 * $day_size; },
	months =>	sub {
		my $self = shift;
		$self->{offset} = $self->{date_begin}[4] + 12 * $self->{date_begin}[5];
		# print " [init months offset=$self->{offset} ]\n";
		$self->{mult} = 31 * $day_size; },
	years =>	sub {
		my $self = shift;
		# print " [QT_D:YEARS_INIT]\n";
		$self->{offset} = $self->{date_begin}[5];
		$self->{mult} = 365 * $day_size; },
	weekyears =>	sub {
		my $self = shift;
		# print " [QT_D:WEEKYEARS_INIT]\n";
		$self->{wkst} = 1 if $self->{wkst} eq '';
		$self->{offset} = $self->{date_begin}[5];
		# print " [QT:$self->{wkst}] \n";
		$self->{mult} = 365 * $day_size; },
);


1;

