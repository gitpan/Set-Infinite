#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

	Set::Infinite::Simple - an interval of 2 scalars

=head1 SYNOPSIS

	This is a building block for Set::Infinite.
	Please use Set::Infinite instead.

	use Set::Infinite::Simple;

	$a = Set::Infinite::Simple->new(1,2);
	print $a->union(5,6);

=head1 USAGE

	$a = Set::Infinite::Simple->new();
	$a = Set::Infinite::Simple->new(1);
	$a = Set::Infinite::Simple->new(1,2);
	$a = Set::Infinite::Simple->new('2001-10-10','2001-10-20', 'Set::Infinite::Date'); # 'type' parameter

	$a = Set::Infinite::Simple->new(@b);	
	$a = Set::Infinite::Simple->new($b);	
		parameters can be:
		undef
		SCALAR => means a set like [1]
		SCALAR,SCALAR
		ARRAY of SCALAR
		Set::Infinite::Simple

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

Internal:

	$a = Set::Infinite::Simple->fastnew( object_begin, object_end, open_begin, open_end );	

=head1 CHANGES

	'new' parameter 'type'

moved to Set::Infinite.pm in version 0.30:

	tolerance
	real		
	integer		
	type

removed in version 0.30:

	tie
	add

=head1 TODO

	formatted string input like '[0..1]'

=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

require Exporter;

package Set::Infinite::Simple;

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(
	infinite minus_infinite separators null inf
	simple_null
	fastnew
);

use strict;
use Carp;

use Set::Infinite::Element_Inf qw(infinite minus_infinite null inf elem_undef);

our $infinite  = Set::Infinite::Element_Inf::infinite;
our $null      = Set::Infinite::Element_Inf::null;

use overload
	'<=>' => \&spaceship,
	qw("" as_string);

our @separators = (
	'[', ']',	# a closed interval 
	'(', ')',	# an open interval 
	'..',		# number separator
	','			# list separator
);

our $simple_null =           __PACKAGE__->fastnew(null, null, 1, 1);
our $simple_everything =     __PACKAGE__->fastnew(minus_infinite, infinite, 1, 1);
our $simple_infinite =       __PACKAGE__->fastnew(infinite, infinite, 1, 1);
our $simple_minus_infinite = __PACKAGE__->fastnew(minus_infinite, minus_infinite, 1, 1);

sub simple_null {
	return $simple_null;
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
	my ($i_beg, $i_end, $open_beg, $open_end);

	if ($tmp1->{a} < $tmp2->{a}) {
		# print "3";

		# if ($tmp1->{b} > $tmp2->{b}) {
		#	# print "6";
		#	return 1;
		# }

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

	# print "  [ simple: fastnew($i_beg, $i_end, $open_beg, $open_end ) ]\n";
	return $simple_null if 
		( $i_beg > $i_end ) or 
		( ($i_beg == $i_end) and ($open_beg or $open_end) ) ;
	return __PACKAGE__->fastnew($i_beg, $i_end, $open_beg, $open_end );
}

sub complement {
	my $self = shift;

	# do we have a parameter?

	if (@_) {
		my $a = shift;
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
	my ($tmp2, $tmp1, $tolerance) = @_; 

	#print " [SIM:UNION:@param] \n";
	#print " [SIM:UNION:$tmp1 U $tmp2] \n";

	return $tmp1 if Set::Infinite::Element_Inf::is_null($tmp2->{a});
	return $tmp2 if Set::Infinite::Element_Inf::is_null($tmp1->{a});


	if ($tolerance) {
		# "integer"
		#print " [SIM:UNION:INT ",ref($tmp1->{a}),"=",$tmp1->{a}," <=> ",ref($tmp1->{b}),"=",$tmp1->{b},"] \n";

		my $a1_open =  $tmp1->{open_begin} ? -$tolerance : $tolerance ;
		my $b1_open =  $tmp1->{open_end}   ? -$tolerance : $tolerance ;
		my $a2_open =  $tmp2->{open_begin} ? -$tolerance : $tolerance ;
		my $b2_open =  $tmp2->{open_end}   ? -$tolerance : $tolerance ;

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

	my $tmp = __PACKAGE__->fastnew($tmp1->{a}, $tmp1->{b}, $tmp1->{open_begin}, $tmp1->{open_end} );

	if ($tmp->{a} > $tmp2->{a}) {
			$tmp->{a} = $tmp2->{a};
			$tmp->{open_begin} = $tmp2->{open_begin};
	}
	elsif ($tmp->{a} == $tmp2->{a}) {
			$tmp->{open_begin} = $tmp2->{open_begin} if $tmp->{open_begin};
	}

	if ($tmp->{b} < $tmp2->{b}) {
			$tmp->{b} = $tmp2->{b};
			$tmp->{open_end} = $tmp2->{open_end};
	}
	elsif ($tmp->{b} == $tmp2->{b}) {
			$tmp->{open_end} = $tmp2->{open_end} if $tmp->{open_end};
	}
	return $tmp;
}

sub spaceship {
	my ($tmp1, $tmp2, $inverted) = @_;

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


sub new {
	my $class = shift;
	my ($self) = bless {}, $class; 
	my ($tmp, $tmp2, $type) = @_;

	# is it an array?
	if (ref($tmp) eq 'ARRAY') {
		# get 2 elements from it
		$tmp  = shift @{$tmp};
		$tmp2 = pop   @{$tmp};
	}

	# print " [SIMPLE:ADD=", $tmp, ";",$tmp2," (", ref(\$tmp), ";",ref(\$tmp2),")] ";

	# is it now defined?
 	unless (defined($tmp)) {
		$self->{a} = null;
		$self->{b} = null;
		return $self;
	}

	if (ref($tmp) eq $class) {
		# print " [SIMPLE:ISA=", $class,":", $tmp,"] ";
		%{$self} = %{$tmp};
		return $self;	
	}

	# print " [SIM:ADD:$tmp,$tmp2, is-null=",$tmp2->is_null,"]\n";

	 if ($type and (ref($tmp) ne $type) ) { 
		$tmp = new $type $tmp;
	}

	if (Set::Infinite::Element_Inf::is_null($tmp2)) {
		($self->{a}, $self->{b}) = ($tmp, $tmp);
	}
	else {
		 if ($type and (ref($tmp2) ne $type) ) {
			$tmp2 = new $type $tmp2;
		}

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


# our %new_count = ();
# our $count;

sub fastnew {

        # my @caller = caller(1);
	# $new_count{$caller[1] . $caller[2]} ++;
	# $count++;
	# if ($count > 20) {
	#         print " [",$caller[1],":",$caller[2]," ", $new_count{$caller[1] . $caller[2]}, " ]\n";
	# }

	bless { a => $_[1] , b => $_[2] , open_begin => $_[3] , open_end => $_[4] }, $_[0];

	# my ($self) = bless { a => $_[1] , b => $_[2] , open_begin => $_[3] , open_end => $_[4] }, $_[0];
	# return $self;
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


1;
