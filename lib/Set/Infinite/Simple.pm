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

	$a = Set::Infinite::Simple->new(@b);	
	$a = Set::Infinite::Simple->new($b);	
		parameters can be:
		undef
		SCALAR => means an interval like (1,1)
		SCALAR,SCALAR
		ARRAY of SCALAR
		Set::Infinite::Simple

	$a = Set::Infinite::Simple->fastnew( object_begin, object_end, open_begin, open_end );	

	$a->real;
	$a->integer;

	$logic = $a->intersects($b);
	$logic = $a->contains($b);

	$i = $a->union($b);	
		NOTE: union returns a list if result is ($a, $b)
	$i = $a->intersection($b);
	$i = $a->complement($b);
	$i = $a->complement;

	@b = sort @a;
	print $a;

	tie $a, 'Set::Infinite::Simple', 1,2;
		SCALAR behaves like a string "min .. max"
	tie @a, 'Set::Infinite::Simple', 1,2;
		$a[0], $a[1] are min and max
		POP, PUSH, SHIFT, UNSHIFT, SPLICE, DELETE, and EXISTS are not defined

	$a->open_end(1)		open-end: elements are < end
	$a->open_begin(1) 	open-start: elements are > begin
	$a->open_end(0)		close-end: elements are <= end
	$a->open_begin(0) 	close-start: elements are >= begin

Global:
	separators(@i)	chooses the separators. 
		default are [ ] ( ) '..' ','.


	infinite		returns an 'infinity' number.
	minus_infinite	returns '- infinity' number.
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
	local type	

=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

require Exporter;

package Set::Infinite::Simple;
$VERSION = "0.22";


@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(
	infinite minus_infinite separators null type inf
	tolerance integer real selector offsetter
	simple_null
	fastnew
);

use strict;
use Carp;

use Set::Infinite::Element_Inf qw(infinite minus_infinite null inf elem_undef);

# sub inf();
# sub infinite();
# sub minus_infinite();
# sub null();

our $DEBUG_TYPE = 0;
our $type = '';
our $infinite  = Set::Infinite::Element_Inf::infinite;
our $null      = Set::Infinite::Element_Inf::null;
# our $quantizer = 'Set::Infinite::Quantize';
our $selector  = 'Set::Infinite::Select';
our $offsetter = 'Set::Infinite::Offset';

sub type {

	# this is a hack - waiting for better ideas

	my ($self, $tmp_type) = @_;

	#print " [S:TYPE: $self $tmp_type ] " ;

	if (not defined ($tmp_type)) {
		# global
		$tmp_type = $self;
		$self = __PACKAGE__;
	}

	#print " [S:TYPE:($self, $tmp_type)] " ;

	if (defined($tmp_type) and ($tmp_type ne '')) {
		if (ref($self)) {
			# local
			$self->{type} = $tmp_type;
		}
		else {
			# global
			$type = $tmp_type;
		}
		eval "use " . $tmp_type;
			carp "Warning: can't start $tmp_type package: $@" if $@;

		my $tmp_selector = eval '&' . $tmp_type . '::selector';
		if ($tmp_selector) {
			if (ref($self)) {
				# local
				$self->{selector} = $tmp_selector;
			}
			else {
				# global
				$selector = $tmp_selector;
			}
			eval "use " . $tmp_selector; 
				carp "Warning: can't start $tmp_type  $tmp_selector package: $@" if $@;
			# print " [ELEM:selector $tmp_type $tmp_selector]\n";
		}

		my $tmp_offsetter = eval '&' . $tmp_type . '::offsetter';
		if ($tmp_offsetter) {
			if (ref($self)) {
				# local
				$self->{offsetter} = $tmp_offsetter;
			}
			else {
				# global
				$offsetter = $tmp_offsetter;
			}
			eval "use " . $tmp_offsetter; 
				carp "Warning: can't start $tmp_type  $tmp_offsetter package: $@" if $@;
			# print " [ELEM:offsetter $tmp_type $tmp_offsetter]\n";
		}

		# TEST for '<=>' function - enable this to help debug new types
		if ($DEBUG_TYPE) {
			if ( (eval "(new " . $tmp_type . " (4)) <=> (new " . $tmp_type . " (3))") != 1) {
				if ((eval "new " . $tmp_type . " (4)") != 4) {
					carp "Warning: can't start " . $tmp_type . " package";
				}
				else {
					carp "Warning: " . $tmp_type . " can't `<=>'";
				}
			}
		} # end DEBUG_TYPE
 	}

	return $self;
}

sub selector {
	my $self = shift;
	# print " [selector:",($self->{selector} or $selector),"] ";
	return ($self->{selector} or $selector);
}

sub offsetter {
	my $self = shift;
	return ($self->{offsetter} or $offsetter);
}

use overload
	'<=>' => \&spaceship,
	qw("" as_string);

our @separators = (
	'[', ']',	# a closed interval 
	'(', ')',	# an open interval 
	'..',		# number separator
	','			# list separator
);

our $tolerance = 0;
our $simple_null =           __PACKAGE__->fastnew(null, null, 1, 1);
our $simple_everything =     __PACKAGE__->fastnew(minus_infinite, infinite, 1, 1);
our $simple_infinite =       __PACKAGE__->fastnew(infinite, infinite, 1, 1);
our $simple_minus_infinite = __PACKAGE__->fastnew(minus_infinite, minus_infinite, 1, 1);

sub simple_null {
	return $simple_null;
}

# sub quantize {
#	my $self = shift;
#	my (@a);
#	tie @a, quantizer, $self, @_, ;
#	return @a;
# }

sub select {
	my $self = shift;
	my (@a);
	tie @a, selector, $self, @_;
	return @a;
}

sub offset {
	my $self = shift;
	my (@a);
	tie @a, offsetter, $self, @_;
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

sub intersects {
	my ($tmp1, $tmp2) = (shift, shift);
	# $tmp2 = __PACKAGE__->new($tmp2, @_) unless ref($tmp2) and $tmp2->isa(__PACKAGE__); 

	# print "I";

	# if (Set::Infinite::Element_Inf::is_null($tmp1->{a}) ) {
	#	print "1";
	#	return 0;
	# }
	# if (Set::Infinite::Element_Inf::is_null($tmp2->{a}) ) {
	#	print "2";
	#	return 0;
	#}

	my ($i_beg, $i_end, $open_beg, $open_end);

	#return 0 if ($tmp1->{b} < $tmp2->{a});
	#return 0 if ($tmp2->{b} < $tmp1->{a});

	if ($tmp1->{a} < $tmp2->{a}) {
		# print "3";
		if ($tmp1->{b} > $tmp2->{b}) {
			# print "6";
			return 1;
		}
		$i_beg 		= $tmp2->{a};
		$open_beg 	= $tmp2->{open_begin};
	}
	elsif ($tmp1->{a} == $tmp2->{a}) {
		# print "4";
		$i_beg 		= $tmp1->{a};
		$open_beg 	= ($tmp1->{open_begin} or $tmp2->{open_begin});
	}
	else {
		# print "5";
		$i_beg 		= $tmp1->{a};
		$open_beg	= $tmp1->{open_begin};
	}

	if ($tmp1->{b} > $tmp2->{b}) {
		# print "6";
		$i_end 		= $tmp2->{b};
		$open_end 	= $tmp2->{open_end};
	}
	elsif ($tmp1->{b} < $tmp2->{b}) {
		# print "8";
		$i_end 		= $tmp1->{b};
		$open_end	= $tmp1->{open_end};
	}
	else {     # if ($tmp1->{b} == $tmp2->{b}) {
		# print "7";
		$i_end 		= $tmp1->{b};
		$open_end 	= ($tmp1->{open_end} or $tmp2->{open_end});
	}

	return 0 if 
		( $i_beg > $i_end ) or 
		( ($i_beg == $i_end) and ($open_beg or $open_end) ) ;
	return 1;
	
}

sub intersection {
	my ($tmp1, $tmp2) = (shift, shift);
	# $tmp2 = __PACKAGE__->new($tmp2, @_) unless ref($tmp2) and $tmp2->isa(__PACKAGE__); 

	return $simple_null if Set::Infinite::Element_Inf::is_null($tmp1->{a});
	return $simple_null if Set::Infinite::Element_Inf::is_null($tmp2->{a});

	my ($i_beg, $i_end, $open_beg, $open_end);


	if ($tmp1->{a} < $tmp2->{a}) {
		$i_beg 		= $tmp2->{a};
		$open_beg 	= $tmp2->{open_begin};
	}
	elsif ($tmp1->{a} == $tmp2->{a}) {
		$i_beg 		= $tmp1->{a};
		$open_beg 	= ($tmp1->{open_begin} or $tmp2->{open_begin});
	}
	else {
		$i_beg 		= $tmp1->{a};
		$open_beg	= $tmp1->{open_begin};
	}


	if ($tmp1->{b} > $tmp2->{b}) {
		$i_end 		= $tmp2->{b};
		$open_end 	= $tmp2->{open_end};
	}
	elsif ($tmp1->{b} == $tmp2->{b}) {
		$i_end 		= $tmp1->{b};
		$open_end 	= ($tmp1->{open_end} or $tmp2->{open_end});
	}
	else {
		$i_end 		= $tmp1->{b};
		$open_end	= $tmp1->{open_end};
	}

	return $simple_null if 
		( $i_beg > $i_end ) or 
		( ($i_beg == $i_end) and ($open_beg or $open_end) ) ;
	return __PACKAGE__->fastnew($i_beg, $i_end, $open_beg, $open_end );
}

sub complement {
	my $self = shift;

	# do we have a parameter?

	if (@_) {
		my $a = shift; # __PACKAGE__->new(@_);
		# $a->{tolerance} = $self->{tolerance} if defined($self->{tolerance});
		$a = $a->complement;
		return $self->intersection($a);
	}

	# print " [CPL-S:",$self,"] ";

	# we don't have a parameter - just complement the set
	return $simple_everything if Set::Infinite::Element_Inf::is_null($self->{a});

	my $tmp1 = __PACKAGE__->fastnew(minus_infinite, $self->{a}, 1, ! $self->{open_begin} );

	# print " [CPL-S:#1:",$tmp1,"] ";

	my $tmp2 = __PACKAGE__->fastnew($self->{b}, infinite, ! $self->{open_end}, 1);

	# print " [CPL-S:#2:",__PACKAGE__,":",$tmp2,"=(",$self->{b},", ",infinite,")] ";

	if ($tmp2->{a} == infinite) {
		return $simple_null if ($tmp1->{b} == minus_infinite);
		return $tmp1;
	}

	return $tmp2 if ($tmp1->{b} == minus_infinite);

	#print " [CPL-S:RES:",$tmp1 ,";", $tmp2,"] ";

	return ($tmp1 , $tmp2);
}

sub union {
	my $tmp2 = shift;
	my $tmp1 = shift; #  __PACKAGE__->new(@_); 

	#print " [SIM:UNION:@param] \n";
	#print " [SIM:UNION:$tmp1 U $tmp2] \n";

	return $tmp1 if Set::Infinite::Element_Inf::is_null($tmp2->{a});
	return $tmp2 if Set::Infinite::Element_Inf::is_null($tmp1->{a});


	if ($tmp2->{tolerance}) {
		# "integer"
		#print " [SIM:UNION:INT ",ref($tmp1->{a}),"=",$tmp1->{a}," <=> ",ref($tmp1->{b}),"=",$tmp1->{b},"] \n";

		my $a1_open =  $tmp1->{open_begin} ? -$tmp2->{tolerance} : $tmp2->{tolerance} ;
		my $b1_open =  $tmp1->{open_end}   ? -$tmp2->{tolerance} : $tmp2->{tolerance} ;
		my $a2_open =  $tmp2->{open_begin} ? -$tmp2->{tolerance} : $tmp2->{tolerance} ;
		my $b2_open =  $tmp2->{open_end}   ? -$tmp2->{tolerance} : $tmp2->{tolerance} ;

		# open_end touching?
		if ((($tmp1->{b}+$tmp1->{b}) + $b1_open ) < (($tmp2->{a}+$tmp2->{a}) - $a2_open)) {
			# self disjuncts b
			return ( $tmp2, $tmp1 );
		}
		if ((($tmp1->{a}+$tmp1->{a}) - $a1_open ) > (($tmp2->{b}+$tmp2->{b}) + $b2_open)) {
			# self disjuncts b
			return ( $tmp2, $tmp1 );
		}
	}
	else {
		# "real"
		#print " [SIM:UNION:REAL ",ref($tmp1->{a}),"=",$tmp1->{a}," <=> ",ref($tmp1->{b}),"=",$tmp1->{b},"] \n";
		if (	($tmp1->{b} < $tmp2->{a}) or
($tmp2->{b} < $tmp1->{a}) ) {
			# self disjuncts b
			return ( $tmp2, $tmp1 );
		}
		if (($tmp1->{b} == $tmp2->{a}) and $tmp1->{open_end} and $tmp2->{open_begin}) {
			# self disjuncts b
			return ( $tmp2, $tmp1 );
		}
		if (($tmp2->{b} == $tmp1->{a}) and $tmp2->{open_end} and $tmp1->{open_begin}) {
			# self disjuncts b
			return ( $tmp2, $tmp1 );
		}
	}

	#print " [SIM:UNION:",ref($tmp1->{a}),"=",$tmp1->{a}," <=> ",ref($tmp1->{b}),"=",$tmp1->{b},"] \n";

	if ($tmp1->{a} > $tmp2->{a}) {
			$tmp1->{a} = $tmp2->{a};
			$tmp1->{open_begin} = $tmp2->{open_begin};
	}
	elsif ($tmp1->{a} == $tmp2->{a}) {
			$tmp1->{open_begin} = $tmp2->{open_begin} if $tmp1->{open_begin};
	}

	if ($tmp1->{b} < $tmp2->{b}) {
			$tmp1->{b} = $tmp2->{b};
			$tmp1->{open_end} = $tmp2->{open_end};
	}
	elsif ($tmp1->{b} == $tmp2->{b}) {
			$tmp1->{open_end} = $tmp2->{open_end} if $tmp1->{open_end};
	}
	return $tmp1;
}

sub add {
	my ($self, $tmp, $tmp2) = @_;

	# is it an array?
	if (ref($tmp) eq 'ARRAY') {
		# get 2 elements from it
		$tmp2 = ${@{$tmp}}[-1];
		$tmp  = ${@{$tmp}}[0];
	}

	# print " [SIMPLE:ADD=", $tmp, ";",$tmp2," (", ref(\$tmp), ";",ref(\$tmp2),")] ";

	# is it now defined?
 	unless (defined($tmp)) {
		$self->{a} = null;
		$self->{b} = null;
		return $self;
	}

	if (ref($tmp)) {
		if ($tmp->isa(__PACKAGE__)) {
			# print " [SIMPLE:ISA=", __PACKAGE__,":", $tmp,"] ";
			%{$self} = %{$tmp};
			return $self;	
		}
	}

	elsif ($self->{type}) {
		# print " [TYPE=",$self->{type},",$tmp] ";
		$tmp = new {$self->{type}} $tmp;
	}

	if ($self->{type} and not ref($tmp2)) {
		$tmp2 = new {$self->{type}} $tmp2;
	}

	# print " [SIM:ADD:$tmp,$tmp2, is-null=",$tmp2->is_null,"]\n";

	if (Set::Infinite::Element_Inf::is_null($tmp2)) {
		($self->{a}, $self->{b}) = ($tmp, $tmp);
	}
	else {
		if ($tmp < $tmp2) {
			($self->{a}, $self->{b}) = ($tmp, $tmp2);
		}
		else {
			($self->{a}, $self->{b}) = ($tmp2, $tmp);
		}
	}
	#print " [add=$self]",($self->{a}, $self->{b}, null),"\n";
	return $self;	
}


sub spaceship {
	my ($tmp1, $tmp2, $inverted) = @_;
	# unless (ref($tmp2) and $tmp2->isa(__PACKAGE__)) {
	#	print " TMP2:isa:", ref(\$tmp2), ":", $tmp2 , ":",caller," ";
	#	$tmp2 = __PACKAGE__->new($tmp2);
	# }

	if ($inverted) {
		return $tmp2->{b} <=> $tmp1->{b} if $tmp1->{a} == $tmp2->{a};
		return $tmp2->{a} <=> $tmp1->{a};
	}

	return $tmp1->{b} <=> $tmp2->{b} if $tmp1->{a} == $tmp2->{a};
	return $tmp1->{a} <=> $tmp2->{a};
}

sub cleanup {
	my ($self) = shift;
	# print " [simple:cleanup:",ref($self->{a}),"] ";
	$self->open_begin(1) 	if ($self->{a} == minus_infinite);
	$self->open_end(1) 		if ($self->{b} == infinite);
	# print " [cleanup:end] ";
	return $self;
}

sub tolerance {
	my $self = shift;
	my $tmp = shift;
	if (ref($self)) {  
		# local
		$self->{tolerance} = $tmp if ($tmp ne '');
		return $self;
	}
	# global
	$tolerance = $tmp if defined($tmp) and ($tmp ne '');
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
		$self->tolerance (0);
		return $self;
	}
	return tolerance(0);
}

sub new {
	my ($self) = bless {}, shift;
	$self->{tolerance} = $tolerance; 
	$self->{type} = $type;
	# $self->{quantizer} = $quantizer;
	# $self->{selector} = $selector;
	# $self->{offsetter} = $offsetter;
	$self->add(@_);
	return $self;
}

sub fastnew {
	my ($self) = bless { a => $_[1] , b => $_[2] , open_begin => $_[3] , open_end => $_[4] }, $_[0];
	$self->{tolerance} = $tolerance; 
	$self->{type} = $type;
	return $self;
}

sub as_string {
	my ($self) = shift;
	my $s;
	# print " [simple:string] ";
	$self->cleanup;
	# return null if $self->is_null;
	my $tmp1 = "$self->{a}";
	my $tmp2 = "$self->{b}";
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
	$self->{a} = null;
	$self->{b} = null;
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
		# print " STORE $data at $index ";
		$self->{a} = $data if $index == 0;
		$self->{b} = $data if $index == 1;
		# print " = $self\n";
		$self->cleanup unless 
			Set::Infinite::Element_Inf::is_null($self->{a}) or 
			Set::Infinite::Element_Inf::is_null($self->{b});
# unless it will become null!
		# print " = $self\n";
		return ($data, @_);
	}
	$self = new($data, @_);
	return @_;
}

sub DESTROY {
}

1;