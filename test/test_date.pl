#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Set::Infinite::Date
# This is work in progress
#

# Note: Set::Infinite::Date module requires HTTP:Date and Time::Local


use Set::Infinite qw(type);
type('Set::Infinite::Date');

$a = Set::Infinite->new('10:00', '13:00');
print " a is ", $a, "\n";
print " $a size is ", $a->size, "\n";
print " $a union (16:00..17:00) is ", $a->union('16:00', '17:00'), "\n";
print " $a complement is ", $a->complement, "\n";
print " $a complement (11:00..12:00) is ", $a->complement("11:00","12:00"), "\n";

$a = Set::Infinite->new('10:00','100:00');
print " Date: ", $a, "\n";
$a = $a->union('1:00', '2:30');
print " Union (1:00..2:30) : ", $a, "\n";
print " $a size is ", $a->size, "\n";
print " $a span is ", $a->span, "\n";
print " $a max is ", $a->max, "\n";
print " $a min is ", $a->min, "\n";

$timeA1 = '2001-04-26 10:00';    
$timeA2 = '2001-04-26 10:30';    

$time2 = '2001-04-26 09:50:00';
$time3 = '2001-04-26 10:20:00';    
$time4 = '2001-04-26 10:40:00';
$time5 = '2001-04-26 11:00:00';

$timeB1 = '2001-04-27 10:00:00';    
$timeB2 = '2001-04-27 10:30:00';    

$a = Set::Infinite->new($timeA1,$timeA2);
print " Interval $a \n";
print "   intersect $time3 ? ", $a->intersects($time3), "\n";
print "   intersect $time4 ? ", $a->intersects($time4), "\n";
print "   contains  $time3..2001-04-26 10:25 ? ", $a->contains($time3,'2001-04-26 10:25'), "\n";
print "   contains  $time4 ? ", $a->contains($time4), "\n";
print "   size is ", $a->size, "\n";
print "   span is ", $a->span, "\n";
print "   max is ", $a->max, "\n";
print "   min is ", $a->min, "\n";

$a = Set::Infinite->new($timeA1,$timeA2,$timeB1,$timeB2);
print " Interval: $a \n";
print " intersect 3 ", $a->intersection($time3), "\n";
print " intersect 4 ", $a->intersection($time4), "\n";
print " intersect 3-4 ", $a->intersection(Set::Infinite->new($time3,$time4)), "\n";
print " intersect 4-5 ", $a->intersection(Set::Infinite->new($time4,$time5)), "\n";
print " intersect 2-5 ", $a->intersection(Set::Infinite->new($time2,$time5)), "\n";

tie $a, 'Set::Infinite', ['1:00','2:00'], ['9:00','10:00'];
print " tied scalar: $a\n";
tie @a, 'Set::Infinite', ['1:00','2:00'], ['9:00','10:00'];
print " tied array: ", "size:",$#a," elem=",join(";",@a),"\n";

1;