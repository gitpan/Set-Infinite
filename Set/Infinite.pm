#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

Set::Infinite - makes sets of intervals

=head1 SYNOPSIS

	use Set::Infinite;

	$a = Set::Infinite->new(1,2);
	print $a->union(5,6);

=head1 DESCRIPTION

Set::Infinite is a Set Theory module for infinite sets. 

It works on strings, reals or integers.
You can provide your own objects or let it make them for you
using the `type'.

It works very well on dates, providing schedule checks (intersections)
and unions.

=head1 USAGE

	$a = Set::Infinite->new();
	$a = Set::Infinite->new(1);
	$a = Set::Infinite->new(1,2);
	$a = Set::Infinite->new($b);
	$a = Set::Infinite->new([1], [1,2], [$b]);

Mode functions:	

	$a->real;

	$a->integer;

Logic functions:

	$logic = $a->intersects($b);

	$logic = $a->contains($b);

	$logic = $a->is_null;

Sets functions:

	$i = $a->union($b);	

	$i = $a->intersection($b);

	$i = $a->complement;
	$i = $a->complement($b);

	$i = $a->span;   

		result is INTERVAL, (min .. max)

	$a->add($b);   

		This is a short for:

		$a = $a->union($b);

Scalar functions:

	$i = $a->min;

	$i = $a->max;

	$i = $a->size;  

Perl functions:

	@b = sort @a;

	print $a;

Global functions:

	separators(@i)

		chooses the interval separators. 

		default are [ ] ( ) '..' ','.

	null($i)		

		chooses 'null' name. default is 'null'

	infinite($i)

		chooses 'infinite' name. default is 'inf'

	infinite

		returns an 'infinite' number.

	minus_infinite

		returns '-infinite' number.

	null

		returns 'null'.

	type($i)

		chooses an object data type. 

		default is none (a normal perl SCALAR).

		examples: 

		type('Math::BigFloat');
		type('Math::BigInt');
		type('Set::Infinite::Date');
		Note: Set::Infinite::Date requires HTTP:Date and Time::Local

	tolerance(0)	defaults to real sets (default)
	tolerance(1)	defaults to integer sets

	real			defaults to real sets (default)

	integer			defaults to integer sets

Internal functions:

	$a->cleanup;

=head1 CAVEATS

	$a = Set::Infinite->new(1,2,3,4);
		Invalid: ",3,4" will be ignored. Use [1,2],[3,4] instead.

	$a = Set::Infinite->new(1..2);
		Invalid: "1..2" will be ignored. Use [1,2] instead.

=head1 TODO

	Make a private mode for `type'

	Make a global mode for `open_*' 

	Create a `dirty' variable so it knows when to cleanup.

	Find out how to accelerate `type' mode.

=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

require Exporter;
package Set::Infinite;
$VERSION = "0.009";

my $package        = 'Set::Infinite';
@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw( 
	infinite 
	minus_infinite 
	separators 
	null
	type
	tolerance 
	integer 
	real
);

use strict;
use Set::Infinite::Simple qw(
	infinite minus_infinite separators null type
	tolerance integer real
);

use overload
	'<=>' => \&spaceship,
	'cmp' => \&cmp,
	qw("" as_string);

sub is_null {
	my $self = shift;
	return ("$self" eq null) ? 1 : 0;
}

sub intersects {
	my $self = shift;
	my @param = @_;

	my $b = Set::Infinite->new(@param); 
	my ($ia, $ib);
	foreach $ib (0 .. $#{  @{ $b->{list} } }) {
		foreach $ia (0 .. $#{  @{ $self->{list} } }) {
			return 1 if $self->{list}[$ia]->intersects($b->{list}[$ib]);
		}
	}
	return 0;	
}

sub intersection {
	my $self = shift;
	my @param = @_;

	my $tmp;
	my $b = Set::Infinite->new(@param);
	my ($ia, $ib);
	my $intersection = Set::Infinite->new();
	foreach $ib (0 .. $#{  @{ $b->{list} } }) {
		foreach $ia (0 .. $#{  @{ $self->{list} } }) {
			$tmp = $self->{list}[$ia]->intersection($b->{list}[$ib]);
			$intersection->add($tmp) if defined($tmp); # ->{a},$tmp->{b}) if $tmp;
		}
	}
	return $intersection;	
}

sub complement {
	my $self = shift;

	# do we have a parameter?

	if (@_) {
		my $a = Set::Infinite->new(@_);
		$a->tolerance($self->{tolerance});
		$a = $a->complement;
		return $self->intersection($a);
	}

	my ($ia);
	my $tmp;

	if (($#{$self->{list}} < 0) or (not defined ($self->{list}))) {
		return Set::Infinite->new(minus_infinite, infinite);
	}

	my $complement = Set::Infinite->new();
	my @tmp = $self->{list}[0]->complement;
	foreach(@tmp) {
		$complement->add($_); 
	}
	
	foreach $ia (1 .. $#{  @{ $self->{list} } }) {
			@tmp = $self->{list}[$ia]->complement;
			$tmp = Set::Infinite->new();
			foreach(@tmp) { $tmp->add($_); }

			$complement = $complement->intersection($tmp); # if $tmp;
	}

	return $complement;	
}

sub union {
	my $self = shift;
	my $b;
	$b = Set::Infinite->new(@_);  # unless ref($b) eq $package;

	my $union = Set::Infinite->new($self);
	my ($ia, $ib);
	B: foreach $ib (0 .. $#{  @{ $b->{list} } }) {
		foreach $ia (0 .. $#{  @{ $union->{list} } }) {
			my @tmp = $union->{list}[$ia]->union($b->{list}[$ib]);
			if ($#tmp == 0) {
				$union->{list}[$ia] = $tmp[0];
				next B;
			}
		}
		$union->add($b->{list}[$ib]);
	}
	return $union;	
}

sub contains {
	my $self = shift;

	# do we have a parameter?
	return 1 unless @_;

	my $a = Set::Infinite->new(@_);
	$a->tolerance($self->{tolerance});
	return ($self->union($a) == $self) ? 1 : 0;
}

sub add {
	my ($self) = shift;
	my @param = @_;

LOOP:
		my $tmp = shift @param;
		return $self unless defined($tmp);

		# is it an array?
		if (ref($tmp) eq 'ARRAY') {
			my @tmp = @{$tmp};

			$tmp = Set::Infinite->new(@tmp) ;
			foreach (@{$tmp->{list}}) {
				push @{ $self->{list} }, Set::Infinite::Simple->new($_) ;
			}

			goto LOOP;
		}
		# does it have a "{list}"?
		elsif ((ref(\$tmp) eq 'REF') and defined ($tmp->{list})) {
			foreach (@{$tmp->{list}}) {
				push @{ $self->{list} }, Set::Infinite::Simple->new($_) ;
			}
		}
		# does it have a "{a},{b}"?
		elsif ((ref(\$tmp) eq 'REF') and defined ($tmp->{a})) {
			push @{ $self->{list} }, Set::Infinite::Simple->new($tmp) ;
		}
		else {
			$tmp = Set::Infinite::Simple->new($tmp,@param);
			$tmp->tolerance($self->{tolerance});
			push @{ $self->{list} }, $tmp;
		}

	return $self;
}

sub min { 
	my ($self) = shift;
	my $tmp;
	my $min = $self->{list}[0]->min if defined($self->{list}[0]);
	foreach(1 .. $#{  @{ $self->{list} } }) {
		$tmp = $self->{list}[$_]->min;
		$min = $tmp if $tmp < $min;
	}
	return $min; 
};

sub max { 
	my ($self) = shift;
	my $tmp;
	my $max = $self->{list}[0]->max if defined($self->{list}[0]);
	foreach(1 .. $#{  @{ $self->{list} } }) {
		$tmp = $self->{list}[$_]->max;
		$max = $tmp if $tmp > $max;
	}
	return $max; 
};

sub size { 
	my ($self) = shift;
	my $tmp;
	$self->cleanup;
	my $size = $self->{list}[0]->size;
	foreach(1 .. $#{ @{ $self->{list} } }) {
		$tmp = $self->{list}[$_]->size;
		$size += $tmp;
	}
	return $size; 
};

sub span { 
	my ($self) = shift;
	return Set::Infinite->new($self->min, $self->max);
};

sub spaceship {
	my ($tmp1, $tmp2, $inverted) = @_;
	bless $tmp1, 'Set::Infinite';
	my $tmp2 = Set::Infinite->new($tmp2);

	if ($inverted) {
		($tmp2, $tmp1) = ($tmp1, $tmp2);
	}

	#return 1 if ($tmp2 eq '');
	#return 0  unless defined($tmp1->{list}) and defined($tmp2->{list});
	#return -1 unless defined($tmp1->{list});

	return $tmp1->min  <=> $tmp2->min  if ($tmp1->min  != $tmp2->min);
	return $tmp1->size <=> $tmp2->size if ($tmp1->size != $tmp2->size);
	return $#{ @{ $tmp1->{list} } } <=> $#{ @{ $tmp2->{list} } } if $#{ @{ $tmp1->{list} } } != $#{ @{ $tmp2->{list} } };
	foreach(0 .. $#{  @{ $tmp1->{list} } }) {
		my $this  = $tmp1->{list}[$_];
		my $other = $tmp2->{list}[$_];
		return $this <=> $other if $this != $other;
	}
	return 0;
}

sub cmp {
	return spaceship @_;
}

sub cleanup {
	my ($self) = shift;

	# $self->tolerance($self->{tolerance});	# ???

	@{ $self->{list} } = sort @{ $self->{list} };

	$_ = 1;
	while ( $_ <= $#{  @{ $self->{list} } } ) {
		my @tmp = $self->{list}[$_]->union($self->{list}[$_ - 1]);
		if ($#tmp == 0) {
			$self->{list}[$_ - 1] = $tmp[0];
			splice (@{$self->{list}}, $_, 1);
		} 
		else {
			$_ ++;
		}
	}
	return $self;
}

sub tolerance {
	my $class = shift;
	my $tmp = shift;
	if (ref($class) eq 'Set::Infinite') {
		my ($self) = $class;
		if ($tmp ne '') {
			$self->{tolerance} = $tmp;
			foreach (0 .. $#{  @{ $self->{list} } }) {
				$self->{list}[$_]->tolerance($self->{tolerance});
			}
		}
		return $self;
	}
	return Set::Infinite::Simple->tolerance($tmp);
}

sub integer {
	if (@_) {
		my ($self) = shift;
		$self->tolerance (1);
		return $self;
	}
	return Set::Infinite::Simple->tolerance(1);
}

sub real {
	if (@_) {
		my ($self) = shift;
		$self->tolerance (0);
		return $self;
	}
	return Set::Infinite::Simple->tolerance(0);
}

sub new {
	my ($self) = bless {}, shift;
	@{ $self->{list} } = ();
	$self->tolerance( Set::Infinite::Simple->tolerance );
	$self->add(@_);
	return $self;
}

sub as_string {
	my ($self) = shift;
	$self->cleanup;
	return null unless $#{$self->{list}} >= 0;
	return join(separators(5), @{ $self->{list} } );
}

# TIE

sub TIEARRAY {
	my $class = shift;
	my $self = $class->new(@_);
	$self->{type} = 2;
	return $self;
}

sub FETCHSIZE {
	my ($self) = shift;
	return 1 + $#{$self->{list}}; 
}

sub STORESIZE {
	return @_;
}

sub CLEAR {
	my ($self) = shift;
	undef $self->{list};
}

sub EXTEND {
	return @_;
}

sub TIESCALAR {
	my $class = shift;
	my $self = $class->new(@_);
	return $self;
}

sub FETCH {
	my ($self) = shift;
	if (@_) {
		# we have an index, so we are an array
		my $index = shift;
		return $self->{list}[$index];
	}
	return $self->as_string;
}

sub STORE {
	my ($self) = shift;
	my $data = shift;
	if (($self->{type} == 2) and @_) {
		# we have a valid index and data, so we are an array
		my $index = $data;
		$data = shift;
		$self->{list}[$index] = $data if $index == 0;
		$self->cleanup;
		return ($data, @_);
	}
	$self = new($data, @_);
	return @_;
}

sub DESTROY {
}

1;
