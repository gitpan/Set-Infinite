#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Set::Infinite quantize-date functions
# This is work in progress
#

use strict;
use warnings;
use Set::Infinite;
my @horario_mes;
my @horario_dia;

my $test = 0;
my ($result, $errors);

sub test {
	my ($header, $sub, $expected) = @_;
	$test++;
	#print "\t# $header \n";
	$result = eval $sub;
    $result = "" unless defined $result;
	if ("$expected" eq "$result") {
		print "ok $test";
	}
	else {
		print "not ok $test"; # \n\t# expected \"$expected\" got \"$result\"";
		print "\n  #  $sub expected \"$expected\" \n  #  got \"$result\" $@";
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

print "1..15\n";

@horario_mes = Set::Infinite->new("2001-04-01 00:00:00")->quantize(unit=>'months', quant=>1);
# print "Month = ",@horario_mes,":\n";
@horario_dia = $horario_mes[0]->quantize(unit=>'days', quant=>1)->compact->list ;
# print "Days $horario_mes[0] = ",@horario_dia,":\n";
test ('', ' join (" ",@horario_dia) ', 
	"[2001-04-01 00:00:00..2001-04-02 00:00:00) [2001-04-02 00:00:00..2001-04-03 00:00:00) [2001-04-03 00:00:00..2001-04-04 00:00:00) [2001-04-04 00:00:00..2001-04-05 00:00:00) [2001-04-05 00:00:00..2001-04-06 00:00:00) [2001-04-06 00:00:00..2001-04-07 00:00:00) [2001-04-07 00:00:00..2001-04-08 00:00:00) [2001-04-08 00:00:00..2001-04-09 00:00:00) [2001-04-09 00:00:00..2001-04-10 00:00:00) [2001-04-10 00:00:00..2001-04-11 00:00:00) [2001-04-11 00:00:00..2001-04-12 00:00:00) [2001-04-12 00:00:00..2001-04-13 00:00:00) [2001-04-13 00:00:00..2001-04-14 00:00:00) [2001-04-14 00:00:00..2001-04-15 00:00:00) [2001-04-15 00:00:00..2001-04-16 00:00:00) [2001-04-16 00:00:00..2001-04-17 00:00:00) [2001-04-17 00:00:00..2001-04-18 00:00:00) [2001-04-18 00:00:00..2001-04-19 00:00:00) [2001-04-19 00:00:00..2001-04-20 00:00:00) [2001-04-20 00:00:00..2001-04-21 00:00:00) [2001-04-21 00:00:00..2001-04-22 00:00:00) [2001-04-22 00:00:00..2001-04-23 00:00:00) [2001-04-23 00:00:00..2001-04-24 00:00:00) [2001-04-24 00:00:00..2001-04-25 00:00:00) [2001-04-25 00:00:00..2001-04-26 00:00:00) [2001-04-26 00:00:00..2001-04-27 00:00:00) [2001-04-27 00:00:00..2001-04-28 00:00:00) [2001-04-28 00:00:00..2001-04-29 00:00:00) [2001-04-29 00:00:00..2001-04-30 00:00:00) [2001-04-30 00:00:00..2001-05-01 00:00:00)");


Set::Infinite::Date->date_format("year-month-day");


$a = Set::Infinite->new('1998-01-01', '2002-01-01');
# print "Years:\n", join (" ", $a->quantize('years', 1) ),"\n";
test ('', ' join (" ", $a->quantize(unit=>"years", quant=>1)->compact->list ) ', 
	"[1998-01-01..1999-01-01) [1999-01-01..2000-01-01) [2000-01-01..2001-01-01) [2001-01-01..2002-01-01) [2002-01-01..2003-01-01)");



$a = Set::Infinite->new('2001-05-02', '2001-05-13');
#print "Weeks:\n ", join (" ", $a->quantize('weeks', 1) ),"\n";
test ('', ' join (" ", $a->quantize(unit=>"weeks")->compact->list ) ',
	"[2001-04-29..2001-05-06) [2001-05-06..2001-05-13) [2001-05-13..2001-05-20)");
#print "ok 3\n";



my (@a);

#print "Years: \n";
$a = Set::Infinite->new('1998-01-01', '2002-01-01');
test ('', ' join (" ", $a->quantize(unit=>"years")->compact->list ) ',
# print "not " unless join (" ",@a) eq
	"[1998-01-01..1999-01-01) [1999-01-01..2000-01-01) [2000-01-01..2001-01-01) [2001-01-01..2002-01-01) [2002-01-01..2003-01-01)");
#print "ok 4\n";



#print "Months: \n";
$a = Set::Infinite->new('1999-11-01', '2000-02-01');
test ('', ' join (" ", $a->quantize(unit=>"months")->compact->list ) ',

#print "not " unless join (" ",@a) eq
	"[1999-11-01..1999-12-01) [1999-12-01..2000-01-01) [2000-01-01..2000-02-01) [2000-02-01..2000-03-01)");
#print "ok 5\n";



#print "Days: \n";
#print "not " unless join (" ",@a) eq
$a = Set::Infinite->new('1999-12-28', '2000-01-03');
test ('', ' join (" ", $a->quantize(unit=>"days")->compact->list ) ',
	"[1999-12-28..1999-12-29) [1999-12-29..1999-12-30) [1999-12-30..1999-12-31) [1999-12-31..2000-01-01) [2000-01-01..2000-01-02) [2000-01-02..2000-01-03) [2000-01-03..2000-01-04)");
#print "ok 6\n";



#print "Weeks: \n";
#print "not " unless join (" ",@a) eq
$a = Set::Infinite->new('2001-05-02', '2001-05-13');
test ('', ' join (" ", $a->quantize(unit=>"weeks")->compact->list ) ',
	"[2001-04-29..2001-05-06) [2001-05-06..2001-05-13) [2001-05-13..2001-05-20)");
#print "ok 7\n";



Set::Infinite::Date->date_format("year-month-day hour:min");
#print "Hours: \n";
#print "not " unless join (" ",@a) eq
$a = Set::Infinite->new('2001-05-02 22:35', '2001-05-03 02:00');
test ('', ' join (" ", $a->quantize(unit=>"hours")->compact->list ) ',
	"[2001-05-02 22:00..2001-05-02 23:00) [2001-05-02 23:00..2001-05-03 00:00) [2001-05-03 00:00..2001-05-03 01:00) [2001-05-03 01:00..2001-05-03 02:00) [2001-05-03 02:00..2001-05-03 03:00)");
#print "ok 8\n";



#print "15 minute: \n";
#print "not " unless join (" ",@a) eq
$a = Set::Infinite->new('2001-05-02 21:35', '2001-05-02 23:47');
test ('', ' join (" ", $a->quantize(unit=>"minutes", quant=>15)->compact->list ) ',
	"[2001-05-02 21:30..2001-05-02 21:45) [2001-05-02 21:45..2001-05-02 22:00) [2001-05-02 22:00..2001-05-02 22:15) [2001-05-02 22:15..2001-05-02 22:30) [2001-05-02 22:30..2001-05-02 22:45) [2001-05-02 22:45..2001-05-02 23:00) [2001-05-02 23:00..2001-05-02 23:15) [2001-05-02 23:15..2001-05-02 23:30) [2001-05-02 23:30..2001-05-02 23:45) [2001-05-02 23:45..2001-05-03 00:00)");
#print "ok 9\n";



Set::Infinite::Date->date_format("hour:min:sec");
#print "30 seconds: \n";
#print "not " unless join (" ",@a) eq
$a = Set::Infinite->new(
    ['21:35:45', '21:43:00'],
	['21:45:10', '21:47:15']);
test ('', ' join (" ", $a->quantize(unit=>"seconds", quant=>30)->compact->list ) ',
	"[21:35:30..21:36:00) [21:36:00..21:36:30) [21:36:30..21:37:00) [21:37:00..21:37:30) [21:37:30..21:38:00) [21:38:00..21:38:30) [21:38:30..21:39:00) [21:39:00..21:39:30) [21:39:30..21:40:00) [21:40:00..21:40:30) [21:40:30..21:41:00) [21:41:00..21:41:30) [21:41:30..21:42:00) [21:42:00..21:42:30) [21:42:30..21:43:00) [21:43:00..21:43:30) [21:45:00..21:45:30) [21:45:30..21:46:00) [21:46:00..21:46:30) [21:46:30..21:47:00) [21:47:00..21:47:30)");
#print "ok 10\n";

# weekyear tests
Set::Infinite::Date->date_format("year-month-day");
$a = Set::Infinite->new( '1997-12-31' );
test ('', ' $a->quantize(unit=>"weekyears") ',
	"[1997-12-29..1999-01-04)");
$a = Set::Infinite->new( '1997-12-31','1998-01-01' );
test ('', ' $a->quantize(unit=>"weekyears") ',
	"[1997-12-29..1999-01-04)");
$a = Set::Infinite->new( '1997-12-31','1999-01-01' );
test ('', ' $a->quantize(unit=>"weekyears") ',
	"[1997-12-29..1999-01-04)");
$a = Set::Infinite->new( '1997-12-31','1999-01-05' );
test ('', ' $a->quantize(unit=>"weekyears") ',
	"[1997-12-29..1999-01-04),[1999-01-04..2000-01-03)");
$a = Set::Infinite->new( '1997-12-20','1999-01-05' );
test ('', ' $a->quantize(unit=>"weekyears") ',
	"[1996-12-30..1997-12-29),[1997-12-29..1999-01-04),[1999-01-04..2000-01-03)");

# TODO: wkst tests

1;
