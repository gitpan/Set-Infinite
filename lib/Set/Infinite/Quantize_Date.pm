package Set::Infinite::Quantize_Date;

# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;

require Exporter;
use Tie::Array;

our @ISA = qw( Tie::StdArray Exporter );
our @EXPORT = qw();
our @EXPORT_OK = qw();

use Time::Local;
use Set::Infinite qw(type);
use Set::Infinite::Arithmetic;
use Set::Infinite::Element_Inf qw(inf);

=head2 NAME

Set::Infinite::Quantize_Date - arrays of date intervals to make calendars

=head2 USAGE

	See Set::Infinite

=head2 CHANGES

	- use ./Arithmetic.pm

	- use Tie::Array

	- added 'weekyears' to return the year from day 1 of first week to day 7 of last week.
	- uses 'wkst', with default 1 = monday.

		->quantize( unit => weekyears, wkst => 1 )

	- option 'strict' will return intersection($a,quantize). Default: parent set.

	- add a parameter like 'minutes' 15 for 15min intervals.
	- round minute values to 00, 15, 30, 45
	- `foreach' work (find out `$#' in advance)
	- make it work on the `set' instead of `span' (let user choose)

=cut

our %Memoize;

sub new {
	my ($class, $parent, %rules);
	if ($#_ == 2) {
		# old syntax (non-hash):  new(1) "one day"  
		($class, $parent, $rules{quant}) = @_;
	}
	elsif ( ($#_ == 3) and (exists ($Set::Infinite::Arithmetic::subs_offset1{$_[2]}) ) ) {  
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

	&{ $Set::Infinite::Arithmetic::subs_offset1_init{$self->{unit}} } ($self);

	$self->{time2_end} = $self->{parent}->max;
	# print " [time2_end isa ", ref($self->{time2_end}), "] ";

	# print " [QD:SIZE: = 2 + ($self->{time2_end} - $self->{first}) /  ($self->{quant} * $self->{mult})]\n";

	$self->{size}  = 2 + ( $self->{time2_end} - $self->{first} ) / 
				( $self->{quant} * $self->{mult} ) ;

	# print " [QD:$self->{size}] \n";
	# print " [QD:new:end] \n";

	$self->{fixtype} = 1 unless exists $self->{fixtype};

	$self->{memo} = '';
	if (exists $self->{offset}) {
		$self->{memo} = $self->{unit} . $self->{quant} . $self->{fixtype};
		$self->{memo} .= $self->{wkst} if exists $self->{wkst};
		# print " [QD:offset=",$self->{offset}," ",$self->{first}," ", $self->{memo}," ",	" ]\n";
 	}

	return $self;
}


# this is a wrapper to _FETCH that memoizes results and makes 'strict' checks.
# %Memoize{$self->{memo}}{...}  stores memoized results  
# $self->{cache}->{...} stores 'strict' results
sub FETCH {
	my ($self) = shift;
	my $index = shift or 0;

	return $self->{cache}->{$index} if exists $self->{cache}->{$index};

	my $tmp = $Memoize{$self->{memo}}{$index + $self->{offset}};
	unless (defined $tmp) {
  		$tmp = _FETCH ($self,$index);
		$Memoize{$self->{memo}}{$index + $self->{offset}} = $tmp;
	}

	if ($self->{strict} and not $self->{strict}->intersects($tmp)) {
		$tmp = Set::Infinite::Simple->simple_null;
	}
	$self->{cache}->{$index} = $tmp;
	return $tmp;
}

sub _FETCH {
	my ($self, $index) = @_;
	my $tmp;
	my ($this, $next);

	# print "*";
	# print " [QD:fetch:$index] ";

	$this = &{ $Set::Infinite::Arithmetic::subs_offset1{$self->{unit}} } ($self, $index);
	$next = &{ $Set::Infinite::Arithmetic::subs_offset1{$self->{unit}} } ($self, $index + 1);

	# if ($this > $self->{time2_end}) {
	#	$self->{size} = $index if $self->{size} > $index;
	#	$self->{cache}->{$index} = Set::Infinite::Simple->simple_null;
	#	return $self->{cache}->{$index};
	# }

	# print " [QD:fetch:new($this,$next)] ";

	return Set::Infinite::Simple->fastnew($this, $next, 0, 1 ) unless $self->{fixtype};

	$tmp = Set::Infinite::Simple->new($this,$next, $self->{type} )->open_end(1);
	# my $tmp = Set::Infinite::Simple->fastnew($this,$next)->open_end(1);

	# if ((ref($tmp->{a})) and ($tmp->{a}->can('mode'))) {   
	if (exists $self->{mode}) {
		$tmp->{a}->mode($self->{mode});
		$tmp->{b}->mode($self->{mode});
	}
	# print " [QD:fetch:$tmp] ";

	return $tmp;

	# global "memoize"
	#if ($self->{memo}) {
	#	$Memoize{$self->{memo}}{$index + $self->{offset}} = $tmp;
	#}
	#
	#if (not $self->{strict} or ($self->{strict}->intersects($tmp))) {
	#	$self->{cache}->{$index} = $tmp;
	#	return $tmp;
	#}
	#$self->{cache}->{$index} = Set::Infinite::Simple->simple_null;
	#return $self->{cache}->{$index};
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

1;
