package Set::Infinite::Basic;

# Copyright (c) 2001, 2002 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

require 5.005_03;
use strict;
# use warnings;

require Exporter;
use Carp;
use Data::Dumper; 
use vars qw( @ISA @EXPORT_OK @EXPORT $VERSION );
use vars qw( $Type $tolerance $fixtype $inf $minus_inf @separators $neg_inf );

@ISA = qw(Exporter);
@EXPORT_OK = qw( INFINITY NEG_INFINITY );
@EXPORT = qw();
$VERSION = '0.00_01';

$inf            = 100**100**100;
$minus_inf = $neg_inf = -$inf;
use constant INFINITY => $inf;
use constant NEG_INFINITY => $minus_inf;

=head1 NAME

Set::Infinite::Basic - Sets of intervals

=head1 SYNOPSIS

  use Set::Infinite::Basic;

  $a = Set::Infinite::Basic->new(1,2);    # [1..2]
  print $a->union(5,6);            # [1..2],[5..6]

=head1 DESCRIPTION

Set::Infinite::Basic is a Set Theory module for infinite sets. 

It works on reals, integers, and objects.

This module does not support recurrences. Recurrences are implemented in Set::Infinite.

=head1 METHODS

=cut


use overload
    '<=>' => \&spaceship,
    qw("" as_string),
;


#  _simple_* - an interval of 2 scalars
use vars qw( $simple_null $simple_everything $simple_inf $simple_minus_inf );
$simple_null =           undef;  
$simple_everything =     _simple_fastnew(-$inf,  $inf, 1, 1);
$simple_inf =            _simple_fastnew( $inf,  $inf, 1, 1);
$simple_minus_inf =      _simple_fastnew(-$inf, -$inf, 1, 1);
sub _simple_null () { undef }

# TODO: make this an object _and_ class method
# TODO: POD
sub separators {
    return $separators[ $_[1] ] if $#_ == 1;
    @separators = @_ if @_;
    return @separators;
}

BEGIN {
    separators (
        '[', ']',    # a closed interval
        '(', ')',    # an open interval
        '..',        # number separator
        ','          # list separator
    );
    # global defaults for object private vars
    $Type = undef;
    $tolerance = 0;
    $fixtype = 1;
}


# _simple_* set of internal methods: basic processing of "spans"

sub _simple_intersects {
    my $tmp1 = $_[0];
    my $tmp2 = $_[1];
    my ($i_beg, $i_end, $open_beg, $open_end);
    my $cmp = $tmp1->{a} <=> $tmp2->{a};
    if ($cmp < 0) {
        $i_beg       = $tmp2->{a};
        $open_beg    = $tmp2->{open_begin};
    }
    elsif ($cmp > 0) {
        $i_beg       = $tmp1->{a};
        $open_beg    = $tmp1->{open_begin};
    }
    else {
        $i_beg       = $tmp1->{a};
        $open_beg    = $tmp1->{open_begin} || $tmp2->{open_begin};
    }
    $cmp = $tmp1->{b} <=> $tmp2->{b};
    if ($cmp > 0) {
        $i_end       = $tmp2->{b};
        $open_end    = $tmp2->{open_end};
    }
    elsif ($cmp < 0) {
        $i_end       = $tmp1->{b};
        $open_end    = $tmp1->{open_end};
    }
    else { 
        $i_end       = $tmp1->{b};
        $open_end    = ($tmp1->{open_end} || $tmp2->{open_end});
    }
    $cmp = $i_beg <=> $i_end;
    return 0 if 
        ( $cmp > 0 ) || 
        ( ($cmp == 0) && ($open_beg || $open_end) ) ;
    return 1;
}


sub _simple_complement {
    my $self = $_[0];
    return $simple_everything unless defined $self->{a};
    my $tmp1 = _simple_fastnew($neg_inf, $self->{a}, 1, ! $self->{open_begin} );
    my $tmp2 = _simple_fastnew($self->{b}, $inf, ! $self->{open_end}, 1);
    if ($tmp2->{a} == $inf) {
        return $simple_null if ($tmp1->{b} == $neg_inf);
        return $tmp1;
    }
    return $tmp2 if ($tmp1->{b} == $neg_inf);
    ($tmp1 , $tmp2);
}

sub _simple_union {
    my ($tmp2, $tmp1, $tolerance) = @_; 
    my %tmp1 = %$tmp1;
    my %tmp2 = %$tmp2;
    my $cmp; 
    if ($tolerance) {
        # "integer"
        my $a1_open =  $tmp1{open_begin} ? -$tolerance : $tolerance ;
        my $b1_open =  $tmp1{open_end}   ? -$tolerance : $tolerance ;
        my $a2_open =  $tmp2{open_begin} ? -$tolerance : $tolerance ;
        my $b2_open =  $tmp2{open_end}   ? -$tolerance : $tolerance ;
        # open_end touching?
        if ((($tmp1{b}+$tmp1{b}) + $b1_open ) < 
            (($tmp2{a}+$tmp2{a}) - $a2_open)) {
            # self disjuncts b
            return ( $tmp1, $tmp2 );
        }
        if ((($tmp1{a}+$tmp1{a}) - $a1_open ) > 
            (($tmp2{b}+$tmp2{b}) + $b2_open)) {
            # self disjuncts b
            return ( $tmp2, $tmp1 );
        }
    }
    else {
        # "real"
        $cmp = $tmp1{b} <=> $tmp2{a};
        if ( $cmp < 0 ||
             ( $cmp == 0 && $tmp1{open_end} && $tmp2{open_begin} ) ) {
            return ( $tmp1, $tmp2 );
        }
        $cmp = $tmp1{a} <=> $tmp2{b};
        if ( $cmp > 0 || 
             ( $cmp == 0 && $tmp2{open_end} && $tmp1{open_begin} ) ) {
            return ( $tmp2, $tmp1 );
        }
    }

    my %tmp;
    $cmp = $tmp1{a} <=> $tmp2{a};
    if ($cmp > 0) {
        $tmp{a} = $tmp2{a};
        $tmp{open_begin} = $tmp2{open_begin};
    }
    elsif ($cmp == 0) {
        $tmp{a} = $tmp1{a};
        $tmp{open_begin} = $tmp1{open_begin} ? $tmp2{open_begin} : 0;
    }
    else {
        $tmp{a} = $tmp1{a};
        $tmp{open_begin} = $tmp1{open_begin};
    }

    $cmp = $tmp1{b} <=> $tmp2{b};
    if ($cmp < 0) {
        $tmp{b} = $tmp2{b};
        $tmp{open_end} = $tmp2{open_end};
    }
    elsif ($cmp == 0) {
        $tmp{b} = $tmp1{b};
        $tmp{open_end} = $tmp1{open_end} ? $tmp2{open_end} : 0;
    }
    else {
        $tmp{b} = $tmp1{b};
        $tmp{open_end} = $tmp1{open_end};
    }
    return \%tmp;
}


sub _simple_spaceship {
    my ($tmp1, $tmp2, $inverted) = @_;
    my $cmp;
    if ($inverted) {
        $cmp = $tmp2->{a} <=> $tmp1->{a};
        return $cmp if $cmp;
        $cmp = $tmp1->{open_begin} <=> $tmp2->{open_begin};
        return $cmp if $cmp;
        $cmp = $tmp2->{b} <=> $tmp1->{b};
        return $cmp if $cmp;
        return $tmp1->{open_end} <=> $tmp2->{open_end};
    }
    $cmp = $tmp1->{a} <=> $tmp2->{a};
    return $cmp if $cmp;
    $cmp = $tmp2->{open_begin} <=> $tmp1->{open_begin};
    return $cmp if $cmp;
    $cmp = $tmp1->{b} <=> $tmp2->{b};
    return $cmp if $cmp;
    return $tmp2->{open_end} <=> $tmp1->{open_end};
}


sub _simple_new {
    my ($tmp, $tmp2, $type) = @_;
    if ($type) {
        if ( ref($tmp) ne $type ) { 
            $tmp = new $type $tmp;
        }
        if ( ref($tmp2) ne $type ) {
            $tmp2 = new $type $tmp2;
        }
    }
    if ($tmp > $tmp2) {
        ($tmp, $tmp2) = ($tmp2, $tmp);
    }
    return { a => $tmp , b => $tmp2 , open_begin => 0 , open_end => 0 };
}


sub _simple_fastnew {
    { a => $_[0] , b => $_[1] , open_begin => $_[2] , open_end => $_[3] };
}

sub _simple_as_string {
    my $self = $_[0];
    my $s;
    return "" unless defined $self;
    $self->{open_begin} = 1 if ($self->{a} == -$inf );
    $self->{open_end}   = 1 if ($self->{b} == $inf );
    my $tmp1 = $self->{a};
    $tmp1 = $tmp1->datetime if UNIVERSAL::can( $tmp1, 'datetime' );
    $tmp1 = "$tmp1";
    my $tmp2 = $self->{b};
    $tmp2 = $tmp2->datetime if UNIVERSAL::can( $tmp2, 'datetime' );
    $tmp2 = "$tmp2";
    return $tmp1 if $tmp1 eq $tmp2;
    $s = $self->{open_begin} ? $separators[2] : $separators[0];
    $s .= $tmp1 . $separators[4] . $tmp2;
    $s .= $self->{open_end} ? $separators[3] : $separators[1];
    return $s;
}

# end of "_simple_" methods


sub type {
    my $self = shift;
    unless (@_) {
        return ref($self) ? $self->{type} : $Type;
    }
    my $tmp_type = shift;
    eval "use " . $tmp_type;
    carp "Warning: can't start $tmp_type : $@" if $@;
    if (ref($self))  {
        $self->{type} = $tmp_type;
        return $self;
    }
    else {
        $Type = $tmp_type;
        return $Type;
    }
}

sub list {
    my $self = shift;
    my @b = ();
    foreach (@{$self->{list}}) {
        push @b, $self->new($_);
    }
    return @b;
}

sub fixtype {
    my $self = shift;
    $self = $self->copy;
    $self->{fixtype} = 1;
    my $type = $self->type;
    foreach (@{$self->{list}}) {
        $_->{a} = $type->new($_->{a}) unless ref($_->{a});
        $_->{b} = $type->new($_->{b}) unless ref($_->{b});
    }
    return $self;
}

sub numeric {
    my $self = shift;
    return $self unless $self->{fixtype};
    $self = $self->copy;
    $self->{fixtype} = 0;
    foreach (@{$self->{list}}) {
        $_->{a} = 0 + $_->{a};
        $_->{b} = 0 + $_->{b};
    }
    return $self;
}

sub _no_cleanup {
    my ($self) = shift;
    $self->{cant_cleanup} = 1;
    return $self;
}

sub first {
    my $self = $_[0];
    if (exists $self->{first} ) {
        return wantarray ? @{$self->{first}} : $self->{first}[0];
    }
    unless ( @{$self->{list}} ) {
        return wantarray ? (undef, 0) : undef; 
    }
    my $first = $self->new( @{$self->{list}} [0] );
    return $first unless wantarray;
    my $res = $self->new->_no_cleanup;
    push @{$res->{list}}, @{$self->{list}} [1 .. $#{$self->{list}}];
    return @{$self->{first}} = ($first) if $res->is_null;
    return @{$self->{first}} = ($first, $res);
}

sub last {
    my $self = $_[0];
    if (exists $self->{last} ) {
        return wantarray ? @{$self->{last}} : $self->{last}[0];
    }
    unless ( @{$self->{list}} ) {
        return wantarray ? (undef, 0) : undef;
    }
    my $last = $self->new( @{$self->{list}} [-1] );
    return $last unless wantarray;  
    my $res = $self->new->_no_cleanup;
    push @{$res->{list}}, @{$self->{list}} [0 .. $#{$self->{list}}-1];
    return @{$self->{last}} = ($last) if $res->is_null;
    return @{$self->{last}} = ($last, $res);
}

sub is_null {
    @{$_[0]->{list}} ? 0 : 1;
}

sub intersects {
    my $a = shift;
    my ($b, $ia, $n);
    if (ref ($_[0]) eq ref($a) ) { 
        $b = shift;
    } 
    else {
        $b = $a->new(@_);  
    }
    my $ib;
    my ($na, $nb) = (0,0);

    $n = $#{$a->{list}};
    if ($n > 4) {
        foreach $ib ($nb .. $#{$b->{list}}) {
            foreach $ia ($n, $n-1, 0 .. $n - 2) {
                return 1 if _simple_intersects($a->{list}->[$ia], $b->{list}->[$ib]);
            }
        }
        return 0;
    }
    foreach $ib ($nb .. $#{$b->{list}}) {
        foreach $ia ($na .. $n) {
            return 1 if _simple_intersects($a->{list}->[$ia], $b->{list}->[$ib]);
        }
    }
    0;    
}

sub iterate {
    # TODO: options 'no-sort', 'no-merge', 'keep-null' ...
    my $a = shift;
    my $iterate = $a->new();
    my ($tmp, $ia);
    my $subroutine = shift;
    foreach $ia (0 .. $#{$a->{list}}) {
        $tmp = &{$subroutine} ( $a->new($a->{list}->[$ia]), @_ );
        $iterate = $iterate->union($tmp) if defined $tmp; 
    }
    return $iterate;    
}

sub intersection {
    my $a1 = shift;
    my $b1;
    if (ref ($_[0]) eq ref($a1) ) {
        $b1 = shift;
    } 
    else {
        $b1 = $a1->new(@_);  
    }
    my ($ia, $ib);
    my ($ma, $mb) = ($#{$a1->{list}}, $#{$b1->{list}});
    my $intersection = $a1->new();
    # for-loop optimization (makes little difference)
    if ($ma < $mb) { 
        ($ma, $mb) = ($mb, $ma);
        ($a1, $b1) = ($b1, $a1);
    }
    my ($tmp1, $tmp2, $tmp1a, $tmp2a, $tmp1b, $tmp2b, $i_beg, $i_end, $open_beg, $open_end, $cmp1);
    my $a0 = 0;
    my @a;

    B: foreach $ib (0 .. $mb) {
        $tmp2 = $b1->{list}[$ib];
        $tmp2a = $tmp2->{a};
        $tmp2b = $tmp2->{b};
        A: foreach $ia ($a0 .. $ma) {
            $tmp1 = $a1->{list}[$ia];
            $tmp1b = $tmp1->{b};

            if ($tmp1b < $tmp2a) {
                $a0++;
                next A;
            }
            $tmp1a = $tmp1->{a};
            if ($tmp1a > $tmp2b) {
                next B;
            }
            if ($tmp1a < $tmp2a) {
                $tmp1a        = $tmp2a;
                $open_beg     = $tmp2->{open_begin};
            }
            elsif ($tmp1a == $tmp2a) {
                $open_beg     = ($tmp1->{open_begin} or $tmp2->{open_begin});
            }
            else {
                $open_beg     = $tmp1->{open_begin};
            }

            if ($tmp1b > $tmp2b) {
                $tmp1b        = $tmp2b;
                $open_end     = $tmp2->{open_end};
            }
            elsif ($tmp1b == $tmp2b) {
                $open_end     = ($tmp1->{open_end} or $tmp2->{open_end});
            }
            else {
                $open_end    = $tmp1->{open_end};
            }
            if ( ( $tmp1a <= $tmp1b ) and
                 ( ($tmp1a != $tmp1b) or 
                   (!$open_beg and !$open_end) or
                   ($tmp1a == $inf) or
                   ($tmp1a == $neg_inf)
                 )
               ) {
                push @a, 
                    { a => $tmp1a, b => $tmp1b, 
                      open_begin => $open_beg, open_end => $open_end } ;
            }
        }
    }
    $intersection->{list} = \@a;
    return $intersection;    
}


sub complement {
    my $self = shift;
    if (@_) {
        if (ref ($_[0]) eq ref($self) ) {
            $a = shift;
        } 
        else {
            $a = $self->new(@_);  
        }
        return $self->intersection( $a->complement );
    }

    unless ( @{$self->{list}} ) {
        return $self->new($neg_inf, $inf);
    }
    my $complement = $self->new();
    @{$complement->{list}} = _simple_complement($self->{list}->[0]); 

    my $tmp = $self->new();
    foreach my $ia (1 .. $#{$self->{list}}) {
        @{$tmp->{list}} = _simple_complement($self->{list}->[$ia]); 
        $complement = $complement->intersection($tmp); 
    }
    return $complement;    
}

=head2 until

Extends a set until another:

    0,5,7 -> until 2,6,10

gives

    [0..2), [5..6), [7..10)

Note: this function is still experimental.

=cut

sub until {
    my $a1 = shift;
    my $b1;
    if (ref ($_[0]) eq ref($a1) ) {
        $b1 = shift;
    } 
    else {
        $b1 = $a1->new(@_);  
    }
    my @b1_min = $b1->min_a;
    my @a1_max = $a1->max_a;

    unless (defined $b1_min[0]) {
        return $a1->until($inf);
    }
    unless (defined $a1_max[0]) {
        return $a1->new(-$inf)->until($b1);
    }

    my ($ia, $ib, $begin, $end);
    $ia = 0;
    $ib = 0;

    my $u = $a1->new;   
    my $last = -$inf;
    while ( ($ia <= $#{$a1->{list}}) && ($ib <= $#{$b1->{list}})) {
        $begin = $a1->{list}[$ia]{a};
        $end   = $b1->{list}[$ib]{b};
        if ( $end <= $begin ) {
            push @{$u->{list}}, {
                a => $last ,
                b => $end ,
                open_begin => 0 ,
                open_end => 1 };
            $ib++;
            $last = $end;
            next;
        }
        push @{$u->{list}}, { 
            a => $begin , 
            b => $end ,
            open_begin => 0 , 
            open_end => 1 };
        $ib++;
        $ia++;
        $last = $end;
    }
    if ($ia <= $#{$a1->{list}}) {
        push @{$u->{list}}, {
            a => $a1->{list}[$ia]{a} ,
            b => $inf ,
            open_begin => 0 ,
            open_end => 1 };
    }
    return $u;    
}

sub union {
    my $a1 = shift;
    my $b1;
    if (ref ($_[0]) eq ref($a1) ) {
        $b1 = shift;
    } 
    else {
        $b1 = $a1->new(@_);  
    }
    # test for union with empty set
    if ( $#{ $a1->{list} } < 0 ) {
        return $b1;
    }
    if ( $#{ $b1->{list} } < 0 ) {
        return $a1;
    }
    my @b1_min = $b1->min_a;
    my @a1_max = $a1->max_a;
    unless (defined $b1_min[0]) {
        return $a1;
    }
    unless (defined $a1_max[0]) {
        return $b1;
    }
    my ($ia, $ib);
    $ia = 0;
    $ib = 0;

    #  size+order matters on speed 
    $a1 = $a1->new($a1);    # don't modify ourselves 
    my $b_list = $b1->{list};
    # -- frequent case - $b1 is after $a1
    if ($b1_min[0] > $a1_max[0]) {
        push @{$a1->{list}}, @$b_list;
        return $a1;
    }

    B: foreach $ib ($ib .. $#{$b_list}) {
        foreach $ia ($ia .. $#{$a1->{list}}) {
            my @tmp = _simple_union($a1->{list}[$ia], $b_list->[$ib], $a1->{tolerance});
            if ($#tmp == 0) {
                    $a1->{list}[$ia] = $tmp[0];
                    next B;
            }
            if ($a1->{list}[$ia]{a} >= $b_list->[$ib]{a}) {
                splice (@{$a1->{list}}, $ia, 0, $b_list->[$ib]);
                next B;
            }
        }
        push @{$a1->{list}}, $b_list->[$ib];
    }
    return $a1;    
}


# there are some ways to process 'contains':
# A CONTAINS B IF A == ( A UNION B )
#    - faster
# A CONTAINS B IF B == ( A INTERSECTION B )
#    - can backtrack = works for unbounded sets
sub contains {
    my $a = shift;
    my $b1 = $a->union(@_);
    return ($b1 == $a) ? 1 : 0;
}

=head2 copy

Makes a new object from the object's data.

=cut

sub copy {
    my $self = shift;
    my $copy = $self->new();
    return $copy unless ref($self);   # constructor!
    foreach my $key (keys %{$self}) {
        if ( ref( $self->{$key} ) eq 'ARRAY' ) {
            @{ $copy->{$key} } = @{ $self->{$key} };
        }
        else {
            $copy->{$key} = $self->{$key};
        }
    }
    return $copy;
}


sub new {
    my $class = shift;
    my $self;
    if ( ref $class ) {
        $self = bless {
                    list      => [],
                    tolerance => $class->{tolerance},
                    type      => $class->{type},
                    fixtype   => $class->{fixtype},
                }, ref($class);
    }
    else {
        $self = bless { 
                    list      => [],
                    tolerance => $tolerance ? $tolerance : 0,
                    type      => $class->type,
                    fixtype   => $fixtype   ? $fixtype : 0,
                }, $class;
    }
    my ($tmp, $tmp2, $ref);
    while (@_) {
        $tmp = shift;
        $ref = ref($tmp);
        if ($ref) {
            if ($ref eq 'ARRAY') {
                # allows arrays of arrays
                $tmp = $class->new(@{$tmp});  # call new() recursively
                push @{ $self->{list} }, @{$tmp->{list}};
                next;
            }
            if ($ref eq 'HASH') {
                push @{ $self->{list} }, $tmp; 
                next;
            }
            if ($tmp->isa(__PACKAGE__)) {
                push @{ $self->{list} }, @{$tmp->{list}};
                next;
            }
        }
        $tmp2 = shift || $tmp;
        push @{ $self->{list} }, _simple_new($tmp,$tmp2, $self->{type} )
    }
    $self;
}

sub min { 
    ($_[0]->min_a)[0];
}

sub min_a { 
    my $self = $_[0];
    return @{$self->{min}} if exists $self->{min};
    return @{$self->{min}} = (undef, 0) unless @{$self->{list}};
    my $tmp = $self->{list}[0]->{a};
    my $tmp2 = $self->{list}[0]{open_begin} || 0;
    if ($tmp2 && $self->{tolerance}) {
            $tmp2 = 0;
            $tmp += $self->{tolerance};
    }
    return @{$self->{min}} = ($tmp, $tmp2);  
};

sub max { 
    ($_[0]->max_a)[0];
}

sub max_a { 
    my $self = $_[0];
    return @{$self->{max}} if exists $self->{max};
    return @{$self->{max}} = (undef, 0) unless @{$self->{list}};
    my $tmp = $self->{list}[-1]{b};
    my $tmp2 = $self->{list}[-1]{open_end} || 0;
    if ($tmp2 && $self->{tolerance}) {
            $tmp2 = 0;
            $tmp -= $self->{tolerance};
    }
    return @{$self->{max}} = ($tmp, $tmp2);  
};

sub count {
    1 + $#{$_[0]->{list}};
}

sub size { 
    my $self = $_[0];
    my $size;  
    foreach( @{$self->{list}} ) {
        if ( $size ) {
            $size += $_->{b} - $_->{a};
        }
        else {
            $size = $_->{b} - $_->{a};
        }
        if ( $self->{tolerance} ) {
            $size += $self->{tolerance} unless $_->{open_end};
            $size -= $self->{tolerance} if $_->{open_begin};
            $size -= $self->{tolerance} if $_->{open_end};
        }
    }
    return $size; 
};

sub span { 
    my $self = $_[0];
    my @max = $self->max_a;
    my @min = $self->min_a;
    return undef unless defined $min[0] && defined $max[0];
    my $a1 = $self->new($min[0], $max[0]);
    $a1->{list}[0]{open_end} = $max[1];
    $a1->{list}[0]{open_begin} = $min[1];
    return $a1;
};

sub spaceship {
    my ($tmp1, $tmp2, $inverted) = @_;
    if ($inverted) {
        ($tmp2, $tmp1) = ($tmp1, $tmp2);
    }
    foreach(0 .. $#{$tmp1->{list}}) {
        my $this  = $tmp1->{list}->[$_];
        if ($_ > $#{ $tmp2->{list} } ) { 
            return 1; 
        }
        my $other = $tmp2->{list}->[$_];
        my $cmp = _simple_spaceship($this, $other);
        return $cmp if $cmp;   # this != $other;
    }
    return $#{ $tmp1->{list} } == $#{ $tmp2->{list} } ? 0 : -1;
}

sub tolerance {
    my $self = shift;
    my $tmp = pop;
    if (ref($self)) {  
        # local
        return $self->{tolerance} unless defined $tmp;
        $self = $self->copy;
        $self->{tolerance} = $tmp;
        delete $self->{max};  # tolerance may change "max"
        return $self;
    }
    # global
    $tolerance = $tmp if defined($tmp);
    return $tolerance;
}

sub integer { 
    $_[0]->tolerance (1);
}

sub real {
    $_[0]->tolerance (0);
}

sub as_string {
    my $self = shift;
    return join( __PACKAGE__->separators(5), map { _simple_as_string($_) } @{$self->{list}} );
}


sub DESTROY {}

1;
__END__

=head2 Mode functions:    

    $a->real;

    $a->integer;

=head2 Logic functions:

    $logic = $a->intersects($b);

    $logic = $a->contains($b);

    $logic = $a->is_null;

=head2 Set functions:

    $i = $a->union($b);    

    $i = $a->intersection($b);

    $i = $a->complement;
    $i = $a->complement($b);

    $i = $a->span;   

        result is (min .. max)

=head2 Scalar functions:

    $i = $a->min;

    $i = $a->max;

    $i = $a->size;  

    $i = $a->count;  # number of spans

=head2 Overloaded Perl functions:

    print    

    sort, <=> 

=head2 Global functions:

    separators(@i)

        chooses the interval separators. 

        default are [ ] ( ) '..' ','.

    INFINITY

        returns an 'Infinity' number.

    NEG_INFINITY

        returns a '-Infinity' number.

    iterate ( sub { } )

        Iterates over a subroutine. 
        Returns the union of partial results.

    first

        In scalar context returns the first interval of a set.

        In list context returns the first interval of a set, and the
        'tail'.

        Works in unbounded sets

    type($i)

        chooses an object data type. 

        default is none (a normal perl SCALAR).

        examples: 

        type('Math::BigFloat');
        type('Math::BigInt');
        type('Set::Infinite::Date');
            See notes on Set::Infinite::Date below.

    tolerance(0)    defaults to real sets (default)
    tolerance(1)    defaults to integer sets

    real            defaults to real sets (default)

    integer         defaults to integer sets

=head2 Internal functions:

    $a->fixtype; 

    $a->numeric;

=head1 CAVEATS

    $a = Set::Infinite->new(10,1);
        Will be interpreted as [1..10]

    $a = Set::Infinite->new(1,2,3,4);
        Will be interpreted as [1..2],[3..4] instead of [1,2,3,4].
        You probably want ->new([1],[2],[3],[4]) instead,
        or maybe ->new(1,4) 

    $a = Set::Infinite->new(1..3);
        Will be interpreted as [1..2],3 instead of [1,2,3].
        You probably want ->new(1,3) instead.

=head1 INTERNALS

The internal representation of a I<span> is a hash:

    { a =>   start of span,
      b =>   end of span,
      open_begin =>   '0' the span starts in 'a'
                      '1' the span starts after 'a'
      open_end =>     '0' the span ends in 'b'
                      '1' the span ends before 'b'
    }

For example, this set:

    [100..200),300,(400..infinity)

is represented by the array of hashes:

    list => [
        { a => 100, b => 200, open_begin => 0, open_end => 1 },
        { a => 300, b => 300, open_begin => 0, open_end => 0 },
        { a => 400, b => infinity, open_begin => 0, open_end => 1 },
    ]

The I<density> of a set is stored in the C<tolerance> variable:

    tolerance => 0;  # the set is made of real numbers.

    tolerance => 1;  # the set is made of integers.

The C<type> variable stores the I<class> of objects that will be stored in the set.

    type => 'DateTime';   # this is a set of DateTime objects

The I<infinity> value is generated by Perl, when it finds a numerical overflow:

    $inf = 100**100**100;

=head1 SEE ALSO

    Set::Infinite

=head1 AUTHOR

    Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

