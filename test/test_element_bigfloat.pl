#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Set::Infinite::Element
#

use Set::Infinite::Element qw(infinite type);
use Math::BigFloat;

my $errors = 0;

sub test {
	my ($header, $sub, $expected) = @_;
	print "\t$header \t--> ";
	$result = eval $sub;
	if ("$expected" eq "$result") {
		print "ok";
	}
	else {
		print "expected \"$expected\" got \"$result\"";
		$errors++;
	}
	print " \n";
}

sub stats {
	if ($errors) {
		print "\nErrors: $errors\n";
	}
	else {
		print "\nNo errors.\n";
	}
}

print "Testing sort\n";

$big3 = new Math::BigFloat(3.3333345);

@a = (
	1, 
	Set::Infinite::Element->new( new Math::BigFloat(0)), 
	infinite,	
	Set::Infinite::Element->new( $big3 ), 
	2, 0 - infinite, 5, 4, infinite
);

test ("Array", 'join(",", @a)', "1,0.,inf,$big3,2,-inf,5,4,inf");
@b = sort @a;
test ("Sorted", 'join(",", @b)', "-inf,0.,1,2,$big3,4,5,inf,inf");

type('Math::BigFloat');
@b = sort @a;
test ("Sorted with type", 'join(",", @b)', "-inf,0.,1,2,$big3,4,5,inf,inf");

print "Testing add, sub\n";
#test ("(infinite is ", infinite, ")\n";
test ("1 + 2",'Set::Infinite::Element->new(1) + Set::Infinite::Element->new(2)', "3.");
test ("1 + inf",'Set::Infinite::Element->new(1) + Set::Infinite::Element->new("inf")', "inf");
test ("1 - inf",'Set::Infinite::Element->new(1) - Set::Infinite::Element->new("inf")', "-inf");

stats;
1;