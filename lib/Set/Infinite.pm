package Set::Infinite;

# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

require 5.005_62;
use strict;
use warnings;

require Exporter;
# use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

# This allows declaration	use Set::Infinite ':all';

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } , qw(type inf) );

our @EXPORT = qw(
	
);
our $VERSION = '0.16';


# Preloaded methods go here.

my $package        = 'Set::Infinite';

#@EXPORT_OK = qw( 
#	infinite 
#	minus_infinite 
#	separators 
#	null
#	type
#	tolerance 
#	integer 
#	real
#);

use Set::Infinite::Simple qw(
	infinite minus_infinite separators null type quantizer inf
); 
# ... tolerance integer real

sub inf();
sub infinite();
sub minus_infinite();
sub null();


use overload
	'<=>' => \&spaceship,
	'cmp' => \&cmp,
	qw("" as_string);

sub quantize {
	my $self = shift;
	my (@a);
	# my $array_ref = shift;
	my $tmp = quantizer;
	# print " [INF:QUANT $tmp,",@_,",$self]\n";
	tie @a, $tmp, @_, $self;
	return @a;
}

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
		#print " [INF:ADD:",ref($tmp),"=$tmp]\n";
		if (ref($tmp) eq 'ARRAY') {
			my @tmp = @{$tmp};

			# print " INF:ARRAY:",@tmp," ";

			# Allows arrays of arrays
			$tmp = Set::Infinite->new(@tmp) ;
			foreach (@{$tmp->{list}}) {
				push @{ $self->{list} }, Set::Infinite::Simple->new($_) ;
			}


			#$tmp = Set::Infinite::Simple->new(@tmp) ;
			#push @{ $self->{list} }, $tmp ;

			goto LOOP;
		}
		# does it have a "{list}"?
		elsif ((ref(\$tmp) eq 'REF')) {
			if (($tmp->isa(__PACKAGE__))) {   # and defined ($tmp->{list})) {
				foreach (@{$tmp->{list}}) {
					push @{ $self->{list} }, Set::Infinite::Simple->new($_) ;
				}
				goto LOOP;
			}
			# does it have a "{a},{b}"?
			elsif (($tmp->isa("Set::Infinite::Simple")) ) {  # and (not $tmp->is_null)) {
				push @{ $self->{list} }, Set::Infinite::Simple->new($tmp) ;
				goto LOOP;
			}
		}
		# else {
			my $tmp2 = shift @param;
			$tmp = Set::Infinite::Simple->new($tmp,$tmp2);
			$tmp->tolerance($self->{tolerance});
			push @{ $self->{list} }, $tmp;

			goto LOOP;
		# }

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
	$tmp2 = Set::Infinite->new($tmp2);

	if ($inverted) {
		($tmp2, $tmp1) = ($tmp1, $tmp2);
	}

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
	# print " FETCHSIZE \n";
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
		# print " FETCH \n";
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


# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

Set::Infinite - Perl extension for Sets of intervals

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

=head2 EXPORT

None by default.

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

	quantize($i)

		returns a tied reference to an array of sets.
		Each array have size $i.
		In some cases, one or more array members may be empty.

		Example: 

			$a = Set::Infinite->new([1,3]);
			print join (" ", $a->quantize(1) );

		Gives: 

			[1..2) [2..3) [3..4)

	type($i)

		chooses an object data type. 

		default is none (a normal perl SCALAR).

		examples: 

		type('Math::BigFloat');
		type('Math::BigInt');
		type('Set::Infinite::Date');
			See notes on Set::Infinite::Date below.

	tolerance(0)	defaults to real sets (default)
	tolerance(1)	defaults to integer sets

	real			defaults to real sets (default)

	integer			defaults to integer sets

Internal functions:

	$a->cleanup;

=head1 Notes on Set::Infinite::Date

Set::Infinite::Date is a Date "plugin" for sets.

It is invoked by:

	type('Set::Infinite::Date');

It requires HTTP:Date and Time::Local

It changes quantize function behaviour to accept time units:

	$a = Set::Infinite->new('2001-05-02', '2001-05-13');
	print "Weeks in $a: ", join (" ", $a->quantize('weeks', 1) );

	$a = Set::Infinite->new('09:30', '10:35');
	print "Quarters of hour in $a: ", join (" ", $a->quantize('minutes', 15) );

Units can be years, months, days, weeks, hours, minutes, or seconds.

max and min functions will show in date/time format, unless
they are used with `0 + '.

=head1 CAVEATS

	$a = Set::Infinite->new(10,1);
		Will be interpreted as [1..10]

	$a = Set::Infinite->new(1,2,3,4);
		Will be interpreted as [1..2],[3..4] instead of [1,2,3,4].
		You probably want ->new([1],[2],[3],[4]) instead,
		or maybe ->new(1,4) 

	$a = Set::Infinite->new(1..3);
		Will be interpreted as [1..2],3 instead of [1,2,3].
		You probably want ->new(1,3) instead.

=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut