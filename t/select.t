#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Set::Infinite::Quantize
# This is work in progress
#

use strict;
use warnings;

use Set::Infinite qw($inf);
# use Set::Infinite::Quantize;
# use Set::Infinite::Select;

my $test = 0;
my ($result, $errors);
my @a;
my $c;

sub test {
	my ($header, $sub, $expected) = @_;
	$test++;
	#print "\t# $header \n";
	$result = eval $sub;
    $result = '' unless defined $result;
	if ("$expected" eq "$result") {
		print "ok $test";
	}
	else {
		print "not ok $test"; # \n\t# expected \"$expected\" got \"$result\"";
		print "\n\t# $sub expected \"$expected\" got \"$result\"  $@";
		$errors++;
	}
	print " \n";
}

sub stats {
	if ($errors) {
		#print "\n\t# Errors: $errors\n";
	}
	else {
		#print "\n\t# No errors.\n";
	}
}

print "1..26\n";
$| = 1;

# select
my $s;

$a = Set::Infinite->new([1,25]);
test ( '', 
  ' $a->quantize(quant=>1)->select( freq => 6, by => [0,2], count => 3 ) ', 
  '[1..2),[3..4),[7..8),[9..10),[13..14),[15..16)');

$a = $a;  # clear warnings

# NOTE: no longer passes this test, since quantize() removes 'undef' values
# $a = Set::Infinite->new([9,25],[100,110]);
# test ( '', 
#  ' $a->quantize(quant=>1)->select( freq => 4, by => [0,1,2] ) ',
#  '[9..10),[10..11),[11..12),[13..14),[14..15),[15..16),[17..18),[18..19),[19..20),[21..22),[22..23),[23..24),[25..26),[101..102),[102..103),[103..104),[105..106),[106..107),[107..108),[109..110),[110..111)' );


# These tests are here for comparing results with "unbounded" tests below

# 'FIRST', bounded
$a = Set::Infinite->new([25,50])->quantize;
$c = $a->select(by => [2,3], count => 2, freq => 5 );
# warn "$c";
@a = $c->first(2);
test ("first, tail", '"@a"', '[27..28),[28..29) [32..33),[33..34)');
@a = defined $a[1] ? $a[1]->first(2) : ();
test ("first, tail", '"@a"', '[32..33),[33..34)');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '');


# 'LAST', bounded
# TODO!


# tests for select on unbounded sets


# 'LAST'
# TODO: last() not implemented
# $a = Set::Infinite->new([-$inf, 25]);
# warn $a;
# $b = $a->quantize->select(by => [-3,-2]);
# warn $b;



# 'FIRST'
$a = Set::Infinite->new([25,$inf])->quantize;
# warn $a;
$b = $a->select(by => [2,3]);
# warn $b;
@a = $b->first;
test ("first, tail", '"@a"', '[27..28) [28..29)');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '[28..29)');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '');


# TODO: complement/first is not implemented
# warn "second of $a is ". $a->complement( $a->first )->first;

# @a = $a->first;
# warn "first, tail is @a";
# warn "first of $b is ".$b->first;

$c = $a->select(by => [2,3], count => 2, freq => 5 );
@a = $c->first;
test ("first, tail", '"@a"', '[27..28) Too complex');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '[28..29) Too complex');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '[32..33) [33..34)');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '[33..34)');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '');

# TODO: test with negative values
$c = $a->select(by => [2,3], freq => 5 );
@a = $c->first;
test ("first, tail", '"@a"', '[27..28) Too complex');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '[28..29) Too complex');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '[32..33) Too complex');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '[33..34) Too complex');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '[37..38) Too complex');

# $Set::Infinite::TRACE = 1;
# count
$a = Set::Infinite->new([25,$inf])->quantize;
# warn $a;
$b = $a->select(count => 2);
# warn $b;
@a = $b->first;
test ("first, tail", '"@a"', '[25..26) [26..27)');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '[26..27)');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '');
$Set::Infinite::TRACE = 0;

# freq+count
$a = Set::Infinite->new([25,$inf])->quantize;
# warn $a;
$b = $a->select(count => 2, freq => 5);
# warn $b;
@a = $b->first;
test ("first, tail", '"@a"', '[25..26) Too complex');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '[30..31)');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '');

# freq
$a = Set::Infinite->new([25,$inf])->quantize;
# warn $a;
$b = $a->select(freq => 5);
# warn $b;
@a = $b->first;
test ("first, tail", '"@a"', '[25..26) Too complex');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '[30..31) Too complex');
@a = defined $a[1] ? $a[1]->first : ();
test ("first, tail", '"@a"', '[35..36) Too complex');


1;
