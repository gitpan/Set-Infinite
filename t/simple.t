#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Set::Infinite::Simple
# This is work in progress
#


use Set::Infinite::Simple qw(infinite minus_infinite);

my $errors = 0;
my $test = 0;

print "1..88\n";

sub test {
	my ($header, $sub, $expected) = @_;
	$test++;
	# print "\t# $header \n";
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
		# print "\n\t# Errors: $errors\n";
	}
	else {
		# print "\n\t# No errors.\n";
	}
}



# print "Contains\n";
$a = Set::Infinite::Simple->new(3,6);
test ("set", '$a', "[3..6]");
$a = Set::Infinite::Simple->new([3,6]);
test ("set", '$a', "[3..6]");
test ("contains [4..5]  ", $a->contains(4,5),   "1");
test ("contains [3..5]  ", $a->contains(3,5),   "1");
test ("contains [2..5]  ", $a->contains(2,5),   "0");
test ("contains [4..15] ", $a->contains(4,15),  "0");
test ("contains [15..16]", $a->contains(15,16), "0");

# print "Operations on open sets\n";
$a = Set::Infinite::Simple->new(1,inf);
test ("set", '$a', "[1..inf)");
$a = $a->complement;
test ("complement : ", '$a', "(-inf..1)");
$b = $a;
test ("copy : ", '$b', "(-inf..1)");
test ("complement : ",    '$a->complement',  "[1..inf)");
test ("union [-1..0] : ", '$a->union(-1,0)', "(-inf..1)");
test ("union [0..1]  : ", '$a->union(0,1)',  "(-inf..1]");
test ("union [1..2]  : ", '$a->union(1,2)',  "(-inf..2]");
test ("union [2..3]  : ", 'join(",",$a->union(2,3))',  "(-inf..1),[2..3]");

# print "Testing 'null' and (0..0)\n";

$a = Set::Infinite::Simple->new();
test ("null", '$a', "null");

$a = Set::Infinite::Simple->new('null');
test ("null", '$a', "null");

$a = Set::Infinite::Simple->new(undef);
test ("null", '$a', "null");

$a = Set::Infinite::Simple->new();
test ("(0,0) intersection to null",'$a->intersects(0,0)',"0");
test ("(0,0) intersection to null",'$a->intersection(0,0)',"null");

$a = Set::Infinite::Simple->new(0,0);
test ("(0,0) intersection to null",'$a->intersects()',"0"); 
test ("(0,0) intersection to null",'$a->intersection()',"null");

test ("(0,0) intersection to 0",'$a->intersects(0)',"1");
test ("(0,0) intersection to 0",'$a->intersection(0)',"0");

$a = Set::Infinite::Simple->new();
test ("(0,0) union to null : ",'$a->union(0,0)',"0");

$a = Set::Infinite::Simple->new(0,0);
test ("(0,0) union to null : ",'$a->union()',"0");

$a = Set::Infinite::Simple->new(0,0);
test ("(0,0) intersection to (1,1) : ",'$a->intersects(1,1)',"0");
test ("(0,0) intersection to (1,1) : ",'$a->intersection(1,1)->as_string',"null");


# print "Testing ",infinite,"\n";

$a = Set::Infinite::Simple->new(infinite);
test ("infinite", '$a', "inf");

$a = Set::Infinite::Simple->new(3,infinite);
test ("(3 .. infinite)", '$a', "[3..inf)");

test ("intersection (4,5) : ", '$a->intersection(4,5)',"[4..5]");
test ("intersection (-infinite, 5)  : ", '$a->intersection("-inf",5)',"[3..5]");
test ("intersection (-infinite, 5)  : ", '$a->intersection(-"inf",5)',"[3..5]");

# print "Testing new\n";

$a = Set::Infinite::Simple->new(3);
test ("Interval from single scalar", '$a', "3");

$a = Set::Infinite::Simple->new(3,4);
test ("Interval from scalar", '$a', "[3..4]");

$a = Set::Infinite::Simple->new([3,4]);
test ("Interval from array", '$a', "[3..4]");

$a = Set::Infinite::Simple->new([3]);
test ("Interval from array with single scalar", '$a', "3");

$b = Set::Infinite::Simple->new([3,4]);
$a = Set::Infinite::Simple->new($b);
test ("Interval from interval", '$a', "[3..4]");

# "hash" removed because it breaks "date"
#%a = ('a'=>3, 'b'=>4);
#$a = Set::Infinite::Simple->new(%a);
#test ("Interval from hash", '$a', "[3..4]");


# print "Real and integer:\n";

$a = Set::Infinite::Simple->new(2,3);
$a->real;
test ("union real (2,3) with (1) ",'$a->union(Set::Infinite::Simple->new(1))', "1");

$a = Set::Infinite::Simple->new(2,3);
$a->integer;
test ("union int  (2,3) with (1): ",'$a->union(Set::Infinite::Simple->new(1))', "[1..3]");


# print "Intersection with scalar:\n";

$a = Set::Infinite::Simple->new(2,1);
test ("Interval:", '$a', "[1..2]");
test (" intersects 2.5 : ", '$a->intersects(2.5)', "0");
test (" intersects 1.5 : ", '$a->intersects(1.5)', "1");
test (" intersects 0.5 : ", '$a->intersects(0.5)', "0");

# print "Intersection with interval:\n";

test ("intersects 0.1 .. 0.3 ", 
	'$a->intersects(Set::Infinite::Simple->new(0.1,0.3))', "0");
test ("intersects 0.1 .. 1.3 ", 
	'$a->intersects(Set::Infinite::Simple->new(0.1,1.3))', "1");
test ("intersects 1.1 .. 1.3 ", 
	'$a->intersects(Set::Infinite::Simple->new(1.1,1.3))', "1");
test ("intersects 1.1 .. 2.3 ", 
	'$a->intersects(Set::Infinite::Simple->new(1.1,2.3))', "1");
test ("intersects 2.1 .. 2.3 ", 
	'$a->intersects(Set::Infinite::Simple->new(2.1,2.3))', "0");
test ("intersects 0.0 .. 4.0 ", 
	'$a->intersects(Set::Infinite::Simple->new(0.0,4.0))', "1");

# print "Union with scalar:\n";

test ("Union 2.0 : ", '$a->union(2.0)', "[1..2]");
test ("Union 2.5 : ", '$a->union(2.5)', "2.5");

# print "Union with interval:\n";

test ("Union 2.0 .. 2.5 : ", '$a->union(Set::Infinite::Simple->new(2.0,2.5))', "[1..2.5]");
test ("Union 0.5 .. 1.5 : ", '$a->union(Set::Infinite::Simple->new(0.5,1.5))', "[0.5..2]");
test ("Union 3.0 .. 4.0 : ", '$a->union(Set::Infinite::Simple->new(3.0,4.0))', "[3..4]");
test ("Union 0.0 .. 4.0 : ", '$a->union(Set::Infinite::Simple->new(0.0,4.0))', "[0..4]");

# print "\n";

$a = Set::Infinite::Simple->new(2,1);
test ("Interval:", '$a', "[1..2]");
test ("intersection 2.5 ", '$a->intersection(2.5)', "null");
test ("intersection 1.5 ", '$a->intersection(1.5)', "1.5");
test ("intersection 0.5 ", '$a->intersection(0.5)', "null");
test ("intersection 0.1 .. 0.3 ", 
	'$a->intersection(Set::Infinite::Simple->new(0.1,0.3))', "null");
test ("intersection 0.1 .. 1.3 ", 
	'$a->intersection(Set::Infinite::Simple->new(0.1,1.3))', "[1..1.3]");
test ("intersection 1.1 .. 1.3 ", '$a->intersection(Set::Infinite::Simple->new(1.1,1.3))', "[1.1..1.3]");
test ("intersection 1.1 .. 2.3 ", '$a->intersection(Set::Infinite::Simple->new(1.1,2.3))', "[1.1..2]");
test ("intersection 2.1 .. 2.3 ", '$a->intersection(Set::Infinite::Simple->new(2.1,2.3))', "null");
test ("intersection 0.0 .. 4.0 ", '$a->intersection(Set::Infinite::Simple->new(0.0,4.0))', "[1..2]");
test ("size", '$a->size', "1");

tie $a, 'Set::Infinite::Simple', 1,2;
test ("tied scalar ",'$a',"[1..2]");
tie @a, 'Set::Infinite::Simple', 1,2;
test ("tied array ",'$a[0] . $a[1]',"12");
$a[1] = -3;
test ("tied array ",'$a[0] . $a[1]',"-31");
tie @b, 'Set::Infinite::Simple';
@b = @a;
$b[1] = 5;
test ("tied array b", '$b[0] . $b[1]',"-35");
test ("tied array a", '$a[0] . $a[1]',"-31");
test ("foreach", '$x = ""; foreach (@a) { $x .= $_; }; $x;', "-31");
test ("size", 	'tied(@a)->size', "4");

# print "cmp\n";
test ("(infinite) cmp inf", 
  'Set::Infinite::Simple->new(infinite) cmp "inf"', "0");
test ("(-infinite) cmp -inf ", 
  '(Set::Infinite::Simple->new(- infinite)) cmp "-inf"', "0");

# print "Complement:\n";
test ("(1,1)  ", 'Set::Infinite::Simple->new(1,1)->complement', "(1..inf)");
test ("(null) ", 'Set::Infinite::Simple->new()->complement', "(-inf..inf)");
test ("(1,infinite)", 'Set::Infinite::Simple->new(1,inf)->complement', "(-inf..1)");
test ("(-infinite,1)", 'Set::Infinite::Simple->new(-inf,1)->complement', "(1..inf)");
test ("(-infinite,infinite)", 'Set::Infinite::Simple->new(-inf,inf)->complement', "null");
test ("complement(10..20) (5,15) : ", 'Set::Infinite::Simple->new(10,20)->complement(5,15)', "(15..20]");

# print "Integer Complement:\n";
test ("(1,1) ", 
	'Set::Infinite::Simple->new(1,1)->integer->complement', "(1..inf)");
test ("(null) ", 
	'Set::Infinite::Simple->new()->integer->complement', "(-inf..inf)");
test ("(1,infinite) ", 
	'Set::Infinite::Simple->new(1,inf)->integer->complement' , "(-inf..1)");
test ("(-infinite,1) ", 
	'Set::Infinite::Simple->new(-inf,1)->integer->complement', "(1..inf)");
test ("(-infinite,infinite) ", 
	'Set::Infinite::Simple->new(-inf,inf)->integer->complement' , "null");
test ("complement(10..20) (5,15) ", 
	'Set::Infinite::Simple->new(10,20)->integer->complement(5,15)', "(15..20]");

stats;
1;