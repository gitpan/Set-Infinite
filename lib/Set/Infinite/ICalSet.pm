#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

Set::Infinite::ICalSet - 'ICal date' set - Deprecated - use Date::Set instead

=head1 SYNOPSIS

This module is obsolete - use Date::Set instead

	use Set::Infinite::ICalSet;

	See eg/ical_2.pl

=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

require Exporter;
use strict;

package Set::Infinite::ICalSet;

use Set::Infinite ':all'; 

our @ISA = qw(Set::Infinite);
our @EXPORT = qw();
our @EXPORT_OK = qw(type);


my $DEBUG = 0;
$Set::Infinite::TRACE = 0;


our $future  = &inf; 
our $past    = -&inf;   
our $forever = __PACKAGE__->new($past, $future);

sub event   { $forever }

sub print {
	my ($self, %parm) = @_;
	print "\n $parm{title} = ",$self,"\n" if $DEBUG;
	return $self;
}

sub period { # time[]
	my (%parm) = @_;
	return __PACKAGE__->new($parm{time}[0], $parm{time}[1]);
}

sub dtstart { # start
	my ($self, %parm) = @_;
	return $self->intersection($parm{start}, $future);
}

sub duration { # unit,duration
	my ($self, %parm) = @_;
	return $self->offset(mode=>'begin', unit=>$parm{unit}, value=>[0, $parm{duration}]);
}

our %freq = qw(SECONDLY seconds MINUTELY minutes HOURLY hours DAILY days WEEKLY weeks MONTHLY months YEARLY years);
our %weekday = qw( SU 0 MO 1 TU 2 WE 3 TH 4 FR 5 SA 6 );

sub rrule { # freq, &method(); optional: interval, until, count
	# TODO: count, interval
	my $self = shift;
	unless (ref($self)) {
		# print " new: $self ";
		unshift @_, $self;
		$self = $forever;
	}
	my $class = ref($self);

	if (($self->{too_complex}) or ($self->min == -&inf) or ($self->max == &inf)) {
		my $b = $class->new();
		$self->trace(title=>"rrule:backtrack"); 
		# print " [rrule:backtrack] \n" if $DEBUG_BT;
		$b->{too_complex} = 1;
		$b->{parent} = $self;
		$b->{method} = 'rrule';
		$b->{param}  = \@_;
		return $b;
	}

	# print "   ", join(" ; ", @_ ), "  ";
	my %parm = @_;
	my $rrule;
	my $when = $self;

	$parm{FREQ} = $parm{FREQ};
	$parm{INTERVAL} = $parm{INTERVAL};
	$parm{COUNT} = $parm{COUNT};

	$when->print(title=>'WHEN');

	if (exists $parm{UNTIL}) {
		my $until = $when;
		$when = $until->intersection($past, $parm{UNTIL});
		$when->print(title=>'UNTIL');
	}

	# BYMONTH, BYWEEKNO, BYYEARDAY, BYMONTHDAY, BYDAY, BYHOUR,
	# BYMINUTE, BYSECOND and BYSETPOS; then COUNT and UNTIL are evaluated

	if (exists $parm{BYMONTH}) {
		my $bymonth = $when;
		my @by = (); foreach ( @{$parm{BYMONTH}} ) { push @by, $_-1, $_; }
		$when = $bymonth->intersection(
			$bymonth->quantize(unit=>'years', strict=>0)
			->offset(mode=>'circle', unit=>'months', value=>[@by], strict=>0 )
			#->print (title=>'months2' . join(',' , @by) )
		)->no_cleanup; 
		$when->print(title=>'BYMONTH');
	}

	if (exists $parm{BYWEEKNO}) {
		my $byweekno = $when;
		my @by = (); foreach ( @{$parm{BYWEEKNO}} ) { push @by, $_-1, $_-1; }
		$when = $byweekno->intersection(
			$byweekno->quantize(unit=>'years', strict=>0)
			#->print (title=>'year')
			# *** Put WKST here ********** TODO *********
			->offset(mode=>'begin', value=>[0,0] )
			->quantize(unit=>'weeks', strict=>0)
			#->print (title=>'week')
			->offset(unit=>'weeks', mode=>'circle', value=>[@by], strict=>0 ) 
		)->no_cleanup; 
		$when->print(title=>'BYWEEKNO');
	}

	if (exists $parm{BYYEARDAY}) {
		my $byyearday = $when;
		my @by = (); foreach ( @{$parm{BYYEARDAY}} ) { push @by, $_-1, $_; }
		$when = $byyearday->intersection(
			$byyearday->quantize(unit=>'years', strict=>0)
			->offset(mode=>'circle', unit=>'days', value=>[@by], strict=>0 )
		)->no_cleanup; 
		$when->print(title=>'BYYEARDAY');
	}

	if (exists $parm{BYMONTHDAY}) {
		my $BYMONTHDAY = $when;    # __PACKAGE__->new($when);
		my @by = (); foreach ( @{$parm{BYMONTHDAY}} ) { push @by, $_-1, $_; }
		$when = $BYMONTHDAY->intersection(
			$BYMONTHDAY->quantize(unit=>'months', strict=>0)
			# ->print (title=>'months')
			->offset(mode=>'circle', unit=>'days', value=>[@by], strict=>0 )
			# ->print (title=>'days')
		)->no_cleanup; 
		$when->print(title=>'BYMONTHDAY');
	}

	if (exists $parm{BYDAY}) {
		my $BYDAY = $when;
		my @by = (); foreach ( map { $weekday{$_} } @{$parm{BYDAY}} ) { push @by, $_, $_+1; }
		$when = $BYDAY->intersection(
			$BYDAY->quantize(unit=>'weeks', strict=>0)
			# ->print (title=>'weeks')
			->offset(mode=>'circle', unit=>'days', value=>[@by], strict=>0 )
			# ->print (title=>'days')
		)->no_cleanup; 
		$when->print(title=>'BYDAY');
	}

	if (exists $parm{BYHOUR}) {
		my $BYHOUR = $when;
		my @by = (); foreach ( @{$parm{BYHOUR}} ) { push @by, $_, $_+1; }
		$when = $BYHOUR->intersection(
			$BYHOUR->offset(mode=>'circle', unit=>'hours', value=>[@by], strict=>0 )
			# ->print (title=>'hours')
		)->no_cleanup; 
		$when->print(title=>'BYHOUR');
	}
 
	if (exists $parm{BYMINUTE}) {
		my $BYMINUTE = $when;
		my @by = (); foreach ( @{$parm{BYMINUTE}} ) { push @by, $_, $_+1; }
		$when = $BYMINUTE->intersection(
			$BYMINUTE->offset(mode=>'circle', unit=>'minutes', value=>[@by], strict=>0 )
			# ->print (title=>'minutes')
		)->no_cleanup; 
		$when->print(title=>'BYMINUTE');
	}

	if (exists $parm{BYSECOND}) {
		my $BYSECOND = $when;
		my @by = (); foreach ( @{$parm{BYSECOND}} ) { push @by, $_, $_+1; }
		$when = $BYSECOND->intersection(
			$BYSECOND->offset(mode=>'circle', unit=>'seconds', value=>[@by], strict=>0 )
			# ->print (title=>'seconds')
		)->no_cleanup; 
		$when->print(title=>'BYSECOND');
	}

	if (exists $parm{BYSETPOS}) {
		my $BYSETPOS = $when;
		my @by = @{$parm{BYSETPOS}};
		$when = $BYSETPOS->intersection(
			$BYSETPOS->compact
			# ->print (title=>'bysetpos1')
			->select( by=> [@by] )
			# ->print (title=>'bysetpos2')
		)->no_cleanup; 
		$when->print(title=>'BYSETPOS');
	}


	# UNTIL and COUNT MUST NOT occur in the same 'recur'
	if (exists $parm{UNTIL}) {
		# UNTIL
		$rrule = $when->intersection(
			$when->quantize(unit=>$freq{$parm{FREQ}}, strict=>0)
			->select(freq=>$parm{INTERVAL}, strict=>0) )
	}
	else {
		# COUNT
		$rrule = $when->intersection(
			$when->quantize(unit=>$freq{$parm{FREQ}}, strict=>0)
			->select(freq=>$parm{INTERVAL}, count=>$parm{COUNT}, strict=>0) )
	}

	return $rrule;
}

sub occurrences { # event->, period 
	my ($self, %parm) = @_;
	return $self->intersection($parm{period});
}


1;