package Set::Infinite::Select;

# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;

require Exporter;
our $VERSION = "0.01";

my $package = 'Set::Infinite::Select';
our @EXPORT = qw();
our @EXPORT_OK = qw();
# our @ISA = qw(Set::Infinite); 

use Set::Infinite qw(type);


=head2 NAME

Set::Infinite::Select - sub-arrays of subsets

=head2 USAGE

This module is just starting.

=head2 TODO

=head2 DONE

=cut

sub get_index {
	my ($self) = shift;
	my ($index) = shift;

	#print " [GET-INDEX:$index] ";
	my $modulo = $index % $self->{freq};
	my $interval = int($index / $self->{freq}) % $self->{interval};
	#print " [GET-INDEX: modulo=$modulo, interval=$interval] ";
	if ($interval != 0) {
		#print " [OUT:INTERVAL=$interval] ";
		return -1;
	}
	unless ($self->{by_as_hash}->{$modulo}) {
		#print " [OUT:BY=$modulo] ";
		return -1;
	}
	return $index;
}

sub new {
	my ($class, $parent, %rules) = @_;
	# print " [ SEL:NEW:rules=",join(",",%rules),"] ";
	my ($self) = bless \%rules, $class;
	$self->{parent} = $parent;

	# print " [ SEL:NEW:", join(", ", @_), "]\n";
	# my $parent = shift;
	# my %rrule = @_;    
	# my %rrule = %$rrule;
	# print " [ SEL:NEW:rrule=",join(",",%rules),"] ";

	# my %rrule = \$rrule;
	# my @parent = @{ $parent->{list} };
	my $parent_size = $#{ $parent->{list} };
	# print " [ SEL:NEW-1:parent=",@parent," size=$parent_size] ";
	# print " [ SEL:NEW-2:parent=",join(",",@{$self->{parent}}),"] ";
	# print " [ SEL:NEW:rrule=",join(",",%rrule),"] ";

	# foreach (keys %rrule) {
	#	$self->{$_} = $rrule{$_};
	# }
	$self->{freq} = 1 unless $self->{freq};
	$self->{by} = [0] unless $self->{by};
	$self->{interval} = 1 unless $self->{interval};
	$self->{count} = int (0.5 + ($parent_size / ($self->{freq} * $self->{interval})) ) unless $self->{count};

	# make "by" hash
	foreach (@{$self->{by}}) {
		# print " [BY:$_] ";
		$self->{by_as_hash}->{$_} = 1;
	}

	# estimate size
	$self->{size}  = $self->{freq} * $self->{count} * $self->{interval};
	# ??? core dump! ??? $self->{size} = $parent_size if ($self->{size} > $parent_size);
	# print " [ SELECT: ", join(",", %$self), " ] ";
	# print " [ SELECT: "; foreach('parent','freq','by','count'){print ",$_=", $self->{$_}; }; print " ] ";
	# print " [ SELECT: "; foreach(keys %$self){print ",$_=", $self->{$_}; }; print " ] ";
	# exit(0);

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
	return Set::Infinite::Simple->simple_null if $this < 0;

	my $tmp = $self->{parent}->{list}->[$this];
	return $tmp;
}

sub STORE {
	return @_;
}

sub DESTROY {
}



1;
