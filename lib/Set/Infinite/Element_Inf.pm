#/bin/perl
# Copyright (c) 2001 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

	Set::Infinite::Element_Inf - a set member

=head1 USAGE

Global:
	infinite		returns an 'infinity' number.
	minus_infinite	returns '-infinity' number.
	null			returns 'null'.

=head1 DESCRIPTION

	This is a building block for Set::Infinite.
	Please use Set::Infinite instead.

=head1 TODO

	infinite($i)	chooses 'infinity' name. default is 'inf'

	null($i)		chooses 'null' name. default is 'null'


=head1 AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

require Exporter;

package Set::Infinite::Element_Inf;
$VERSION = "0.17";

my $package        = 'Set::Infinite::Element_Inf';
@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(infinite minus_infinite null is_null elem_undef inf);

use strict;
use Carp;

use overload
	'<=>' => \&spaceship,
	'cmp' => \&cmp,
	'+'   => \&add,
	'-'   => \&sub,
	qw("" as_string),
	fallback => 1;


our $infinite  	= 'inf';
our $null      	= '';	# changed in 0.21
our $undef 	= 'undef';
our $minus_infinite = "-$infinite";

our $o_infinite = 	bless \$infinite, 	__PACKAGE__;
our $o_minus_infinite = bless \$minus_infinite, __PACKAGE__;
our $o_null =    	bless \$null,   	__PACKAGE__;
our $o_elem_undef =   	bless \$undef,  	__PACKAGE__;

sub infinite () {
	return $o_infinite;
}

sub inf () {
	return $o_infinite;
}

sub minus_infinite () {
	return $o_minus_infinite;
}

sub null () {
	return $o_null;
}

sub elem_undef () {
	return $o_elem_undef;
}

sub as_string {
	return ${$_[0]};
}

our %null = (
	'' 	=> 1,
	$null	=> 1
);

sub is_null {
	my $self = pop;
	return 1 unless defined($self);
	return $null{$self} ? 1 : 0;
}

our %add = (
	'' => { 
		''      	=> $o_null,	
		'0'      	=> 0,	
		$null     	=> $o_null,	
		$infinite 	=> $o_infinite,
		$minus_infinite => $o_minus_infinite },
	'0' => { 
		''      	=> 0,	
		'0'      	=> 0,	
		$null     	=> 0,	
		$infinite 	=> $o_infinite,
		$minus_infinite => $o_minus_infinite },
	$null => { 
		''      	=> $o_null,	
		'0'      	=> 0,	
		$null     	=> $o_null,	
		$infinite 	=> $o_infinite,
		$minus_infinite => $o_minus_infinite },
	$infinite => { 
		''      	=> $o_infinite,	
		'0'      	=> $o_infinite,	
		$null    	=> $o_infinite,	
		$infinite 	=> $o_infinite,
		$minus_infinite => $o_elem_undef },
	$minus_infinite => { 
		''      	=> $o_minus_infinite,	
		'0'      	=> $o_minus_infinite,	
		$null    	=> $o_minus_infinite,	
		$infinite 	=> $o_elem_undef,
		$minus_infinite => $o_minus_infinite }
);

our %sub = (
	'' => { 
		''      	=> $o_null,	
		'0'      	=> 0,	
		$null     	=> $o_null,	
		$infinite 	=> $o_minus_infinite,
		$minus_infinite => $o_infinite },
	'0' => { 
		''      	=> 0,	
		'0'      	=> 0,	
		$null     	=> 0,	
		$infinite 	=> $o_minus_infinite,
		$minus_infinite => $o_infinite },
	$null => { 
		''      	=> $o_null,	
		'0'      	=> 0,	
		$null     	=> $o_null,	
		$infinite 	=> $o_minus_infinite,
		$minus_infinite => $o_infinite },
	$infinite => { 
		''      	=> $o_infinite,	
		'0'     	=> $o_infinite,	
		$null    	=> $o_infinite,	
		$infinite 	=> $o_elem_undef,
		$minus_infinite => $o_infinite },
	$minus_infinite => { 
		''      	=> $o_minus_infinite,	
		'0'     	=> $o_minus_infinite,	
		$null    	=> $o_minus_infinite,	
		$infinite 	=> $o_minus_infinite,
		$minus_infinite => $o_elem_undef }
);

# 0 ne null !
our %cmp = (
	'' => { 
		''      	=> 0,	
		'0'      	=> 0,	
		$null     	=> 0,	
		$infinite 	=> -1,
		$minus_infinite => 1 },
	'0' => { 
		''      	=> 0,	
		'0'      	=> 0,	
		$null     	=> 1,	
		$infinite 	=> -1,
		$minus_infinite => 1 },
	$null => { 
		''      	=> 0,	
		'0'      	=> -1,	
		$null     	=> 0,	
		$infinite 	=> -1,
		$minus_infinite => 1 },
	$infinite => { 
		''      	=> 1,	
		'0'     	=> 1,	
		$null    	=> 1,	
		$infinite 	=> 0,
		$minus_infinite => 1 },
	$minus_infinite => { 
		''      	=> -1,	
		'0'     	=> -1,	
		$null    	=> -1,	
		$infinite 	=> -1,
		$minus_infinite => 0 }
);

sub add {
	my ($tmp1, $tmp2, $inverted) = @_;
	my $stmp1 =  "$tmp1";
	my $stmp2 =  "$tmp2";

	my $tmp = $add{$stmp1}{$stmp2};
	return $tmp if defined($tmp);

	return infinite 	if $stmp1 eq $infinite;
	return minus_infinite 	if $stmp1 eq $minus_infinite;
	return infinite  	if $stmp2 eq $infinite;
	return minus_infinite 	if $stmp2 eq $minus_infinite;

	return $tmp1 	if $null{$stmp2};
	return $tmp2 	if $null{$stmp1};

	return $tmp1 + $tmp2;

}

sub sub {
	my ($tmp1, $tmp2, $inverted) = @_;

	if ($inverted) {
		($tmp2, $tmp1) = ($tmp1, $tmp2);
	}

	my $stmp1 =  "$tmp1";
	my $stmp2 =  "$tmp2";


	my $tmp = $sub{$stmp1}{$stmp2};
	return $tmp if defined($tmp);

	return $tmp1	if $null{$stmp2};
	return - $tmp2	if $null{$stmp1};

	return infinite     	if $stmp1 eq $infinite;
	return minus_infinite  	if $stmp1 eq $minus_infinite;

	return minus_infinite  	if $stmp2 eq $infinite;
	return infinite     	if $stmp2 eq $minus_infinite;
	return $tmp1 - $tmp2;
}

sub spaceship {
	my ($tmp1, $tmp2, $inverted) = @_;
	my $res;
	my ($stmp1, $stmp2);

	# print " [inf:cmp:", $tmp1, "<=>", $tmp2, "] ";
	$tmp2 = "" unless defined($tmp2);

	if ($inverted) {
		($tmp2, $tmp1) = ($tmp1, $tmp2);
	}

	$stmp1 = "$tmp1";
	$stmp2 = "$tmp2";

	my $tmp = $cmp{$stmp1}{$stmp2};
	if (defined($tmp)) {
		return $tmp ;
	}

	return 1	if $null{$stmp2};
	return -1	if $null{$stmp1};

	if    ($stmp1 eq $stmp2) 	{ $res = 0; }
	elsif ($stmp1 eq $infinite)  	{ $res = 1; }
	elsif ($stmp2 eq $infinite)  	{ $res = -1; }
	elsif ($stmp1 eq $minus_infinite) { $res = -1; }
	elsif ($stmp2 eq $minus_infinite) { $res = 1; }
	else { 
		$res = ( $tmp1 <=> $tmp2 ); 
		$res = ( $stmp1 cmp $stmp2 ) unless $res; 
	}
	return $res;
}

sub cmp {
	return spaceship @_;
}


1;