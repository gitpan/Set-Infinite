#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Set::Infinite backtracking

use strict;
use warnings;

# use Set::Infinite::Quantize;
use Set::Infinite qw(inf);

my ($a, $a_quant, $b, $c, $d, $finite, $q);


my $test = 0;
my ($result, $errors);

sub test {
	my ($header, $sub, $expected) = @_;
	$test++;
	#print "\t# $header \n";
	$result = eval $sub;
	if ("$expected" eq "$result") {
		print "ok $test";
	}
	else {
		print "not ok $test"; # \n\t# expected \"$expected\" got \"$result\"";
		print "\n\t# $sub expected \"$expected\" got \"$result\"";
		$errors++;
	}
	print " \n";
}


print "1..19\n";

 $a = Set::Infinite->new([-&inf,15]);
 $a_quant = $a->quantize(quant => 1);
 $finite = Set::Infinite->new([10,20]);
 $q = $a->quantize(quant => 1);

 # print "a = $a\n";

# 1 "too complex"
	# print "q = ",$q,"\n";
	test ('', '$q', $Set::Infinite::too_complex);

# 2 scalar
	# print "r = ",$q->intersection(10,20),"\n";
	test ('', '$q->intersection(10,20)', '[10..16)');

# 3 "date"
	$a = Set::Infinite->new([-&inf,3800]);
	# print "s = ",$a->quantize(quant => 1, unit => 'hours')->intersection(1000,15000),"\n";
	test ('', '$a->quantize(quant => 1, unit => \'hours\')->intersection(1000,15000)', 
		'[1000..7200)');

# 4 almost-intersecting "date"
	$a = Set::Infinite->new([-&inf,3800]);
	# print "t = ",$a->quantize(quant => 1, unit => 'hours')->intersection(3700,15000),"\n";
	test ('', '$a->quantize(quant => 1, unit => \'hours\')->intersection(3700,15000)', 
		'[3700..7200)');
	test ('', '$a->quantize(quant => 1, unit => \'hours\')->intersection(3900,15000)', 
		'[3900..7200)');

# 6 null "date"
	# print "u = ",$a->quantize(quant => 1, unit => 'hours')->intersection(9000,15000),"\n";
	test ('', '$a->quantize(quant => 1, unit => \'hours\')->intersection(9000,15000)', 
		'');

# 7 recursive 
	# print "v: ", $a->quantize(quant => 1)->quantize(quant => 1)->intersection(10,20), "\n";
	test ('', '$a->quantize(quant => 1)->quantize(quant => 1)->intersection(10,20)', 
		'[10..20]');

# 8 intersection with 'b' complex
	# print "w: ", $finite->intersection( $a->quantize(quant => 1) ), "\n";
	test ('', '$finite->intersection( $a->quantize(quant => 1) )', 
		'[10..20]');

# 9 - 12 intersection with both 'a' and 'b' complex
	$b = Set::Infinite->new([10,&inf])->quantize(quant => 1);
	$c = Set::Infinite->new([20,&inf])->quantize(quant => 1);
	$d = Set::Infinite->new([-&inf,12])->quantize(quant => 1);

	# intersecting 
	# print "x = ",$a_quant->intersection($b),"\n";
	test ('', '$a_quant->intersection($b)', 
		'[10..16)');

	# non-intersecting
	# print "y = ",$a_quant->intersection($c),"\n";
	test ('', '$a_quant->intersection($c)', 
		'');

	# intersecting but too complex
	# print "z = ",$a_quant->intersection($d),"\n";
	test ('', '$a_quant->intersection($d)', 
		$Set::Infinite::too_complex);

	# intersecting but too complex, then intersect again
	# print "i = ",$a_quant->intersection($d)->intersection($finite),"\n";
	test ('', '$a_quant->intersection($d)->intersection($finite)', 
		'[10..13)');

# 13 - 15 offset
	# print "j = ",$a->quantize(quant => 4)->offset( value => [1,-1] )->intersection($finite),"\n";
	test ('', '$a->quantize(quant => 4)->offset( value => [1,-1] )->intersection($finite)', 
		'[10..11),[13..15),[17..19)');

	# BIG offset
	# print "k = ",$a->quantize(quant => 4)->offset( value => [20,18] )->intersection($finite),"\n";
	test ('', '$a->quantize(quant => 4)->offset( value => [20,18] )->intersection($finite)', 
		'[12..14),[16..18),20');

	# intersecting, both complex
	$a = Set::Infinite->new([-&inf,15]);
	test ('', '$a->quantize(quant => 4)->offset( value => [1,-1] )->intersection($b)->intersection($finite)', 
		'[10..11),[13..15)');

# select
	# print "l = ", $a->quantize(quant => 2)->select( freq => 3 )->intersection($finite), "\n";
	test ('', '$a->quantize(quant => 1)->select( freq => 2 )->intersection($finite)', 
		'[10..11),[12..13),[14..15)');

	# BIG, negative select
	# -- wrong! (TODO ????)
	# test ('', '$a->quantize(quant => 1)->select( freq => 2, by => [-10,10] )->intersection($finite)', 
	#	'[10..11),[12..13),[14..15)');

	# intersecting, both complex
	#  (TODO ????)

# intersects

	# intersecting 
	test ('', '$a_quant->intersects($b)', 
		'1');

	# non-intersecting
	test ('', '$a_quant->intersects($c)', 
		'0');

# union
	test ('', '$a_quant->union([50,60])->intersection([0,100])', 
		'[0..16),[50..60]');

# complement
	#  (TODO ????)

# min
	#  (TODO ????)

# max
	#  (TODO ????)

# span
	#  (TODO ????)

# size
	#  (TODO ????)

# contains
	# -- wrong! (TODO ????)
	# test ('', '$a_quant->contains([0,100])', 
	#	'');

1;