#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

	Set::Infinite::Element - a set member

=head1 USAGE

	$a = Set::Infinite::Element->new();
	$a = Set::Infinite::Element->new(1);
	$a = Set::Infinite::Element->new( new Math::BigFloat(3.333) );

	$logic = $a->is_null;

	@b = sort @a;
	print $a;

	tie $a, 'Set::Infinite::Element', 1;

Global:

	type($i)	chooses an object data type. 
		default is none (a normal perl $something scalar).
		example: 'Math::BigFloat', 'Math::BigInt'


=head1 DESCRIPTION

	This is a building block for Set::Infinite::Simple.
	Please use Set::Infinite instead.

=head1 TODO

	Local versions of quantizer, type

=head1 CAVEATS

	BigFloat members sort wrongly when mixed with Real members. 
	It looks like a BigFloat 'cmp' problem.

=head1 CHANGES

v.0.15

	Functions moved to Element_Inf:

	infinite		returns an 'infinite' number.
	minus_infinite	returns '-infinite' number.
	null			returns 'null'.

	infinite($i)	chooses 'infinite' name. default is 'inf'
	null($i)		chooses 'null' name. default is 'null'

=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

require Exporter;

package Set::Infinite::Element;
$VERSION = "0.16";

my $package        = 'Set::Infinite::Element';
@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(infinite minus_infinite type null quantizer is_null inf elem_undef);

use strict;
use Carp;

use overload
	'<=>' => \&spaceship,
	'cmp' => \&cmp,
	'+'   => \&add,
	'-'   => \&sub,
	'/'   => \&div,
	qw("" as_string),
	fallback => 1;

use Set::Infinite::Element_Inf qw(infinite minus_infinite null inf elem_undef);

sub inf();
sub infinite();
sub minus_infinite();
sub null();

our $type = '';
our $infinite  = Set::Infinite::Element_Inf::infinite;
our $null      = Set::Infinite::Element_Inf::null;
our $quantizer = 'Set::Infinite::Quantize';

sub type {
	if (@_) {
		$type = pop;
		eval "use $type";
			carp "Warning: can't start $type package: $@" if $@;

		my $tmp = eval '&' . $type . '::quantizer';
		if ($tmp) {
			$quantizer = $tmp;
			eval "use $quantizer"; 
				carp "Warning: can't start $type package: $@" if $@;
			# print " [ELEM:quantizer $type $tmp]\n";
		}

		#my $tmp = &Set::Infinite::Date::quantizer;
		#print " [ELEM:quantizer $type $tmp]\n";

		if ( (eval "(new $type (4)) cmp (new $type (3))") != 1) {
			if ((eval "new $type (4)") != 4) {
				carp "Warning: can't start $type package";
			}
			else {
				carp "Warning: $type can't `cmp'";
			}
		}
	}
	return $type;
}

sub quantizer {
	# if (@_) {
	#	$quantizer = pop;
	# }
	return $quantizer;
}


sub quantize {
	my $self = shift;
	my (@a);
	tie @a, $quantizer, @_, $self;
	return @a;
}

sub is_null {
	my $self = pop;
	return Set::Infinite::Element_Inf::is_null($self->{v});
}

sub div {
	my ($tmp1, $tmp2) = @_;
	return $tmp1->{v} / $tmp2;
}

sub add {
	my ($tmp1, $tmp2) = @_;
	return $tmp1->{v} + $tmp2;
}

sub sub {
	my ($tmp1, $tmp2, $inverted) = @_;
	return $tmp1->{v} - $tmp2 unless $inverted;
	return $tmp2 - $tmp1->{v};
}

sub spaceship {
	my ($tmp1, $tmp2, $inverted) = @_;
	my $res;
	# my ($stmp1, $stmp2);

	# print " [ELEM:CMP:",ref($tmp1),"=$tmp1 <=> ",ref($tmp2),"=$tmp2] \n";


	if ( ref($tmp2) and $tmp2->isa(__PACKAGE__) ) {

		#$res = ( $tmp1->{v} <=> $tmp2->{v} ) unless $inverted; 
		#$res = ( $tmp2->{v} <=> $tmp1->{v} ) if $inverted; 
		#return $res if $res;

		$tmp2 = $tmp2->{v};
	} 

	$tmp1 = $tmp1->{v};

	if ($inverted) {
		($tmp2, $tmp1) = ($tmp1, $tmp2);
	}


	$res = ( $tmp1 <=> $tmp2 ); 
	unless ($res) {
		$res = ( $tmp1 cmp $tmp2 ); 
	}

	# print " [ELEM:CMP:",ref($tmp1),"=$tmp1 <=> ",ref($tmp2),"=$tmp2 = $res] \n";
	return $res;
}

sub cmp {
	return spaceship @_;
}

sub new {
	my ($self) = bless {}, shift;
	my $val = shift;

	unless (defined($val)) {
		$self->{v} = null;
		# return $self;
	}

	elsif (ref($val)) {
		if ( $val->isa(__PACKAGE__) ) {
			$self->{v} = $val->{v};
			# return $self;
		}
		else {
			#print " [REF:$val] ";
			$self->{v} = $val;
			# return $self;
		}
	}

	elsif ($type) {
		$self->{v} = new $type $val;
	}
	else {
		$self->{v} = $val;
	}

	return $self;
}

sub as_string {
	my ($self) = shift;
	return "$self->{v}";
}

# TIE

sub TIESCALAR {
	my $class = shift;
	my $self = $class->new(@_);
	return $self;
}

sub FETCH {
	my ($self) = shift;
	return $self->as_string;
}

sub STORE {
	my ($self) = shift;
	my $data = shift;
	$self = new($data, @_);
	return @_;
}

sub DESTROY {
}

1;