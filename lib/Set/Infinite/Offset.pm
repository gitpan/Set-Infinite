package Set::Infinite::Offset;
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;
require Exporter;
use Set::Infinite::Function;
use Carp;
use Time::Local;

our $VERSION = "0.02";
our @EXPORT = qw();
our @EXPORT_OK = qw();
our @ISA = qw(Set::Infinite::Function); 

=head2 NAME

Set::Infinite::Offset - Offsets a set :)

=head2 SYNOPSIS

	$a->offset ( value => [1,2] );

=head2 TODO

Use hash to select "mode" funtion.

=head2 CHANGES

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
	years => 	sub { carp __PACKAGE__ . " years not implemented"; return @_ },
	months => 	sub { carp __PACKAGE__ . " months not implemented"; return @_ },
	days => 	sub { $_[0] * $day_size },
	weeks =>	sub { 7 * $_[0] * $day_size },
	hours =>	sub { $_[0] * $hour_size },
	minutes =>	sub { $_[0] * $minute_size },
	seconds =>	sub { $_[0] * $second_size },
	one =>  	sub { $_[0] },
);

sub init {
	my $self = shift;
	#print " [offset:init] ";
	unless (ref($self->{value}) eq 'ARRAY') {
		#print " [value:scalar:", $self->{value} ,"]\n";
		$self->{value} = [0 + $self->{value}, 0 + $self->{value}];
	}
	# print " [ofs:value:", join (",", @{$self->{value} }),"]\n";
	$self->{mode}   = 'offset' unless $self->{mode};
	$self->{unit}   = 'one' unless $self->{unit};

	return $self;
}

sub FETCH {
	my ($self, $x) = @_;
	my ($tmp, $this, $next);

	# sub func_begin {
	# my ($self, $x) = @_;
	# tmp pointer because perl gets confused with $self->{parent}->{list}->[$x]->{a}
	my $interval = $self->{parent}->{list}->[$x];

	my $open_begin = $interval->{open_begin};
	my $open_end = $interval->{open_end};

	if ( Set::Infinite::Element_Inf::is_null($interval->{a}) ) {
		return Set::Infinite::Simple->simple_null ;
	}

	# print " [parent:", $interval,"]\n";
	# print " [parent:", $interval->{a},"]\n";
	# print " [mode:",$self->{mode},"]\n";
	# print " [value:", join (",", @{$self->{value} }),"]\n";

	my $value0 = &{ $subs{$self->{unit}} } ($self->{value}->[0]);
	my $value1 = &{ $subs{$self->{unit}} } ($self->{value}->[1]);

	if ($self->{mode} eq 'begin') {
			$this =  $interval->{a} + $value0 ;
			$next =  $interval->{a} + $value1 ;
	}
	elsif ($self->{mode} eq 'end') {
			$this =  $interval->{b} + $value0 ;
			$next =  $interval->{b} + $value1 ;
	}
	else {     
			# $self->{mode} eq 'offset') 
			$this =  $interval->{a} + $value0 ;
			$next =  $interval->{b} + $value1 ;
	}

	if ($this > $next) { 
		# print " [ofs:out($this,$next)] ";
		return Set::Infinite::Simple->simple_null;
	}

	# print " [ofs($this,$next)] ";

	return Set::Infinite::Simple->
		fastnew($this,$next)->
		open_end($open_end)->
		open_begin($open_begin);
}


1;
