package Set::Infinite::Offset;
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;
require Exporter;
use Set::Infinite::Function;
use Set::Infinite::Arithmetic;
# use Set::Infinite::Element_Inf qw(inf minus_inf);
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


1;

