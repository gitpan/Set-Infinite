#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Tests for Set::Infinite::Quantize/Select
# This is work in progress
#

use strict;
use warnings;

my $b;
my $c;
my $events;
my $last_workdays;

my $test = 0;
my ($result, $errors);

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
		print "\n\t# $sub \n\t# expected \"$expected\" \n\t#      got \"$result\"";
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


use Set::Infinite;

Set::Infinite->type('Set::Infinite::Date');


print "1..13\n";


$a = Set::Infinite->new(['2001-01-01','2001-01-23'],['2001-02-01','2001-02-03']);
# print $a,"\n";
# print $a->quantize( unit => "weeks" ),"\n";
# print $a->quantize( unit => "weeks" )->select( freq => 2, by => [1] ),"\n";

# $b = $a->quantize( unit => "weeks" );
# print "b-select ",$b->select( freq => 2, by => [1] ),"\n";

test ( "Month offset: ", ' $a->offset(unit => "months", mode=>"offset", value=>[1,1]) ',
 "[2001-02-01 00:00:00..2001-02-23 00:00:00],[2001-03-01 00:00:00..2001-03-03 00:00:00]");

test ( "Year offset: ", ' $a->offset(unit => "years", mode=>"offset", value=>[1,1]) ',
 "[2002-01-01 00:00:00..2002-01-23 00:00:00],[2002-02-01 00:00:00..2002-02-03 00:00:00]");

test ( "Weekday offset: ", ' $a->offset(unit => "weekdays", mode=>"offset", value=>[1,1]) ',
  "[2001-01-01 00:00:00..2001-01-29 00:00:00],2001-02-05 00:00:00");

test ( "Joined array: ", ' $a->quantize( unit => "weeks")->compact ',
 "[2000-12-31 00:00:00..2001-01-07 00:00:00),[2001-01-07 00:00:00..2001-01-14 00:00:00),[2001-01-14 00:00:00..2001-01-21 00:00:00),[2001-01-21 00:00:00..2001-01-28 00:00:00),[2001-01-28 00:00:00..2001-02-04 00:00:00)");

test ( "Joined array: ", ' join ("", $a->quantize( unit => "weeks" )->select( freq => 2, by => [1])->compact ) ',
 "[2001-01-07 00:00:00..2001-01-14 00:00:00),[2001-01-21 00:00:00..2001-01-28 00:00:00)");

$b = Set::Infinite->new(["2001-09-09","2001-09-10"]);
#print "b=",$b,"\n";
# print "b union a=",$b->union($a),"\n";
# print "a.quant=",$a->quantize( unit => "months" )->union,"\n";
$c = $a->quantize( unit => "months" )->union;
#print "c=",$c,"\n";
# print "b union ''=",$b->union(''),"\n";
# my $c2 = $c->union('');
# print "b union c2=",$b->union($c2),"\n";
#print "b is a ",ref($b),"\n";
#print "b union c=",$b->union($c),"\n";
#print "c union b=",$c->union($b),"\n";
test ( "Union with object: ", ' $c->union($b) ',
 "[2001-01-01 00:00:00..2001-03-01 00:00:00),[2001-09-09 00:00:00..2001-09-10 00:00:00]");

$a = Set::Infinite->new(['2001-01-01'],['2004-04-04'],['2006-06-06'],['2007-07-07']);
test ( '', ' $a->select( freq => 2 )->union() ',
  "2001-01-01 00:00:00,2006-06-06 00:00:00");

$a = Set::Infinite->new(['2001-01-01','2004-01-01'],['2007-01-01','2008-01-01']);
# print "\nTEST1: ", $a;
# print "\nTEST2: ", $a->quantize( unit => "years", quant => 1 );
# print "\nTEST3: ", $a->quantize( unit => "years", quant => 1 )->select( freq => 2, by => [1] );
# print "\nTEST4: ", $a->quantize( unit => "years", quant => 1 )->select( freq => 2, by => [1] )->union();
# print "\n";
test ( '', ' $a->quantize( unit => "years", quant => 1 )->select( freq => 2, by => [1] )->union() ',
  "[2002-01-01 00:00:00..2003-01-01 00:00:00),[2004-01-01 00:00:00..2005-01-01 00:00:00),[2008-01-01 00:00:00..2009-01-01 00:00:00)");

$a = Set::Infinite->new(['2001-01-01','2001-01-09'],['2001-01-20','2001-01-25']);
 
test (  "offset: ", '$a->offset( mode => "offset", value => [4,-4] )->union',
  "[2001-01-01 00:00:04..2001-01-08 23:59:56],[2001-01-20 00:00:04..2001-01-24 23:59:56]");
test (  "begin:  ", '$a->offset( mode => "begin", value => [-1,1] )',
  "[2000-12-31 23:59:59..2001-01-01 00:00:01],[2001-01-19 23:59:59..2001-01-20 00:00:01]");
test (  "end:    ", '$a->offset( mode => "end", value => [-1,1] )',
  "[2001-01-08 23:59:59..2001-01-09 00:00:01],[2001-01-24 23:59:59..2001-01-25 00:00:01]");


# "This event happens from 13:00 to 14:00 every Tuesday, unless that Tuesday is the 15th of the month."
# print "  #12\n";
my $interval = Set::Infinite->new('2001-05-01')->quantize(unit=>'months');
# print "  # Weeks: ", $interval->quantize(unit=>'weeks'), "\n";
my $tuesdays = $interval->quantize(unit=>'weeks')->
	offset( mode => 'begin', unit => 'days', value => [2, 3] );
# print "  # tuesdays: ", $tuesdays, "\n";
my $fifteenth = $interval->quantize(unit=>'months')->
	offset( mode => 'begin', unit => 'days', value => [14, 15] );
# print "  # fifteenth: ", $fifteenth, "\n";
# print "  # tuesdays less fifteenth: ", $tuesdays-> complement($fifteenth), "\n";
# print "  # tuesdays MODE: ", $tuesdays->min->{a}, "\n";
# print "  # tuesdays less fifteenth at 13:00 : ", $tuesdays-> complement($fifteenth)->offset( mode => 'begin', unit => 'hours', value => [13, 14] ), "\n";
$events =  $tuesdays -> complement ( $fifteenth ) ->
	offset( mode => 'begin', unit => 'hours', value => [13, 14] );
# print "  # events in may 2001: ", $events;

test (  "offset: ", ' $events ',
	"[2001-05-01 13:00:00..2001-05-01 14:00:00),[2001-05-08 13:00:00..2001-05-08 14:00:00),[2001-05-22 13:00:00..2001-05-22 14:00:00),[2001-05-29 13:00:00..2001-05-29 14:00:00)");

# RRULE:FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1
# which means 'the last work day of the month'. 

$interval = Set::Infinite->new('2001-05-01', '2001-07-31');

my $workdays = 
	$interval->quantize(unit=>'weeks')->
	offset( unit => 'days', value => [1, -1] );

my $month_ends = 
	$interval->quantize(unit=>'months')->
	offset( mode => 'end', unit => 'days', value => [-4, 0] );

$last_workdays =
	$workdays->intersection($month_ends)->
	offset( mode => 'end', unit => 'days', value => [-1, 0] );

#print "interval: $interval\n";
#print "workdays: ", $workdays, "\n";
#print "month ends: ", $month_ends, "\n";
#print "last workdays: ", $last_workdays, "\n";

test( "last workday ", ' $last_workdays ', 
	"[2001-05-31 00:00:00..2001-06-01 00:00:00),[2001-06-29 00:00:00..2001-06-30 00:00:00),[2001-07-31 00:00:00..2001-08-01 00:00:00)");
1;
