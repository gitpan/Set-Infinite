#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for first()
#

use strict;
use warnings;

use Set::Infinite qw($inf);
$| = 1;

my $test = 0;
my ($result, $errors);
my @a;
my $c;
my $span;
$b=$b;  # clear a warning

sub test {
	my ($header, $sub, $expected) = @_;
	$test++;
	#print "\t# $header \n";
    $result = eval $sub;
    $result = '' unless defined $result;
	if ("$expected" eq "$result") {
		print "ok $test - $header";
	}
	else {
		print "not ok $test\n    # $header\n"; # \n\t# expected \"$expected\" got \"$result\"";
		print "    # $sub expected \"$expected\" got \"$result\"  $@";
		$errors++;
	}
	print " \n";
}

print "1..14\n";
$| = 1;

# $Set::Infinite::TRACE = 1;
# $Set::Infinite::PRETTY_PRINT = 1;

$a = Set::Infinite->new([10],[30]);
test ("until after,after", 
    '$a->until( [20],[40] )', "[10..20),[30..40)");
test ("until before,inside",
    '$a->until( [0],[20] )', "(-$inf..0),[10..20),[30..$inf)");
test ("until out of sync",
    '$a->until( [-20],[0],[20],[40],[60] )', "(-$inf..0),[10..20),[30..40)");

test ("until nothing",
    '$a->until()',
    "[10..$inf)");
$a = Set::Infinite->new();
test ("since nothing",
    '$a->until(10)',
    "(-$inf..10)");
test ("since nothing until nothing",
    '$a->until()',
    "(-$inf..$inf)");
 
# unbounded recurrences

# $Set::Infinite::TRACE = 1;
# $Set::Infinite::PRETTY_PRINT = 1;

# $a = ...0,20,40,60... forever
$a = Set::Infinite->new( -$inf, $inf )
    ->quantize( quant => 20 )
    ->offset( mode => 'begin', value => [0,0] );
# $b = ...10,30,50,70... forever
$b = $a->offset( value => [10,10] );
# warn "a: ". $a->intersection(5,45);
# warn "b: ". $b->intersection(5,45);
test ("until unbounded recurrence",
    '$a->until( $b )->intersection(5,45)', 
    "[5..10),[20..30),[40..45]");
test ("until unbounded recurrence, later",
    '$a->until( $b )->intersection(15,55)',
    "[20..30),[40..50)");

# let's test if contains() works properly with unbounded recurrences
# because we'll need that

test ("contains - unbounded recurrence",
    '$a->contains( 20 )', 1 ); 
test ("doesn't contain - unbounded recurrence",
    '$a->contains( 15 )', 0 );

# intersection with small sets is heavily used by backtracking code
# when checking timezones

test ("until - intersection - small set",
    '$a->until( $b )->intersection(22,28)',
    "[22..28]");
test ("until - non-intersection - small set",
    '$a->until( $b )->intersection(32,38)',
    "");

# $Set::Infinite::TRACE = 1;
# $Set::Infinite::PRETTY_PRINT = 1;
test ("until - contains - small set",
    '$a->until( $b )->contains(22,28)',
    "1");
$Set::Infinite::TRACE = 0;
$Set::Infinite::PRETTY_PRINT = 0;
test ("until - doesn't contain - small set",
    '$a->until( $b )->contains(32,38)',
    "0");

# first, min, max
# - TODO!

1;
