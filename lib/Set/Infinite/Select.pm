package Set::Infinite::Select;
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;
use Set::Infinite::Function;
require Exporter;
our $VERSION = "0.02";
our @EXPORT = qw();
our @EXPORT_OK = qw();
our @ISA = qw(Set::Infinite::Function); 

=head2 NAME

Set::Infinite::Select - sub-arrays of subsets

=head2 USAGE

(some reefknot related examples here...)

=head2 TODO

Some kind of specialized "foreach" inside Quantizer.pm, that returns a
less sparse list for sparse sets.

=head2 CHANGES

0.02
	uses "Function.pm"
	returns a much less sparse list than version 0.01

=head2 AUTHOR

Flavio Soibelmann Glock - fglock@pucrs.br

=cut

sub init {
	my $self = shift;
	my $parent_size = $#{ $self->{parent}->{list} };
	$self->{freq} = 1 unless $self->{freq};
	$self->{by} = [0] unless $self->{by};
	$self->{interval} = 1 unless $self->{interval};
	$self->{count} = int (0.5 + ($parent_size / ($self->{freq} * $self->{interval})) ) unless $self->{count};
	# estimate size
	$self->{size}  = (1 + $#{$self->{by}}) * $self->{count};
	# ??? core dump! ??? $self->{size} = $parent_size if ($self->{size} > $parent_size);
	return $self;
}

sub FETCHSIZE {
	my ($self) = shift;
	return $self->{size}; 
}

sub FETCH {
	my ($self) = shift;
	my $index = shift;
	my $this = 	$self->{by}->[ $index % (1 + $#{$self->{by}}) ] +
		$self->{interval} * $self->{freq} * int ( $index / (1 + $#{$self->{by}}) ) ; 
	# print " [GET-INDEX:$index = $this] ";
	return $self->{parent}->{list}->[$this];
}


1;
