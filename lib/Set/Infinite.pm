package Set::Infinite;

# Copyright (c) 2001, 2002 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

require 5.005_62;
use strict;
use warnings;

require Exporter;
# use AutoLoader qw(AUTOLOAD);
use Carp;

our @ISA = qw(Exporter);

# This allows declaration    use Set::Infinite ':all';
our %EXPORT_TAGS = ( 'all' => [ qw(type inf new ) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } , qw(type inf new ) );
our @EXPORT = qw();

our $VERSION = '0.36_11';

our $TRACE = 0;      # basic trace method execution
our $DEBUG_BT = 0;     # backtrack tracer

# Preloaded methods go here.

use Set::Infinite::_Simple;

# global defaults 
#    for object private vars
our $type = '';
our $tolerance = 0;


sub inf();
sub infinite();
sub minus_infinite();
sub null();

our $too_complex = "Too complex";
our $backtrack_depth = 0;
our $max_backtrack_depth = 10;

=head1 NAME

Set::Infinite - Sets of intervals

=head1 SYNOPSIS

  use Set::Infinite;

  $a = Set::Infinite->new(1,2);    # [1..2]
  print $a->union(5,6);            # [1..2],[5..6]

=head1 DESCRIPTION

Set::Infinite is a Set Theory module for infinite sets. 

It works on reals or integers.
You can provide your own objects or let it make them for you
using the `type'.

It works very well on dates, providing schedule checks (intersections),
unions, and infinite recurrences.

=head1 METHODS

=cut


use overload
    # '@{}' => \&{ 
    #    return () unless $#_ >= 0;
    #    print " [\@:$_[0]:",caller,":", ref(\$_[0]), "] "; 
    #    # return () if ref(\$_[0]) eq 'SCALAR'; # ???
    #    # return () unless exist $_[0]->{list};
    #    return compact_array($_[0]->{list});
    # },
    '<=>' => \&spaceship,
    qw("" as_string),
;

sub type {
    # this is still a hack - waiting for better ideas
    my $tmp_type = pop;
    my $self = shift || __PACKAGE__;

    # print " [TYPE:$tmp_type -- $self] \n";

    if (defined($tmp_type) and ($tmp_type ne '')) {
        if (ref($self)) {
            # local
            $self->{type} = $tmp_type;
        }
        else {
            # global
            $type = $tmp_type;
        }
        eval "use " . $tmp_type; 
        carp "Warning: can't start $tmp_type : $@" if $@;
     }
    return $self;
}

sub list {
    my $self = shift;
    # my $class = ref($self);
    my @b = ();
    foreach (@{$self->{list}}) {
        push @b, $self->new($_);
    }
    return @b;
}

sub fixtype {
    my $self = shift;
    foreach (@{$self->{list}}) {
        $_->{a} = $type->new($_->{a}) unless ref($_->{a});
        $_->{b} = $type->new($_->{b}) unless ref($_->{b});
    }
    return $self;
}

sub compact {
    my $self = shift;
    # my $class = ref($self);

    my $b = $self->new();
    if ($self->{too_complex}) {
        $self->trace(title=>"compact:backtrack"); 
        # print " [compact:backtrack] \n" if $DEBUG_BT;
        $b->{too_complex} = 1;
        $b->{parent} = $self->copy;
        $b->{method} = 'compact';
        $b->{param}  = \@_;
        return $b;
    }
    foreach (@{$self->{list}}) {
        unless ( Set::Infinite::Element_Inf::is_null($_->{a}) ) {
            push @{$b->{list}}, $_;
        }
    }
    $b->{cant_cleanup} = 1; 
    return $b;
}

sub trace { # title=>'aaa'
    return shift unless $TRACE;
    my ($self, %parm) = @_;
    my @caller = caller(1);
    # my $nothing = "$self";
    print " [",$caller[1],":",$caller[2]," \"$parm{title}\" $self ]\n" if $TRACE == 1;
    print " [",sprintf("%4d", $caller[2]),": \"$parm{title}\" ]\n" if $TRACE == 2;
    return $self;
}

use Set::Infinite::Quantize_Date;
use Set::Infinite::Function;     # used under Select/Offset
use Set::Infinite::Select;       # tied
use Set::Infinite::Offset;       # tied

# quantize: splits in same-size subsets

sub quantize {
    my $self = shift;
    # $self->trace(title=>"quantize"); 
    if (($self->{too_complex}) or ($self->min == -&inf) or ($self->max == &inf)) {
        $self->trace(title=>"quantize:backtrack"); 
        # print " [quantize:backtrack] \n" if $DEBUG_BT;
        my $b = $self->new();
        $b->{too_complex} = 1;
        $b->{parent} = $self->copy;
        $b->{method} = 'quantize';
        $b->{param}  = \@_;
        return $b;
    }
    $self->trace(title=>"quantize"); 
    my (@a);
    my %param = @_;
    my @a2;
    tie @a, 'Set::Infinite::Quantize_Date', $self, %param;
    my $b = $self->new();        # $self); # clone myself
    $b->{list} = \@a;        # change data
    $b->{cant_cleanup} = 1;     # quantize output is "virtual" (tied) -- can't splice, sort
    # print " [QUANT:returns:",ref($b),"] \n";
    return $b;
}


# select: position-based selection of subsets

sub select {
    my $self = shift;
    $self->trace(title=>"select");
    if ($self->{too_complex}) {
        my $b = $self->new();
        $b->{too_complex} = 1;
        $b->{parent} = $self->copy;
        $b->{method} = 'select';
        $b->{param}  = \@_;
        return $b;
    }
    my (@a);
    my %param = @_;
    my @a2;
    # print " [INF:SELECT $tmp,",@_,",$self FROM:", $self->{list}->[0],"]\n";
    tie @a, 'Set::Infinite::Select', $self, %param;
    my $b = $self->new();        # $self); # clone myself
    $b->{list} = \@a;        # change data
    $b->{cant_cleanup} = 1;     # select output is "virtual" (tied) -- can't splice, sort
    return $b;
}

# offset: offsets subsets
sub offset {
    my $self = shift;
    #  my $class = ref($self);

    $self->trace(title=>"offset");

    if ($self->{too_complex}) {
        my $b1 = $self->new();
        $b1->{too_complex} = 1;
        $b1->{parent} = $self->copy;
        $b1->{method} = 'offset';
        $b1->{param}  = \@_;
        return $b1;
    }

    # return $self if $#{ $self->{list} } < 0;

    my @a;
    my %param = @_;
    my $b1 = $self->new();        # $self); # clone myself

    unless (ref($param{value}) eq 'ARRAY') {
        #print " [value:scalar:", $param{value} ,"]\n";
        $param{value} = [0 + $param{value}, 0 + $param{value}];
    }
    $param{mode}   =      'offset' unless $param{mode};
    $param{unit}   =      'one'    unless $param{unit};
    my $parts  =      ($#{$param{value}}) / 2;
    # $param{strict} =      0        unless $param{strict};
    $param{fixtype} =     1        unless exists $param{fixtype};
    # $param{fetchsize} = $param{parts} * (1 + $#{ $self->{list} });
    my $sub_unit =    $Set::Infinite::Arithmetic::subs_offset2{$param{unit}};
    my $sub_mode =    $Set::Infinite::Offset::_MODE{$param{mode}};
    # $param{parent_list} = $self->{list};

    # print " [ofs:$param{mode} $param{unit} value:", join (",", @{$param{value} }),"]\n";

    my ($i, $j);
    my ($cmp, $this, $next, $ib, $part, $open_begin, $open_end, $tmp);

    my @value;
    foreach $j (0 .. $parts) {
        push @value, [ $param{value}[$j+$j], $param{value}[$j+$j + 1] ];
    }

    foreach $i (0 .. $#{ $self->{list} }) {
        my $interval = $self->{list}[$i];
        my $ia = $interval->{a};

        next if Set::Infinite::Element_Inf->is_null($ia);  # skip if interval is null
        $ib = $interval->{b};
        $open_begin = $interval->{open_begin};
        $open_end = $interval->{open_end};
        # do offset
        foreach $j (0 .. $parts) {
                # print " ..[ofs:$param{mode}=$param{sub_mode} $param{unit}=$param{sub_unit} value:", $param{value}[$j+$j], ",", $param{value}[$j+$j + 1],"]\n";
                ($this, $next, $cmp) = &{ $sub_mode } 
                    ( $sub_unit, $ia, $ib, @{$value[$j]} );
                next if ($cmp > 0);    # skip if a > b
                # print " [ofs($this,$next)] ";
                unless ($cmp) {
                    $open_end = $open_begin;
                    $this = $next;  #  make sure to use the same object from cache!
                }
                # skip this if don't need to "fixtype"
                if ($param{fixtype}) {
                    # bless results into 'type' class
                    # print " [ofs($this,$next) = $class] ";
                    if (ref($this) ne ref($ia) ) {
                            $this = $ia->new($this);
                            $next = $ia->new($next);
                    }
                } 
                push @a, { a => $this , b => $next ,
                        open_begin => $open_begin , open_end => $open_end };
        }  # parts
    }  # self

    @a = sort { $a->{a} <=> $b->{a} } @a;

    $b1->{list} = \@a;        # change data
    $b1->{cant_cleanup} = 1; 

    # print " N = $#a \n";

    return $b1;
}


sub is_null {
    my $self = shift;
    return 1 unless $#{$self->{list}} >= 0;
    Set::Infinite::Element_Inf::is_null($self->{list}->[0]->{a});
}

=head2 is_too_complex

Sometimes a set might be too complex to print. 
It will happen when you ask for a quantization on a 
set bounded by -inf or inf.

=cut

sub is_too_complex {
    my $self = shift;
    $self->{too_complex} ? 1 : 0;
}


sub backtrack {
    #
    #  NOTICE: set/reset $DEBUG_BT to enable debugging
    #

    my ($self, $method, $arg) = @_;
    return $self->$method ($arg)  unless $self->{too_complex};

    $backtrack_depth++;
    if ($backtrack_depth > $max_backtrack_depth) {
        carp (__PACKAGE__ . ": Backtrack too deep (more than " . $max_backtrack_depth . " levels)");
    }
    # print " [BT:depth=",$backtrack_depth,"] \n";
    print " [BT$backtrack_depth-0:",join(";",@_),"] \n" if $DEBUG_BT;
    my $result;
    print " [bt$backtrack_depth-0-1:self=",join(";",%{$self}),"] \n" if $DEBUG_BT;
    # print " [bt$backtrack_depth-1:caller:",join(";",caller),"] \n" if $DEBUG_BT;
    # print " [bt$backtrack_depth-2:parent:",ref($self->{parent})," -- ",join(";",%{$self->{parent}}),"] \n" if $self->{parent} and not (ref($self->{parent}) eq 'ARRAY');
    # print " [bt$backtrack_depth-3:complex:a,b] \n";

    # backtrack on parent sets
    if (ref($self->{parent}) eq 'ARRAY') {
        # has 2 parents (intersection, union, ...)
        # data structure: {method} - method name, {parent} - array, parent list
            # print " [bt$backtrack_depth-3.5:complex: 2-PARENTS ] \n";
        my $result1 = $self->{parent}[0];
        $result1 = $result1->backtrack($method, $arg) if $result1->{too_complex};
            # print " [bt$backtrack_depth-3-6:res1:$result] \n";
        my $result2 = $self->{parent}[1];
        $result2 = $result2->backtrack($method, $arg) if $result2->{too_complex};
            # print " [bt$backtrack_depth-3-7:res2:$result] \n";

        if ( $result1->{too_complex} or $result2->{too_complex} ) {
                # backtrack failed...
                $backtrack_depth--;
                return $self;
        }

        # apply {method}
            # print "\n\n<eval-2 method:$self->{method} - $the_method \n\n";
            # $result = &{ \& { $self->{method} } } ($result1, $result2);
        my $method = $self->{method};
        $result = $result1->$method ($result2);
            # print "\n\n/eval-2> \n\n";

        $backtrack_depth--;
        return $result;
    }  # parent is ARRAY


    # has 1 parent and parameters (offset, select, quantize)
    # data structure: {method} - method name, {param} - array, param list

    # TODO: backtrack on complement()

        print " [bt$backtrack_depth-3-05: 1-PARENT ] \n" if $DEBUG_BT;
        my $result1 = $self->{parent};
        my @param = @{$self->{param}};
        my $my_method = $self->{method};

        my $backtrack_arg2;

        # print " [bt$backtrack_depth-3-06:res1:before_backtrack:$result1] \n";
        # $backtrack_arg must be modified second to method and param
        print " [bt$backtrack_depth-3-08:BEFORE:$arg;" . $my_method . ";",join(";",@param),"] \n" if $DEBUG_BT;
 
            # quantize - apply quantization without modifying
            if ($my_method eq 'quantize') {

                # -----------------------
                # (TODO) ????

                if (($arg->{too_complex}) or ($arg->min == -&inf) or ($arg->max == &inf)) {
                    $backtrack_arg2 = $arg;
                }
                else {
                    $backtrack_arg2 = $arg->quantize(@param, strict=>0); # span/union
                }

                # -----------------------

            }
            # offset - apply offset with negative values
            elsif ($my_method eq 'offset') {

                # -----------------------
                # (TODO) ????

                my %tmp = @param;

                #    unless (ref($tmp{value}) eq 'ARRAY') {
                #        $tmp{value} = [0 + $tmp{value}, 0 + $tmp{value}];
                #    }
                #    # $tmp{value}[0] = - $tmp{value}[0]; -- don't do this!
                #    # $tmp{value}[1] = - $tmp{value}[1]; -- don't do this!

                $backtrack_arg2 = $arg->offset( unit => $tmp{unit}, mode => $tmp{mode}, value => [- $tmp{value}[0], - $tmp{value}[-1]] );

            }
            # select - check "by" behaviour
            else {    # if ($my_method eq 'select') {

                # -----------------------
                # (TODO) ????
                # see: 'BIG, negative select' in backtrack.t

                $backtrack_arg2 = $arg;

                # -----------------------

            }

    print " [bt$backtrack_depth-3-10:AFTER:$backtrack_arg2;" . $my_method . ";",join(";",@param),"] \n" if $DEBUG_BT;
    # print " [bt$backtrack_depth-3-11:  WAS:$arg] \n";

    $result1 = $result1->backtrack($method, $backtrack_arg2); # if $result1->{too_complex};
    # print " [bt$backtrack_depth-3-12:res1:after_backtrack:$result1] \n";
    # apply {method}

    my $expr = 'return $result1->' . $self->{method} . '(@param)' if $DEBUG_BT;
    print " [bt$backtrack_depth-3-14:expr: $result1 -- ",$self->{method}," ]\n" if $DEBUG_BT;
    print " [bt$backtrack_depth-3-15:expr: $expr ; param: ", join(";",@param),"]\n" if $DEBUG_BT;
    # print "\n\n<eval-1 method:$self->{method} - $the_method \n\n";
    # $result = &{\& {$self->{method} } } ($result1, @param);
    $method = $self->{method};
    $result = $result1->$method (@param);
    # print "\n\n/eval-1> \n\n";
    print " [bt$backtrack_depth-3-19:RESULT ",ref($result), "=",join(";",%{$result}),"=$result] \n" if $DEBUG_BT;
    # print " [bt$backtrack_depth-3-22:  WAS:$arg] \n";
    # print " [bt$backtrack_depth-3-25:end:res:$expr = $result] \n";
    $backtrack_depth--;
    return $result;
}

sub intersects {
    my $a = shift;
    my $b;
    # print " [I:", ref ($_[0]), "] ";
    if (ref ($_[0]) eq 'HASH') {
        # optimized for "quantize"
        $a->trace(title=>"intersects:simple");
        # print "*";
        # print " n:", $#{$a->{list}}, "=$a ";
        $b = shift;
        foreach my $ia (0 .. $#{$a->{list}}) {
            return 1 if _simple_intersects($a->{list}->[$ia], $b);
        }
        return 0;    
    } 
    elsif (ref ($_[0]) ) { 
        $b = shift;
    } 
    else {
        $b = $a->new(@_);  
    }

    $a->trace(title=>"intersects");
    # print "-";

    if ($a->{too_complex}) {
        print " [inter:complex:a] \n" if $DEBUG_BT;
        $a = $a->backtrack('intersection', $b);
        # print " [int:WAS:b:", $b, "--",ref($b),"] \n";
    }  # don't put 'else' here
    if ($b->{too_complex}) {
        print " [inter:complex:b] \n" if $DEBUG_BT;
        $b = $b->backtrack('intersection', $a);
    }

    if (($a->{too_complex}) or ($b->{too_complex})) {
        print " [inter:backtrack] \n" if $DEBUG_BT;
        my $intersection = $a->new();
        $intersection->{too_complex} = 1;
        $intersection->{parent} = [$a->copy, $b->copy];
        $intersection->{method} = 'intersects';
        return $intersection;
    }

    # no difference in time
    # ($a, $b) = ($b, $a) if $#{$a->{list}} > $#{$b->{list}};

    my ($ia, $ib);
    my ($na, $nb) = (0,0);
    # my $intersection = $class->new();
    B: foreach $ib ($nb .. $#{$b->{list}}) {
        foreach $ia ($na .. $#{$a->{list}}) {
            #next B if Set::Infinite::Element_Inf::is_null($a->{list}->[$ia]->{a});
            #next B if Set::Infinite::Element_Inf::is_null($b->{list}->[$ib]->{a});
        #    if ( $a->{list}->[$ia]->{a} > $b->{list}->[$ib]->{b} ) {
        #        $na = $ia;
        #        next B;
        #    }
            # next B if ($a->{list}->[$ia]->{a} > $b->{list}->[$ib]->{b}) ;
            return 1 if _simple_intersects($a->{list}->[$ia], $b->{list}->[$ib]);
        }
    }
    0;    
}

sub iterate {

    # TODO: options 'no-sort', 'no-merge', 'keep-null' ...

    my $a = shift;
    # my $class = ref($a);
    my $iterate = $a->new();

    # print " [iterate ",$a,"--",ref($a)," from ", caller, "] \n";

    if ($a->{too_complex}) {
        $a->trace(title=>"iterate:backtrack");
        # print " [iterate:backtrack] \n" if $DEBUG_BT;
        $iterate->{too_complex} = 1;
        $iterate->{parent} = $a->copy;
        $iterate->{method} = 'iterate';
        $iterate->{param} = \@_;
        return $iterate;
    }

    $a->trace(title=>"iterate");

    my ($tmp, $ia);
    my $subroutine = shift;
    foreach $ia (0 .. $#{$a->{list}}) {
        # print " [iterate:$a->{list}->[$ia] -- $subroutine ]\n";
        $tmp = &{$subroutine} ( $a->new($a->{list}->[$ia]) );
        # print " [iterate:result:$tmp]\n";
        $iterate = $iterate->union($tmp) unless Set::Infinite::Element_Inf::is_null($tmp); 
    }
    return $iterate;    
}

sub intersection {
    my $a1 = shift;
    my $b1;
    $a1->trace(title=>"intersection");
    if (ref ($_[0]) eq ref($a1) ) {
        $b1 = shift;
    } 
    else {
        $b1 = $a1->new(@_);  
    }
    my $tmp;
    # print " [intersect ",$a,"--",ref($a)," with ", $b, "--",ref($b)," ", caller, "] \n";

    if ($a1->{too_complex}) {
        print " [inter:complex:a] \n" if $DEBUG_BT;
        $a1 = $a1->backtrack('intersection', $b1);
        # print " [int:WAS:b:", $b1, "--",ref($b1),"] \n";
    }  # don't put 'else' here
    if ($b1->{too_complex}) {
        print " [inter:complex:b] \n" if $DEBUG_BT;
        $b1 = $b1->backtrack('intersection', $a1);
    }

    if (($a1->{too_complex}) or ($b1->{too_complex})) {
        print " [inter:backtrack] \n" if $DEBUG_BT;
        my $intersection = $a1->new();
        $intersection->{too_complex} = 1;
        $intersection->{parent} = [$a1->copy, $b1->copy];
        $intersection->{method} = 'intersection';
        return $intersection;
    }

    # print " [intersect \n    ",$a,"--",ref($a)," with \n    ", $b, "--",ref($b)," \n    ", caller, "] \n";

    my ($ia, $ib);
    # my ($na, $nb) = (0,0);
    # $tmp = ref($a1->{list}) . ref($b1->{list}); # instantiate, just in case
    my ($ma, $mb) = ($#{$a1->{list}}, $#{$b1->{list}});
    my $intersection = $a1->new();

    # for loop optimization
    if ($ma < $mb) {
        ($ma, $mb) = ($mb, $ma);
        # ($na, $nb) = ($nb, $na);
        ($a1, $b1) = ($b1, $a1);
    }

    my ($tmp1, $tmp2);
    my ($tmp1a, $tmp2a, $tmp1b, $tmp2b);
    my ($i_beg, $i_end, $open_beg, $open_end);

    my ($cmp1);

    B: foreach $ib (0 .. $mb) {
        $tmp2 = $b1->{list}[$ib];
        $tmp2a = $tmp2->{a};
        $tmp2b = $tmp2->{b};
        # my $dummy = ref($pb1);
         A: foreach $ia (0 .. $ma) {
            $tmp1 = $a1->{list}[$ia];
            $tmp1b = $tmp1->{b};

            next A if $tmp1b < $tmp2a; 

            $tmp1a = $tmp1->{a};
            next B if $tmp1a > $tmp2b;

            $cmp1 = $tmp1a <=> $tmp2a;

            if ($cmp1 < 0) {
                $i_beg         = $tmp2a;
                $open_beg     = $tmp2->{open_begin};
            }
            elsif ($cmp1 == 0) {
                $i_beg         = $tmp1a;
                $open_beg     = ($tmp1->{open_begin} or $tmp2->{open_begin});
            }
            else {
                $i_beg         = $tmp1a;
                $open_beg    = $tmp1->{open_begin};
            }

            $cmp1 = $tmp1b <=> $tmp2b;

            if ($cmp1 > 0) {
                $i_end         = $tmp2b;
                $open_end     = $tmp2->{open_end};
            }
            elsif ($cmp1 == 0) {
                $i_end         = $tmp1b;
                $open_end     = ($tmp1->{open_end} or $tmp2->{open_end});
            }
            else {
                $i_end         = $tmp1b;
                $open_end    = $tmp1->{open_end};
            }
            # print " [ simple: fastnew($i_beg, $i_end, $open_beg, $open_end ) ]\n";
            $cmp1 = $i_beg <=> $i_end;
            unless (( $cmp1 > 0 ) or 
                    ( ($cmp1 == 0) and ($open_beg or $open_end) )) {
                push @{$intersection->{list}}, 
                    { a => $i_beg, b => $i_end, 
                      open_begin => $open_beg, open_end => $open_end } ;
            }
        }
    }
    # print " [intersect GIVES\n    ",$intersection,"\n\n";
    return $intersection;    
}

sub complement {
    my $self = shift;
    # my $class = ref($self);
    $self->trace(title=>"complement");
    # do we have a parameter?
    if (@_) {
        if (ref ($_[0]) eq ref($self) ) {
            $a = shift;
        } 
        else {
            $a = $self->new(@_);  
        }
        $a = $a->complement;
        # print " [CPL:intersect ",$self," with ", $a, "] ";
        return $self->intersection($a);
    }

    my ($ia);
    my $tmp;
    # print " [CPL:",$self,"] ";

    if (($#{$self->{list}} < 0) or (not defined ($self->{list}))) {
        return $self->new(minus_infinite, infinite);
    }

    my $complement = $self->new();
    @{$complement->{list}} = _simple_complement($self->{list}->[0]); 

    $tmp = $self->new();
    foreach $ia (1 .. $#{$self->{list}}) {
        @{$tmp->{list}} = _simple_complement($self->{list}->[$ia]); 
        $complement = $complement->intersection($tmp); # if $tmp;
    }
    # print " [CPL:RES:",$complement,"] ";

    return $complement;    
}

# version 0.22.02 - faster union O(n*n) => O(n)
# version 0.30 - sends tolerance
# $a, $b renamed to $a1, $b1 to prevent clashing with 'sort' 
sub union {
    my $a1 = shift;
    # my $class = ref($a1);
    my $b1;

    $a1->trace(title=>"union");

    # print " [UNION] \n";
    # print " [union: new b] \n";

    return $a1->compact if ($#_ < 0);  # old usage

    if (ref ($_[0]) eq ref($a1) ) {
        $b1 = shift;
    } 
    else {
        $b1 = $a1->new(@_);  
    }

    if (($a1->{too_complex}) or ($b1->{too_complex})) {
        print " [union:backtrack] \n" if $DEBUG_BT;
        my $union = $a1->new();
        $union->{too_complex} = 1;
        $union->{parent} = [$a1->copy, $b1->copy];
        $union->{method} = 'union';
        return $union;
    }

    # -- special case: $a1 or $b1 is empty
     # print " A=0 B=$b1 " if $#{$a1->{list}} < 0;
     # print " B=0 A=$a1 " if $#{$b1->{list}} < 0;
    return $a1 if $#{$b1->{list}} < 0;
    return $b1 if $#{$a1->{list}} < 0;

    my ($ia, $ib);
    $ia = 0;
    $ib = 0;

    #  size+order matters on speed 

    # print " [ ",$a1->max," <=> ",$b1->max," ] \n";
 
    $a1 = $a1->new($a1);    # don't modify ourselves 
    my $b_list = $b1->{list};
    # -- frequent case - $b1 is after $a1
    if ($b1->min > $a1->max) {
        # print " [UNION: $a1 \n         $b1 $#{$b_list}\n       ";
        push @{$a1->{list}}, @$b_list;
        return $a1;
    }

    # print " [UNION: NORMAL ] \n";

    B: foreach $ib ($ib .. $#{$b_list}) {
        foreach $ia ($ia .. $#{$a1->{list}}) {
            # $self->{list}->[$_ - 1] = $tmp[0];
            # splice (@{$self->{list}}, $_, 1);

            my @tmp = _simple_union($a1->{list}->[$ia], $b_list->[$ib], $a1->{tolerance});
            # print " [+union: $tmp[0] ; $tmp[1] ] \n";

            if ($#tmp == 0) {
                    $a1->{list}->[$ia] = $tmp[0];
                    next B;
            }

            # print " [union:index-a: ($ia .. ", $#{$a->{list}}, ")  \n";
            # print " [union:index-b: ($ib .. ", $#{$b_list}, ")  \n";
            # print "  a -- ($a->{list}->[$ia]->{a} >= \n";
            # print "  b -- $b_list->[$ib] ref=",ref($b_list->[$ib])," => ",join(" - ", %{$b_list->[$ib]}),"\n";
            my %hash = %{$b_list->[$ib]};
            # print "    -- $hash{a} ]\n";
            # print "    -- $b_list->[$ib]->{a} ]\n";

            # this doesn't always work -- use a temp variable instead:  if ($a->{list}->[$ia]->{a} >= $b->{list}->[$ib]->{a}) 
            if ($a1->{list}->[$ia]->{a} >= $hash{a}) 
            {
                # print "+ ";
                # splice(@array,$index,0,$value)
                # insert $b[$ib] before $a[$ia] 
                splice (@{$a1->{list}}, $ia, 0, $b_list->[$ib]);
                # $a->add($b->{list}->[$ib]);
                next B;
            }

        }
        # print "- ";
        # $a->add($b->{list}->[$ib]);
        push @{$a1->{list}}, $b_list->[$ib];
    }
    # print " [union: done from ", join(" ", caller), " ] \n";
    # print " [union: result = $a ] \n";
    # $a->{cant_cleanup} = 1;

    # print "\n TEST: $test\n A:    $a\n ORIG: $a\n B:    $b\n" if $test != $a;

    return $a1;    
}

sub contains {
    my $a = shift;
    $a->trace(title=>"contains");
    return ($a->union(@_) == $a) ? 1 : 0;
}


=head2 copy

Makes a new object from the object's data.

=cut

sub copy {
    my $self = shift;
    my $copy = $self->new();
    foreach my $key (keys %{$self}) {
        $copy->{$key} = $self->{$key};
    }
    return $copy;
}


sub new {
    my $class = shift;
    my $class_name = ref($class) ? ref($class) : $class;
    my ($self) = bless { list => [] }, $class_name;
    # $self->trace(title=>"new");
    # print " [INF:new:", ref($self)," - ", join(' - ', caller), " ]\n"; # if $TRACE;
    # set up private variables
    if (ref($class)) {
        $self->{tolerance} = $class->{tolerance} if $class->{tolerance};
        $self->{type}      = $class->{type}      if $class->{type};
    }
    else {
        $self->{tolerance} = $tolerance ? $tolerance : '';
        $self->{type} =      $type      ? $type : '';
    }
    # print " [INF:new:$class ", $tolerance, " ",$type," ",$self->{tolerance}," ",$self->{type}," ]\n"; 

    my ($tmp, $tmp2, $ref);
    while (@_) {
        # return $self unless @_;
        $tmp = shift;
        # print " [INF:ADD:",ref($tmp),"=$tmp ; @_ ]\n";
        $ref = ref($tmp);
        if ($ref) {
            if ($ref eq 'ARRAY') {
                # print " INF:ADD:ARRAY:",@tmp," ";
                # Allows arrays of arrays
                $tmp = $class->new(@{$tmp});  # call new() recursively
                push @{ $self->{list} }, @{$tmp->{list}};
                next;
            }
            if ($ref eq 'HASH') {
                # print " INF:ADD:HASH\n";
                push @{ $self->{list} }, $tmp; 
                next;
            }
            # does it have a "{list}"?
            if ($tmp->isa(__PACKAGE__)) {
                # print " INF:ADD:",__PACKAGE__,":",$tmp," \n";
                push @{ $self->{list} }, @{$tmp->{list}};
                next;
            }
        }
        $tmp2 = shift;
        push @{ $self->{list} }, _simple_new($tmp,$tmp2, $self->{type} );
        # next;
    }
    $self;
}

sub min { 
    my ($self) = shift;
    my $tmp;

    $self->trace(title=>"min"); 

    foreach(@{$self->{list}}) {
        $tmp = $_->{a};
        return $tmp unless Set::Infinite::Element_Inf::is_null($tmp) ;
    }
    # print " min:null /min> ";
    return Set::Infinite::Element_Inf::null;  
};

sub max { 
    my ($self) = shift;
    my $tmp;
    my $i;
    my $tmp_ptr;  # perl bug? too deep - maybe due to autovivification

    $self->trace(title=>"max"); 

    for($i = $#{$self->{list}}; $i >= 0; $i--) {
        $tmp_ptr = $self->{list}->[$i];
        $tmp = $tmp_ptr->{b};
        #print "max:$tmp ";
        return $tmp unless Set::Infinite::Element_Inf::is_null($tmp) ;
    }
    return Set::Infinite::Element_Inf::null; 
};

sub size { 
    my ($self) = shift;
    my $tmp;
    # $self->cleanup;
    # print " [INF:SIZE:$self->{list}->[0]->{b} - $self->{list}->[0]->{a} ] \n";
    my $size = $self->{list}->[0]->{b} - $self->{list}->[0]->{a};
    foreach(1 .. $#{$self->{list}}) {
        $size += $self->{list}->[$_]->{b} - $self->{list}->[$_]->{a};
    }
    return $size; 
};

sub span { 
    my ($self) = shift;
    return $self->new($self->min, $self->max);
};

sub spaceship {
    my ($tmp1, $tmp2, $inverted) = @_;
    if ($inverted) {
        ($tmp2, $tmp1) = ($tmp1, $tmp2);
    }
    foreach(0 .. $#{$tmp1->{list}}) {
        my $this  = $tmp1->{list}->[$_];
        my $other = $tmp2->{list}->[$_];
        my $cmp = _simple_spaceship($this, $other);
        return $cmp if $cmp;   # this != $other;
    }
    return 0;
}

sub no_cleanup {
    my ($self) = shift;
    $self->{cant_cleanup} = 1; 
    return $self;
}

sub cleanup {
    my ($self) = shift;
    return $self if $self->{cant_cleanup};     # quantize output is "virtual", can't be cleaned

    $_ = 1;
    while ( $_ <= $#{$self->{list}} ) {
        my @tmp = _simple_union($self->{list}->[$_],
            $self->{list}->[$_ - 1], 
            $self->{tolerance});
        if ($#tmp == 0) {
            $self->{list}->[$_ - 1] = $tmp[0];
            splice (@{$self->{list}}, $_, 1);
        } 
        else {
            $_ ++;
        }
    }

    return $self;
}


#-------- tolerance, integer, real

sub tolerance {
    my $tmp = pop;
    my $self = shift;
    if (ref($self)) {  
        # local
        $self->{tolerance} = $tmp if ($tmp ne '');
        return $self;
    }
    # global
    $tolerance = $tmp if defined($tmp) and ($tmp ne '');
    return $tolerance;
}

sub integer {
    if (@_) {
        my ($self) = shift;
        $self->tolerance (1);
        return $self;
    }
    return tolerance(1);
}

sub real {
    if (@_) {
        my ($self) = shift;
        $self->tolerance (0);
        return $self;
    }
    return tolerance(0);
}



sub as_string {
    my ($self) = shift;
    return $too_complex  if $self->{too_complex};
    $self->cleanup;
    # return null          unless $#{$self->{list}} >= 0;
    return join(separators(5), map { _simple_as_string($_) } @{$self->{list}} );
}


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

        result is INTERVAL, (min .. max)

=head2 Scalar functions:

    $i = $a->min;

    $i = $a->max;

    $i = $a->size;  

=head2 Perl functions:

    @b = sort @a;

    print $a;

=head2 Global functions:

    separators(@i)

        chooses the interval separators. 

        default are [ ] ( ) '..' ','.

    null($i)        

        chooses 'null' name. default is ''

    infinite($i)

        chooses 'infinite' name. default is 'inf'

    infinite

        returns an 'infinite' number.

    minus_infinite

        returns '-infinite' number.

    null

        returns the 'null' object.

    quantize( parameters )

        Makes equal-sized subsets.

        In array context: returns a tied reference to the subset list.
        In set context: returns an ordered set of equal-sized subsets.

        The quantization function is external to this module:
        Parameters may vary depending on implementation. 

        Positions for which a subset does not exist may show as null.

        Example: 

            $a = Set::Infinite->new([1,3]);
            print join (" ", $a->quantize( quant => 1 ) );

        Gives: 

            [1..2) [2..3) [3..4)

    select( parameters )

        Selects set members based on their ordered positions.
        Selection is more useful after quantization.

        In array context: returns a tied reference to the array of selected subsets.
        In set context: returns the set of selected subsets.

        Unselected subsets may show as null.

        The selection function is external to this module:
        Parameters may vary depending on implementation. 

            freq     - default=1
            by       - default=[0]
            count    - dafault=infinite

    offset ( parameters )

        Offsets the subsets. Parameters: 

            value   - default=[0,0]
            mode    - default='offset'. Possible values are: 'offset', 'begin', 'end'.
            unit    - type of value. Can be 'days', 'weeks', 'hours', 'minutes', 'seconds'.

    iterate ( sub { } )

        EXPERIMENTAL - may be removed in next release
        Iterates over a subroutine. 
        Returns the union of partial results.

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

    integer            defaults to integer sets

=head2 Internal functions:

    $a->cleanup;

    $a->backtrack($b);

    $a->fixtype;

=head1 Notes on Dates

See module Date::Set for up-to-date information on date-sets. 

Set::Infinite::Date and Set::Infinite::ICal are Date "plugins" for sets.

use:

    type('Set::Infinite::Date');  # 2001-05-02 10:00:00   
    # or
    type('Set::Infinite::ICal');  # 20010502T100000Z


Both require Time::Local.
Set::Infinite::ICal requires Date::ICal.

They change quantize function behaviour to accept time units:

    use Set::Infinite;
    use Set::Infinite::Quantize_Date;
    Set::Infinite->type('Set::Infinite::Date');
    Set::Infinite::Date->date_format("year-month-day");

    $a = Set::Infinite->new('2001-05-02', '2001-05-13');
    print "Weeks in $a: ", join (" ", $a->quantize(unit => 'weeks', quant => 1) );

    $a = Set::Infinite->new('09:30', '10:35');
    print "Quarters of hour in $a: ", join (" ", $a->quantize(unit => 'minutes', quant => 15) );

Quantize units can be years, months, days, weeks, hours, minutes, or seconds.
To quantize the year to first-week-of-year until last-week-of-year, use 'weekyears':

        ->quantize( unit => weekyears, wkst => 1 )

'wkst' parameter is '1' for monday (default), '7' for sunday.

max and min functions will also show in date/time format.

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

=head1 SEE ALSO

    Date::Set

=head1 AUTHOR

    Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

