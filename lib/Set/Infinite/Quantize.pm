package Set::Infinite::Quantize;

# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

# CHANGES
# 0.21 - change quantize(1) -> quantize( quant => 1 )

use strict;
use warnings;

require Exporter;
our $VERSION = "0.21";

my $package = 'Set::Infinite::Quantize';
our @EXPORT = qw();
our @EXPORT_OK = qw();

use Set::Infinite qw(type);

=head2 NAME

Set::Infinite::Quantize - arrays of subsets

=head2 USAGE

	Please see Set::Infinite

=head2 TODO

	returns '' when an index does not match. alternatives?

	Quantization function? (eg: months)
	Quantization base? (eg: time/years or hours)

=head2 DONE

	make `foreach' work (find out `$#' in advance)
	make it work on the `set' instead of `span' (let user choose)

=cut

sub get_index {
	my ($self) = shift;
	my ($index) = shift;
	# my $rest = $self->{begin} % $self->{quant};
	my $tmp = int($self->{begin} / $self->{quant});
	return ($tmp + $index) * $self->{quant};
}

sub new {
	# print " [ QUANT:NEW:", join(", ", @_), "]\n";
	my ($class, $parent, %rules);
	if ($#_ == 2) {
		# old syntax (non-hash)
		($class, $parent, $rules{quant}) = @_;
	}
	else {
		($class, $parent, %rules) = @_;
	}
	my ($self) = bless \%rules, $class;

	# my ($self) = bless {}, shift;
	$self->{quant} = 1 unless $self->{quant};
	# my $tmp = Set::Infinite->new(@_); 
	$self->{parent}   = $parent;
	# print " [ QUANT:parent=", $self->{parent}, " ", ref($self->{parent}), "]\n";
	$self->{begin} = $self->{parent}->min;
	$self->{end}   = $self->{parent}->max;
	# print " [ QUANT ]\n";
	# estimate size
	$self->{size}  = 2 + ($self->{end} - $self->{begin}) / $self->{quant};
	# print " [end:",$self->{end},"]";
	# print " [size:",$self->{size},"]";
	# print " [get_index:",$self->get_index($self->{size}),"]";
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
	my $this = get_index($self, $index);
	my $next = get_index($self, $index + 1);
	# >  is for close-ended
	# >= is for open-ended
	# if ($this >= $self->{end}) {
	#	$self->{size} = $index if $self->{size} > $index;
	#	return '';
	# }
	my $tmp = Set::Infinite::Simple->new($this,$next)->open_end(1);
	return $tmp if $self->{parent}->intersects($tmp);
	return Set::Infinite::Simple->simple_null;
}

sub STORE {
	return @_;
}

sub DESTROY {
}


1;
