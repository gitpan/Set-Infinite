#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

	Set::Infinite::_Simple - an interval of 2 scalars

=head1 SYNOPSIS

	This is a building block for Set::Infinite.
	Please use Set::Infinite instead.

	use Set::Infinite::_Simple;

	$a = Set::Infinite::_simple_new(1,2);
	print Set::Infinite::_simple_union($a, [5,6]);

=head1 USAGE

    # obsolete docs! see Synopsis.

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

	print $a;

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

=head1 TODO

	formatted string input like '[0..1]'

=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

require Exporter;

package Set::Infinite;


use strict;
use Carp;

use Set::Infinite::Element_Inf qw(infinite minus_infinite null inf elem_undef);

our @separators = (
	'[', ']',	# a closed interval 
	'(', ')',	# an open interval 
	'..',		# number separator
	','			# list separator
);

our $simple_null =           _simple_fastnew(null, null, 1, 1);
our $simple_everything =     _simple_fastnew(minus_infinite, infinite, 1, 1);
our $simple_infinite =       _simple_fastnew(infinite, infinite, 1, 1);
our $simple_minus_infinite = _simple_fastnew(minus_infinite, minus_infinite, 1, 1);

sub _simple_null {
	return $simple_null;
}

sub separators {
	return $separators[shift] if $#{@_} == 0;
	@separators = @_ if @_;
	return @separators;
}

sub _simple_intersects {
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




sub _simple_complement {
	my $self = shift;

	# do we have a parameter?

	if (@_) {
            carp "_simple_complement no longer accepts parameters";
	}

	# print " [CPL-S:",$self,"] ";

	return $simple_everything if Set::Infinite::Element_Inf::is_null($self->{a});

	my $tmp1 = _simple_fastnew(minus_infinite, $self->{a}, 1, ! $self->{open_begin} );

	# print " [CPL-S:#1:",$tmp1,"] ";

	my $tmp2 = _simple_fastnew($self->{b}, infinite, ! $self->{open_end}, 1);

	# print " [CPL-S:#2:",__PACKAGE__,":",$tmp2,"=(",$self->{b},", ",infinite,")] ";

	if ($tmp2->{a} == infinite) {
		return $simple_null if ($tmp1->{b} == minus_infinite);
		return $tmp1;
	}

	return $tmp2 if ($tmp1->{b} == minus_infinite);

	#print " [CPL-S:RES:",$tmp1 ,";", $tmp2,"] ";

	return ($tmp1 , $tmp2);
}

sub _simple_union {
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

	my $tmp = _simple_fastnew($tmp1->{a}, $tmp1->{b}, $tmp1->{open_begin}, $tmp1->{open_end} );
    #my %$tmp = (%$tmp1);

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

sub _simple_spaceship {
	my ($tmp1, $tmp2, $inverted) = @_;
    my $cmp = $tmp1->{a} <=> $tmp2->{a};
	if ($inverted) {
		return $cmp ? - $cmp : $tmp2->{b} <=> $tmp1->{b}; 
	}
	return $cmp ? $cmp : $tmp1->{b} <=> $tmp2->{b};
}

sub _simple_new {
	# my $class = shift;
	my $self;
	# my ($self) = {};    # bless {}, $class; 
	my $tmp = shift;
	# my ($tmp, $tmp2, $type) = @_;

	# print " [SIMPLE:ADD=", $tmp, ";",$tmp2," (", ref(\$tmp), ";",ref(\$tmp2),")] ";
 	unless (defined($tmp)) {
		$self->{a} = $self->{b} = null;
		return $self;
	}

	if (ref($tmp) eq 'HASH') {
		# print " [SIMPLE:ISA=", $class,":", $tmp,"] ";
		return $tmp;
		# %{$self} = %{$tmp};
		# return $self;	
	}

	# print " [SIM:ADD:$tmp,$tmp2]\n";   # is-null=",$tmp2->is_null,"]\n";
	my ($tmp2, $type) = @_;
	if ($type and (ref($tmp) ne $type) ) { 
		$tmp = new $type $tmp;
	}

	if (Set::Infinite::Element_Inf::is_null($tmp2)) {
		$self->{a} = $self->{b} = $tmp;
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


sub _simple_fastnew {
	{ a => $_[0] , b => $_[1] , open_begin => $_[2] , open_end => $_[3] };
}

sub _simple_as_string {
	my $self = shift;
	my $s;
	# print " [simple:string] ";

    $self->{open_begin} = 1 if ($self->{a} == minus_infinite );
    $self->{open_end}   = 1 if ($self->{b} == infinite );

	# return null if $self->is_null;
	my $tmp1 = "$self->{a}";
	my $tmp2 = exists($self->{b}) ? "$self->{b}" : $tmp1;
	return $tmp1 if $tmp1 eq $tmp2;
	$s = $self->{open_begin} ? $separators[2] : $separators[0];
	$s .= $tmp1 . $separators[4] . $tmp2;
	$s .= $self->{open_end} ? $separators[3] : $separators[1];
	return $s;
}


1;
