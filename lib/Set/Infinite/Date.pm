#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

Set::Infinite::Date - a 'date' scalar

=head1 SYNOPSIS

	use Set::Infinite::Date;

	$a = Set::Infinite::Date->new("10:00");

	This module requires Time::Local

=head1 USAGE

	$a = Set::Infinite::Date->new();
	$a = Set::Infinite::Date->new('2001-02-30 10:00:00');
	$a = Set::Infinite::Date->new('2001-02-30');
	$a = Set::Infinite::Date->new('10:00:00');
	$a = Set::Infinite::Date->new($b);

Perl:

	@b = sort @a;
	print $a;

Date input format:
	All HTTP::Date formats, plus:

	('2001-02-30 10:00', '11:00')
	('2001-02-30 10:00:00', '11:00:00')
		means day 2001-02-30, from 10:00:00 to 11:00:00

	('10:00', '11:00') or
	('10:00:00', '11:00:00') 
		means from 10:00:00 to 11:00:00; day is not specified

	(10000, 11888) 
		time-number format (seconds since epoch)

String conversion functions:

	0 + $s	returns the Date as a time-number (epoch).
			This is faster than	date2time or hour2time.

	time2date 
	date2time 
	time2hour 
	hour2time

	date_format($s) 
		$s is a string containing any combination of the words:
		'year' 'month' 'day' 'hour' 'min' 'sec'
		examples: 
			"year-month-day hour:min:sec" (default)
			"month/day"
			"min:sec"
	date_format returns the date format string.

Internal functions:
	$a->mode($b);
		mode can be 
		1 (beginning in 00:00:00) or 
		2 (absolute dates like 2001-01-01 00:00:00)

=head1 TODO

	$time_format for mode=1
	understand input using date_format/time_format

=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

require Exporter;
package Set::Infinite::Date;
$VERSION = "0.17";

my $DEBUG = 1;
# @ISA = qw(Set::Infinite::Simple); # DON'T !
@ISA = qw(Set::Infinite::Element_Inf);  # is_null
@EXPORT = qw();
@EXPORT_OK = qw(
	time2date date2time time2hour hour2time quantizer day_size
);

use strict;
# use HTTP::Date qw(str2time);
use Time::Local;
use Set::Infinite::Element_Inf;

#--- THIS FUNCTION IS (HEAVILY) MODIFIED FROM HTTP::Date -- Copyright 1995-1999, Gisle Aas

sub str2time {
    my $str = shift;    # '1996-02-29 12:00:00' 
    my @d = $str =~ 
	/(\d{4})-(\d\d?)-(\d\d?)
     (?:
	       (?:\s+)  # separator before clock
	    (\d\d?):?(\d\d)    # hour:min
	    (?::?(\d\d(?:\.\d*)?))?  # optional seconds (and fractional)
	 )?                    # optional clock
	/x; 
    $d[0] -= 1900;  # year
    $d[1]--;        # month
    $d[3] = 0 unless $d[3];
    $d[4] = 0 unless $d[4];
    $d[5] = 0 unless $d[5];
	# print " # $str == ", join(";",@d), " \n";
    return timegm(reverse @d);
}

#--- END CODE DERIVED FROM HTTP::Date

use overload
	'<=>' => \&spaceship,
	'cmp' => \&cmp,
	'-' => \&sub,
	'+' => \&add,
	'/' => \&div,
	qw("" as_string);

our $quantizer = 'Set::Infinite::Quantize_Date';
our $selector  = 'Set::Infinite::Select';
our $offsetter = 'Set::Infinite::Offset';

our $day_size = timegm(0,0,0,2,3,2001) - timegm(0,0,0,1,3,2001);
our $hour_size = $day_size / 24;
our $minute_size = $hour_size / 60;
our $second_size = $minute_size / 60;

our $date_format = "year-month-day hour:min:sec";

sub day_size { $day_size }

sub quantizer {
	# if (@_) {
	#	$quantizer = pop;
	# }
	return $quantizer;
}

sub date_format {
	$date_format = pop if @_;
	return $date_format;
}

# export time2date and date2time
sub time2date (;$)  { 
	my $tmp = shift;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($tmp);
	$year += 1900;
	$mon++;
	foreach ($sec,$min,$hour,$mday,$mon,$year) {
		$_ = '0' . $_ if $_ < 10;
	}
	$tmp = $date_format;
	$tmp =~ s/year/$year/;
	$tmp =~ s/month/$mon/;
	$tmp =~ s/day/$mday/;
	$tmp =~ s/sec/$sec/;
	$tmp =~ s/min/$min/;
	$tmp =~ s/hour/$hour/;
	return $tmp;
}

sub date2time ($;$) { return str2time (shift) }

sub time2hour {
	my $a = shift;

	my $tmp = int($a / $hour_size);
	$a -= ($tmp * $hour_size);
	my $tmp_min = int($a / $minute_size);
	$a -= ($tmp_min * $minute_size);
	my $tmp_sec = int($a / $second_size);

	return sprintf("%02d:%02d:%02d", $tmp, $tmp_min, $tmp_sec);
}

sub hour2time {
	#  00, 00:00, or 00:00:00
	my $a = shift;
	# my ($tmp, $tmp_min, $tmp_sec) = (0,0,0);
	my ($tmp, $tmp_min, $tmp_sec) = split(":", $a . ":0:0"); # , 3);
	return $tmp * $hour_size + $tmp_min * $minute_size + $tmp_sec * $second_size;
}

sub div {
	my ($tmp1, $tmp2) = @_;
	return $tmp1->{a} / $tmp2;
}

sub sub {
	# TODO: (since 0.21) keep format ("mode") in result (see: "Date::add")
	my ($tmp1, $tmp2, $inverted) = @_;
	$tmp2 = Set::Infinite::Date->new($tmp2) unless ref($tmp2) and $tmp2->isa(__PACKAGE__);
	if ($inverted) {
		return - $tmp1 if $tmp2->is_null;
		return Set::Infinite::Date->new( $tmp2->{a} - $tmp1->{a} );
	}
	return $tmp1 unless defined($tmp2);
	return Set::Infinite::Date->new( $tmp1->{a} - $tmp2->{a} );
}

sub add {
	my ($tmp1, $tmp2, $inverted) = @_;
	return $tmp1 unless defined($tmp2);
	# print " [DATE::ADD $tmp1 $tmp2] ";
	$tmp2 = Set::Infinite::Date->new($tmp2) unless ref($tmp2) and $tmp2->isa(__PACKAGE__);
	my $result = Set::Infinite::Date->new( $tmp1->{a} + $tmp2->{a} );
	if ($inverted) {
		$result->{mode} = $tmp2->{mode};
	}
	else {
		$result->{mode} = $tmp1->{mode};
	}
	return $result;
}

sub spaceship {
	my ($tmp1, $tmp2, $inverted) = @_;
	# print " [DATE:CMP:",caller(1),"]\n";
	# print " $tmp1 ";

	return 1 unless defined($tmp2);

	# if ($DEBUG) {
		# if ($tmp2->isa(__PACKAGE__)) {
		#	print " [DATE:CMP:$inverted:",$tmp1->{a};
		#	print " [ ",$tmp2,": ", ref($tmp2), ": ", ref(\$tmp2), "]\n";
		#	print "    <=>",$tmp2->{a},"]\n";
		#}
		# { else {
		#	print " [DATE:CMP:$inverted:",$tmp1;
		#	print " [ ",$tmp2,": ", ref($tmp2), ": ", ref(\$tmp2), "]\n";
		#	print "    <=>",$tmp2,"]\n";
		# }
	# }

	$tmp2 = Set::Infinite::Date->new($tmp2) unless ref($tmp2) and $tmp2->isa(__PACKAGE__);

	if ($inverted) {
		return ( $tmp2->{a} <=> $tmp1->{a} );
	}
	return ( $tmp1->{a} <=> $tmp2->{a} );
}

sub cmp {
	return spaceship @_;
}

sub new {
	my ($self) = bless {}, shift;
	my $tmp = shift;
	$tmp = '' unless defined $tmp;
	$self->{string} = '';
	if ($tmp =~ /\d[\/\.\-]\d/) {
		# $self->{string} = $tmp;
		$self->{a} = date2time($tmp);
		$self->{mode} = 2;
	}
	elsif ($tmp =~ /\d\:\d/) {
		# $self->{string} = $tmp;
		$self->{a} = hour2time($tmp);
		$self->{mode} = 1;
	}
	else {
		# $self->{string} = $tmp;
		$self->{a} = $tmp;
		$self->{mode} = 0;
	}
	return $self;
}

sub mode {
	my ($self) = shift;
	$self->{mode} = shift;
	$self->{string} = '';
	return $self;
}

sub as_string {
	my ($self) = shift;

	#return '' unless defined($self);
	#print " [ $self->{string} ] " ;

	if ($self->{string} ne '') {
		# done
		#print "1 ";
	}
	elsif (not defined($self->{a})) {
		$self->{string} = '';
		#print "2 ";
	}
	elsif ($self->{mode} == 0) {
		$self->{string} = $self->{a};
		#print "3 ";
	}
	elsif ($self->{mode} == 1) {
		$self->{string} = time2hour($self->{a});
	}
	else {
		$self->{string} = time2date($self->{a});
	}
	return $self->{string};
}

# sub epoch {
#	return 0 + $_[0]->{a};
# }

1;