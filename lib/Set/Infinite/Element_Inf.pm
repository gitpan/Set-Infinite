#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

    Set::Infinite::Element_Inf - a set member

=head1 USAGE

Global:
    infinite        returns an 'infinity' number.
    minus_infinite  returns '-infinity' number.

=head1 DESCRIPTION

    This is a building block for Set::Infinite.
    Please use Set::Infinite instead.

=head1 TODO

    infinite($i)    chooses 'infinity' name. default is 'inf'


=head1 AUTHOR

    Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

require Exporter;

package Set::Infinite::Element_Inf;
$VERSION = "0.18";

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(infinite minus_infinite minus_inf null is_null elem_undef inf
  o_infinite o_minus_infinite);

use strict;
use Carp;

use overload
    '<=>' => \&spaceship,
    '+'   => \&add,
    '-'   => \&sub,
    qw("" as_string),
    fallback => 1;


our $infinite       = rand() * 1e100;   # 'inf' is some very random constant;
our $null           = undef;   
our $undef          = undef;
our $minus_infinite = -$infinite;  

our $o_infinite =       bless \$infinite,       __PACKAGE__;
our $o_minus_infinite = bless \$minus_infinite, __PACKAGE__;
our $o_null =           undef;   
our $o_elem_undef =     undef;  

sub infinite ()       { $o_infinite }
sub inf ()            { $o_infinite }
sub minus_infinite () { $o_minus_infinite }
sub minus_inf ()      { $o_minus_infinite }
sub null ()           { $o_null }
sub elem_undef ()     { $o_elem_undef }

sub as_string ()      { ${$_[0]} == $infinite ? 'inf' : '-inf' }

sub is_null           { ! defined $_[-1] }

sub add { ${$_[0]} == $infinite ? $o_infinite : $o_minus_infinite }

our @inverted = ( $infinite, $minus_infinite );

sub sub { ${$_[0]} == $inverted[$_[2]] ? $o_infinite : $o_minus_infinite }

sub spaceship {
    return 0 if ${$_[0]} == $_[1];
    ${$_[0]} == $inverted[$_[2]] ? 1 : -1;
}

1;
