#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Set::Infinite::Element
#

use Set::Infinite::Element qw(infinite);
use Set::Infinite::Element_Inf qw(inf);

my $errors = 0;
my $test = 0;

print "1..29\n";


sub test {
	my ($header, $sub, $expected) = @_;
	$test++;
	#print "\t# $header \n";
	$result = eval $sub;
	if ("$expected" eq "$result") {
		print "ok $test";
	}
	else {
		print "not ok $test"; 
		print "\n\t# expected \"$expected\" got \"$result\"";
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


#print "Testing new\n";

test ('null',	'Set::Infinite::Element->new()' ,	'null');
test ("null",	'Set::Infinite::Element->new()',		"null");
test ("0",		'Set::Infinite::Element->new(0)',	"0");

$a = Set::Infinite::Element->new();
test ("null",	'$a',	'null');
$a = Set::Infinite::Element->new(0);
test ("0",		'$a',	'0');

test ("infinite",
	'Set::Infinite::Element->new(inf)', inf);

$a = Set::Infinite::Element->new(inf);
test ("infinite", '$a', 'inf');

$a = Set::Infinite::Element->new(- inf);
test ("-infinite", '$a', '-inf');

$a = - Set::Infinite::Element->new(infinite);
test ("-infinite", '$a', '-inf');

#print "Testing sort\n";

test ("-infinite cmp infinite", '
  Set::Infinite::Element->new(- inf) cmp
  Set::Infinite::Element->new(inf)', "-1");
test ("-infinite cmp 10", '
  Set::Infinite::Element->new(- inf) cmp
  Set::Infinite::Element->new("10")', "-1");
test ("-infinite cmp 10", '
  Set::Infinite::Element->new(- inf) cmp
  10', "-1");
test ("-infinite cmp 0", 
  'Set::Infinite::Element->new(- inf) cmp
  0', "-1");

test ("infinite cmp -infinite", 
  'Set::Infinite::Element->new(inf) cmp
  Set::Infinite::Element->new(- inf)', "1");
test ("infinite cmp -1", 
  'Set::Infinite::Element->new(inf) cmp
  -1', "1");
test ("infinite cmp 0", 
  'Set::Infinite::Element->new(inf) cmp
  0', "1");
test ("infinite cmp 1", 
  'Set::Infinite::Element->new(inf) cmp
  1', "1");
test ("infinite cmp 2", 
  'Set::Infinite::Element->new(inf) cmp
  2', "1");

test ("infinite cmp inf", 
  'Set::Infinite::Element->new(inf) cmp
  inf', "0");

test ("-infinite cmp -inf", 
  'Set::Infinite::Element->new(- inf) cmp
  - inf', "0");

@a = (
	1, 0, infinite,	3, 2, 0 - infinite, 5, 4, infinite
);

test ("Array", 'join(",", @a)', "1,0,inf,3,2,-inf,5,4,inf");
@b = sort @a;
test ("Sorted", 'join(",", @b)', "-inf,0,1,2,3,4,5,inf,inf");

#print "Testing add, sub\n";
#test ("(infinite is ", infinite, ")\n";
test ("1 + 2",'Set::Infinite::Element->new(1) + Set::Infinite::Element->new(2)', "3");
test ("1 + inf",'Set::Infinite::Element->new(1) + Set::Infinite::Element->new(inf)', inf);
test ("1 - inf",'Set::Infinite::Element->new(1) - Set::Infinite::Element->new(inf)', - inf);

#print "Testing literals\n";
# test ("a + b",'Set::Infinite::Element->new("a") + Set::Infinite::Element->new("b")', "0");
test ("a + inf",'Set::Infinite::Element->new("a") + Set::Infinite::Element->new(inf)', inf);
test ("a - inf",'Set::Infinite::Element->new("a") - Set::Infinite::Element->new(inf)', - inf);

@a = (
	'c','a','b', 1, 0, infinite,	3, 2, 0 - infinite, 5, 4, infinite
);
test ("Array", 'join(",", @a)', "c,a,b,1,0,inf,3,2,-inf,5,4,inf");
@b = sort @a;
test ("Sorted", 'join(",", @b)', "-inf,0,1,2,3,4,5,a,b,c,inf,inf");

stats;
1;