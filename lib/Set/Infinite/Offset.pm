package Set::Infinite::Offset;
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;
require Exporter;
use Set::Infinite::Function;
use Set::Infinite::Arithmetic;
use Set::Infinite::Element_Inf qw(inf minus_inf);
use Carp;
use Time::Local;

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

	- use ./Arithmetic.pm

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

# return value = ($this, $next, $cmp)
our %_MODE = (
	circle => sub {
			my ($sub, $a, $b, $ia, $ib) = @_;
			if ($ia >= 0) {
				&{ $sub } ($a, $ia, $ib ) 
			}
			else {
				&{ $sub } ($b, $ia, $ib ) 
			}
	},
	begin => sub {
			my ($sub, $a, $b, $ia, $ib) = @_;
			&{ $sub } ($a, $ia, $ib ) ;
	},
	end => sub {
			my ($sub, $a, $b, $ia, $ib) = @_;
			&{ $sub } ($b, $ia, $ib ) ;
	},
	offset => sub {
			my ($sub, $a, $b, $ia, $ib) = @_;
			my ($this) =       &{ $sub } ($a, $ia, $ib ) ; 
			my ($tmp, $next) = &{ $sub } ($b, $ia, $ib ) ; 
			($this, $next, $this <=> $next); 
	}
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
	$self->{fixtype} = 1 unless exists $self->{fixtype};

	$self->{fetchsize} = $self->{parts} * (1 + $#{ $self->{parent}->{list} });
	$self->{cache} = ();
	$self->{sub} = $Set::Infinite::Arithmetic::subs_offset2{$self->{unit}};
	$self->{sub_mode} = $_MODE{$self->{mode}};
	$self->{parent_list} = $self->{parent}->{list};
	# print " UNIT: $self->{unit} SUB: $self->{sub}\n";

	return $self;
}

sub FETCHSIZE {
	my ($self) = shift;
	# print " [Offset::FETCHSIZE] ", $tmp, "\n";
	return $self->{fetchsize};
}

sub FETCH {
	my $self = shift;
	my $x = shift;
	# my $cache = $self->{cache}{$x};
	# return $cache if defined $cache;

	# tmp pointer because perl gets confused with $self->{parent}->{list}->[$x]->{a}
	my $interval = $self->{parent_list}[$x / $self->{parts}];
	my $ia = $interval->{a};

	# test if parent interval is null
	if ( (ref($ia) eq 'Set::Infinite::Element_Inf') and ( $$ia eq '' ) ) {
		return Set::Infinite::Simple->simple_null;
	}

	my ($cmp, $this, $next, $ib, $part, $open_begin, $open_end, $tmp);
	 $ib = $interval->{b};
	 $part = 2 * ($x % $self->{parts});
	 $open_begin = $interval->{open_begin};
	 $open_end = $interval->{open_end};

	($this, $next, $cmp) = &{ $self->{sub_mode} } 
			( $self->{sub}, $ia, $ib, $self->{value}->[$part], $self->{value}->[$part + 1] );

	if ($cmp > 0) { 
		return Set::Infinite::Simple->simple_null;
	}

	# print " [ofs($this,$next)] ";
	if ($cmp == 0) {
		$open_end = $open_begin;
		$this = $next;  #  make sure to use the same object from cache!
	}

	if ($self->{fixtype}) {
		# bless results into 'type' class
		my $class = ref($ia);
		# my $class = $Set::Infinite::type;

		# print " [ofs($this,$next) = $class] ";
		if (ref($this) ne $class) {
			$this = $class->new($this);
			$this->mode($ia->{mode}) if exists $ia->{mode};

			$next = $class->new($next);
			$next->mode($ia->{mode}) if exists $ia->{mode};
		}
	}

	$tmp = bless { a => $this , b => $next ,
                open_begin => $open_begin , open_end => $open_end }, 
		'Set::Infinite::Simple';
	if (($self->{strict} != 0) and not ($self->{strict}->intersects($tmp)) ) {
		return Set::Infinite::Simple->simple_null;
	}
	return $tmp;
}


1;

