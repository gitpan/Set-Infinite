package Set::Infinite::Function;
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;

require Exporter;
our $VERSION = "0.01";
our @EXPORT = qw();
our @EXPORT_OK = qw();

=head2 NAME

Set::Infinite::Function - virtual method; apply a function to an infinite set

=head2 SYNOPSIS

	# Derived modules should override: init, FETCHSIZE, func_begin, func_end, FETCH.
	package new_function;
	use Set::Infinite::Function;
	our @ISA = qw(Set::Infinite::Function);

	# some methods ...

	# some hack to register the function with Set::Infinite ...

	package main;
	print $a->new_function(%parameters);

Default function is f(x) = x;

=head2 TODO

Derived functions should register themselves automatically with Set::Infinite

Apply this module to Quantize.pm, Select.pm, Select.pm.

=head2 CHANGES

version 0.01 - module started

=head2 AUTHOR

Flavio Soibelmann Glock - fglock@pucrs.br

=cut

sub init {
	my ($self) = @_;
	# do some initialization here
	return ($self);
}

# func_begin maps a value "x" to the subset-begin function
# second return parameter means "open" or "closed-begin"
sub func_begin {
	my ($self, $x) = @_;
	my $interval = $self->{parent}->{list}->[$x];
	my $open = $interval->is_open_begin;
	my $f    = $interval->{a};
	return ($f, $open);
}

# func_end maps a value "x" to the subset-end function
# second return parameter means "open" or "closed-end"
sub func_end {
	my ($self, $x) = @_;
	my $interval = $self->{parent}->{list}->[$x];
	my $open = $interval->is_open_end;
	my $f    = $interval->{b};
	return ($f, $open);
}

sub FETCH {
	my ($self, $x) = @_;
	my ($tmp, $this, $open_begin, $next, $open_end);
	($this, $open_begin) = $self->func_begin ($x);
	($next, $open_end)   = $self->func_end   ($x);
	return Set::Infinite::Simple->
		new($this,$next)->
		open_end($open_end)->
		open_begin($open_begin);
}

sub FETCHSIZE {
	my ($self) = shift;
	# print " [Function::FETCHSIZE] ", @{ $self->{parent}->{list} }, "\n";
	return 1 + $#{ $self->{parent}->{list} };
}

sub TIEARRAY {
	my ($class, $parent, %rules) = @_;
	my ($self) = bless \%rules, $class;
	$self->{parent} = $parent;  
	$self->init;
	return $self;
}

sub STORESIZE {	return @_; }

sub CLEAR { my ($self) = shift; return @_; }

sub EXTEND { return @_; }

sub STORE { return @_; }

sub DESTROY { }

1;
