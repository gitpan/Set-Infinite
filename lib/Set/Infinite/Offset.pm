package Set::Infinite::Offset;

# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;

require Exporter;
our $VERSION = "0.01";

my $package = 'Set::Infinite::Offset';
our @EXPORT = qw();
our @EXPORT_OK = qw();
# our @ISA = qw(Set::Infinite); 

use Set::Infinite qw(type);


=head2 NAME

Set::Infinite::Offset - Offsets subsets

=head2 USAGE

This module is just starting.

=head2 TODO

=head2 DONE

=cut

sub new {
	my ($class, $parent, %rules) = @_;
	my ($self) = bless \%rules, $class;
	$self->{parent} = $parent;
	$self->{size}   = 1 + $#{ $parent->{list} };
	# print " [OFFSET:VALUE:", $self->{value} ,"] ";
	unless (ref($self->{value}) eq 'ARRAY') {
		$self->{value} = [0 + $self->{value}, 0 + $self->{value}];
	}
	# $self->{value}  = [0,0] unless $self->{value};
	# print " [OFFSET:VALUE:", join(",", @{$self->{value}}),"] ";
	$self->{mode}   = 'offset' unless $self->{mode};
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
	# print " [fetchsize ", $self->{size},"] ";
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

	# print " [fetch:$index=$tmp + $self->{value}] ";
	my $tmp = $self->{parent}->{list}->[$index];
	return Set::Infinite::Simple->simple_null unless $tmp;

	# print " [fetch:$index=$tmp + ",@{$self->{value}},"] ";
	# print " [fetch: ", $tmp->{a} , " + 1 = ", $tmp->{a}+1 ,"] ";
	my $subset = Set::Infinite::Simple->new($tmp);

	if ($self->{mode} eq 'begin') {
		($subset->{a}, $subset->{b}) = ($tmp->{a} + $self->{value}->[0], $tmp->{a} + $self->{value}->[1]);
	}
	elsif ($self->{mode} eq 'end') {
		($subset->{a}, $subset->{b}) = ($tmp->{b} + $self->{value}->[0], $tmp->{b} + $self->{value}->[1]);
	}
	else {     
		# $self->{mode} eq 'offset') 
		($subset->{a}, $subset->{b}) = ($tmp->{a} + $self->{value}->[0], $tmp->{b} + $self->{value}->[1]);
	}
	if ($subset->{a} > $subset->{b}) { 
		return Set::Infinite::Simple->simple_null;
	}
	return $subset;
}

sub STORE {
	return @_;
}

sub DESTROY {
}



1;
