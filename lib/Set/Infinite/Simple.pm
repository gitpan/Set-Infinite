#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

	Set::Infinite::Simple - an interval of 2 scalars

=head1 SYNOPSIS

	use Set::Infinite::Simple;

	$a = Set::Infinite::Simple->new(1,2);
	print $a->union(5,6);

=head1 DESCRIPTION

	This is a building block for Set::Infinite.
	Please use Set::Infinite instead.

=head1 USAGE

	$a = Set::Infinite::Simple->new();
	$a = Set::Infinite::Simple->new(1);
	$a = Set::Infinite::Simple->new(1,2);
	$a = Set::Infinite::Simple->new( a => 1, b => 2, tolerance => 1);	# integer interval
	$a = Set::Infinite::Simple->new(@b);	
	$a = Set::Infinite::Simple->new($b);	
		parameters can be:
		undef
		SCALAR => means an interval like (1,1)
		SCALAR,SCALAR
		ARRAY of SCALAR
		<removed!> HASH containing 'a'
		<removed!> HASH containing 'a' and 'b'
		Set::Infinite::Simple
	$a->real;
	$a->integer;

	$logic = $a->intersects($b);
	$logic = $a->contains($b);
	$logic = $a->is_null;

	$i = $a->union($b);	
		NOTE: union returns a list if result is ($a, $b)
	$i = $a->intersection($b);
	$i = $a->complement($b);
	$i = $a->complement;
	$i = $a->min;
	$i = $a->max;
	$i = $a->size;   # SCALAR, size of interval.
	$i = $a->span;   # INTERVAL, (min .. max); has no meaning here
	@b = sort @a;
	print $a;

	tie $a, 'Set::Infinite::Simple', 1,2;
		SCALAR behaves like a string "min .. max"
	tie @a, 'Set::Infinite::Simple', 1,2;
		$a[0], $a[1] are min and max
		POP, PUSH, SHIFT, UNSHIFT, SPLICE, DELETE, and EXISTS are not defined
	$i = tied(@a)->size;

	$a->open_end(1)		open-end: elements are < end
	$a->open_begin(1) 	open-start: elements are > begin
	$a->open_end(0)		close-end: elements are <= end
	$a->open_begin(0) 	close-start: elements are >= begin

Global:
	separators(@i)	chooses the separators. 
		default are [ ] ( ) '..' ','.

	null($i)		chooses 'null' name. default is 'null'
	infinite($i)	chooses 'infinite' name. default is 'inf'

	infinite		returns an 'infinite' number.
	minus_infinite	returns '- infinite' number.
	null			returns 'null'.

	type($i)	chooses an object data type. 
		default is none (a normal perl $something variable).
		example: 'Math::BigFloat', 'Math::BigInt'

	tolerance(0)	defaults to real sets (default)
	tolerance(1)	defaults to integer sets
	real			defaults to real sets (default)
	integer			defaults to integer sets

Internal:
	$a->tolerance(1);  works in integer mode
	$a->tolerance(0);  works in real mode (default)
	$a->add($b)  changes contents to $b

=head1 TODO

	formatted string input like '[0..1]'

=head1 SEE ALSO

	Other options for working with sets:

	Set::IntRange
		Works on integers only
		use Bit::Vector for storage

	Set::Window
		Works on integers only		

=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

require Exporter;

package Set::Infinite::Simple;
$VERSION = "0.12";

my $package        = 'Set::Infinite::Simple';
@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(
	infinite minus_infinite separators null type
	tolerance integer real quantizer
);

use strict;
use Carp;
use Set::Infinite::Element qw(infinite minus_infinite type null
	quantizer
);

use overload
	'<=>' => \&spaceship,
	'cmp' => \&cmp,
	qw("" as_string);

our @separators = (
	'[', ']',	# a closed interval 
	'(', ')',	# an open interval 
	'..',		# number separator
	','			# list separator
);

our $granularity = 0; # 1e-10; `real' tolerance
our $tolerance = $granularity;

sub quantize {
	my $self = shift;
	my (@a);
	tie @a, quantizer, @_, $self;
	return @a;
}

sub separators {
	return $separators[shift] if $#{@_} == 0;
	@separators = @_ if @_;
	return @separators;
}

sub open_end {
	my $self = shift;
	my $tmp = shift;
	$self->{open_end} = $tmp ? 1 : 0;
	return $self;	
}

sub open_begin {
	my $self = shift;
	my $tmp = shift;
	$self->{open_begin} = $tmp ? 1 : 0;
	return $self;	
}

sub is_null {
	my $self = shift;
	return (($self->{a} eq null) or ($self->{a} eq "")) ? 1 : 0;
}

sub intersects {
	my $self = shift;
	return $self->intersection(@_)->is_null ? 0 : 1;

	#my $tmp = $self->intersection(@_);
	#return 0 if ($tmp->{a} eq null) or ($tmp->{a} eq "");
	#return 1;	
}

sub intersection {
	my $tmp1 = shift;
	my $tmp2 = Set::Infinite::Simple->new(@_); 
	my ($i_beg, $i_end, $open_beg, $open_end);

	$i_beg 		= $tmp1->{a};
	$open_beg	= $tmp1->{open_begin};
	if ($tmp1->{a} == $tmp2->{a}) {
		$open_beg 	= ($tmp1->{open_begin} or $tmp2->{open_begin});
	}
	elsif ($tmp1->{a} < $tmp2->{a}) {
		$i_beg 		= $tmp2->{a};
		$open_beg 	= $tmp2->{open_begin};
	}

	$i_end 		= $tmp1->{b};
	$open_end	= $tmp1->{open_end};
	if ($tmp1->{b} == $tmp2->{b}) {
		$open_end 	= ($tmp1->{open_end} or $tmp2->{open_end});
	}
	elsif ($tmp1->{b} > $tmp2->{b}) {
		$i_end 		= $tmp2->{b};
		$open_end 	= $tmp2->{open_end};
	}
	return Set::Infinite::Simple->new() if ($i_beg == $i_end) and ($open_beg or $open_end);	
	return Set::Infinite::Simple->new() if ($i_beg > $i_end) or (not defined($i_beg)) or (not defined($i_end));	

	my $tmp = Set::Infinite::Simple->new($i_beg, $i_end);
	$tmp->open_begin(1) if $open_beg;
	$tmp->open_end(1) if $open_end;
	return $tmp;
}

sub complement {
	my $self = shift;

	# do we have a parameter?

	if (@_) {
		my $a = Set::Infinite::Simple->new(@_);
		$a->tolerance($self->{tolerance});
		$a = $a->complement;
		return $self->intersection($a);
	}

	# we don't have a parameter - just complement the set
	return Set::Infinite::Simple->new(minus_infinite, infinite) if $self->is_null;

	my $tmp1 = Set::Infinite::Simple->new(minus_infinite, $self->{a});
	$tmp1->open_end(not $self->{open_begin});

	my $tmp2 = Set::Infinite::Simple->new($self->{b}, infinite);
	$tmp2->open_begin(not $self->{open_end});

	return Set::Infinite::Simple->new() if 
		(($tmp1 == infinite) or ($tmp1 == minus_infinite)) and
		(($tmp2 == infinite) or ($tmp2 == minus_infinite));

	return $tmp1 if ($tmp2 == infinite);
	return $tmp1 if ($tmp2 == minus_infinite);

	return $tmp2 if ($tmp1 == infinite);
	return $tmp2 if ($tmp1 == minus_infinite);

	return ($tmp1 , $tmp2);
}

sub union {
	my $self = shift;
	# my $b = shift;

	my $tmp1 = Set::Infinite::Simple->new($self);
	my $tmp2 = Set::Infinite::Simple->new(@_); 

	return $tmp1 if $tmp2->is_null; # defined($tmp2->{a}) and defined($tmp2->{b});
	return $tmp2 if $tmp1->is_null; # unless defined($tmp1->{a}) and defined($tmp1->{b});

	# return ( $tmp1, $tmp2 ) unless $tmp1->intersects($tmp2);

	if ($tmp1->{tolerance}) {
		# "integer"
		my $a1_open =  $tmp1->{open_begin} ? -$tmp1->{tolerance} : $tmp1->{tolerance} ;
		my $b1_open =  $tmp1->{open_end}   ? -$tmp1->{tolerance} : $tmp1->{tolerance} ;
		my $a2_open =  $tmp2->{open_begin} ? -$tmp1->{tolerance} : $tmp1->{tolerance} ;
		my $b2_open =  $tmp2->{open_end}   ? -$tmp1->{tolerance} : $tmp1->{tolerance} ;

		# open_end touching?
		if ((($tmp1->{b}+$tmp1->{b}) + $b1_open ) < (($tmp2->{a}+$tmp2->{a}) - $a2_open)) {
			# self disjuncts b
			return ( $tmp1, $tmp2 ); # if ( $tmp1->{open_end}) or ( $tmp2->{open_begin});
		}
		if ((($tmp1->{a}+$tmp1->{a}) - $a1_open ) > (($tmp2->{b}+$tmp2->{b}) + $b2_open)) {
			# self disjuncts b
			return ( $tmp1, $tmp2 ); # if ( $tmp2->{open_end}) or ( $tmp1->{open_begin});
		}
	}
	else {
		# "real"
		if ($tmp1->{b} < $tmp2->{a}) {
			# self disjuncts b
			return ( $tmp1, $tmp2 );
		}
		if ($tmp2->{b} < $tmp1->{a}) {
			# self disjuncts b
			return ( $tmp1, $tmp2 );
		}
		if ($tmp1->{b} == $tmp2->{a}) {
			# self disjuncts b
			return ( $tmp1, $tmp2 ) unless (not $tmp1->{open_end}) or (not $tmp2->{open_begin});
		}
		if ($tmp2->{b} == $tmp1->{a}) {
			# self disjuncts b
			return ( $tmp1, $tmp2 ) unless (not $tmp2->{open_end}) or (not $tmp1->{open_begin});
		}
	}

	if ($tmp1->{a} == $tmp2->{a}) {
			$tmp1->{open_begin} = $tmp2->{open_begin} if $tmp1->{open_begin};
	}
	if ($tmp1->{a} > $tmp2->{a}) {
			$tmp1->{a} = $tmp2->{a};
			$tmp1->{open_begin} = $tmp2->{open_begin};
	}

	if ($tmp1->{b} == $tmp2->{b}) {
			$tmp1->{open_end} = $tmp2->{open_end} if $tmp1->{open_end};
	}
	if ($tmp1->{b} < $tmp2->{b}) {
			$tmp1->{b} = $tmp2->{b};
			$tmp1->{open_end} = $tmp2->{open_end};
	}
	return $tmp1;
}

sub contains {
	my $self = shift;

	# do we have a parameter?
	return 1 unless @_;

	my $a = Set::Infinite::Simple->new(@_);
	$a->tolerance($self->{tolerance});
	return ($self->union($a) == $self) ? 1 : 0;
}

sub add {
	my ($self) = shift;
	my @param = @_;

	# is it an array?
	if (ref($param[0]) eq 'ARRAY') {
		# get 2 elements from it
		my @aux = @{$param[0]};
		$aux[1] = $aux[0] unless defined($aux[1]);
		@param = ($aux[0], $aux[1], @param[1..$#param]);
	}

	# is it now defined?
	unless (defined($param[0])) {
		undef $self->{a};
		undef $self->{b};
		return $self;
	}

	my $tmp  = shift @param;
	my $tmp2 = shift @param;

	if (ref($tmp) eq $package) {
		($self->{a}, $self->{b}) =  ($tmp->{a}, $tmp->{b});
		$self->tolerance($tmp->{tolerance}) 	if defined $tmp->{tolerance};
		$self->open_begin($tmp->{open_begin})	if defined $tmp->{open_begin};
		$self->open_end($tmp->{open_end})   	if defined $tmp->{open_end};
		unshift @param, $tmp2;
		return $self;	
	}

	my $tmp1_elem = Set::Infinite::Element->new($tmp);
	my $tmp2_elem = Set::Infinite::Element->new($tmp2);
	if ($tmp2_elem == undef) {
		($self->{a}, $self->{b}) = ($tmp1_elem, $tmp1_elem);
	}
	else {
		if ($tmp1_elem < $tmp2_elem) {
			($self->{a}, $self->{b}) = ($tmp1_elem, $tmp2_elem);
		}
		else {
			($self->{a}, $self->{b}) = ($tmp2_elem, $tmp1_elem);
		}
	}
	return $self;	
}

sub min { 
	my ($self) = shift;
	return $self->{a}; 
};

sub max { 
	my ($self) = shift;
	return $self->{b}; 
};

sub size { 
	my ($self) = shift;
	return $self->{b} - $self->{a};
};

sub span { 
	return shift;
};

sub spaceship {
	my ($tmp1) = shift;
	my $tmp2 = Set::Infinite::Simple->new(shift);
	my $inverted = shift;

	if ($inverted) {
		($tmp2, $tmp1) = ($tmp1, $tmp2);
	}

	return 1  if not defined($tmp2->{a});

	return $tmp1->max <=> $tmp2->max if $tmp1->min == $tmp2->min;
	return $tmp1->min <=> $tmp2->min;
}

sub cmp {
	return spaceship @_;
}

sub cleanup {
	my ($self) = shift;
	if ($self->{a} > $self->{b}) {
		($self->{a}, $self->{b}) = ($self->{b}, $self->{a});
	}
	$self->open_begin(1) if ($self->{a} == minus_infinite);
	$self->open_end(1)	 if ($self->{b} == infinite);
	return $self;
}

sub tolerance {
	my $class = shift;
	my $tmp = shift;
	if (ref($class) eq 'Set::Infinite::Simple') {
		$class->{tolerance} = $tmp if ($tmp ne '');
		return $class;
	}
	$tolerance = $tmp if ($tmp ne '');
	return $tolerance;
}

sub integer {
	if (@_) {
		my ($self) = shift;
		$self->tolerance (1);
		return $self;
	}
	return tolerance(1);
}

sub real {
	if (@_) {
		my ($self) = shift;
		$self->tolerance ($granularity);
		return $self;
	}
	return tolerance($granularity);
}

sub new {
	my ($self) = bless {}, shift;
	$self->tolerance($tolerance);
	$self->add(@_);
	return $self;
}

sub as_string {
	my ($self) = shift;
	my $s;
	$self->cleanup;
	my $tmp1 = "$self->{a}";
	my $tmp2 = "$self->{b}";
	return null if $self->is_null;
	return $tmp1 if $tmp1 eq $tmp2;
	$s = $self->{open_begin} ? $separators[2] : $separators[0];
	$s .= $tmp1 . $separators[4] . $tmp2;
	$s .= $self->{open_end} ? $separators[3] : $separators[1];
	return $s;
}

# TIE

sub TIEARRAY {
	my $class = shift;
	my $self = $class->new(@_);
	$self->{type} = 2;
	return $self;
}

sub FETCHSIZE {
	return 2; 
}

sub STORESIZE {
	return @_;
}

sub CLEAR {
	my ($self) = shift;
	undef $self->{a};
	undef $self->{b};
}

sub EXTEND {
	return @_;
}

sub TIESCALAR {
	my $class = shift;
	my $self = $class->new(@_);
	$self->{type} = 1;
	return $self;
}

sub FETCH {
	my ($self) = shift;
	if (@_) {
		# we have an index, so we are an array
		my $index = shift;
		return $self->{a} if $index == 0;
		return $self->{b} if $index == 1;
		return undef;
	}
	return $self->as_string;
}

sub STORE {
	my ($self) = shift;
	my $data = shift;
	if (($self->{type} == 2) and @_ and (($data == 0) or ($data == 1))) {
		# we have a valid index and data, so we are an array
		my $index = $data;
		$data = shift;
		$self->{a} = $data if $index == 0;
		$self->{b} = $data if $index == 1;
		$self->cleanup;
		return ($data, @_);
	}
	$self = new($data, @_);
	return @_;
}

sub DESTROY {
}

1;