#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Set::Infinite::Date
# This is work in progress
#

# Note: Set::Infinite::Date module requires HTTP:Date and Time::Local

use strict;
use warnings;
$| = 1;
use Set::Infinite qw($inf);

# Just to help the warnings:
use Set::Infinite::Date;

my ($timeA1, $timeA2);
my ($timeB1, $timeB2);
my ($time2, $time3, $time4, $time5, @a);


my $test = 0;
my ($result, $errors);

print "1..26\n";

sub test {
	my ($header, $sub, $expected) = @_;
	$test++;
	#print "\t# $header \n";
	$result = eval $sub;
        $result = '' unless defined $result;
	if ("$expected" eq "$result") {
		print "ok $test";
	}
	else {
		print "not ok $test"; # \n\t# expected \"$expected\" got \"$result\"";
		print "\n\t# $sub expected \"$expected\" got \"$result\" $@";
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

Set::Infinite->type('Set::Infinite::Date');



$a = Set::Infinite->new('10:00:00', '13:00:00');

#print " a is ", $a, "\n";

test('','$a','[10:00:00..13:00:00]');

#print " $a size is ", $a->size, "\n";

test('','$a->size','03:00:00');   # 03:00:00 or 10800

#print " $a union (16:00..17:00) is ", $a->union('16:00:00', '17:00:00'), "\n";

test('','$a->union(\'16:00:00\', \'17:00:00\')','[10:00:00..13:00:00],[16:00:00..17:00:00]');

# print " $a complement is ", $a->complement, "\n";

test('','$a->complement', "(-$inf..10:00:00),(13:00:00..$inf)");

#print " $a complement (11:00:00..12:00:00) is ", $a->complement("11:00","12:00"), "\n";

test('','$a->complement("11:00:00","12:00:00")','[10:00:00..11:00:00),(12:00:00..13:00:00]');



$a = Set::Infinite->new('10:00:00','100:00:00');

test('','$a','[10:00:00..100:00:00]');

$a = $a->union('01:00:00', '02:30:00');

test('','$a','[01:00:00..02:30:00],[10:00:00..100:00:00]');
test('','$a->size','91:30:00');  # "329400" or "91:30:00"

test('','$a->span','[01:00:00..100:00:00]');

test('','$a->max','100:00:00');
test('','$a->min','01:00:00');


$timeA1 = '2001-04-26 10:00:00';    

$timeA2 = '2001-04-26 10:30:00';    


$time2 = '';
$time3 = '';    
$time4 = '';
$time5 = '';


$time2 = '2001-04-26 09:50:00';

$time3 = '2001-04-26 10:20:00';    

$time4 = '2001-04-26 10:40:00';

$time5 = '2001-04-26 11:00:00';



$timeB1 = '2001-04-27 10:00:00';    

$timeB2 = '2001-04-27 10:30:00';    



$a = Set::Infinite->new($timeA1,$timeA2);

test('','$a','[2001-04-26 10:00:00..2001-04-26 10:30:00]');
test('','$a->intersects($time3)','1');
test('','$a->intersects($time4)','0');

test('','$a->contains($time3,"2001-04-26 10:25:00")','1');

# warn "contains $a $time4";
test('','$a->contains($time4)','0');

test('','$a->size','1970-01-01 00:30:00');   # "1800" or "1970-01-01 00:30:00"

test('','$a->span','[2001-04-26 10:00:00..2001-04-26 10:30:00]');

test('','$a->max','2001-04-26 10:30:00');
test('','$a->min','2001-04-26 10:00:00');



$a = Set::Infinite->new($timeA1,$timeA2,$timeB1,$timeB2);

test('','$a','[2001-04-26 10:00:00..2001-04-26 10:30:00],[2001-04-27 10:00:00..2001-04-27 10:30:00]');
test('','$a->intersection($time3)','2001-04-26 10:20:00');
test('','$a->intersection($time4)','');

test('','$a->intersection(Set::Infinite->new($time3,$time4))','[2001-04-26 10:20:00..2001-04-26 10:30:00]');

test('','$a->intersection(Set::Infinite->new($time4,$time5))','');

test('','$a->intersection(Set::Infinite->new($time2,$time5))','[2001-04-26 10:00:00..2001-04-26 10:30:00]');


# tie $a, 'Set::Infinite', ['01:00:00','02:00:00'], ['09:00:00','10:00:00'];
# test('','$a','[01:00:00..02:00:00],[09:00:00..10:00:00]');

# tie @a, 'Set::Infinite', ['01:00:00','02:00:00'], ['09:00:00','10:00:00'];
# test('','$#a','1'); 
# test('','join(";",@a)','[01:00:00..02:00:00];[09:00:00..10:00:00]');



1;
