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
	'<=>' => \&spaceship,
	'cmp' => \&cmp,
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
	# print " [ical:add:", $tmp1, " + ", ref($tmp2), "->", $tmp2, "] ";

	unless (ref($tmp2) and $tmp2->isa(__PACKAGE__)) { $tmp2 = __PACKAGE__->new($tmp2); }
	return __PACKAGE__->new( $tmp1->epoch + $tmp2->epoch );

	# return Date::ICal::add($tmp1, $tmp2);
}

sub sub {
	my ($tmp1, $tmp2, $inverted) = @_;
	# print " [ical:sub:", $tmp1, " - ", ref($tmp2), "->", $tmp2, "] ";
	# print " [duration:", $tmp1->epoch, "] ";

	return $tmp2->epoch - $tmp1->epoch if $inverted;
	return $tmp1->epoch - $tmp2->epoch;

	# if it could represent a duration
	# return __PACKAGE__->new( epoch => ($tmp2->epoch - $tmp1->epoch) ) if $inverted;
	# return __PACKAGE__->new( epoch => ($tmp1->epoch - $tmp2->epoch) );
}

sub div {
	my ($tmp1, $tmp2) = @_;
	return $tmp1 / $tmp2;
}

sub spaceship {
	my ($tmp1, $tmp2, $inverted) = @_;
	return 1 unless defined($tmp2);

	# print " [ical:cmp:", $tmp1, "<=>", ref($tmp2), "->", $tmp2, "] ";

	# ???
	return 1 if Set::Infinite::Element_Inf::is_null($tmp2);

	unless ( ref($tmp2) ) {   # and $tmp2->isa(__PACKAGE__) ) {
		# print " [ical:cmp:new] ";
		$tmp2 = __PACKAGE__->new($tmp2) ;
	}
	elsif ($tmp2->isa('Set::Infinite::Element_Inf')) {
		# print " [ical:cmp:inf] ";
		if ($inverted) {
			return Set::Infinite::Element_Inf::cmp($tmp2, $tmp1);
		}
		return Set::Infinite::Element_Inf::cmp($tmp1, $tmp2);
	}

	if ($inverted) {
		return $tmp2->compare($tmp1);
	}
	return $tmp1->compare($tmp2);
}

sub cmp {
	return spaceship @_;
}

sub as_string {
	my ($self) = shift;
	return $self->ical;
}

sub new {
	my ($self) = shift;

	# print " [ical:new:", join(';', @_) , "] ";

	if ( Set::Infinite::Element_Inf->is_null($_[0]) ) {
		# print " [ical:new:null] ";
		return Set::Infinite::Element_Inf->null ;
	}

	if (ref($_[0]) and $_[0]->isa('Set::Infinite::Element_Inf')) {
		# print " [ical:new:inf] ";
		return $_[0];
	}

	# print " [new...";
	if ($#_ == 0) {
		# epoch or ical mode?
		my $value = $_[0];
		if ($value =~ /^[12]\d{7}/) {
			$self = Date::ICal->new( ical => $_[0] );
		}
		else {
			# NOT 19971024
			$self = Date::ICal->new( epoch => $_[0] );
		}
	}
	else {
		$self = Date::ICal->new( @_ );
	}
	bless $self, __PACKAGE__;
	# print " [ical:new:", $self , "] ";
	return $self;
}

sub mode {
	return @_;
}

1;