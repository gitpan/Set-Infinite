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

our $VERSION = '0.22.05';


# Preloaded methods go here.

use Set::Infinite::Simple qw(
	infinite minus_infinite separators null type quantizer selector offsetter inf
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

# quantize: splits in same-size subsets
sub quantize {
	my $self = shift;
	my (@a);
	# my $array_ref = shift;
	my $tmp = $self->{list}->[0]->quantizer or quantizer;
	# print " [INF:QUANT $tmp,",@_,",$self]\n";
	tie @a, $tmp, $self, @_;

	# array output: can be used by "foreach"
	return @a if wantarray; 
	
	# object output: can be further "intersection", "union", etc.
	my $b = __PACKAGE__->new($self); # clone myself
	$b->{list} = \@a; 	# change data
	$b->{cant_cleanup} = 1; 	# quantize output is "virtual" (tied) -- can't splice, sort
	return $b;
}

# select: position-based selection of subsets
use Set::Infinite::Function; 	# ???
use Set::Infinite::Select; 	# ???
sub select {
	my $self = shift;
	my (@a);
	# my $array_ref = shift;
	my $tmp = $self->{list}->[0]->selector or selector;
	# print " [INF:SELECT $tmp,",@_,",$self FROM:", $self->{list}->[0],"]\n";
	tie @a, $tmp, $self, @_;

	# array output: can be used by "foreach"
	# if (wantarray) { print " [wantarray] " }
	return @a if wantarray; 
	
	# object output: can be further "intersection", "union", etc.
	my $b = __PACKAGE__->new($self); # clone myself
	$b->{list} = \@a; 	# change data
	$b->{cant_cleanup} = 1; 	# select output is "virtual" (tied) -- can't splice, sort
	return $b;
}

# offset: offsets subsets
use Set::Infinite::Offset; 	# ???
sub offset {
	my $self = shift;
	my (@a);
	# my $array_ref = shift;
	my $tmp = $self->{list}->[0]->offsetter or offsetter;
	# print " [INF:OFFSET $tmp,",$self,",",join(",",@_),"]\n";
	tie @a, $tmp, $self, @_;

	# array output: can be used by "foreach"
	# if (wantarray) { print " [wantarray] " }
	return @a if wantarray; 
	
	# object output: can be further "intersection", "union", etc.
	my $b = __PACKAGE__->new($self); # clone myself
	$b->{list} = \@a; 	# change data
	$b->{cant_cleanup} = 1; 	# offset output is "virtual" (tied) -- can't splice, sort
	return $b;
}


sub is_null {
	my $self = shift;
	return 1 unless $#{$self->{list}} >= 0;
	return 1 if Set::Infinite::Element_Inf::is_null($self->{list}->[0]->{a});
	return 0;
	# return ("$self" eq null) ? 1 : 0;
}

sub intersects {
	my $a = shift;
	my $b;
	#my @param = @_;
	#my $b = __PACKAGE__->new(@param); 

	if (ref ($_[0]) eq __PACKAGE__) {
		$b = shift;
	} 
	else {
		# my @param = @_;
		$b = __PACKAGE__->new(@_);  
	}

	my ($ia, $ib);
	my ($na, $nb) = (0,0);
	my $intersection = __PACKAGE__->new();
	B: foreach $ib ($nb .. $#{  @{ $b->{list} } }) {
		foreach $ia ($na .. $#{  @{ $a->{list} } }) {
			#next B if Set::Infinite::Element_Inf::is_null($a->{list}->[$ia]->{a});
			#next B if Set::Infinite::Element_Inf::is_null($b->{list}->[$ib]->{a});
		#	if ( $a->{list}->[$ia]->{a} > $b->{list}->[$ib]->{b} ) {
		#		$na = $ia;
		#		next B;
		#	}
			# next B if ($a->{list}->[$ia]->{a} > $b->{list}->[$ib]->{b}) ;
			return 1 if $a->{list}->[$ia]->intersects($b->{list}->[$ib]);
		}
	}
	return 0;	
}

sub intersection {
	my $a = shift;

	if (ref ($_[0]) eq __PACKAGE__) {
		$b = shift;
	} 
	else {
		# my @param = @_;
		$b = __PACKAGE__->new(@_);  
	}

	# my @param = @_;
	# my $b = __PACKAGE__->new(@param);

	my $tmp;
	#print " [intersect ",$a,"--",ref($a)," with ", $b, "--",ref($b)," ", caller, "] \n";
	my ($ia, $ib);
	my ($na, $nb) = (0,0);
	my $intersection = __PACKAGE__->new();
	B: foreach $ib ($nb .. $#{  @{ $b->{list} } }) {
		foreach $ia ($na .. $#{  @{ $a->{list} } }) {
			#	my ($pa, $pb) = ($a->{list}->[$ia], $b->{list}->[$ib]);
			# print " [intersect ",$ia,"--",$ib," ]\n";
			# print " [intersect   ",$pa,"--",$pb," ]\n";
			# print " [intersect     ",%{$a->{list}->[$ia]},"--",%{$b->{list}->[$ib]}," ]\n";
			#next B if Set::Infinite::Element_Inf::is_null($pa->{a});
			#next B if Set::Infinite::Element_Inf::is_null($pb->{a});
			#	if ( $pa->{a} > $pb->{b} ) {
			#		$na = $ia;
			#		next B;
			#	}
			# print "   [intersect_simple ",$a->{list}->[$ia]," with ", $b->{list}->[$ib], "] \n";
			# unless ($a->{list}->[$ia]->is_null) {

			$tmp = $a->{list}->[$ia]->intersection($b->{list}->[$ib]);
			push @{$intersection->{list}}, $tmp unless Set::Infinite::Element_Inf::is_null($tmp->{a}); # ->{a},$tmp->{b}) if $tmp;

			# $intersection->add($tmp) if defined($tmp); # ->{a},$tmp->{b}) if $tmp;
			# }
		}
	}
	return $intersection;	
}

sub complement {
	my $self = shift;

	# do we have a parameter?

	if (@_) {

		if (ref ($_[0]) eq __PACKAGE__) {
			$a = shift;
		} 
		else {
			$a = __PACKAGE__->new(@_);  
			$a->tolerance($self->{tolerance});
		}

		$a = $a->complement;
		# print " [CPL:intersect ",$self," with ", $a, "] ";
		return $self->intersection($a);
	}

	my ($ia);
	my $tmp;

	# print " [CPL:",$self,"] ";

	if (($#{$self->{list}} < 0) or (not defined ($self->{list}))) {
		return __PACKAGE__->new(minus_infinite, infinite);
	}

	my $complement = __PACKAGE__->new();
	my @tmp = $self->{list}->[0]->complement;
	# print " [CPL:ADDED:",join(";",@tmp),"] ";

	#foreach(@tmp) {
	# 	$complement->add($_); 
	#}
	push @{$complement->{list}}, @tmp; 

	foreach $ia (1 .. $#{  @{ $self->{list} } }) {
			@tmp = $self->{list}->[$ia]->complement;
			$tmp = __PACKAGE__->new();
			# foreach(@tmp) { $tmp->add($_); }
			push @{$tmp->{list}}, @tmp; 

			$complement = $complement->intersection($tmp); # if $tmp;
	}

	# print " [CPL:RES:",$complement,"] ";

	return $complement;	
}

# version 0.22.02 - faster union O(n*n) => O(n)
sub union {
	my $self = shift;
	my $b;
	# print " [UNION] \n";
	# print " [union: new b] \n";
	if (ref ($_[0]) eq __PACKAGE__) {
		$b = shift;
	} 
	else {
		$b = __PACKAGE__->new(@_);  
	}

	# print " [union: new union] \n";
	my $a = __PACKAGE__->new($self);
	# print " [union: $a +\n       $b ] \n";
	my ($ia, $ib);
	$ia = 0;
	$ib = 0;
	B: foreach $ib ($ib .. $#{  @{ $b->{list} } }) {
		foreach $ia ($ia .. $#{  @{ $a->{list} } }) {
			# $self->{list}->[$_ - 1] = $tmp[0];
			# splice (@{$self->{list}}, $_, 1);

			my @tmp = $a->{list}->[$ia]->union($b->{list}->[$ib]);
			# print " [+union: $tmp[0] ; $tmp[1] ] \n";

			if ($#tmp == 0) {
					$a->{list}->[$ia] = $tmp[0];
					next B;
			}

			if ($a->{list}->[$ia]->{a} >= $b->{list}->[$ib]->{a}) 
			{
				# print "+ ";
				# splice(@array,$index,0,$value)
				splice (@{$a->{list}}, $ia, 0, $b->{list}->[$ib]);
				# $a->add($b->{list}->[$ib]);
				next B;
			}

		}
		# print "- ";
		# $a->add($b->{list}->[$ib]);
		push @{$a->{list}}, $b->{list}->[$ib];
	}
	# print " [union: done from ", join(" ", caller), " ] \n";
	# print " [union: result = $a ] \n";
	# $a->{cant_cleanup} = 1;

	#	foreach $ia (0 .. $#{  @{ $a->{list} } }) {
	#		my @tmp = $a->{list}->[$ia];
	#		print " #", $ia, ": ", $a->{list}->[$ia], " is ", join(" ", %{$a->{list}->[$ia]} ) , "\n";
	#	}
	# print " [union: is ", join(" ", %$a) , " ] \n";

	return $a;	
}

sub contains {
	my $self = shift;

	# do we have a parameter?
	return 1 unless @_;

	if (ref ($_[0]) eq __PACKAGE__) {
		$a = shift;
	} 
	else {
		$a = __PACKAGE__->new(@_);  
		$a->tolerance($self->{tolerance});
	}

	return ($self->union($a) == $self) ? 1 : 0;
}

sub add {
	my ($self) = shift;
	my @param = @_;

	#print " [I:ADD] ";
LOOP:
		my $tmp = shift @param;
		return $self unless defined($tmp);

		# is it an array?
		#print " [INF:ADD:",ref($tmp),"=$tmp ; ",@param,"]\n";
		if (ref($tmp) eq 'ARRAY') {
			my @tmp = @{$tmp};

	
			# print " INF:ADD:ARRAY:",@tmp," ";

			# Allows arrays of arrays
			$tmp = __PACKAGE__->new(@tmp) ;
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
				# print " INF:ADD:",__PACKAGE__,":",$tmp," ";
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
			#print " [NEW] " ;
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
	foreach(0 .. $#{$self->{list}}) {
		$tmp = $self->{list}->[$_]->{a};
		#print "min:$tmp ";
		return $tmp unless Set::Infinite::Element_Inf::is_null($tmp) ;
	}
	return Set::Infinite::Element_Inf::null; 
};

sub max { 
	my ($self) = shift;
	my $tmp;
	my $i;
	for($i = $#{$self->{list}}; $i >= 0; $i--) {
		$tmp = $self->{list}->[$i]->{b};
		#print "max:$tmp ";
		return $tmp unless Set::Infinite::Element_Inf::is_null($tmp) ;
	}
	return Set::Infinite::Element_Inf::null; 
};

sub size { 
	my ($self) = shift;
	my $tmp;
	# $self->cleanup;
	my $size = $self->{list}->[0]->{b} - $self->{list}->[0]->{a};
	foreach(1 .. $#{ @{ $self->{list} } }) {
		$tmp = $self->{list}->[$_]->{b} - $self->{list}->[$_]->{a};
		$size += $tmp;
	}
	return $size; 
};

sub span { 
	my ($self) = shift;
	return __PACKAGE__->new($self->min, $self->max);
};

sub spaceship {
	my ($tmp1, $tmp2, $inverted) = @_;

	if ($inverted) {
		if (ref ($tmp1) ne __PACKAGE__) {
			$tmp1 = __PACKAGE__->new($tmp1);  
		}
		($tmp2, $tmp1) = ($tmp1, $tmp2);
	}
	else {
		if (ref ($tmp1) ne __PACKAGE__) {
			$tmp2 = __PACKAGE__->new($tmp2);  
		}
	}

	return $tmp1->min  <=> $tmp2->min  if ($tmp1->min  != $tmp2->min);
	return $tmp1->size <=> $tmp2->size if ($tmp1->size != $tmp2->size);
	return $#{ @{ $tmp1->{list} } } <=> $#{ @{ $tmp2->{list} } } if $#{ @{ $tmp1->{list} } } != $#{ @{ $tmp2->{list} } };
	foreach(0 .. $#{  @{ $tmp1->{list} } }) {
		my $this  = $tmp1->{list}->[$_];
		my $other = $tmp2->{list}->[$_];
		return $this <=> $other if $this != $other;
	}
	return 0;
}

sub cmp {
	return spaceship @_;
}

sub cleanup {
	my ($self) = shift;
	return $self if $self->{cant_cleanup}; 	# quantize output is "virtual", can't be cleaned

	# $self->tolerance($self->{tolerance});	# ???

	# my $debug_optimize = __PACKAGE__->new($self);

	# removed in version 0.22.02 after deprecating "add"
	# @{ $self->{list} } = sort @{ $self->{list} };

	$_ = 1;
	while ( $_ <= $#{  @{ $self->{list} } } ) {
		my @tmp = $self->{list}->[$_]->union($self->{list}->[$_ - 1]);
		if ($#tmp == 0) {
			$self->{list}->[$_ - 1] = $tmp[0];
			splice (@{$self->{list}}, $_, 1);
		} 
		else {
			$_ ++;
		}
	}

	# if (join("",@{$debug_optimize->{list}}) ne join("",@{$self->{list}})) {
	#  	print " [CLEANUP:", join(" ",@{$debug_optimize->{list}}), "\n";
	# }

	return $self;
}

sub tolerance {
	my $class = shift;
	my $tmp = shift;
	if (ref($class) eq __PACKAGE__) {
		my ($self) = $class;
		if ($tmp ne '') {
			$self->{tolerance} = $tmp;
			foreach (0 .. $#{  @{ $self->{list} } }) {
				$self->{list}->[$_]->tolerance($self->{tolerance});
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
		return $self->{list}->[$index];
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
		$self->{list}->[$index] = $data if $index == 0;
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

Set::Infinite - Sets of intervals

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

Set functions:

	$i = $a->union($b);	

	$i = $a->intersection($b);

	$i = $a->complement;
	$i = $a->complement($b);

	$i = $a->span;   

		result is INTERVAL, (min .. max)

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

		chooses 'null' name. default is ''

	infinite($i)

		chooses 'infinite' name. default is 'inf'

	infinite

		returns an 'infinite' number.

	minus_infinite

		returns '-infinite' number.

	null

		returns the 'null' object.

	quantize( parameters )

		Makes equal-sized subsets.

		In array context: returns a tied reference to the subset list.
		In set context: returns an ordered set of equal-sized subsets.

		The quantization function is external to this module:
		Parameters may vary depending on implementation. 

		Positions for which a subset does not exist may show as null.

		Example: 

			$a = Set::Infinite->new([1,3]);
			print join (" ", $a->quantize( quant => 1 ) );

		Gives: 

			[1..2) [2..3) [3..4)

	select( parameters )

		Selects set members based on their ordered positions.
		Selection is more useful after quantization.

		In array context: returns a tied reference to the array of selected subsets.
		In set context: returns the set of selected subsets.

		Unselected subsets may show as null.

		The selection function is external to this module:
		Parameters may vary depending on implementation. 

			freq     - default=1
			by       - default=[0]
			interval - default=1
			count    - dafault=infinite

	offset ( parameters )

		Offsets the subsets.

		The selection function is external to this module:
		Parameters may vary depending on implementation. 

			value   - default=[0,0]
			mode    - default='offset'. Possible values are: 'offset', 'begin', 'end'.

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

	$a->add($b);  # Use $a = $a->union($b) instead.

=head1 Notes on Set::Infinite::Date

Set::Infinite::Date is a Date "plugin" for sets.

It is invoked by:

	type('Set::Infinite::Date');

It requires HTTP:Date and Time::Local

It changes quantize function behaviour to accept time units:

	use Set::Infinite;
	use Set::Infinite::Quantize_Date;
	Set::Infinite->type('Set::Infinite::Date');
	Set::Infinite::Date->date_format("year-month-day");

	$a = Set::Infinite->new('2001-05-02', '2001-05-13');
	print "Weeks in $a: ", join (" ", $a->quantize(unit => 'weeks', quant => 1) );

	$a = Set::Infinite->new('09:30', '10:35');
	print "Quarters of hour in $a: ", join (" ", $a->quantize(unit => 'minutes', quant => 15) );

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

=head1 CHANGES

0.21
	Change: "quantize()" or "quantize( quant => 1)" instead of "quantize(1)".
	Change: "quantize(unit => 'minutes', quant => 15)" instead of "quantize('minutes',15)"
	New methods: "select" and "offset"

0.22.02
	Faster cleanup, max, min
	Cleaner (faster?) union

=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

