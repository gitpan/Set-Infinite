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

#use Set::Infinite;
use Set::Infinite::Quantize;
use Set::Infinite::Select;

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

sub stats {
	if ($errors) {
		#print "\n\t# Errors: $errors\n";
	}
	else {
		#print "\n\t# No errors.\n";
	}
}

print "1..2\n";

# select
my $s;

$a = Set::Infinite->new([1,25]);
test ( '', 
  ' $a->quantize(quant=>1)->select( freq => 3, by => [0,2], interval => 2, count => 3 )->as_string; ', 
  '[1..2),[3..4),[7..8),[9..10),[13..14),[15..16)');

$a = Set::Infinite->new([9,25],[100,110]);
test ( '', 
  ' $a->quantize(quant=>1)->select( freq => 4, by => [0,1,2] )->as_string; ',
  '[9..10),[10..11),[11..12),[13..14),[14..15),[15..16),[17..18),[18..19),[19..20),[21..22),[22..23),[23..24),[25..26),,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,[101..102),[102..103),[103..104),[105..106),[106..107),[107..108),[109..110),[110..111),' );


1;
