package Set::Infinite;

# Copyright (c) 2001, 2002 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

require 5.005_03;
use strict;
# use warnings;

require Exporter;
use Set::Infinite::Basic;
use Carp;
use Data::Dumper; 

use vars qw( @ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION 
    $TRACE $DEBUG_BT $PRETTY_PRINT $inf $minus_inf 
    $too_complex $backtrack_depth 
    $max_backtrack_depth $max_intersection_depth );
@ISA = qw( Set::Infinite::Basic Exporter );

# This allows declaration    use Set::Infinite ':all';
%EXPORT_TAGS = ( 'all' => [ qw(inf new $inf) ] );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } , qw(inf new $inf trace_open trace_close) );
@EXPORT = qw();

$VERSION = 0.51;

use Set::Infinite::Arithmetic;

# Infinity vars
$inf            = 100**100**100;
$minus_inf      = -$inf;

# obsolete!
sub inf ()            { $inf }
sub minus_inf ()      { $minus_inf }

# internal "trace" routines for debugging
use vars qw( $trace_level %level_title );

BEGIN {
    $TRACE = 0;         # enable basic trace method execution
    $DEBUG_BT = 0;      # enable backtrack tracer
    $PRETTY_PRINT = 0;  # 0 = print 'Too Complex'; 1 = describe functions
    $trace_level = 0;   # indentation level when debugging

    $too_complex =    "Too complex";
    $backtrack_depth = 0;
    $max_backtrack_depth = 10;    # backtrack()
    $max_intersection_depth = 5;  # first()
}

=head1 NAME

Set::Infinite - Sets of intervals

=head1 SYNOPSIS

  use Set::Infinite;

  $a = Set::Infinite->new(1,2);    # [1..2]
  print $a->union(5,6);            # [1..2],[5..6]

=head1 DESCRIPTION

Set::Infinite is a Set Theory module for infinite sets. 

It works with reals, integers, and objects.

When it is used dates, this module provides schedule checks (intersections),
unions, and infinite recurrences.

=cut


use overload
    '<=>' => \&spaceship,
    qw("" as_string),
;

# These methods are inherited from Set::Infinite::Basic "as-is":
#   type  list  fixtype  numeric  min  max
#   integer  real  new  span  copy
 
# obsolete!
sub compact {
    return $_[0];
}

# internal "trace" routines for debugging

sub trace { # title=>'aaa'
    return $_[0] unless $TRACE;
    my ($self, %parm) = @_;
    my @caller = caller(1);
    # print "self $self ". ref($self). "\n";
    print "" . ( ' | ' x $trace_level ) .
            "$parm{title} ". $self->copy .
            ( exists $parm{arg} ? " -- " . $parm{arg}->copy : "" ).
            " $caller[1]:$caller[2] ]\n" if $TRACE == 1;
    print "$parm{title} ",sprintf("%4d", $caller[2])," ]\n" if $TRACE == 2;
    return $self;
}

sub trace_open { 
    return $_[0] unless $TRACE;
    my ($self, %parm) = @_;
    my @caller = caller(1);
    # my $nothing = "$self";
    print "" . ( ' | ' x $trace_level ) .
            "\\ $parm{title} ". $self->copy .
            ( exists $parm{arg} ? " -- ". $parm{arg}->copy : "" ).
            " $caller[1]:$caller[2] ]\n" if $TRACE == 1;
    $trace_level++; 
    $level_title{$trace_level} = $parm{title};
    return $self;
}

sub trace_close { 
    return $_[0] unless $TRACE;
    my ($self, %parm) = @_;  
    my @caller = caller(0);
    print "" . ( ' | ' x ($trace_level-1) ) .
            "\/ $level_title{$trace_level} ".
            ( exists $parm{arg} ? 
               (
                  defined $parm{arg} ? 
                      "ret ". ( UNIVERSAL::isa($parm{arg}, __PACKAGE__ ) ? 
                           $parm{arg}->copy : 
                           "<$parm{arg}>" ) :
                      "undef"
               ) : 
               ""     # no arg 
            ).
            " $caller[1]:$caller[2] ]\n" if $TRACE == 1;
    $trace_level--;
    return $self;
}


# internal method
# creates a 'function' object that can be solved by backtrack()
sub _function {
    my ($self, $method) = (shift, shift);
    my $b = $self->new();
    $b->{too_complex} = 1;
    $b->{parent} = $self;   
    $b->{method} = $method;
    $b->{param}  = [ @_ ];
    return $b;
}

# same as _function, but with 2 arguments
sub _function2 {
    my ($self, $method, $arg) = (shift, shift, shift);
    unless ( $self->{too_complex} || $arg->{too_complex} ) {
        # warn( "eval $method $self $arg" );
        return $self->$method($arg, @_);
    }
    my $b = $self->new();
    $b->{too_complex} = 1;
    $b->{parent} = [ $self, $arg ];
    $b->{method} = $method;
    $b->{param}  = [ @_ ];
    return $b;
}

# quantize: splits in same-size subsets

sub quantize {
    my $self = shift;
    $self->trace_open(title=>"quantize") if $TRACE; 
    my @min = $self->min_a;
    my @max = $self->max_a;
    if (($self->{too_complex}) or 
        (defined $min[0] && $min[0] == -&inf) or 
        (defined $max[0] && $max[0] == &inf)) {
        # $self->trace(title=>"quantize:backtrack"); 
        # print " [quantize:backtrack] \n" if $DEBUG_BT;
        my $b = $self->_function( 'quantize', @_ );
        # $b->trace( title=>"quantize: created a function: $b" );

        # TODO: find out how to calculate 'last'
        $b->{last} = [ undef, 0 ];

        if (defined $min[0] ) {    # && ($min[0] != -&inf) ) {
            my $first;
            if (( $min[0] == -&inf ) || ( $min[0] == &inf )) {
                $first = $self->new( $min[0] );
                $b->{first} = [$first, $b];  # link to itself!
            }
            else {
                $first = $self->new( $min[0] )->quantize(@_);
                # warn "   quantize first = $first";
                # move $self->min ahead
                # $b->trace( title=>"quantize: first=$first complement=". $first->complement );
                @{$b->{first}} = ($first, 
                    $b->{parent}->
                        _function2( 'intersection', $first->complement )->
                        _function( 'quantize', @_ ) );
            }

            my $last;
            if (( $max[0] == -&inf ) || ( $max[0] == &inf )) {
                $last = $self->new( $max[0] );
                @{$b->{last}} = ($last, $b); # link to itself!
            }
            else {
                # warn "$self max @max";
                my $max = $max[0];
                # $max -= 1e-9 if $max[1];  TODO: fix open_end
                $last = $self->new( $max )->quantize(@_);
                if ($max[1]) {
                    # open_end
                    my $min0 = $last->min;
                    if ($min0 <= $max) {
                        my $last0 = $self->new( $last->min - 1e-9 )->quantize(@_);
                        # warn "   quantize last = $last0 , $last";
                        $last = $last0;
                    }
                }
                # move $self->max back
                @{$b->{last}} = ($last, $b->{parent}->
                        _function2( 'intersection', $last->complement )->
                        _function( 'quantize', @_ ) );
            }

            @{$b->{min}} = $first->min_a;
            @{$b->{max}} = $last->max_a;
            $b->trace_close( arg => $b );
            return $b;
        }

        $b->trace_close( arg => $b );
        return $b;
    }
    # $self->trace(title=>"quantize"); 
    my @a;
    my %rule = @_;
    my $b = $self->new();    
    my $parent = $self;

    $rule{unit} =   'one' unless $rule{unit};
    $rule{quant} =  1     unless $rule{quant};
    $rule{parent} = $parent; 
    $rule{strict} = $parent unless exists $rule{strict};
    $rule{type} =   $parent->{type};

    my ($min, $open_begin) = $parent->min_a;

    # print " [MIN:$min] \n";
    unless (defined $min) {
        # print " [NULL!]\n";
        $self->trace_close( arg => $b );
        return $b;    
    }

    if (ref($min)) {
        # TODO: mode is 'Date' specific
        $rule{mode} = $min->{mode} if (exists $min->{mode});
    }

    $rule{fixtype} = 1 unless exists $rule{fixtype};
    # $Set::Infinite::Arithmetic::Init_quantizer{$rule{unit}} (\%rule);
    $Set::Infinite::Arithmetic::Init_quantizer{$rule{unit}}->(\%rule);

    $rule{sub_unit} = $Set::Infinite::Arithmetic::Offset_to_value{$rule{unit}};
    carp "Quantize unit '".$rule{unit}."' not implemented" unless ref( $rule{sub_unit} ) eq 'CODE';

    my ($max, $open_end) = $parent->max_a;
    # $rule{offset} = $Set::Infinite::Arithmetic::Value_to_offset{$rule{unit}} (\%rule, $min);
    $rule{offset} = $Set::Infinite::Arithmetic::Value_to_offset{$rule{unit}}->(\%rule, $min);
    # my $last_offset = $Set::Infinite::Arithmetic::Value_to_offset{$rule{unit}} (\%rule, $max);
    my $last_offset = $Set::Infinite::Arithmetic::Value_to_offset{$rule{unit}}->(\%rule, $max);
    $rule{size} = $last_offset - $rule{offset} + 1; 
    my ($index, $tmp, $this, $next);
    for $index (0 .. $rule{size} ) {
        # ($this, $next) = $rule{sub_unit} (\%rule, $index);
        ($this, $next) = $rule{sub_unit}->(\%rule, $index);
        unless ( $rule{fixtype} ) {
                $tmp = { a => $this , b => $next ,
                        open_begin => 0, open_end => 1 };
        }
        else {
                $tmp = Set::Infinite::Basic::_simple_new($this,$next, $rule{type} );
                $tmp->{open_end} = 1;
                # TODO: 'mode' is 'DATE' specific
                if (exists $rule{mode}) {
                    $tmp->{a}->mode($rule{mode});
                    $tmp->{b}->mode($rule{mode});
                }
        }
        next if ( $rule{strict} and not $rule{strict}->intersects($tmp));
        push @a, $tmp;
    }


    $b->{list} = \@a;        # change data
    $b->{cant_cleanup} = 1;     
    # print " [QUANT:returns:",ref($b),"] \n";
    # $self->trace(title=>"quantize:end");
    $self->trace_close( arg => $b );
    return $b;
}


# select: position-based selection of subsets

sub select {
    my $self = shift;
    # $TRACE =1;
    $self->trace_open(title=>"select") if $TRACE;
    # $TRACE=0;

    # pre-process parameters
    my %param = @_;
    #       freq     - default=parent size, or "1" if we have a count
    #       by       - default=[0]
    #       count    - default=infinite
    my $res = $self->new();
    my $max = 1 + $#{ $self->{list} };

    my ($freq, $count);

    # $param{freq}  = 1 unless exists $param{freq} or exists $param{by};
    $param{count} = $inf if exists $param{freq} and ! exists $param{count};
    # ($param{freq}, $param{count}) = (1,1) unless exists $param{freq} and exists $param{count};

    $freq =  exists $param{freq}  ? $param{freq} :
             exists $param{count} ? 1 : $max;
    $freq *= $param{interval} if exists $param{interval};  # obsolete
    my @by = exists $param{by}    ? @{ $param{by} } : (0);
    $count = exists $param{count} ? $param{count} : $inf;

    # warn "select: freq=$freq count=$count by=[@by]";

    if ($count <= 0) {
        $self->trace_close( arg => $res );
        return $res;
    }

    my @min = $self->min_a;
    my @max = $self->max_a;

    # if ( $self->{too_complex} && ($count != $inf) ) {
    #    # warn "select is complex but defineable: min=".$self->min_a ." count=$count freq=$freq";
    # }
    if ($self->{too_complex}) {
        $res = $self->_function( 'select', @_ );

        # TODO: find out how to calculate 'last' 
        $res->{last} = [ undef, 0 ];

        # conditions for "definition"/boundedness: 
        # - freq, count, min [. . .
        # - positive by, min [.. . 
        # - freq, count, by, min [.. .  .. .
        # - negative by and max   .. .]

        # carp "testing select too_complex ". $self->span;

        # my @min = $self->min_a;
        # my @max = $self->max_a;
        if ( defined $min[0] and ($min[0] != -$inf) ) {
            # warn "select is complex but defineable: min=".$self->min_a ." count=$count freq=$freq";
            # carp " testing select min...";
            # my %param = @_;
            # my @by = exists $param{by} ? @{ $param{by} } : (0);
            my @by1 = sort @by;
            # TODO: @by *can* be negative!
            if ( ($by1[0] >= 0) or (exists $param{freq} and exists $param{count}) ) {
                # carp "select might be defineable - min = ".$self->min_a;
                # my @first = $self->first;
                # warn "select-first = $first[0]";

                my $result = $self->new()->no_cleanup;
                my $tail = $self;
                # my $index = 0;
                my @first;

                # TODO: freq / count
            GET_SOME:
                my $index = 0;
                for (my $pos = 0; ; $pos++) {

                    if ($freq > 1 and $freq < $inf) {
                        if ($pos >= $freq) { 
                            # warn "pos >= freq  $pos >= $freq";
                            last;
                        }
                    }
                    else {
                        if ($index > $#by1) { 
                            # warn "index > by1  $index > $#by1";
                            last;
                        }
                    }

                    # warn "select: get from tail";
                    @first = $tail->first;
                    # warn "selecting: @first index=$index pos=$pos freq=$freq count=$count";
                    if (($index <= $#by1) && ($by1[$index] == $pos)) {
                        push @{ $result->{list} }, @{ $first[0]->{list} } if defined $first[0];
                        # carp "    push $first[0] ". $first[0]->{list}[0];
                        $index++;
                    }
                    $tail = $first[1];
                    last unless defined $tail;
                }
                # warn "result of quantize @by1 is $result, tail is ".$tail->min."..., count is $count";
                $param{count} --;
                if ($param{count} != $inf) {
                    # warn "select: count is not infinite: count=$param{count} got $result tail=$tail";
                    # $index = 0;
                    goto GET_SOME if $param{count} > 0;
                }
                if ($param{count} > 0) {
                    # warn "select: return union result $result and tail $tail count=$param{count}";
                    # $result = $result->union( $tail->select(%param) );
                    #### ??? $res =  $self->_function( 'select', %param );
                    # $tail = $tail->_function( 'select', %param );
                    my @first = $result->first;
                    # warn "res=$res first=@first tail=$tail";
                    my $union;
                    if (defined $first[1]) {
                        # TODO: save $tail->select->min, so that it doesn't try to re-evaluate to find union->first
                        # @tail_min = $tail_min; ???
                        $union = $tail->
                            _function( 'select', %param )->
                            _function2( 'union', $first[1] );
                    }
                    else {
                        $union = $tail->_function( 'select', %param );
                    }
                    # warn "    union = $union";
                    # setup min/first cache
                    $res->{first} = [$first[0], $union];            
                    # warn "TODO: setup first cache";
                    $self->trace_close( arg => $res );
                    return $res;
                }
                # warn "select: return $result and no tail";
                $self->trace_close( arg => $result );
                return $result;
            }
        }
        elsif ( defined $max[0] and ($max[0] != $inf) ) {
            # carp " testing select max...";
            my %param = @_;
            my @by = exists $param{by} ? @{ $param{by} } : (0);
            my @by1 = sort @by;
            if ( ($by1[-1] < 0) and not (exists $param{freq} or exists $param{count}) ){
                # carp "select might be defineable - max = ".$self->max." and by = @by";
                # TODO: find out what '100' should be
                # warn $b->intersection($self->max - 100, $self->max);
            }
        }

        $self->trace_close( arg => $res );
        return $res;
    }

    unless ($max) {
        $self->trace_close( arg => $res );
        return $res;   # empty parent
    }

    # warn " by @by count $count freq $freq";
 
    my $n = 0;
    my ($base, $pos);
    my %selection;
    while ( $n < $count ) {
        $base = $n * $freq;
        for (@by) {
            $pos = $base + $_;
            # carp " [$base-$max $pos] ";
            $selection{$pos} = 1 unless ($pos < 0) or ($pos >= $max);
        }
        $n++;
        last if $base >= $max;
    }

    my $tmp;
    my @keys = sort { $a <=> $b } keys %selection;

    # warn " keys @keys ";
    # carp " SELECT: @by = { @{ $param{by} } } = @keys parent=$self";

    foreach (@keys) {
        $tmp = $self->{list}[$_];
        # next unless defined $tmp;
        push @{$res->{list}}, $tmp;
    }
    $res->{cant_cleanup} = 1; 
    # carp " res: $res";
    $self->trace_close( arg => $res );
    return $res;
}

# first() could also be called "car" as in Lisp
# sub car { &first }

# first() is the same as: select(by=>[0])
#     extension: first( count => 3 ) returns n subsets

# use Data::Dumper; warn "using Data::Dumper";

sub first {
    my $self = shift;
    # my $n;

    if (exists $self->{first} ) {
        # from cache
        $self->trace(title=>"> first - cache ". ( defined ${$self->{first}}[0] ? "@{$self->{first}}" : "undef 0" ) ) if $TRACE;
        return wantarray ? @{$self->{first}} : $self->{first}[0];
    }

    $self->trace_open(title=>"first") if $TRACE;
    # trace_open;

    if ( $self->{too_complex} ) {
        # my @parent = $self->min_a;
        my $method = $self->{method};

        # warn "getting first of a $method";
        # warn Dumper($self);

        if ($method eq 'complement') {

            # TODO: should look for next "existing" interval,
            #       instead of the "empty" interval between quantize() elements

            my @parent_min = $self->{parent}->first;
            unless ( defined $parent_min[0] ) {
                    $self->trace_close( arg => 'bad parent: undef 0' );
                    return wantarray ? (undef, 0) : undef;
            }

            # warn "$method parent $self->{parent} first is @parent_min";
            my $parent_complement;
            my $first;
            my @next;
            my $parent;
            if ( $parent_min[0]->min == -$inf ) {
                my @parent_second = $parent_min[1]->first;
                #    (-inf..min)        (second..?)
                #            (min..second)   = complement
                # warn "$method second is @parent_second";
                $first = $self->new( $parent_min[0]->complement );
                $first->{list}[0]{b} = $parent_second[0]->{list}[0]{a};
                $first->{list}[0]{open_end} = ! $parent_second[0]->{list}[0]{open_begin};
                @{ $first->{list} } = () if 
                    ( $first->{list}[0]{a} == $first->{list}[0]{b}) && 
                        ( $first->{list}[0]{open_begin} ||
                          $first->{list}[0]{open_end} );
                @next = $parent_second[0]->max_a;
                $parent = $parent_second[1];
                # warn "$method second first $first next @next";
            }
            else {
                #            (min..?)
                #    (-inf..min)        = complement
                $parent_complement = $parent_min[0]->complement;
                # warn "$method first is $parent_complement";
                $first = $self->new( $parent_complement->{list}[0] );
                @next = $parent_min[0]->max_a;
                $parent = $parent_min[1];
            }
            unless (wantarray) {
                $self->trace_close( arg => $first );
                return $first;
            }

            # carp "first-tail not defined for method '$method'";
            # my $tail = $self->new( $parent_complement->{list}[-1] )->intersection( $parent_min[1] );
            # warn "tail starts in ". $parent_min[0]->max;
            my @no_tail = $self->new(-$inf,$next[0]);
            $no_tail[0]->{list}[0]{open_end} = $next[1];
            # warn "tail complement @no_tail";

            # TODO: change to: compl(p union n_t)
            # my $tail = $parent_min[1]->complement->complement($no_tail[0]);
            my $tail = $parent->union($no_tail[0])->complement;  
            # warn "tail $tail";
            $self->trace_close( arg => "$first $tail" ) if $TRACE;
            # warn "first $method \n    self = $self \n    first = $first \n    tail = $tail";
            return @{$self->{first}} = ($first, $tail);
        }  # end: first-complement

        if ($method eq 'intersection') {
            my @parent = @{ $self->{parent} };
            # warn "$method parents @parent";

            # TODO: check min1/min2 for undef

            my $retry_count = 0;
            my (@first, @min, $which, $first1, $intersection);

            SEARCH: while ($retry_count++ < $max_intersection_depth) {
                return undef unless defined $parent[0];
                return undef unless defined $parent[1];

                @{$first[0]} = $parent[0]->first;
                @{$first[1]} = $parent[1]->first;
                $self->trace( title=>"trying #$retry_count: $first[0][0] -- $first[1][0]" );

                # warn "trying #$retry_count: $first[0][0] -- $first[1][0]" ;

                unless ( defined $first[0][0] ) {
                    # warn "don't know first of $method";
                    $self->trace_close( arg => 'undef' );
                    return undef;
                }
                unless ( defined $first[1][0] ) {
                    # warn "don't know first of $method";
                    $self->trace_close( arg => 'undef' );
                    return undef;
                }
                @{$min[0]} = $first[0][0]->min_a;
                @{$min[1]} = $first[1][0]->min_a;
                unless ( defined $min[0][0] && defined $min[1][0] ) {
                    $self->trace( title=>"can't find min()" );
                    $self->trace_close( arg => 'undef' );
                    return undef;
                } 

                # $which is the index to the bigger "first".
                $which = ($min[0][0] < $min[1][0]) ? 1 : 0;  

                # warn " which $which ";

                for my $which1 ( $which, 1 - $which ) {

                  my $tmp_parent = $parent[$which1];
                  ($first1, $parent[$which1]) = @{ $first[$which1] };
                  # $self->trace( title=>"which = $which1 < $first1 , $parent[$which1] >" );

                  # warn "ref ". ref($first1);
                  if ( $first1->is_null ) {
                    # warn "first1 empty! count $retry_count";
                    # trace_close;
                    # return $first1, undef;
                    $intersection = $first1;
                    $which = $which1;
                    last SEARCH;
                  }
                  # warn "intersection is $first1 + $parent[$which1] ($min1[0]), $parent[1-$which1] ($min2[0]) count $retry_count";

                  # $TRACE = 1;
                  $intersection = $first1->intersection( $parent[1-$which1] );

                  # warn "intersection with $first1 is $intersection";

                  # $TRACE = 0;
                  unless ( $intersection->is_null ) { 
                    # $self->trace( title=>"got an intersection" );
                    if ( $intersection->is_too_complex ) {
                        $self->trace( title=>"got a too_complex intersection" );
                        $parent[$which1] = $tmp_parent;
                    }
                    else {
                        $self->trace( title=>"got an intersection" );
                        $which = $which1;
                        last SEARCH;
                    }
                  };

                }

                $self->trace( title=>"next try" );
            }
            $self->trace( title=>"exit loop" );

            if ( $intersection->is_null ) {
                # my ($second1, $second2);
                $self->trace( title=> "got no intersection so far" );
            }

            if ( $#{ $intersection->{list} } > 0 ) {
                # warn "intersection has ". $#{ $intersection->{list} } . " elements: $intersection";
                my $tail;
                ($intersection, $tail) = $intersection->first;
                $parent[$which] = $parent[$which]->union( $tail );
                # TODO: remove $intersection from [1-$which]
            }

            # warn "first intersection is $intersection of $first1 $parent[1-$which]";
            unless (wantarray) {
                    $self->trace_close( arg => $intersection );
                    return $intersection;
            }
            # my $tmp = $self->{parent}[$which]->complement( $intersection )->intersection (
            #           $self->{parent}[1-$which]->complement( $intersection ) );
            my $tmp;
            if ( defined $parent[$which] and defined $parent[1-$which] ) {
                $tmp = $parent[$which]->intersection ( $parent[1-$which] );
            }
            $self->trace_close( arg => "$intersection ". (defined $tmp ? "$tmp" : "") ) if $TRACE;
            return @{$self->{first}} = ($intersection, $tmp);

        } # end: first-intersection


        if ($method eq 'union') {
            my (@first, @min);
            my @parent = @{ $self->{parent} };
            @{$first[0]} = $parent[0]->first;
            @{$first[1]} = $parent[1]->first;
            unless ( defined $first[0][0] ) {
                # looks like one set was empty
                return @{$first[1]};
            }
            @{$min[0]} = $first[0][0]->min_a;
            @{$min[1]} = $first[1][0]->min_a;

            # check min1/min2 for undef
            unless ( defined $min[0][0] ) {
                $self->trace_close( arg => "@{$first[1]}" );
                return @{$first[1]}
            }
            unless ( defined $min[1][0] ) {
                $self->trace_close( arg => "@{$first[0]}" );
                return @{$first[0]}
            }

            my $which = ($min[0][0] < $min[1][0]) ? 0 : 1;
            my $first = $first[$which][0];
            # return $first unless wantarray;
            unless (wantarray) {
                    $self->trace_close( arg => $first );
                    return $first;
            }
            # find out the tail
            my $parent1 = $first[$which][1];
            # warn $self->{parent}[$which]." - $first = $parent1";
            my $parent2 = ($min[0][0] == $min[1][0]) ? 
                $self->{parent}[1-$which]->complement($first) : 
                $self->{parent}[1-$which];
            my $tail;
            if (( ! defined $parent1 ) || $parent1->is_null) {
                # warn "union parent1 tail is null"; 
                $tail = $parent2;
            }
            else {
                $tail = $parent1->$method( $parent2 );
            }

            # warn "   parent is a ".Dumper($self->{parent}[1]);

            # warn " union $which ".$self->{parent}[0]."=$min1 ".$self->{parent}[1]."=$min2";
            # warn " first=$first sample=$parent1 tail=$tail";
            # carp "end: first from a $method";
            $self->trace_close( arg => "$first $tail" ) if $TRACE;
            return @{$self->{first}} = ($first, $tail);
        } # end: first-union

        if ($method eq 'until') {
            my @parent = @{ $self->{parent} };
            my $redo = $parent[0]->until( $parent[1] );
            my @first = $redo->first;
            return wantarray ? @first : $first[0];
        }

        # 'quantize', 'select', 'recur_by_rule', 'offset', 'iterate'
        # warn "first() doesn't know how to do $method-first, but maybe $method() knows";
        # warn " parent was ".$self->{parent};
        $self->trace( title=> "redo" );
        my $redo = $self->{parent}->$method( @{ $self->{param} } );
        # my $new_method = exists $redo->{method} ? $redo->{method} : "[none]";
        # $redo->trace( title=> "redo" ); 
        # now we've got a ".$new_method;

        # TODO: check for deep recursion!
        my @first = $redo->first;
        $redo->trace_close( arg => "@first" ) if $TRACE;
        return wantarray ? @first : $first[0];  
    }

    # $self->trace( title => "self = simple" );
    return $self->SUPER::first;
}

sub last {
    my $self = shift;

    if (exists $self->{last} ) {
        # from cache
        $self->trace(title=>"> last - cache ". ( defined ${$self->{last}}[0] ? "@{$self->{last}}" : "undef 0" ) ) if $TRACE;
        return wantarray ? @{$self->{last}} : $self->{last}[0];
    }

    $self->trace(title=>"last") if $TRACE;

    if ( $self->{too_complex} ) {
        my $method = $self->{method};

        if ($method eq 'complement') {
            my @parent_max = $self->{parent}->last;
            unless ( defined $parent_max[0] ) {
                $self->trace_close( arg => 'bad parent: undef 0' );
                return wantarray ? (undef, 0) : undef;
            }
            my $parent_complement;
            my $last;
            my @next;
            my $parent;
            if ( $parent_max[0]->max == $inf ) {
                #    (inf..min)        (second..?) = parent
                #            (min..second)         = complement
                my @parent_second = $parent_max[1]->last;
                $last = $self->new( $parent_max[0]->complement );
                $last->{list}[0]{a} = $parent_second[0]->{list}[0]{b};
                $last->{list}[0]{open_begin} = ! $parent_second[0]->{list}[0]{open_end};
                @{ $last->{list} } = () if
                    ( $last->{list}[0]{a} == $last->{list}[0]{b}) &&
                        ( $last->{list}[0]{open_end} ||
                          $last->{list}[0]{open_begin} );
                @next = $parent_second[0]->min_a;
                $parent = $parent_second[1];
            }
            else {
                #            (min..?)
                #    (-inf..min)        = complement
                $parent_complement = $parent_max[0]->complement;
                $last = $self->new( $parent_complement->{list}[-1] );
                @next = $parent_max[0]->min_a;
                $parent = $parent_max[1];
            }
            unless (wantarray) {
                $self->trace_close( arg => $last );
                return $last;
            }
            my @no_tail = $self->new($next[0], $inf);
            $no_tail[0]->{list}[-1]{open_begin} = $next[1];
            my $tail = $parent->union($no_tail[-1])->complement;
            $self->trace_close( arg => "$last $tail" ) if $TRACE;
            return @{$self->{last}} = ($last, $tail);
        }

        if ($method eq 'intersection') {
            my @parent = @{ $self->{parent} };
            # TODO: check max1/max2 for undef

            my $retry_count = 0;
            my (@last, @max, $which, $last1, $intersection);

            SEARCH: while ($retry_count++ < $max_intersection_depth) {
                return undef unless defined $parent[0];
                return undef unless defined $parent[1];

                @{$last[0]} = $parent[0]->last;
                @{$last[1]} = $parent[1]->last;
                $self->trace( title=>"trying #$retry_count: $last[0][0] -- $last[1][0]" ) if $TRACE;
                # warn "last trying #$retry_count: $last[0][0] -- $last[1][0]" ;
                unless ( defined $last[0][0] ) {
                    # warn "don't know last of $method";
                    $self->trace_close( arg => 'undef' );
                    return undef;
                }
                unless ( defined $last[1][0] ) {
                    # warn "don't know last of $method";
                    $self->trace_close( arg => 'undef' );
                    return undef;
                }
                @{$max[0]} = $last[0][0]->max_a;
                @{$max[1]} = $last[1][0]->max_a;
                unless ( defined $max[0][0] && defined $max[1][0] ) {
                    $self->trace( title=>"can't find max()" );
                    $self->trace_close( arg => 'undef' );
                    return undef;
                }

                # $which is the index to the smaller "last".
                $which = ($max[0][0] > $max[1][0]) ? 1 : 0;

                for my $which1 ( $which, 1 - $which ) {

                  my $tmp_parent = $parent[$which1];
                  ($last1, $parent[$which1]) = @{ $last[$which1] };
                  # warn "ref ". ref($last1);
                  if ( $last1->is_null ) {
                    # warn "first1 empty! count $retry_count";
                    # trace_close;
                    # return $first1, undef;
                    $which = $which1;
                    $intersection = $last1;
                    last SEARCH;
                  }
                  $intersection = $last1->intersection( $parent[1-$which1] );

                  # warn "last intersection with $last1 is $intersection [$which1]";

                  # $TRACE = 0;
                  unless ( $intersection->is_null ) {
                    # $self->trace( title=>"got an intersection" );
                    if ( $intersection->is_too_complex ) {
                        $self->trace( title=>"got a too_complex intersection" ); 
                        # warn "too complex intersection";
                        $parent[$which1] = $tmp_parent;
                    }
                    else {
                        $self->trace( title=>"got an intersection" );
                        $which = $which1;
                        last SEARCH;
                    }
                  };

                }

                $self->trace( title=>"next try" );
            }
            $self->trace( title=>"exit loop" );
            if ( $intersection->is_null ) {
                $self->trace( title=> "got no intersection so far" );
            }

            if ( $#{ $intersection->{list} } > 0 ) {
                my $tail;
                ($intersection, $tail) = $intersection->last;
                $parent[$which] = $parent[$which]->union( $tail );
                # TODO: remove $intersection from [1-$which]
            }
            unless (wantarray) {
                    $self->trace_close( arg => $intersection );
                    return $intersection;
            }
            my $tmp;
            if ( defined $parent[$which] and defined $parent[1-$which] ) {
                $tmp = $parent[$which]->intersection ( $parent[1-$which] );
            }
            $self->trace_close( arg => "$intersection ". (defined $tmp ? "$tmp"
: "") ) if $TRACE;
            return @{$self->{last}} = ($intersection, $tmp);
        }

        if ($method eq 'union') {
            my (@last, @max);
            my @parent = @{ $self->{parent} };
            @{$last[0]} = $parent[0]->last;
            @{$last[1]} = $parent[1]->last;
            @{$max[0]} = $last[0][0]->max_a;
            @{$max[1]} = $last[1][0]->max_a;

            # check max1/max2 for undef
            unless ( defined $max[0][0] ) {
                $self->trace_close( arg => "@{$last[1]}" );
                return @{$last[1]}
            }
            unless ( defined $max[1][0] ) {
                $self->trace_close( arg => "@{$last[0]}" );
                return @{$last[0]}
            }

            my $which = ($max[0][0] > $max[1][0]) ? 0 : 1;
            my $last = $last[$which][0];
            # return $last unless wantarray;
            unless (wantarray) {
                    $self->trace_close( arg => $last );
                    return $last;
            }
            # find out the tail
            my $parent1 = $last[$which][1];
            # warn $self->{parent}[$which]." - $last = $parent1";
            my $parent2 = ($max[0][0] == $max[1][0]) ?
                $self->{parent}[1-$which]->complement($last) :
                $self->{parent}[1-$which];
            my $tail;
            if (( ! defined $parent1 ) || $parent1->is_null) {
                # warn "union parent1 tail is null";
                $tail = $parent2;
            }
            else {
                $tail = $parent1->$method( $parent2 );
            }
            $self->trace_close( arg => "$last $tail" ) if $TRACE;
            return @{$self->{first}} = ($last, $tail);
        }

        # 'quantize', 'select', 'recur_by_rule', 'offset', 'iterate'
        # last() doesn't know how to do $method-last, 
        # but maybe $method() knows

        # warn " parent was ".$self->{parent};
        $self->trace( title=> "redo" ) if $TRACE;
        # warn "redo $method";
        my $redo = $self->{parent}->$method( @{ $self->{param} } );
        # my $new_method = exists $redo->{method} ? $redo->{method} : "[none]";
        # $redo->trace( title=> "redo" );
        # now we've got a ".$new_method;

        # TODO: check for deep recursion!
        my @last = $redo->last;
        $redo->trace_close( arg => "@last" ) if $TRACE;
        return wantarray ? @last : $last[0];
    }
    return $self->SUPER::last;
}

# offset: offsets subsets
sub offset {
    my $self = shift;
    #  my $class = ref($self);

    $self->trace_open(title=>"offset") if $TRACE;

    if ($self->{too_complex}) {
        my $b1 = $self->_function( 'offset', @_ );
        # first() code
        ## $self->trace( title => "*** offset doesn't have a first! ***" );
        my ($first, $tail) = $self->first;
        # TODO: check for invalid $first, $tail
        $first = $first->offset( @_ );
        $tail  = $tail->_function( 'offset', @_ );
        $b1->{first} = [$first, $tail];

        my $last;
        ($last, $tail) = $self->last;
        # TODO: check for invalid $last, $tail
        $last = $last->offset( @_ );
        $tail  = $tail->_function( 'offset', @_ );
        $b1->{last} = [$last, $tail];

        $self->trace_close( arg => $b1 );
        return $b1;
    }

    # return $self if $#{ $self->{list} } < 0;

    my @a;
    my %param = @_;
    my $b1 = $self->new();        # $self); # clone myself
    my ($interval, $ia, $i);
    $param{mode} = 'offset' unless $param{mode};

    # optimization for 1-parameter offset

    if (($param{mode} eq 'begin') and ($#{$param{value}} == 1) and
        ($param{value}[0] == $param{value}[1]) and
        ($param{value}[0] == 0) ) {
            # offset == zero
            foreach $i (0 .. $#{ $self->{list} }) {
                $interval = $self->{list}[$i];
                # next unless defined $interval;  
                $ia = $interval->{a};
                push @a, { a => $ia , b => $ia,
                        open_begin => 0 , open_end => 0 };
                        # open_begin => $open_begin , open_end => $open_end };
            }
            $b1->{list} = \@a;        # change data
            $b1->{cant_cleanup} = 1;
            $self->trace_close( arg => $b1 );
            return $b1;
    }

    unless (ref($param{value}) eq 'ARRAY') {
        #print " [value:scalar:", $param{value} ,"]\n";
        $param{value} = [0 + $param{value}, 0 + $param{value}];
    }
    $param{unit}   =      'one'    unless $param{unit};
    my $parts  =      ($#{$param{value}}) / 2;
    # $param{strict} =      0        unless $param{strict};
    # $param{fixtype} =     1        unless exists $param{fixtype};
    # $param{fetchsize} = $param{parts} * (1 + $#{ $self->{list} });
    my $sub_unit =    $Set::Infinite::Arithmetic::subs_offset2{$param{unit}};
    my $sub_mode =    $Set::Infinite::Arithmetic::_MODE{$param{mode}};
    # $param{parent_list} = $self->{list};

    carp "unknown unit $param{unit} for offset()" unless defined $sub_unit;
    carp "unknown mode $param{mode} for offset()" unless defined $sub_mode;

    # print " [ofs:$param{mode} $param{unit} value:", join (",", @{$param{value} }),"]\n";

    my ($j);
    my ($cmp, $this, $next, $ib, $part, $open_begin, $open_end, $tmp);

    my @value;
    foreach $j (0 .. $parts) {
        push @value, [ $param{value}[$j+$j], $param{value}[$j+$j + 1] ];
    }

    foreach $i (0 .. $#{ $self->{list} }) {
        $interval = $self->{list}[$i];
        # next unless defined $interval;
        $ia =         $interval->{a};
        $ib =         $interval->{b};
        $open_begin = $interval->{open_begin};
        $open_end =   $interval->{open_end};
        # do offset
        foreach $j (0 .. $parts) {
                # print " [ofs:$param{mode} $param{unit} value:", $param{value}[$j+$j], ",", $param{value}[$j+$j + 1],"]\n";
                # print " [ofs($ia,$ib)] ";
                ($this, $next) = &{ $sub_mode } 
                    ( $sub_unit, $ia, $ib, @{$value[$j]} );
                next if ($this > $next);    # skip if a > b
                # print " [ = ofs($this,$next)] \n";
                if ($this == $next) {
                    $open_end = $open_begin;
                    # $this = $next;  #  make sure to use the same object from cache!
                }
                # skip this if don't need to "fixtype"
                if ($self->{fixtype}) {
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
    $self->trace_close( arg => $b1 );
    return $b1;
}

# note: is_null might return a wrong value if is_too_complex is set.
# this is due to the implementation of min()
sub is_null {
    my $self = shift;
    return 0 if $self->{too_complex};
    return $self->SUPER::is_null;
}


sub is_too_complex {
    my $self = shift;
    $self->{too_complex} ? 1 : 0;
}


# shows how a set looks like after quantize->compact
sub _quantize_span {
    my $self = shift;
    my %param = @_;
    $self->trace_open(title=>"_quantize_span") if $TRACE;
    my $res;
    if ($self->{too_complex}) {
        $res = $self->{parent};
        if ($self->{method} ne 'quantize') {
            $self->trace( title => "parent is a ". $self->{method} );
            if ( $self->{method} eq 'union' ) {
                my $arg0 = $self->{parent}[0]->_quantize_span(%param);
                my $arg1 = $self->{parent}[1]->_quantize_span(%param);
                $res = $arg0->union( $arg1 );
            }
            elsif ( $self->{method} eq 'intersection' ) {
                my $arg0 = $self->{parent}[0]->_quantize_span(%param);
                my $arg1 = $self->{parent}[1]->_quantize_span(%param);
                $res = $arg0->intersection( $arg1 );
            }

            # TODO: other methods
            else {
                $res = $self; # ->_function( "_quantize_span", %param );
            }
            $self->trace_close( arg => $res );
            return $res;
        }

        # $res = $self->{parent};
        if ($res->{too_complex}) {
            $res->trace( title => "parent is complex" );
            $res = $res->_quantize_span( %param );
            $res = $res->quantize( @{$self->{param}} )->_quantize_span( %param );
        }
        else {
            $res = $res->iterate (
                sub {
                    $_[0]->quantize( @{$self->{param}} )->span;
                }
            );
        }
    }
    else {
        $res = $self->iterate (   sub { $_[0] }   );
    }
    $self->trace_close( arg => $res ) if $TRACE;
    return $res;
}

sub backtrack {
    #
    #  NOTE: set/reset $DEBUG_BT to enable debugging
    #
    my ($self, $method, $arg) = @_;
    unless ( $self->{too_complex} ) {
        $self->trace_open( title => 'backtrack '.$method ) if $TRACE;
        my $tmp = $self->$method ($arg);
        $self->trace_close( arg => $tmp ) if $TRACE;
        return $tmp;
    }
    $self->trace_open( title => 'backtrack '.$self->{method} ) if $TRACE;

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
        # has 2 parents (intersection, union, until ...)
        # data structure: {method} - method name, {parent} - array, parent list
        # print " [bt$backtrack_depth-3.5:complex: 2-PARENTS ] \n";

        $self->trace( title=>"array - method is $method" );

        if ($self->{method} eq 'until') {
            $self->trace( title=>"trying to find out from < $arg > - before" );
            # warn "[ min,max = ", ( ref($arg->min) ? $arg->min->datetime : $arg->min ) ," - ", $arg->max,"]\n";
            # warn "[ a-max = ", ( ref($self->{parent}[0]->max) ? $self->{parent}[0]->max->datetime : $self->{parent}[0]->max ) ," ]\n";
            # warn "[ b-min = ", ( ref($self->{parent}[1]->min) ? $self->{parent}[1]->min->datetime : $self->{parent}[1]->min ) ," ]\n";

            my $before = $self->{parent}[0]->intersection( -$inf, $arg->min )->max;
            $before = $arg->min unless $before;
            $self->trace( title=>"trying to find out from < $arg > - after" );
            my $after = $self->{parent}[1]->intersection( $arg->max, $inf )->min;
            $after = $arg->max unless $after;
            $self->trace( title=>"before, after is < $before , $after >" );
            $arg = $arg->new( $before, $after );
        }

        my $result1 = $self->{parent}[0];
        $result1 = $result1->backtrack($method, $arg) if $result1->{too_complex};
        # print " [bt$backtrack_depth-3-6:res1:$result] \n";
        my $result2 = $self->{parent}[1];
        $result2 = $result2->backtrack($method, $arg) if $result2->{too_complex};
        # print " [bt$backtrack_depth-3-7:res2:$result] \n";

        if ( $result1->{too_complex} or $result2->{too_complex} ) {
                # backtrack failed...
                $backtrack_depth--;
                $self->trace_close( arg => $self ) if $TRACE;

                # return the simplified version
                return $result1->_function2( $self->{method}, $result2 );
        }

        # apply {method}
        # print "\n\n<eval-2 method:$self->{method} - $the_method \n\n";
        # $result = &{ \& { $self->{method} } } ($result1, $result2);

        my $method = $self->{method};
        $result = $result1->$method ($result2);
        # print "\n\n/eval-2> \n\n";

        $backtrack_depth--;
        $self->trace_close( arg => $result ) if $TRACE;
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
 
            if ($my_method eq 'complement') {
                $backtrack_arg2 = $arg;  
            }
            elsif ($my_method eq 'quantize') {

                if ($arg->{too_complex}) {
                    $backtrack_arg2 = $arg;
                }
                else {
                    $backtrack_arg2 = $arg->quantize(@param)->_quantize_span;
                }
            }
            # offset - apply offset with negative values
            elsif ($my_method eq 'offset') {
                # (TODO) ????
                my %tmp = @param;

                #    unless (ref($tmp{value}) eq 'ARRAY') {
                #        $tmp{value} = [0 + $tmp{value}, 0 + $tmp{value}];
                #    }
                #    # $tmp{value}[0] = - $tmp{value}[0]; -- don't do this!
                #    # $tmp{value}[1] = - $tmp{value}[1]; -- don't do this!

                my @values = sort @{$tmp{value}};

                # $arg->trace( title => "offset: unit => $tmp{unit}, mode => $tmp{mode}, value => [- $tmp{value}[0], - $tmp{value}[-1]] " );
                # $backtrack_arg2 = $arg->offset( unit => $tmp{unit}, mode => $tmp{mode}, value => [- $tmp{value}[0], - $tmp{value}[-1]] );
                $backtrack_arg2 = $arg->offset( unit => $tmp{unit}, mode => $tmp{mode}, value => [- $values[-1], - $values[0]] );

                $backtrack_arg2 = $arg->union( $backtrack_arg2 );   # another hack - fixes some problems with 'begin' mode

            }
            # select - check "by" behaviour
            else {    # if ($my_method eq 'select') {
                # (TODO) ????
                # see: 'BIG, negative select' in backtrack.t

                $backtrack_arg2 = $arg;
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
    $self->trace_close( arg => $result );
    return $result;
}

sub intersects {
    my $a = shift;
    my ($b, $ia, $n);
    if (ref ($_[0]) eq 'HASH') {
        # optimized for "quantize"
        $b = shift;
        # TODO: make a test for this:
        return $a->intersects($a->new($b)) if ($a->{too_complex});
        $n = $#{$a->{list}};
        if ($n > 4) {
            foreach $ia ($n, $n-1, 0 .. $n - 2) {
                return 1 if Set::Infinite::Basic::_simple_intersects($a->{list}->[$ia], $b);
            }
            return 0;
        }
        foreach $ia (0 .. $n) {
            return 1 if Set::Infinite::Basic::_simple_intersects($a->{list}->[$ia], $b);
        }
        return 0;    
    } 
    if (ref ($_[0]) eq ref($a) ) { 
        $b = shift;
    } 
    else {
        $b = $a->new(@_);  
    }
    $a->trace(title=>"intersects");
    if ($a->{too_complex}) {
        $a = $a->backtrack('intersection', $b);
    }  # don't put 'else' here
    if ($b->{too_complex}) {
        $b = $b->backtrack('intersection', $a);
    }
    if (($a->{too_complex}) or ($b->{too_complex})) {
        return undef;   # we don't know the answer!
    }
    return $a->SUPER::intersects( $b );
}

sub iterate {
    my $a = shift;
    if ($a->{too_complex}) {
        $a->trace(title=>"iterate:backtrack");
        my $return = $a->_function( 'iterate', @_ );

        # first() helper
        my @first = $a->first;
        # warn "iterate: FIRST of $a was @first";
        $first[0] = $first[0]->iterate( @_ ) if ref($first[0]);
        $first[1] = $first[1]->_function( 'iterate', @_ ) if ref($first[1]);
        # warn "iterate: FIRST got @first";
        $return->{first} = \@first;

        # last() helper
        my @last = $a->last;
        # warn "iterate: LAST of $a was @last";
        $last[0] = $last[0]->iterate( @_ ) if ref($last[0]);
        $last[1] = $last[1]->_function( 'iterate', @_ ) if ref($last[1]);
        # warn "iterate: LAST got @last";
        $return->{last} = \@last;

        return $return;
    }
    $a->trace(title=>"iterate");
    return $a->SUPER::iterate( @_ );
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
    $a1->trace_open(title=>"intersection", arg => $b1) if $TRACE;
    if (($a1->{too_complex}) or ($b1->{too_complex})) {
        my $arg0 = $a1->_quantize_span;
        my $arg1 = $b1->_quantize_span;
        unless (($arg0->{too_complex}) or ($arg1->{too_complex})) {
            my $res = $arg0->_quantize_span->intersection( $arg1->_quantize_span );
            $a1->trace_close( arg => $res ) if $TRACE;
            return $res;
        }
    }
    if ($a1->{too_complex}) {
        # added: unless $b1->{too_complex}
        $a1 = $a1->backtrack('intersection', $b1) unless $b1->{too_complex};
    }  # don't put 'else' here
    if ($b1->{too_complex}) {
        # added: unless $b1->{too_complex}
        $b1 = $b1->backtrack('intersection', $a1) unless $a1->{too_complex};
    }
    if (($a1->{too_complex}) or ($b1->{too_complex})) {
        $a1->trace_close( ) if $TRACE;
        return $a1->_function2( 'intersection', $b1 );
    }
    return $a1->SUPER::intersection( $b1 );
}

sub complement {
    my $self = shift;
    # do we have a parameter?
    if (@_) {
        if (ref ($_[0]) eq ref($self) ) {
            $a = shift;
        } 
        else {
            $a = $self->new(@_);  
        }
        $self->trace_open(title=>"complement", arg => $a) if $TRACE;
        $a = $a->complement;
        my $tmp =$self->intersection($a);
        $self->trace_close( arg => $tmp ) if $TRACE;
        return $tmp;
    }
    $self->trace_open(title=>"complement") if $TRACE;
    if ($self->{too_complex}) {
        $self->trace_close( ) if $TRACE;
        return $self->_function( 'complement', @_ );
    }
    return $self->SUPER::complement;
}


sub until {
    my $a1 = shift;
    my $b1;
    if (ref ($_[0]) eq ref($a1) ) {
        $b1 = shift;
    } 
    else {
        $b1 = $a1->new(@_);  
    }
    $a1->trace_open(title=>"until", arg => $b1) if $TRACE;
    # warn "until: $a1 n=". $#{ $a1->{list} } ." $b1 n=". $#{ $b1->{list} } ;
    if (($a1->{too_complex}) or ($b1->{too_complex})) {
        my $u = $a1->_function2( 'until', $b1 );
        # first() code

        $a1->trace( title=>"computing first()" );
        my @first1 = $a1->first;
        my @first2 = $b1->first;
        # $a1->trace( title=>"first got $first1[0] and $first2[0] (". defined ($first1[0]) . ";". defined ($first2[0]) .")" );
        # $a1->trace( title=>"first $first1[0]{list}[0]{a} ".$first1[0]{list}[0]{open_end} );
        # $a1->trace( title=>"first $first2[0]{list}[0]{a} ".$first2[0]{list}[0]{open_end} );
        my ($first, $tail);
        if ( $first2[0] <= $first1[0] ) {
            # added ->first because it returns 2 spans if $a1 == $a2
            $first = $a1->new()->until( $first2[0] )->first;
            $tail = $a1->_function2( "until", $first2[1] );
        }
        else {
            $first = $a1->new( $first1[0] )->until( $first2[0] );
            if ( defined $first1[1] ) {
                $tail = $first1[1]->_function2( "until", $first2[1] );
            }
            else {
                $tail = undef;
            }
        }
        $u->{first} = [ $first, $tail ];
        $a1->trace_close( arg => $u ) if $TRACE;

        return $u;
    }
    return $a1->SUPER::until( $b1 );
}


sub union {
    my $a1 = shift;
    my $b1;
    return $a1 if $#_ < 0;
    if (ref ($_[0]) eq ref($a1) ) {
        $b1 = shift;
    } 
    else {
        $b1 = $a1->new(@_);  
    }
    $a1->trace_open(title=>"union", arg => $b1) if $TRACE;
    if (($a1->{too_complex}) or ($b1->{too_complex})) {
        $a1->trace_close( ) if $TRACE;
        return $a1 if $b1->is_null;
        return $b1 if $a1->is_null;
        return $a1->_function2( 'union', $b1);
    }
    return $a1->SUPER::union( $b1 );
}

# there are some ways to process 'contains':
# A CONTAINS B IF A == ( A UNION B )
#    - faster
# A CONTAINS B IF B == ( A INTERSECTION B )
#    - can backtrack = works for unbounded sets
sub contains {
    my $a = shift;
    $a->trace_open(title=>"contains") if $TRACE;
    if ( $a->{too_complex} ) { 
        # we use intersection because it is better for backtracking
        my $b = (ref $_[0] eq ref $a) ? $_[0] : $a->new(@_);
        my $b1 = $a->intersection($b);
        if ( $b1->{too_complex} ) {
            $b1->trace_close( arg => 'undef' ) if $TRACE;
            return undef;
        }
        $a->trace_close( arg => ($b1 == $b ? 1 : 0) ) if $TRACE;
        return ($b1 == $b) ? 1 : 0;
    }
    my $b1 = $a->union(@_);
    if ( $b1->{too_complex} ) {
        $b1->trace_close( arg => 'undef' ) if $TRACE;
        return undef;
    }
    $a->trace_close( arg => ($b1 == $a ? 1 : 0) ) if $TRACE;
    return ($b1 == $a) ? 1 : 0;
}

sub min_a { 
    my ($self) = shift;
    if (exists $self->{min} ) {
        $self->trace(title=>"min_a cache= @{$self->{min}}" ) if $TRACE; 
        return @{$self->{min}};
    }
    $self->trace_open(title=>"min_a") if $TRACE; 
    my $tmp;
    my $i;
    if ($self->{too_complex}) {
        my $method = $self->{method};
        # offset, select, quantize
        if ( ref $self->{parent} ne 'ARRAY' ) {
            my @parent;
            # warn " min ",$self->{method}," ",$self->{parent}->min_a;

            if ($method eq 'iterate') {
                # warn "min of iterate";
                @parent = $self->{parent}->min_a;
                unless (defined $parent[0]) {
                    $self->trace_close( arg => "@parent" ) if $TRACE;
                    return @{$self->{min}} = @parent;  # undef
                }
                # warn "min of iterate @parent";
                my $min = $self->new( $parent[0] )->iterate( @{ $self->{param} } );
                # warn "iterate got ". $min->min->ymd;
                @parent = $min->min_a;
                $self->trace_close( arg => "@parent" ) if $TRACE;
                return @{$self->{min}} = @parent;
            }

            if ($method eq 'complement') {
                @parent = $self->{parent}->min_a;
                unless (defined $parent[0]) {
                    $self->trace_close( arg => "@parent" ) if $TRACE;
                    return @{$self->{min}} = @parent;  # undef
                }
                if ($parent[0] != -$inf) {
                    $self->trace_close( arg => "-$inf 1" ) if $TRACE;
                    return @{$self->{min}} = (-$inf, 1);
                }
                my $first = $self->first;
                unless (defined $first) {
                    $self->trace_close( arg => "undef" ) if $TRACE;
                    return @{$self->{min}} = (undef, 0);
                }
                @parent = $first->max;
                $parent[1] = defined $parent[1] ? 1 - $parent[1] : 1;  # invert open/close set
                $self->trace_close( arg => "@parent" ) if $TRACE;
                return @{$self->{min}} = @parent;
            }

            my @first = $self->{parent}->first;
            unless (defined $first[0]) {
                $self->trace_close( arg => "undef 0" ) if $TRACE;
                return @{$self->{min}} = (undef, 0);
            }
            # warn "first is $first[0]";
            my @min = $first[0]->min;
            $self->trace_close( arg => "@min" ) if $TRACE;
            return @{$self->{min}} = @min;

        }
        else {
            # warn "$method min parents = ". $self->{parent}[0] . " " . $self->{parent}[1];
            if ($method eq 'union') {

                my @p1 = $self->{parent}[0]->min_a;
                my @p2 = $self->{parent}[1]->min_a;
                unless (defined $p1[0]) {
                    $self->trace_close( arg => 'undef 0' ) if $TRACE;
                    return @{$self->{min}} = @p1 ;
                }
                # my @p2 = $self->{parent}[1]->min_a;
                unless (defined $p2[0]) {
                    $self->trace_close( arg => 'undef 0' ) if $TRACE;
                    return @{$self->{min}} = @p2 ;
                }

                if ($p1[0] == $p2[0]) {
                    $p1[1] =  $p1[1] ? $p1[0] : $p1[1] ;
                    $self->trace_close( arg => "@p1" ) if $TRACE;
                    return @{$self->{min}} = @p1;
                }
                $self->trace_close( arg => ($p1[0] < $p2[0] ? "@p1" : "@p2") ) if $TRACE;
                return @{$self->{min}} = $p1[0] < $p2[0] ? @p1 : @p2;
            }
            if ($method eq 'intersection') {

                my @first = $self->first;
                unless (defined $first[0]) {
                    $self->trace_close( arg => "undef 0" ) if $TRACE;
                    return @{$self->{min}} = (undef, 0);
                }
                my @min = $first[0]->min;
                $self->trace_close( arg => "@min" ) if $TRACE;
                return @{$self->{min}} = @min;

            }
        }
    }

    $self->trace( title=> 'min simple tolerance='. $self->{tolerance}  );
    $self->trace_close( arg => 'undef 0' ) if $TRACE;
    return $self->SUPER::min_a;
};


sub max_a { 
    my ($self) = shift;
    return @{$self->{max}} if exists $self->{max};
    my $tmp;
    my $i;
    $self->trace_open(title=>"max_a") if $TRACE; 
    if ($self->{too_complex}) {
        my $method = $self->{method};
        # offset, select, quantize
        if ( ref $self->{parent} ne 'ARRAY' ) {
            my @parent;
            # print " max ",$self->{method}," ",$self->{parent}->max_a,"\n";

            if ($method eq 'iterate') {
                @parent = $self->{parent}->max_a;
                unless (defined $parent[0]) {
                    $self->trace_close( arg => "@parent" ) if $TRACE;
                    return @{$self->{max}} = @parent;  # undef
                }
                my $max = $self->new( $parent[0] )->iterate( @{ $self->{param} } );
                @parent = $max->max_a;
                $self->trace_close( arg => "@parent" ) if $TRACE;
                return @{$self->{max}} = @parent;
            }

            if ($method eq 'complement') {
                @parent = $self->{parent}->min_a;
                unless (defined $parent[0]) {
                    $self->trace_close( arg => "undef" ) if $TRACE;
                    return @{$self->{max}} = @parent;
                }
                if ( $parent[0] == -&inf ) {
                    $self->trace_close( arg => "$inf 1" ) if $TRACE;
                    return @{$self->{max}} = ($inf, 1);
                }
                $parent[1] = 1 - $parent[1];  # invert open/close set
                $self->trace_close( arg => "@parent" ) if $TRACE;
                return @{$self->{max}} = @parent;
            }

            @parent = $self->{parent}->max_a;
            unless (defined $parent[0]) {
                $self->trace_close( arg => "undef" ) if $TRACE;
                return @{$self->{max}} = @parent;
            }

            #  - 1e-10 is a fixup for open sets
            $tmp = $parent[0];
            # $tmp -= 1e-10 if $parent[1] and ($method eq 'quantize');
            if ( ($tmp == &inf) or ($tmp == -&inf) ) {
                $self->trace_close( arg => "$tmp 1" ) if $TRACE;
                return @{$self->{max}} = ($tmp, 1);
            }

            $self->trace( title=>"creating sample for $method" );
            my $sample;

            # TODO: this is a Date::Set hack
            #  - we shouldn't know about recur_by_rule here
            if ( $method eq 'recur_by_rule' ) {
                my %param = @{$self->{param}};
                $self->trace( title=>"freq = ".$param{FREQ} ) if $method eq 'recur_by_rule';
                my %FREQ = (
    SECONDLY => 'seconds',
    MINUTELY => 'minutes',
    HOURLY   => 'hours',
    DAILY    => 'days',
    WEEKLY   => 'weeks',
    MONTHLY  => 'months',
    YEARLY   => 'years'
                );
                $sample = $self->new($tmp)->quantize( unit=>$FREQ{$param{FREQ}} );
            } 
            # END_HACK
            else {
                $sample = { a => $tmp - 1 - $self->{tolerance}, 
                     b => $tmp,
                     open_begin => 0, 
                     open_end => $parent[1] };
            }

            # print " tol=",$self->{tolerance}," max=$tmp open=$parent[1]\n";
            @{$self->{max}} = $self->new( $sample )->$method( @{$self->{param}} )->max_a;
            $self->trace_close( arg => "@{$self->{max}}" ) if $TRACE;
            return @{$self->{max}} ;
        }
        else {
            my @p1 = $self->{parent}[0]->max_a;
            unless (defined $p1[0]) {
                $self->trace_close( arg => "@p1" ) if $TRACE;
                return @{$self->{max}} = @p1;
            }
            my @p2 = $self->{parent}[1]->max_a;
            unless (defined $p2[0]) {
                $self->trace_close( arg => "@p2" ) if $TRACE;
                return @{$self->{max}} = @p2;
            }
            if ($method eq 'union') {
                if ($p1[0] == $p2[0]) {
                    $p1[1] = $p1[1] ? $p1[0] : $p1[1];
                    $self->trace_close( arg => "@p1" ) if $TRACE;
                    return @{$self->{max}} = @p1;
                }
                $self->trace_close( arg => ( $p1[0] > $p2[0] ? "@p1" : "@p2" ) ) if $TRACE;
                return @{$self->{max}} = $p1[0] > $p2[0] ? @p1 : @p2;
            }
            if ($method eq 'intersection') {
                if ($p1[0] == $p2[0]) {
                    $p1[1] = $p1[1] ? $p1[1] : $p1[0];
                    $self->trace_close( arg => "@p1" ) if $TRACE;
                    return @{$self->{max}} = @p1;
                }
                $self->trace_close( arg => ( $p1[0] < $p2[0] ? "@p1" : "@p2" ) ) if $TRACE;
                return @{$self->{max}} = $p1[0] < $p2[0] ? @p1 : @p2;
            }
        }
    }
    $self->trace_close( arg => "undef 0" ) if $TRACE;
    return $self->SUPER::max_a;
};

sub count {
    my ($self) = shift;
    return $inf if $self->{too_complex};
    return $self->SUPER::count;
}

sub size { 
    my ($self) = shift;
    my $tmp;
    if ($self->{too_complex}) {
        # TODO: quantize could use 'quantize_span'
        # print " max ",$self->{method}," ",$self->{parent}->max,"\n";
        my @min = $self->min_a;
        my @max = $self->max_a;
        return undef unless defined $max[0] and defined $min[0];
        return $max[0] - $min[0];
    }
    return $self->SUPER::size;
};


sub spaceship {
    my ($tmp1, $tmp2, $inverted) = @_;
    carp "Can't compare unbounded sets" 
        if $tmp1->{too_complex} or $tmp2->{too_complex};
    return $tmp1->SUPER::spaceship( $tmp2, $inverted );
}

sub no_cleanup {
    my ($self) = shift;
    $self->{cant_cleanup} = 1; 
    return $self;
}

sub cleanup {
    my ($self) = shift;
    return $self if $self->{too_complex};
    return $self if $self->{cant_cleanup};     # quantize output is "virtual", can't be cleaned
    $_ = 1;
    while ( $_ <= $#{$self->{list}} ) {
        my @tmp = Set::Infinite::Basic::_simple_union($self->{list}->[$_],
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


sub tolerance {
    my $self = shift;
    my $tmp = pop;
    if (ref($self)) {  
        # local
        return $self->{tolerance} unless defined $tmp;
        if ($self->{too_complex}) {
            my $b1 = $self->_function( 'tolerance', $tmp );
            $b1->{tolerance} = $tmp;   # for max/min processing
            return $b1;
        }
        $self = $self->copy;
        $self->{tolerance} = $tmp;
        return $self;
    }
    # global
    __PACKAGE__->SUPER::tolerance( $tmp ) if defined($tmp);
    return __PACKAGE__->SUPER::tolerance;   
}


sub _pretty_print {
    my $self = shift;
    # return "()" if $self->is_null;
    return "$self" unless $self->{too_complex};
    return $self->{method} . "( " .
               ( ref($self->{parent}) eq 'ARRAY' ? 
                   $self->{parent}[0] . ' ; ' . $self->{parent}[1] : 
                   $self->{parent} ) .
           " )";
}

sub as_string {
    my $self = shift;
    return ( $PRETTY_PRINT ? $self->_pretty_print : $too_complex ) 
        if $self->{too_complex};
    $self->cleanup;
    return $self->SUPER::as_string;
}


sub DESTROY {}

1;
__END__

=head1 SET FUNCTIONS

=head2 union

    $set = $a->union($b);

Returns the set of all elements from both sets.

This function behaves like a "or" operation.

    $set1 = new Set::Infinite( [ 1, 4 ], [ 8, 12 ] );
    $set2 = new Set::Infinite( [ 7, 20 ] );
    print $set1->union( $set2 );
    # output: [1..4],[7..20]

=head2 intersection

    $set = $a->intersection($b);

Returns the set of elements common to both sets.

This function behaves like a "and" operation.

    $set1 = new Set::Infinite( [ 1, 4 ], [ 8, 12 ] );
    $set2 = new Set::Infinite( [ 7, 20 ] );
    print $set1->intersection( $set2 );
    # output: [8..12]

=head2 complement

    $set = $a->complement;

Returns the set of all elements that don't belong to the set.

    $set1 = new Set::Infinite( [ 1, 4 ], [ 8, 12 ] );
    print $set1->complement;
    # output: (-inf..1),(4..8),(12..inf)

The complement function might take a parameter:

    $set = $a->complement($b);

Returns the set-difference, that is, the elements that don't
belong to the given set.

    $set1 = new Set::Infinite( [ 1, 4 ], [ 8, 12 ] );
    $set2 = new Set::Infinite( [ 7, 20 ] );
    print $set1->complement( $set2 );
    # output: [1..4]


=head1 DENSITY FUNCTIONS    

=head2 real

    $a->real;

Returns a set with density "0".

=head2 integer

    $a->integer;

Returns a set with density "1".

=head1 LOGIC FUNCTIONS

=head2 intersects

    $logic = $a->intersects($b);

=head2 contains

    $logic = $a->contains($b);

=head2 is_null

    $logic = $a->is_null;

=head2 is_too_complex

Sometimes a set might be too complex to enumerate or print.

This happens with sets that represent infinite recurrences, such as
when you ask for a quantization on a
set bounded by -inf or inf.

=head1 SCALAR FUNCTIONS

=head2 min

    $i = $a->min;

=head2 max

    $i = $a->max;

=head2 size

    $i = $a->size;  

=head2 count

    $i = $a->count;

=head1 OVERLOADED LANGUAGE OPERATORS

=head2 stringification

    print $set;

    $str = "$set";

See also: C<as_string>.

=head2 comparison

    sort

    > < == >= <= <=> 

See also: C<spaceship>.

=head1 CLASS METHODS

    separators(@i)

        chooses the interval separators for stringification. 

        default are [ ] ( ) '..' ','.

    inf

        returns an 'Infinity' number.

    minus_inf

        returns '-Infinity' number.

=head2 type

    type($i)

Chooses a default object data type.

default is none (a normal perl SCALAR).

    type('Math::BigFloat');
    type('Math::BigInt');
    type('Set::Infinite::Date');

See notes on Set::Infinite::Date below.

=head1 SPECIAL SET FUNCTIONS (WIDGETS)

=head2 span

    $i = $a->span;

        result is INTERVAL, (min .. max)

=head2 until

Extends a set until another:

    0,5,7 -> until 2,6,10

gives

    [0..2), [5..6), [7..10)

Note: this function is still experimental.

=head2 quantize

    quantize( parameters )

        Makes equal-sized subsets.

        In array context: returns a tied reference to the subset list.
        In set context: returns an ordered set of equal-sized subsets.

        The quantization function is external to this module:
        Parameters may vary depending on implementation. 

        Positions for which a subset does not exist may show as undef.

        Example: 

            $a = Set::Infinite->new([1,3]);
            print join (" ", $a->quantize( quant => 1 ) );

        Gives: 

            [1..2) [2..3) [3..4)

=head2 select

    select( parameters )

        Selects set members based on their ordered positions
        (Selection is more useful after quantization).

            freq     - default=1
            by       - default=[0]
            count    - default=Infinity

 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15    # [0..15] quantized by "1"

 0              5             10             15    # freq => 5

    1     3        6     8       11    13          # freq => 5, by => [ -2, 1 ]

    1     3        6     8                         # freq => 5, by => [ -2, 1 ], count => 2

    1                                     14       # by => [ -2, 1 ]

=head2 offset

    offset ( parameters )

        Offsets the subsets. Parameters: 

            value   - default=[0,0]
            mode    - default='offset'. Possible values are: 'offset', 'begin', 'end'.
            unit    - type of value. Can be 'days', 'weeks', 'hours', 'minutes', 'seconds'.

=head2 iterate

    iterate ( sub { } , @args )

Iterates on the set spans, over a callback subroutine. 
Returns the union of all partial results.

The callback argument C<$_[0]> is a span. If there are additional arguments they are passed to the callback.

The callback can return a span, a hashref (see C<Set::Infinite::Basic>), a scalar, an object, or C<undef>.

=head2 first / last

    first / last

In scalar context returns the first interval of a set.

In list context returns the first interval of a set, and the 'tail'.

Works even in unbounded sets

=head2 type

    type($i)

Chooses a default object data type. 

default is none (a normal perl SCALAR).

examples: 

        type('Math::BigFloat');
        type('Math::BigInt');
        type('Set::Infinite::Date');
            See notes on Set::Infinite::Date below.

=head1 INTERNAL FUNCTIONS

=head2 cleanup

    $a->cleanup;

Internal function to fix the internal set representation.
This is used after operations that might return invalid
values.

=head2 backtrack

    $a->backtrack( 'intersection', $b );

Internal function to evaluate recurrences.

=head2 numeric

    $a->numeric;

Internal function to ignore the set "type".
It is used in some internal optimizations, when it is
possible to use scalar values instead of objects.

=head2 fixtype

    $a->fixtype;

Internal function to fix the result of operations
that use the numeric() function.

=head2 tolerance

    $a->tolerance(0)    # defaults to real sets (default)
    $a->tolerance(1)    # defaults to integer sets

Internal function for changing the set "density".

=head2 min_a

    ($min, $min_is_open) = $set->min_a;

=head2 max_a

    ($max, $max_is_open) = $set->max_a;


=head2 as_string

Implements the "stringification" operator.

Stringification of unbounded recurrences is not implemented.

Unbounded recurrences are stringified as "function descriptions",
if the class variable $PRETTY_PRINT is set.

=head2 spaceship

Implements the "comparison" operator.

Comparison of unbounded recurrences is not implemented.

=head1 NOTES ON DATES

See modules DateTime::Set and Date::Set for up-to-date information on date-sets. 

Set::Infinite::Date is a Date "plug-in" for sets.

usage:

    type('Set::Infinite::Date');  # allows values like '2001-05-02 10:00:00'

Set::Infinite::Date requires Time::Local.

    use Set::Infinite;
    Set::Infinite->type('Set::Infinite::Date');
    Set::Infinite::Date->date_format("year-month-day");

    $a = Set::Infinite->new('2001-05-02', '2001-05-13');
    print "Weeks in $a: ", $a->quantize(unit => 'weeks', quant => 1);

    $a = Set::Infinite->new('09:30', '10:35');
    print "Quarters of hour in $a: ", $a->quantize(unit => 'minutes', quant => 15);

Quantize units can be years, months, days, weeks, hours, minutes, or seconds.
To quantize the year to first-week-of-year until last-week-of-year, use 'weekyears':

        ->quantize( unit => weekyears, wkst => 1 )

'wkst' parameter is '1' for monday (default), '7' for sunday.

max and min functions will also show in date/time format.

=head1 CAVEATS

=over 4

=item * "span" notation

    $a = Set::Infinite->new(10,1);

Will be interpreted as [1..10]

=item * "multiple-span" notation

    $a = Set::Infinite->new(1,2,3,4);

Will be interpreted as [1..2],[3..4] instead of [1,2,3,4].
You probably want ->new([1],[2],[3],[4]) instead,
or maybe ->new(1,4) 

=item * "range operator"

    $a = Set::Infinite->new(1..3);

Will be interpreted as [1..2],3 instead of [1,2,3].
You probably want ->new(1,3) instead.

=back

=head1 INTERNALS

The base I<set> object, without recurrences, is a C<Set::Infinite::Basic>.

A I<recurrence-set> is represented by a I<method name>, 
one or two I<parent objects>, and extra arguments.
The C<list> key is set to an empty array, and the
C<too_complex> key is set to C<1>.

This is a structure that holds a union of two "complex sets":

  {
    too_complex => 1,             # "this is a recurrence"
    list   => [ ],                # not used
    method => 'union',            # function name
    parent => [ $set1, $set2 ],   # "leaves" in the syntax-tree
    param  => [ ]                 # optional arguments for the function
  }

This is a structure that holds the complement of a "complex set":

  {
    too_complex => 1,             # "this is a recurrence"
    list   => [ ],                # not used
    method => 'complement',       # function name
    parent => $set,               # "leaf" in the syntax-tree
    param  => [ ]                 # optional arguments for the function
  }

=head1 SEE ALSO

C<DateTime::Set>

The perl-date-time project <http://datetime.perl.org> 

C<Date::Set>

The Reefknot project <http://reefknot.sf.net>

=head1 AUTHOR

Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

