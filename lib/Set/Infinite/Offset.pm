package Set::Infinite::Offset;
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;
require Exporter;
use Set::Infinite::Function;
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

sub init {
	my $self = shift;
	#print " [offset:init] ";
	unless (ref($self->{value}) eq 'ARRAY') {
		#print " [value:scalar:", $self->{value} ,"]\n";
		$self->{value} = [0 + $self->{value}, 0 + $self->{value}];
	}
	#print " [value:", join (",", @{$self->{value} }),"]\n";
	$self->{mode}   = 'offset' unless $self->{mode};
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
		$this = $next = $interval->{a} ;
	}
	# print " [parent:", $interval->{a},"]\n";
	#print " [mode:",$self->{mode},"]\n";
	#print " [value:", join (",", @{$self->{value} }),"]\n";
	elsif ($self->{mode} eq 'begin') {
		$this =  $interval->{a} + $self->{value}->[0] ;
		$next =  $interval->{a} + $self->{value}->[1] ;
	}
	elsif ($self->{mode} eq 'end') {
		$this =  $interval->{b} + $self->{value}->[0] ;
		$next =  $interval->{b} + $self->{value}->[1] ;
	}
	else {     
		# $self->{mode} eq 'offset') 
		$this =  $interval->{a} + $self->{value}->[0] ;
		$next =  $interval->{b} + $self->{value}->[1] ;
	}

	if ($this > $next) { 
		return Set::Infinite::Simple->simple_null;
	}
	return Set::Infinite::Simple->
		fastnew($this,$next)->
		open_end($open_end)->
		open_begin($open_begin);
}


1;
