package Set::Infinite::Offset;
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;
require Exporter;
use Set::Infinite::Function;
use Set::Infinite::Element_Inf qw(inf minus_inf);
use Carp;
use Time::Local;

our $VERSION = "0.03";
our @EXPORT = qw();
our @EXPORT_OK = qw();
our @ISA = qw(Set::Infinite::Function); 

=head2 NAME

Set::Infinite::Offset - Offsets a set :)

=head2 SYNOPSIS

	$a->offset ( value => [1,2], mode => 'offset', unit => 'days' );

	$a->offset ( value => [1,2, -5,-4], mode => 'offset', unit => 'days' );
		note: if mode = circle, then -5 counts from end (like a Perl negative array index).

	$a->offset ( value => [1,2], mode => 'offset', unit => 'days', strict => $a );
		option 'strict' will return intersection($a,offset). Default: none.

=head2 CHANGES

0.04
	strict
	multiple value-pairs
	negative begin value counts from end

0.03
	backtracking

0.02
	uses "Function.pm"

=head2 AUTHOR

Flavio Soibelmann Glock - fglock@pucrs.br

=cut

# our $day_size =    $Set::Infinite::Quantize_Date::day_size; 
our $day_size =    timegm(0,0,0,2,3,2001) - timegm(0,0,0,1,3,2001);
our $hour_size =   $day_size / 24;
our $minute_size = $hour_size / 60;
our $second_size = $minute_size / 60;

our %subs = (
	years => 	sub {
		my ($self, $index) = @_;
		return $self if $self == &inf;
		my $class = ref($self);
		# print " [ofs:year:$self -- $index]\n";
		my @date = gmtime( $self ); 
		$date[5] +=	1900 + $index;
		my $tmp = timegm(@date);
		return $tmp unless $class;
		$tmp = $class->new($tmp);
		$tmp->mode($self->{mode}) if exists $self->{mode};
		return $tmp;
	},
	months => 	sub {
		my ($self, $index) = @_;
		# print " [ofs:month:$self -- $index]\n";
		return $self if $self == &inf;
		my $class = ref($self);
		my @date = gmtime( $self );
		my $mon = 	$date[4] + $index; 
		my $year =	$date[5] + 1900;
		if ($mon > 11) {
			my $addyear = int($mon / 12);
			$mon = $mon - 12 * $addyear;
			$year += $addyear;
		}
		# elsif ($mon < 0) {
		#	$mon += 12;
		#	$year -= 1;
		# }
		$date[4] = $mon;
		$date[5] = $year;
		my $tmp = timegm(@date);
		return $tmp unless $class;
		$tmp = $class->new($tmp);
		$tmp->mode($self->{mode}) if exists $self->{mode};
		return $tmp;
	},
	days => 	sub { $_[0] + $_[1] * $day_size },
	weeks =>	sub { $_[0] + $_[1] * 7 * $day_size },
	hours =>	sub { $_[0] + $_[1] * $hour_size },
	minutes =>	sub { $_[0] + $_[1] * $minute_size },
	seconds =>	sub { $_[0] + $_[1] * $second_size },
	one =>  	sub { $_[0] + $_[1] },
);

sub init {
	my $self = shift;
	#print " [offset:init] ";
	unless (ref($self->{value}) eq 'ARRAY') {
		#print " [value:scalar:", $self->{value} ,"]\n";
		$self->{value} = [0 + $self->{value}, 0 + $self->{value}];
	}
	# print " [ofs:$self->{mode} $self->{unit} value:", join (",", @{$self->{value} }),"]\n";
	$self->{mode}   = 'offset' unless $self->{mode};
	$self->{unit}   = 'one' unless $self->{unit};

	$self->{parts}  = (1 + $#{$self->{value}}) / 2;

	$self->{strict} = 0 unless $self->{strict};

	return $self;
}

sub FETCHSIZE {
	my ($self) = shift;
	my $tmp = $self->{parts} * (1 + $#{ $self->{parent}->{list} });
	# print " [Offset::FETCHSIZE] ", $tmp, "\n";
	return $tmp;
}

sub FETCH {
	my ($self, $x) = @_;
	my ($tmp, $this, $next);

	my $part = 2 * ($x % $self->{parts});

	# tmp pointer because perl gets confused with $self->{parent}->{list}->[$x]->{a}
	my $interval = $self->{parent}->{list}->[$x / $self->{parts}];

	my $open_begin = $interval->{open_begin};
	my $open_end = $interval->{open_end};

	if ( Set::Infinite::Element_Inf::is_null($interval->{a}) ) {
		return Set::Infinite::Simple->simple_null ;
	}

	# print " [parent:", $interval,"]\n";
	## print " [ofs:parent:", $interval->{a},"]\n";
	# print " [mode:",$self->{mode},"]\n";
	# print " [value:", join (",", @{$self->{value} }),"]\n";

	# my $value0 = &{ $subs{$self->{unit}} } ($self->{value}->[$part + 0]);
	# my $value1 = &{ $subs{$self->{unit}} } ($self->{value}->[$part + 1]);

	if ($self->{mode} eq 'circle') {
		if ($self->{value}->[$part + 0] >= 0) {
			$this =  &{ $subs{$self->{unit}} } ($interval->{a}, $self->{value}->[$part + 0]) ;
			$next =  &{ $subs{$self->{unit}} } ($interval->{a}, $self->{value}->[$part + 1]) ;
		}
		else {
			$this =  &{ $subs{$self->{unit}} } ($interval->{b}, $self->{value}->[$part + 0]) ;
			$next =  &{ $subs{$self->{unit}} } ($interval->{b}, $self->{value}->[$part + 1]) ;
		}
	}
	elsif ($self->{mode} eq 'begin') {
			$this =  &{ $subs{$self->{unit}} } ($interval->{a}, $self->{value}->[$part + 0]) ;
			$next =  &{ $subs{$self->{unit}} } ($interval->{a}, $self->{value}->[$part + 1]) ;
	}
	elsif ($self->{mode} eq 'end') {
			$this =  &{ $subs{$self->{unit}} } ($interval->{b}, $self->{value}->[$part + 0]) ;
			$next =  &{ $subs{$self->{unit}} } ($interval->{b}, $self->{value}->[$part + 1]) ;
	}
	else {     
			# $self->{mode} eq 'offset') 
			$this =  &{ $subs{$self->{unit}} } ($interval->{a}, $self->{value}->[$part + 0]) ;
			$next =  &{ $subs{$self->{unit}} } ($interval->{b}, $self->{value}->[$part + 1]) ;
	}

	if ($this > $next) { 
		# print " [ofs:out($this,$next)] ";
		return Set::Infinite::Simple->simple_null;
	}

	# print " [ofs($this,$next)] ";

	$tmp = Set::Infinite::Simple->
		fastnew($this,$next)->
		open_end($open_end)->
		open_begin($open_begin);

	return $tmp unless ($self->{strict});

	if ($self->{strict}->intersects($tmp)) {
		return $tmp;
	}
	return Set::Infinite::Simple->simple_null;	
}


1;
