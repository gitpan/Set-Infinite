#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Set::Infinite::Simple
# This is work in progress
#


use Set::Infinite::Simple qw(infinite minus_infinite type);
use Math::BigFloat;

my $errors = 0;
my $test = 0;

print "1..16\n";

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


type('Math::BigFloat');

#print "Contains\n";

$a = Set::Infinite::Simple->new([new Math::BigFloat(3),new Math::BigFloat(6)]);
test ("set", '$a', "[3...6.]");
test ("contains [4..5]  ", '$a->contains(4,5)',   "1");
test ("contains [3..5]  ", '$a->contains(3,5)',   "1");
test ("contains [2..5]  ", '$a->contains(2,5)',   "0");
test ("contains [4..15] ", '$a->contains(4,15)',  "0");
test ("contains [15..16]", '$a->contains(15,16)', "0");

#print "Operations on open sets\n";
$a = Set::Infinite::Simple->new(new Math::BigFloat(1),'inf');
test ("set", '$a', "[1...inf)");
$a = $a->complement;
test ("complement : ", '$a', "(-inf..1.)");
$b = $a;
test ("copy : ", '$b', "(-inf..1.)");
test ("complement : ",    '$a->complement',  "[1...inf)");

#print "Complement:\n";
test ("(1,1)  ", 'Set::Infinite::Simple->new(new Math::BigFloat(1),new Math::BigFloat(1))->complement', "(1...inf)");
test ("(null) ", 	'Set::Infinite::Simple->new()->complement', "(-inf..inf)");
test ("(1,infinite)", 	'Set::Infinite::Simple->new(1,"inf")->complement', "(-inf..1.)");
test ("(-infinite,1)", 	'Set::Infinite::Simple->new("-inf",1)->complement', "(1...inf)");
test ("(-infinite,infinite)", 	'Set::Infinite::Simple->new("-inf","inf")->complement', "null");
test ("complement(10..20) (5,15) : ", 	'Set::Infinite::Simple->new(new Math::BigFloat(10),new Math::BigFloat(20))->complement(5,15)', "(15...20.]");

stats;
1;
