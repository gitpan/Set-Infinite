#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

Set::Infinite::ICal - an ICal 'date' scalar

=head1 SYNOPSIS

	use Set::Infinite::ICal;

	This module requires Date::ICal

	See Set::Infinite, Date::ICal

=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

require Exporter;
package Set::Infinite::ICal;
$VERSION = "0.01";

my $DEBUG = 1;
@ISA = qw(Date::ICal);  # Set::Infinite::Element_Inf);
@EXPORT = qw();
@EXPORT_OK = qw(
	quantizer
);

use strict;
use Date::ICal;
use Set::Infinite::Element_Inf;

use overload
	'0+' => sub { $_[0]->{epoch} },   # \&Date::ICal::epoch,
	'<=>' => \&spaceship,
	'-' => \&sub,
	'+' => \&add,
	'/' => \&div,
	qw("" as_string);

our $quantizer = 'Set::Infinite::Quantize_Date';
our $selector  = 'Set::Infinite::Select';
our $offsetter = 'Set::Infinite::Offset';

sub quantizer {
	return $quantizer;
}

sub add {
	my ($tmp1, $tmp2) = @_;
	# print "+";
	# print " [ical:add:", $tmp1, " + ", ref($tmp2), "->", $tmp2, "] ";

	# unless (ref($tmp2) and $tmp2->isa(__PACKAGE__)) { $tmp2 = __PACKAGE__->new($tmp2); }
	return __PACKAGE__->new( $tmp1->{epoch} + $tmp2 );

	# return Date::ICal::add($tmp1, $tmp2);
}

sub sub {
	my ($tmp1, $tmp2, $inverted) = @_;
	# print " [ical:sub:", $tmp1, " - ", ref($tmp2), "->", $tmp2, "] ";
	# print " [duration:", $tmp1->epoch, "] ";
	# print "-";

	$tmp1 = $tmp1->{epoch} if ref($tmp1);
	$tmp2 = $tmp2->{epoch} if ref($tmp2);

	return $tmp2 - $tmp1 if $inverted;
	return $tmp1 - $tmp2;

	# if it could represent a duration
	# return __PACKAGE__->new( epoch => ($tmp2->epoch - $tmp1->epoch) ) if $inverted;
	# return __PACKAGE__->new( epoch => ($tmp1->epoch - $tmp2->epoch) );
}

sub div {
	my ($tmp1, $tmp2) = @_;
	# print "/";
	return $tmp1 / $tmp2;
}

sub spaceship {
	my ($tmp1, $tmp2, $inverted) = @_;
	return 1 unless defined($tmp2);

	# print "=";
	# print " [ical:cmp:", $tmp1, "<=>", ref($tmp2), "->", $tmp2, "] ";

	# ???
	# return 1 if Set::Infinite::Element_Inf::is_null($tmp2);

	unless ( ref($tmp2) ) {                                   # and $tmp2->isa(__PACKAGE__) ) {
		# print " [ical:cmp:new] ";
		# print "N $tmp2 ";

		if ($inverted) {
			return $tmp2 <=> $tmp1->{epoch};
		}
		return $tmp1->{epoch} <=> $tmp2;

		# $tmp2 = __PACKAGE__->new($tmp2) ;
	}
	elsif ( ref($tmp2) eq 'Set::Infinite::Element_Inf' ) {    # $tmp2->isa('Set::Infinite::Element_Inf')) {
		# print " [ical:cmp:inf] ";
		# print "I";
		if ($inverted) {
			return Set::Infinite::Element_Inf::spaceship($tmp2, $tmp1);
		}
		return Set::Infinite::Element_Inf::spaceship($tmp1, $tmp2);
	}

	# print "C";

	# most frequent case

	# $tmp1->{epoch} = $tmp1->epoch unless $tmp1->{epoch};
	# $tmp2->{epoch} = $tmp2->epoch unless $tmp2->{epoch};

	if ($inverted) {
		return $tmp2->{epoch} <=> $tmp1->{epoch};
	}
	return $tmp1->{epoch} <=> $tmp2->{epoch};
}

sub as_string {
	my ($self) = shift;
	$self->{string} = $self->ical unless $self->{string};
	return $self->{string};
}

our %new_cache = ();

sub new {
	my ($self) = shift;

	my $data = shift;

	my $string;
	if (ref($data)) {
		if ($data->isa(__PACKAGE__)) {
			$string = "$data";
		}
		elsif ($data->isa('Date::ICal')) {
			$string = $data->ical;
		}
		elsif ($data->isa('Set::Infinite::Element_Inf')) {
			# print " [ical:new:inf] ";
			return $data;
		}
		else {
			$string = "$data";
		}
	}
	else {
		$string = $data;
	}

	# print "N";
	# print " [ical:new:", join(';', @_) , "] ";

	if ((not defined $string) or ($string eq '')) {
		# print " [ical:new:null] ";
		return Set::Infinite::Element_Inf->null ;
	}

	# get it from " $new_cache "
	elsif (exists $new_cache{$string}) {
		# print "V";
		$self = $new_cache{$string};
		return $self;
	}

	elsif ($#_ == -1) {
		# epoch or ical mode?

		if ($string =~ /^[12]\d{7}([^\d]|$)/) {
			# print "1";
			# must be ical format
			$self = Date::ICal->new( ical => $string );
			bless $self, __PACKAGE__;
			$self->{string} = $string;    # cache string
			$self->{epoch} = $self->epoch;  # cache epoch
			$new_cache{$string} = $self;  # cache object
			return $self;
		}
		else {
			# NOT 19971024 -- must be "epoch"
			# print "2";
			# most frequent case: use " $new_cache " to optimize

			$self = Date::ICal->new( epoch => $string );
			bless $self, __PACKAGE__;
			$self->{epoch} = $string;     # cache epoch
			$new_cache{$string} = $self;  # cache object
			return $self;
		}
	}
	else {
		# print "3";
		$self = Date::ICal->new( $data, @_ );
	}
	bless $self, __PACKAGE__;
	$self->{epoch} = $self->epoch;      # cache epoch
	# print " [ical:new:", $self , "] ";
	return $self;
}

sub mode {
	return @_;
}

1;