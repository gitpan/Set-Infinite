#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Interface package for ICal / ICalSet
# based on "offset"
# *** This is work in progress *** not intended for actual use
#

use strict;
use warnings;
use Set::Infinite::ICal;
use Set::Infinite::ICalSet qw(type);

# ----- SAMPLE DATA ------

our ($a, $b, $c);
my $test = 1;
if ($test == 1) {
	Set::Infinite::ICalSet::type('Set::Infinite::ICal');
	$a = '20010923Z';
	$b = '20011106T235959Z';  
	$c = '20010101T100000Z';
}
elsif ($test == 2) {
	Set::Infinite::ICalSet::type('Set::Infinite::Date'); 
	$a = '2001-09-23 00:00:00';
	$b = '2001-11-06 23:59:59';
	$c = '2001-01-01 10:00:00';
}
else {
	use Time::Local;
	$a = timegm(  0, 0, 0, 23, 8, 101 ); 
	$b = timegm( 59,59,23,  6,10, 101 ); 
	$c = timegm(  0, 0,10,  1, 0, 101 );
}

#-------------------------

my ($event, $vperiod);
$vperiod = Set::Infinite::ICalSet::period( time=>[$a,$b] );
print "period: $vperiod\n";

# ---- direct syntax ----

my $occurrences = $vperiod->
	rrule( FREQ=>'WEEKLY', COUNT=>2, 
		BYMONTH => [9,10],
		# BYWEEKNO => [40,41],
		# BYYEARDAY => [-65],
		BYMONTHDAY => [20,21,22,23],
		# BYDAY => [qw(SU TU TH)],
		# BYHOUR => [10,13],
		BYSETPOS => [0, -1],
	);

print "occurrences: $occurrences \n";

# ---- functional syntax ----

$event = Set::Infinite::ICalSet::rrule( FREQ=>'WEEKLY', COUNT=>2, 
		BYMONTH => [9,10],
	);

print "occurrences: ", $event->occurrences( period => $vperiod)," \n";

1;

__END__

