#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Set::Infinite::Quantize
# This is work in progress
#
# CHANGES
# 0.21 - change quantize(1) -> quantize( quant => 1 )


use strict;
use warnings;

use Set::Infinite::Quantize;


# print "test: ",join (" ",  Set::Infinite->new([1,3])->quantize(quant => 1) ), "\n";
# foreach (
#	Set::Infinite->new([1,3],[5,10])->quantize(quant => 0.5)
#	) { print " $_ "; }
#print "\n";



print "1..8\n";

#print "1: \n";
$a = Set::Infinite->new([1,3]);
#print join (" ",@{$a->quantize(quant => 1)}),"\n";
print "not " unless join (" ", $a->quantize(quant => 1) ) eq 
	"[1..2) [2..3) [3..4) ";
print "ok 1\n";

#print "25: \n";
$a = Set::Infinite->new([315,434], [530,600]);
#print join (" ",@{$a->quantize(quant => 25)}),"\n";
print "not " unless join (" ", $a->quantize(quant => 25) ) eq 
	"[300..325) [325..350) [350..375) [375..400) [400..425) [425..450)    [525..550) [550..575) [575..600) [600..625)";
print "ok 2\n";


my (@a);

#print "25: \n";
@a = Set::Infinite->new([315,434], [530,600])->quantize(quant=>25);
# tie @a, 'Set::Infinite::Quantize', 25, [315,434], [530,600];
#print join (" ",@a),"\n";
print "not " unless join (" ",@a) eq "[300..325) [325..350) [350..375) [375..400) [400..425) [425..450)    [525..550) [550..575) [575..600) [600..625)";
print "ok 3\n";

#print "25: \n";
# tie @a, 'Set::Infinite::Quantize', 25, 315,434;
@a = Set::Infinite->new([315,434])->quantize(quant=>25);
#print join (" ",@a),"\n";
print "not " unless join (" ",@a) eq "[300..325) [325..350) [350..375) [375..400) [400..425) [425..450)";
print "ok 4\n";

# tie @a, 'Set::Infinite::Quantize', 25, 300,434;
@a = Set::Infinite->new([300,434])->quantize(quant=>25);
#print join (" ",@a),"\n";
print "not " unless join (" ",@a) eq "[300..325) [325..350) [350..375) [375..400) [400..425) [425..450) ";
print "ok 5\n";

# tie @a, 'Set::Infinite::Quantize', 25, 315,450;
@a = Set::Infinite->new([315,450])->quantize(quant=>25);
#print join (" ",@a),"\n";
print "not " unless join (" ",@a) eq "[300..325) [325..350) [350..375) [375..400) [400..425) [425..450) [450..475)";
print "ok 6\n";

# tie @a, 'Set::Infinite::Quantize', 25, 300,450;
@a = Set::Infinite->new([300,450])->quantize(quant=>25);
#print join (" ",@a),"\n";
print "not " unless join (" ",@a) eq "[300..325) [325..350) [350..375) [375..400) [400..425) [425..450) [450..475) ";
print "ok 7\n";

# recursive test
$a = Set::Infinite->new([1,3]);
# print "r: ", $a->quantize(quant => 1)->quantize(quant => 1), "\n";
print "not " unless join (" ", $a->quantize(quant => 1)->quantize(quant => 1) ) eq 
	"[1..2) [2..3) [3..4)  ";
print "ok 8\n";


1;