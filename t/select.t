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

print "1..2\n";

# select
my $s;

$a = Set::Infinite->new([1,25]);
$s = $a->quantize(1)->
        select( freq => 3, by => [0,2], interval => 2, count => 3 )->
        as_string;
print "not " unless 
    $s eq '[1..2),,[3..4),,,,[7..8),,[9..10),,,,[13..14),,[15..16),,,'
    # $s eq '[1..2)[3..4)[7..8)[9..10)[13..14)[15..16)'
;
print "ok 1\n";
# print "# $s\n";

$a = Set::Infinite->new([9,25],[100,110]);
print "not " unless 
$s = $a->quantize(1)-> 
        select( freq => 4, by => [0,1,2] )->
        as_string;
print "not " unless 
    $s eq '[9..10),[10..11),[11..12),,[13..14),[14..15),[15..16),,[17..18),[18..19),[19..20),,[21..22),[22..23),[23..24),,[25..26),,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,[101..102),[102..103),[103..104),,[105..106),[106..107),[107..108),,[109..110),[110..111),,'
    # $s eq '[1..2)[3..4)[7..8)[9..10)[13..14)[15..16)[9..10)[10..11)[11..12)[13..14)[14..15)[15..16)[17..18)[18..19)[19..20)[21..22)[22..23)[23..24)[25..26)[101..102)[102..103)[103..104)[105..106)[106..107)[107..108)[109..110)[110..111)'
;
print "ok 2\n";
# print "# $s\n";


1;
