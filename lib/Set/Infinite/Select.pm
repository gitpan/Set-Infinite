package Set::Infinite::Select;
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;
use Set::Infinite::Function;
use Set::Infinite::Element_Inf;
require Exporter;
our @EXPORT = qw();
our @EXPORT_OK = qw();
our @ISA = qw(Set::Infinite::Function); 

=head2 NAME

Set::Infinite::Select - sub-arrays of subsets

=head2 SYNOPSIS

	Internal use by Set::Infinite.

	->select ( freq => 10, count => 3, by => [ 4, 5, -1 ] )

	See eg/ical.pl and t/*

=head2 CHANGES

	- option 'strict' will return intersection($a,select). Default: none.

0.03
	negative indexes count backwards from end

0.02
	uses "Function.pm"
	returns a much less sparse list than version 0.01

=head2 AUTHOR

Flavio Soibelmann Glock - fglock@pucrs.br

=cut

sub init {
	my $self = shift;
	my $parent_size = $#{ $self->{parent}->{list} };
	if ($parent_size < 0) {
		$self->{size} = -1;
		return $self;
	}

	$self->{freq} = 1 + $parent_size unless $self->{freq};
	$self->{by} = [0] unless $self->{by};
	$self->{interval} = 1 unless $self->{interval};
	$self->{count} = int (0.5 + ($parent_size / ($self->{freq} * $self->{interval})) ) unless $self->{count};
	# estimate size
	$self->{size}  = (1 + $#{$self->{by}}) * $self->{count};

	$self->{size} = $parent_size if ($self->{size} > $parent_size);

	# print " [select: size=$self->{size} freq=$self->{freq} parent_size=$parent_size by=",join(",",@{$self->{by}}),"]\n";

	$self->{cache} = {};   # empty hash
	$self->{strict} = 0 unless $self->{strict};
	return $self;
}

sub FETCHSIZE {
	my ($self) = shift;
	return $self->{size}; 
}

sub FETCH {
	my ($self) = shift;
	my $index = shift;
	if ($index and (exists $self->{cache}->{$index})) {
		# print "*";
		return $self->{cache}->{$index};
	}
	my $this;
	# my $return;
	my $dummy;
	my $tmp;
	
	my $parent_list = $self->{parent}->{list};
	my $parent_size = $#{$parent_list};
	my $by_max      = $#{$self->{by}};
	my $by = $self->{by}->[ $index % (1 + $by_max) ];

	if ($by >= 0) {
		# positive indexes
		$this =	$by +
			$self->{interval} * $self->{freq} * int ( $index / (1 + $by_max) ) ;
	}
	else {
		# negative indexes -- count backwards from end
		$this =	$self->{interval} * $self->{freq} * int ( 1 + $index / (1 + $by_max) ) ;
		# print " [1] $this]\n";
		# handle end overflow (the subset is smaller than freq)
		if ($this > ($parent_size + 1 ) ) {
			# print " [select:ovf $this < ", $parent_list->[$this-2], " & ", $parent_list->[$this-1], " & ", $parent_list->[$this], " > ";
			$this = $parent_size;
			# print "--> $this $parent_size \n";
			$dummy = $parent_list->[$this-1];  # instantiate or get a "Can't use an undefined value as a HASH reference"
			if (Set::Infinite::Element_Inf::is_null($parent_list->[$this-1]->{a})) {
				$this-- if $this;  # handle 30-day month
				# may not need this:
				# print "--> $this $parent_size \n";
				$dummy = $parent_list->[$this-1];  # instantiate
				if (Set::Infinite::Element_Inf::is_null($parent_list->[$this-1]->{a})) {
					$this-- if $this;  # handle 29-day month
				}
			}
			# print " [2] $this]\n";
		}
		$this += $by;
	}

	# positive-only indexes:
	# $this =	$self->{by}->[ $index % (1 + $#{$self->{by}}) ] +
	#	$self->{interval} * $self->{freq} * int ( $index / (1 + $#{$self->{by}}) ) ; 

	# print " [GET-INDEX:$index = $this] \n";

	if (($this > $parent_size) or ($this < 0)) { 
		# print " [select:out $this] \n";
		$self->{cache}->{$index} = Set::Infinite::Simple->simple_null;
		return $self->{cache}->{$index};
	}

	$tmp = $parent_list->[$this];
	if ($self->{strict} and not ($self->{strict}->intersects($tmp))) {
		$tmp = Set::Infinite::Simple->simple_null;
	}

	$self->{cache}->{$index} = $tmp;
	# print " [select: $self->{cache}->{$index}] \n";
	return $tmp;

	# $return = $parent_list->[$this];
	# print " [select: $return] \n";
	# return $return;

	# if (ref($return)) {
	#	return $return;
	# }
	# print " [select:not a ref: $return] \n";
	# return $return;
}


1;
