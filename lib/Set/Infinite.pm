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
use Data::Dumper; 

our @ISA = qw(Exporter);

# This allows declaration    use Set::Infinite ':all';
our %EXPORT_TAGS = ( 'all' => [ qw(type inf new $inf) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } , qw(type inf new $inf trace_open trace_close) );
our @EXPORT = qw();

our $VERSION = '0.38';

our $TRACE = 0;      # basic trace method execution
our $DEBUG_BT = 0;   # backtrack tracer
our $PRETTY_PRINT = 0;  # 0 = print 'Too Complex'; 1 = describe functions 

# Preloaded methods go here.

use Set::Infinite::_Simple;
use Set::Infinite::Arithmetic;

# global defaults for object private vars
our $type = '';
our $tolerance = 0;
our $fixtype = 1;

# Infinity vars
our $inf            = 10**10**10;
our $minus_inf      = -$inf;

sub inf ()            { $inf }
sub minus_inf ()      { $minus_inf }

our $too_complex =    "Too complex";
our $backtrack_depth = 0;
our $max_backtrack_depth = 10;    # backtrack()
our $max_intersection_depth = 5;  # first()

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
    carp "Can't list an unbounded set" if $self->{too_complex};
    my @b = ();
    foreach (@{$self->{list}}) {
        # next unless defined $_;
        push @b, $self->new($_);
    }
    return @b;
}

sub fixtype {
    my $self = shift;
    $self = $self->copy;
    $self->{fixtype} = 1;
    return $self if $self->{too_complex};
    foreach (@{$self->{list}}) {
        # next unless defined $_;
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
    return $self if $self->{too_complex};
    foreach (@{$self->{list}}) {
        # next unless defined $_;
        $_->{a} = 0 + $_->{a};
        $_->{b} = 0 + $_->{b};
    }
    return $self;
}

sub compact {
    return $_[0];
}


# internal "trace" routines for debugging

our $trace_level = 0;
our %level_title;
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
            ( exists $parm{arg} ? "ret ". ( UNIVERSAL::isa($parm{arg}, __PACKAGE__ ) ? $parm{arg}->copy : "<$parm{arg}>" ) : "" ).
            " $caller[1]:$caller[2] ]\n" if $TRACE == 1;
    $trace_level--;
    return $self;
}


# internal method
# creates a 'function' object that can be solved by backtrack()
sub _function {
    my ($self, $method) = (shift, shift);

    # unless ( $self->{too_complex} ) {
    #    warn( "eval $method $self" );
    #    return $self->$method(@_);
    # }

    my $b = $self->new();
    $b->{too_complex} = 1;
    $b->{parent} = $self;   
    $b->{method} = $method;
    $b->{param}  = \@_;
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
    $b->{param}  = \@_;
    return $b;
}

# quantize: splits in same-size subsets

sub quantize {
    my $self = shift;
    $self->trace_open(title=>"quantize"); 
    my @min = $self->min_a;
    my @max = $self->max_a;
    if (($self->{too_complex}) or 
        (defined $min[0] && $min[0] == -&inf) or 
        (defined $max[0] && $max[0] == &inf)) {
        # $self->trace(title=>"quantize:backtrack"); 

        # warn "quantize a ". $self->{method} if $self->{too_complex};
        # warn "quantize a Inf"  if (defined $max[0] && $max[0] == &inf);
        # warn "quantize a -Inf" if (defined $min[0] && $min[0] == -&inf);

        # print " [quantize:backtrack] \n" if $DEBUG_BT;
        my $b = $self->_function( 'quantize', @_ );
        # $b->trace( title=>"quantize: created a function: $b" );

        if (defined $min[0] ) {    # && ($min[0] != -&inf) ) {
            my $first;
            if (( $min[0] == -&inf ) || ( $min[0] == &inf )) {
                $first = $self->new( $min[0] );
                @{$b->{first}} = ($first, $b);  # link to itself!
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

            # warn "    parent: ".$b->{parent};
            # my $tmp = $first->union($last)->union($b);
            # @{$tmp->{first}} = ($first, $b->union($last) );  # setup first-cache
            # @{$tmp->{last}}  = ($last,  $b->union($first) );
            # @{$tmp->{min}} = $first->min_a;
            # @{$tmp->{max}} = $last->max_a;
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
    $Set::Infinite::Arithmetic::Init_quantizer{$rule{unit}} (\%rule);

    $rule{sub_unit} = $Set::Infinite::Arithmetic::Offset_to_value{$rule{unit}};
    carp "Quantize unit '".$rule{unit}."' not implemented" unless ref( $rule{sub_unit} ) eq 'CODE';

    my ($max, $open_end) = $parent->max_a;
    $rule{offset} = $Set::Infinite::Arithmetic::Value_to_offset{$rule{unit}} (\%rule, $min);
    my $last_offset = $Set::Infinite::Arithmetic::Value_to_offset{$rule{unit}} (\%rule, $max);
    $rule{size} = $last_offset - $rule{offset} + 1; 
    my ($index, $tmp, $this, $next);
    for $index (0 .. $rule{size} ) {
        ($this, $next) = $rule{sub_unit} (\%rule, $index);
        unless ( $rule{fixtype} ) {
                $tmp = { a => $this , b => $next ,
                        open_begin => 0, open_end => 1 };
        }
        else {
                $tmp = Set::Infinite::_simple_new($this,$next, $rule{type} );
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
    $self->trace_open(title=>"select");
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
        $res->{too_complex} = 1;
        $res->{parent} = $self;  # ->copy;
        $res->{method} = 'select';
        $res->{param}  = \@_;

        # TODO: this is an inefficient and wrong way to solve 
        #    the min/max issue!
        # $b->{min} = $self->min_a;
        # $b->{max} = $self->max_a;

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
                    # if ($freq > 1 and $freq < $inf) {
                    #        last if $pos >= $freq;
                    # }
                    # else {
                    #        last if $index > $#by1;
                    # }
                    # $tail = $first[1];
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
                    $res =  $self->_function( 'select', %param );
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
                    @{$res->{first}} = ($first[0], $union);            
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
    my $count = shift || 1;
    my $n;

    if (exists $self->{first} ) {
        # from cache
        $self->trace(title=>"> first - cache ". ( defined ${$self->{first}}[0] ? "@{$self->{first}}" : "undef 0" ) ) if $TRACE;
        return wantarray ? @{$self->{first}} : $self->{first}[0];
    }

    $self->trace_open(title=>"first");
    # trace_open;

    if ( $self->{too_complex} ) {
        # my @parent = $self->min_a;
        my $method = $self->{method};

        # unless (defined $parent[0]) {
        #    trace_close;
        #    return undef;
        # }

        # warn "getting first of a $method";
        # warn Dumper($self);

        if ($method eq 'complement') {

            # TODO: should look for next "existing" interval,
            #       instead of the "empty" interval between quantize() elements

            my @parent_min = $self->{parent}->first;
            unless ( defined $parent_min[0] ) {
                    # warn "don't know first of $method";
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

        # if ($parent[0] == $inf) {
        #    # or ($parent[0] == -$inf);
        #    trace_close;
        #    return $self->new($parent[0]);
        # }

        if ($method eq 'intersection') {
            # warn "first not defined for method '$method'";

            my @parent = @{ $self->{parent} };
            # warn "$method parents @parent";

            # TODO: check min1/min2 for undef

            my $retry_count = 0;
            my (@first, @min, $which, $first1, $intersection);

            while ($retry_count++ < $max_intersection_depth) {
                @{$first[0]} = $parent[0]->first;
                @{$first[1]} = $parent[1]->first;
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
                    $self->trace_close( arg => 'undef' );
                    return undef;
                }
                $which = ($min[0][0] < $min[1][0]) ? 1 : 0; 
                ($first1, $parent[$which]) = @{ $first[$which] };

                # warn "ref ". ref($first1);
                if ( $first1->is_null ) {
                    # warn "first1 empty! count $retry_count";
                    # trace_close;
                    # return $first1, undef;
                    $intersection = $first1;
                    last;
                }
                # warn "intersection is $first1 + $parent[$which] ($min1[0]), $parent[1-$which] ($min2[0]) count $retry_count";

# $TRACE = 1;
                $intersection = $first1->intersection( $parent[1-$which] );
# $TRACE = 0;
                last unless ( $intersection->is_null );
                last unless defined $parent[$which];
            }

            if ( $intersection->is_null ) {
                # my ($second1, $second2);

                # warn "got no intersection so far!";

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
                @{$min[0]} = $first[0][0]->min_a;
                @{$min[1]} = $first[1][0]->min_a;
            # my @min1 = $self->{parent}[0]->min_a;
            # my @min2 = $self->{parent}[1]->min_a;

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

        # 'quantize', 'select', 'recur_by_rule'
        # warn "first() doesn't know how to do $method-first, but maybe $method() knows";
        # warn " parent was ".$self->{parent};
        my $redo = $self->{parent}->$method( @{ $self->{param} } );
        # my $new_method = exists $redo->{method} ? $redo->{method} : "[none]";
        $redo->trace( title=> "redo" ); 
        # now we've got a ".$new_method;

        # TODO: check for deep recursion!
        my @first = $redo->first;
        $redo->trace_close( arg => "@first" ) if $TRACE;
        return wantarray ? @first : $first[0];  
    }

    # $self->trace( title => "self = simple" );

    unless ( @{$self->{list}} ) {
        $self->trace_close( arg => 'empty set: undef 0' );
        return wantarray ? (undef, 0) : undef; 
    }
    
    $n = $#{$self->{list}};
    $count = $n+1 unless $count <= ($n+1);
    # warn "return [0 .. $count-1] , [$count .. $n]";
    my $first = $self->new( @{$self->{list}} [0 .. $count-1] )->no_cleanup;
    if ( $n == ($count-1) || ! wantarray ) {  # FIRST
        $self->trace_close( arg => $first );
        return $first;
    }
    my $res = $self->new->no_cleanup;
    push @{$res->{list}}, @{$self->{list}} [$count .. $n];
    # warn "first-wantarray = ( $first , $res )";
    $self->trace_close( arg => "$first $res" ) if $TRACE;
    return @{$self->{first}} = ($first, $res);
}

my $dummy = <<'____TODO____';
sub last {
    my $self = shift;
    my $count = shift || 1;
    my $n;

    $self->trace(title=>"last");

    if ( $self->{too_complex} ) {
        my @parent = $self->max_a;
        my $method = $self->{method};
        # warn "here: @parent $method";
        return undef unless defined $parent[0];

        # carp "getting last from a $method";

        if ($method eq 'complement') {
            my @parent_max = $self->{parent}->last;
            # carp "parent's first is @parent_max";
            my $parent_complement = $parent_max[0]->complement;
            # carp "last is $parent_complement";
            # TODO: tail
            return $self->new( $parent_complement->{list}[-1] );
        }


        return $self->new($parent[0]) if ($parent[0] == $inf) or ($parent[0] == -$inf);
        # carp "getting last from a $method";

        # if ($method eq 'complement') {
        #    my @parent_min = $self->{parent}->first;
        #    # carp "parent's first is @parent_min";
        #    my $parent_complement = $parent_min[0]->complement;
        #    # carp "last is $parent_complement";
        #    # TODO: tail
        #    return $self->new( $parent_complement->{list}[0] );
        # }

        if ($method eq 'intersection') {
            die "last not defined for method '$method'";

            my $min1 = $self->{parent}[0]->min_a;
            my $min2 = $self->{parent}[1]->min_a;

            # TODO: check min1/min2 for undef

            my $which = ($min1 > $min2) ? 0 : 1;

            my $last1 = $self->{parent}[$which]->last;
            my $last2 = $self->{parent}[1-$which]->last;
            warn "parents are $self->{parent}[$which] , $self->{parent}[1-$which]";
            warn "last parents are $last1 , $last2";

            if ($min1 == $min2) {
                my $intersection = $last1->intersection( $last2 );
                warn "last intersection is $intersection";
                return $intersection unless wantarray;
                return $intersection, $self->{parent}[$which]->complement( $intersection )->intersection (
                    $self->{parent}[1-$which]->complement( $intersection ) );
            }

            return undef;
        }
        if ($method eq 'union') {
            my $max1 = $self->{parent}[0]->max_a;
            my $max2 = $self->{parent}[1]->max_a;

            # TODO: check max1/max2 for undef

            my $which = ($max1 > $max2) ? 0 : 1;
            my $last = $self->{parent}[$which]->last;
            return $last unless wantarray;
            # find out the tail
            my $parent1 = $self->{parent}[$which]->complement($last);
            my $parent2 = ($max1 == $max2) ? 
                $self->{parent}[1-$which]->complement($last) : 
                $self->{parent}[1-$which];
            my $tail = $parent1->$method( $parent2 );

            # warn "   parent is a ".Dumper($self->{parent}[1]);
            # warn " union $which ".$self->{parent}[0]."=$min1 ".$self->{parent}[1]."=$min2";
            # warn " last=$last sample=$parent1 tail=$tail";
            # carp "end: last from a $method";
            return ($last, $tail);
        }
        if ($method eq 'quantize') {
            # quantize max back, if parent method is quantize()
            # TODO: use 'unit' instead of '-1'
            my $sample = { a => $parent[0] - 1 - $self->{tolerance},
                     b => $parent[0] ,
                     open_begin => 0 ,
                     open_end => $parent[1] };
            my $last = $self->new( $sample )->$method( @{$self->{param}} )->last;
            return $last unless wantarray;
            # find out the tail
            $sample = $self->{parent}->complement($last);
            # warn "tail = quantize $sample";
            my $tail = $sample->$method( @{$self->{param}} );
            # carp "end: last from a $method";
            return ($last, $tail);
        }

        # if ($method eq 'select') {

        # warn "last() doesn't know how to do $method-last, but maybe $method() knows";
        my $redo = $self->{parent}->$method( @{ $self->{param} } );
        my $new_method = exists $redo->{method} ? $redo->{method} : "[none]";
        # warn "now we've got a ".$new_method;

        return $redo->last if $method ne $new_method;  # new_method should be 'union' or '[none]'

        # return undef  # carp "end: last from a select - calling $method";

        # TODO:
        # warn "    method=$method min=".$parent[0];
        # quantize min back, if parent method is quantize()
        # TODO: fix select-min problem

        carp "last not defined for method '$method'";
    }
    return undef unless @{$self->{list}};
    # carp " last of bounded = $self";
    $n = $#{$self->{list}};
    $count = $n - $count + 1;
    $count = 0 if $count < 0;
    # warn "return [0 .. $count-1] , [$count .. $n]";
    my $last = $self->new( @{$self->{list}} [$count .. $n] )->no_cleanup;
    return $last if $count == 0 || ! wantarray;  # last
    my $res = $self->new->no_cleanup;
    push @{$res->{list}}, @{$self->{list}} [0 .. $count-1];
    # warn "last-wantarray = ( $last , $res )";
    return $last, $res;
}
____TODO____


# offset: offsets subsets
sub offset {
    my $self = shift;
    #  my $class = ref($self);

    $self->trace_open(title=>"offset");

    if ($self->{too_complex}) {
        my $b1 = $self->new();
        $b1->{too_complex} = 1;
        $b1->{parent} = $self;  # ->copy;
        $b1->{method} = 'offset';
        $b1->{param}  = \@_;
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
                push @a, { a => $ia , b => $ia };
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

    # print " N = $#a \n";

    $self->trace_close( arg => $b1 );
    return $b1;
}

# note: is_null might return a wrong value if is_too_complex is set.
# this is due to the implementation of min()

sub is_null {
    my $self = shift;

    return 0 if $self->{too_complex};
    return 0 if @{$self->{list}};
    return 1;

    # my @min = $self->min_a;
    # defined $min[0] ? undef : 1;
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


# shows how a set looks like after quantize->compact
sub _quantize_span {
    my $self = shift;
    my %param = @_;
    $self->trace_open(title=>"_quantize_span");
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
        # TODO! - use compact()
        $res = $self->iterate (   sub { $_[0] }   );
    }
    $self->trace_close( arg => $res );
    return $res;
}

sub backtrack {
    #
    #  NOTICE: set/reset $DEBUG_BT to enable debugging
    #

    my ($self, $method, $arg) = @_;
    unless ( $self->{too_complex} ) {
        $self->trace_open( title => 'backtrack '.$method );
        # trace_open;
        my $tmp = $self->$method ($arg);
        $self->trace_close( arg => $tmp );
        return $tmp;
    }

    $self->trace_open( title => 'backtrack '.$self->{method} );
    #trace_open;

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
                $self->trace_close( arg => $self );
                return $self;
        }

        # apply {method}
        # print "\n\n<eval-2 method:$self->{method} - $the_method \n\n";
        # $result = &{ \& { $self->{method} } } ($result1, $result2);
        my $method = $self->{method};
        $result = $result1->$method ($result2);
        # print "\n\n/eval-2> \n\n";

        $backtrack_depth--;
        $self->trace_close( arg => $result );
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
    $self->trace_close( arg => $result );
    return $result;
}

sub intersects {
    my $a = shift;
    my ($b, $ia, $n);
    # print " [I:", ref ($_[0]), "] ";
    if (ref ($_[0]) eq 'HASH') {
        # optimized for "quantize"
        # $a->trace(title=>"intersects:simple ");
        # print " n:", $#{$a->{list}}, "=$a ";
        $b = shift;
        
        # TODO: make a test for this:
        return $a->intersects($a->new($b)) if ($a->{too_complex});

        # return 0 unless defined $b;
        # $a->trace(title=>"intersects:simple " . join(':', %$b) );
        $n = $#{$a->{list}};
        if ($n > 4) {
            foreach $ia ($n, $n-1, 0 .. $n - 2) {
                return 1 if _simple_intersects($a->{list}->[$ia], $b);
            }
            return 0;
        }
        foreach $ia (0 .. $n) {
            return 1 if _simple_intersects($a->{list}->[$ia], $b);
        }
        # print "don't\n";
        return 0;    
    } 

    if (ref ($_[0]) ) { 
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
        return undef;   # we don't know the answer!
    }

    # no difference in time
    # ($a, $b) = ($b, $a) if $#{$a->{list}} > $#{$b->{list}};

    my $ib;
    my ($na, $nb) = (0,0);
    # my $intersection = $class->new();

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
    # my $class = ref($a);
    my $iterate = $a->new();

    # print " [iterate ",$a,"--",ref($a)," from ", caller, "] \n";

    if ($a->{too_complex}) {
        $a->trace(title=>"iterate:backtrack");
        # print " [iterate:backtrack] \n" if $DEBUG_BT;
        $iterate->{too_complex} = 1;
        $iterate->{parent} = $a;  # ->copy;
        $iterate->{method} = 'iterate';
        $iterate->{param} = \@_;
        return $iterate;
    }

    $a->trace(title=>"iterate");

    my ($tmp, $ia);
    my $subroutine = shift;
    foreach $ia (0 .. $#{$a->{list}}) {
        # next unless defined $a->{list}->[$ia];
        # print " [iterate:$a->{list}->[$ia] -- $subroutine ]\n";
        $tmp = &{$subroutine} ( $a->new($a->{list}->[$ia]) );
        # print " [iterate:result:$tmp]\n";
        $iterate = $iterate->union($tmp) if defined $tmp; 
    }
    return $iterate;    
}

sub intersection {

    # return undef unless defined $_[1];

    my $a1 = shift;
    my $b1;
    # $a1->trace(title=>"intersection", arg => $b1);
    if (ref ($_[0]) eq ref($a1) ) {
        $b1 = shift;
    } 
    else {
        $b1 = $a1->new(@_);  
    }
    $a1->trace_open(title=>"intersection", arg => $b1);
    # my $tmp;
    # print " [intersect ",$a,"--",ref($a)," with ", $b, "--",ref($b)," ", caller, "] \n";

    # TODO: remove this? too specific
    # if ( $#{ $a1->{list} } == 0 ) {
    #    $a1->trace( title => "intersection: special case 'backtrack'" );
    #    if ( $a1->span->contains($b1->span) ) {
    #        # warn " --- no change";
    #        $a1->trace_close( arg => $b1 );
    #        return $b1;
    #    }
    # }

    if (($a1->{too_complex}) or ($b1->{too_complex})) {
        my $arg0 = $a1->_quantize_span;
        my $arg1 = $b1->_quantize_span;
        # $a1->trace( title => "intersection: span $arg0 with $arg1");
        unless (($arg0->{too_complex}) or ($arg1->{too_complex})) {
            my $res = $arg0->_quantize_span->intersection( $arg1->_quantize_span );
            $a1->trace_close( arg => $res );
            return $res;
        }
    }

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
        $intersection->{parent} = [$a1,$b1]; # [$a1->copy, $b1->copy];
        $intersection->{method} = 'intersection';
        $a1->trace_close( arg => $intersection );
        return $intersection;
    }

    # print " [intersect \n    ",$a,"--",ref($a)," with \n    ", $b, "--",ref($b)," \n    ", caller, "] \n";

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
            # print " [ simple: fastnew($i_beg, $i_end, $open_beg, $open_end ) ]\n";
            # unless (( $tmp1a > $tmp1b ) or 
            #         ( ($tmp1a == $tmp1b) and ($open_beg or $open_end) )) {
            if ( ( $tmp1a <= $tmp1b ) and
                 ( ($tmp1a != $tmp1b) or 
                   (!$open_beg and !$open_end) or
                   ($tmp1a == $inf) or
                   ($tmp1a == -$inf)
                 )
               ) {
                push @a, 
                    { a => $tmp1a, b => $tmp1b, 
                      open_begin => $open_beg, open_end => $open_end } ;
                # $intersection->trace( title => "add ". join(" ", %{$a[-1]} ));
            }
            # elsif {
            # } 
        }
    }
    $intersection->{list} = \@a;
    # print " [intersect GIVES\n    ",$intersection,"\n\n";

    # NOTE: trace arg removed because it would cause a "cleanup"
    $a1->trace_close(); # ( arg => $intersection );

    return $intersection;    
}

# TODO: make complement() work with backtracking

sub complement {
    my $self = shift;
    # my $class = ref($self);
    # $self->trace(title=>"complement");
    # carp "Can't complement an unbounded set" if $self->{too_complex};
    # do we have a parameter?
    if (@_) {
        if (ref ($_[0]) eq ref($self) ) {
            $a = shift;
        } 
        else {
            $a = $self->new(@_);  
        }
        $self->trace_open(title=>"complement", arg => $a);
        #trace_open;
        $a = $a->complement;
        # print " [CPL:intersect ",$self," with ", $a, "] ";
        my $tmp =$self->intersection($a);
        $self->trace_close( arg => $tmp );
        return $tmp;
    }

    $self->trace_open(title=>"complement");

    if ($self->{too_complex}) {
        # TODO: check set "span" when backtracking
        my $b1 = $self->new();
        $b1->{too_complex} = 1;
        $b1->{parent} = $self;  # ->copy;
        $b1->{method} = 'complement';
        $b1->{param}  = \@_;
        $self->trace_close( arg => $b1 );
        return $b1;
    }

    my ($ia);
    my $tmp;
    # print " [CPL:",$self,"] ";

    if (($#{$self->{list}} < 0) or (not defined ($self->{list}))) {
        $self->trace_close( arg => $self->new(minus_inf, inf) ) if $TRACE;
        return $self->new(minus_inf, inf);
    }

    my $complement = $self->new();
    @{$complement->{list}} = _simple_complement($self->{list}->[0]); 

    $tmp = $self->new();
    foreach $ia (1 .. $#{$self->{list}}) {
        @{$tmp->{list}} = _simple_complement($self->{list}->[$ia]); 
        $complement = $complement->intersection($tmp); # if $tmp;
    }
    # print " [CPL:RES:",$complement,"] ";

    $self->trace_close( arg => $complement );
    return $complement;    
}


sub union {
    my $a1 = shift;
    # my $class = ref($a1);
    my $b1;

    # print " [UNION] \n";
    # print " [union: new b] \n";

    if ($#_ < 0) {  # old usage
        $a1->trace(title=>"union", arg => $a1);
        return $a1;  # ->compact;
    }

    if (ref ($_[0]) eq ref($a1) ) {
        $b1 = shift;
    } 
    else {
        $b1 = $a1->new(@_);  
    }

    $a1->trace_open(title=>"union", arg => $b1);

    # test for union with empty set
    # warn "union: $a1 n=". $#{ $a1->{list} } ." $b1 n=". $#{ $b1->{list} } ;
    if ( $#{ $a1->{list} } < 0 and ! $a1->{too_complex} ) {
        $b1->trace_close( arg => $b1 );
        return $b1;
    }
    if ( $#{ $b1->{list} } < 0 and ! $b1->{too_complex} ) {
        $a1->trace_close( arg => $a1 );
        return $a1;
    }

    if (($a1->{too_complex}) or ($b1->{too_complex})) {
        print " [union:backtrack] \n" if $DEBUG_BT;
        my $union = $a1->new();
        $union->{too_complex} = 1;
        $union->{parent} = [$a1,$b1];   # [$a1->copy, $b1->copy];
        $union->{method} = 'union';
        $a1->trace_close( arg => $union );
        return $union;
    }

    # -- special case: $a1 or $b1 is empty
     # print " A=0 B=$b1 " if $#{$a1->{list}} < 0;
     # print " B=0 A=$a1 " if $#{$b1->{list}} < 0;

    my @b1_min = $b1->min_a;
    my @a1_max = $a1->max_a;

    unless (defined $b1_min[0]) {
        # $#{$b1->{list}} < 0;
        $a1->trace_close( arg => $a1 );
        return $a1;
    }
    unless (defined $a1_max[0]) {
        # $#{$a1->{list}} < 0;
        $a1->trace_close( arg => $b1 );
        return $b1;
    }

    my ($ia, $ib);
    $ia = 0;
    $ib = 0;

    #  size+order matters on speed 

    # print " [ ",$a1->max," <=> ",$b1->max," ] \n";
 
    $a1 = $a1->new($a1);    # don't modify ourselves 
    my $b_list = $b1->{list};
    # -- frequent case - $b1 is after $a1
    if ($b1_min[0] > $a1_max[0]) {
        # print " [UNION: $a1 \n         $b1 $#{$b_list}\n       ";
        push @{$a1->{list}}, @$b_list;
        $a1->trace_close( arg => $a1 );
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

    # $a->trace(title=>"end: union");

    $a1->trace_close( arg => $a1 );
    return $a1;    
}

# use Data::Dumper; warn 'using Data::Dumper';

sub contains {
    my $a = shift;
    # $TRACE = 1;
    $a->trace_open(title=>"contains");

    # print Dumper($a);
    # print Dumper($_[0]);

    if ( $a->{too_complex} ) { 
        $a->trace_close( arg => 'undef' ); 
        return undef; 
    }
    my $b1 = $a->union(@_);
    if ( $b1->{too_complex} ) {
        $b1->trace_close( arg => 'undef' );
        return undef;
    }
    # warn " compare $b1 == $a ";
    $a->trace_close( arg => ($b1 == $a ? 1 : 0) );
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
        $copy->{$key} = $self->{$key};
    }

    # these are "cache" keys and had better be flushed (test?)
    # delete $copy->{max} if exists $copy->{max};
    # delete $copy->{min} if exists $copy->{min};

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
        $self->{tolerance} = $class->{tolerance}; # if $class->{tolerance};
        $self->{type}      = $class->{type};      # if $class->{type};
        $self->{fixtype}   = $class->{fixtype};   # if $class->{fixtype};
    }
    else {
        $self->{tolerance} = $tolerance ? $tolerance : 0;
        $self->{type} =      $type      ? $type : '';
        $self->{fixtype} =   $fixtype   ? $fixtype : 0;
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
        # print " [$tmp:",ref($tmp),"]eq[$tmp2:",ref($tmp2),"] ";
        # if (Set::Infinite::Element_Inf::is_null($tmp)) {
        #    carp " [1]$tmp is null ";
        # }
        # if (Set::Infinite::Element_Inf::is_null($tmp2)) {
        #    carp " [2]$tmp2 is null ";
        # }
        push @{ $self->{list} }, _simple_new($tmp,$tmp2, $self->{type} );
        # next;
    }
    $self;
}

sub min { 
    $_[0]->trace_open(title=>"min"); 
    #trace_open;
    # don't! "wantarray" breaks some tests in Date::Set!
    # wantarray ? $_[0]->min_a : ($_[0]->min_a)[0] 

    my $tmp;

    if ( $_[0]->{too_complex} ) {
        $tmp = ($_[0]->min_a)[0];
        # warn "min would be $tmp";
        # if ($tmp != -$inf) {
        #    $tmp = $_[0]->first;
        #    $tmp = ($tmp->min_a)[0] if defined $tmp;
        # }
    }
    else {
        $tmp = ($_[0]->min_a)[0];
    }
    $_[0]->trace_close( arg => $tmp );
    return $tmp;
}

sub min_a { 
    my ($self) = shift;

    if (exists $self->{min} ) {
        $self->trace(title=>"min_a cache= @{$self->{min}}" ) if $TRACE; 
        return @{$self->{min}};
    }
    $self->trace_open(title=>"min_a"); 
    my $tmp;
    my $i;


    if ($self->{too_complex}) {
        my $method = $self->{method};
        # offset, select, quantize
        if ( ref $self->{parent} ne 'ARRAY' ) {
            my @parent;
            # print " min ",$self->{method}," ",$self->{parent}->min_a,"\n";

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
                $self->trace_close( arg => "undef 0" );
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
                    $self->trace_close( arg => 'undef 0' );
                    return @{$self->{min}} = @p1 ;
                }
                # my @p2 = $self->{parent}[1]->min_a;
                unless (defined $p2[0]) {
                    $self->trace_close( arg => 'undef 0' );
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
    for($i = 0; $i <= $#{$self->{list}}; $i++) {
        # foreach(0 .. $#{$self->{list}}) {
        # next unless defined $self->{list}[$i];
        $tmp = $self->{list}[$i]->{a};
        my $tmp2 = $self->{list}[$i]{open_begin};
        if ($tmp2 and $self->{tolerance}) {
            $tmp2 = 0;
            $tmp += $self->{tolerance};
        }
        #print "min:$tmp ";
        $tmp2 = 0 unless defined $tmp2;
        $self->trace_close( arg => "$tmp $tmp2" ) if $TRACE;
        return @{$self->{min}} = ($tmp, $tmp2);  
    }
    $self->trace_close( arg => 'undef 0' );
    return @{$self->{min}} = (undef, 0);   
};



sub max { 
    $_[0]->trace_open(title=>"max"); 
    #trace_open;
    # don't! "wantarray" breaks some tests in Date::Set!
    # wantarray ? $_[0]->max_a : ($_[0]->max_a)[0]
    my $tmp = ($_[0]->max_a)[0];
    $_[0]->trace_close( arg => $tmp );
    return $tmp;
}

sub max_a { 
    my ($self) = shift;
    return @{$self->{max}} if exists $self->{max};
    my $tmp;
    my $i;

    $self->trace_open(title=>"max_a"); 

    if ($self->{too_complex}) {
        my $method = $self->{method};
        # offset, select, quantize
        if ( ref $self->{parent} ne 'ARRAY' ) {
            my @parent;
            # print " max ",$self->{method}," ",$self->{parent}->max_a,"\n";

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

            my $sample = { a => $tmp - 1 - $self->{tolerance}, 
                     b => $tmp,
                     open_begin => 0, 
                     open_end => $parent[1] };

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

    for($i = $#{$self->{list}}; $i >= 0; $i--) {
        ## $tmp_ptr = $self->{list}->[$i];
        ## $tmp = $tmp_ptr->{b};

        # next unless defined $self->{list}[$i];
        $tmp = $self->{list}[$i]{b};
        my $tmp2 = $self->{list}[$i]{open_end};
        if ($tmp2 and $self->{tolerance}) {
            $tmp2 = 0;
            $tmp -= $self->{tolerance};
        }
        # print "max:$tmp open=$tmp2\n";
        $tmp2 = 0 unless defined $tmp2;
        $self->trace_close( arg => "$tmp $tmp2" ) if $TRACE;
        return @{$self->{max}} = ($tmp, $tmp2);  
    }
    $self->trace_close( arg => "undef 0" ) if $TRACE;
    return @{$self->{max}} = (undef, 0); 
};

sub size { 
    my ($self) = shift;
    my $tmp;
    # $self->cleanup;
    # print " [INF:SIZE:$self->{list}->[0]->{b} - $self->{list}->[0]->{a} ] \n";

    if ($self->{too_complex}) {
        # print " max ",$self->{method}," ",$self->{parent}->max,"\n";
        # if ($self->{method} eq 'quantize') {
        my @min = $self->min_a;
        my @max = $self->max_a;
        return undef unless defined $max[0] and defined $min[0];
        return $max[0] - $min[0];
        # }
    }

    my $size = 0;
    foreach(0 .. $#{$self->{list}}) {
        # next unless defined $self->{list}->[$_];
        $size += $self->{list}->[$_]->{b} - $self->{list}->[$_]->{a};
        $size -= $self->{tolerance} if $self->{list}->[$_]->{open_begin};
        $size -= $self->{tolerance} if $self->{list}->[$_]->{open_end};
     }
    return $size; 
};

sub span { 
    my ($self) = shift;
    my @max = $self->max_a;
    my @min = $self->min_a;
    return undef unless defined $min[0] and defined $max[0];
    # print " span: @min -- @max \n";

    # TODO: what happens if max/min is undef

    my $a1 = $self->new($min[0], $max[0]);
    $a1->{list}[0]{open_end} = $max[1];
    $a1->{list}[0]{open_begin} = $min[1];
    return $a1;
};

sub spaceship {
    my ($tmp1, $tmp2, $inverted) = @_;
    carp "Can't compare unbounded sets" if $tmp1->{too_complex} or $tmp2->{too_complex};

    if ($inverted) {
        ($tmp2, $tmp1) = ($tmp1, $tmp2);
    }
    foreach(0 .. $#{$tmp1->{list}}) {
        my $this  = $tmp1->{list}->[$_];
        return -1 if $_ > $#{ $tmp2->{list} };
        my $other = $tmp2->{list}->[$_];

        # my @caller = caller(1);
        # print " [",$caller[1],":",$caller[2]," spaceship $tmp1 $tmp2 ]\n";

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
    return $self if $self->{too_complex};
    return $self if $self->{cant_cleanup};     # quantize output is "virtual", can't be cleaned

    $_ = 1;
    while ( $_ <= $#{$self->{list}} ) {
        # unless (defined $self->{list}->[$_]) {
        #    splice (@{$self->{list}}, $_, 1);
        #    next;
        # }

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
    my $self = shift;
    my $tmp = pop;
    # my $self = shift;
    # print " tolerance $self = $tmp \n";
    if (ref($self)) {  
        # local

        return $self->{tolerance} unless defined $tmp;

        if ($self->{too_complex}) {
            my $b1 = $self->new();
            $b1->{too_complex} = 1;
            $b1->{parent} = $self;  
            $b1->{method} = 'tolerance';
            $b1->{param}  = [ $tmp ];
            $b1->{tolerance} = $tmp;   # for max/min processing
            return $b1;
        }

        $self = $self->copy;
        $self->{tolerance} = $tmp;
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
    # return "()" if $PRETTY_PRINT && $self->is_null;
    return ( $PRETTY_PRINT ? $self->_pretty_print : $too_complex ) if $self->{too_complex};
    $self->cleanup;
    # return null          unless $#{$self->{list}} >= 0;
    return join(separators(5), map { _simple_as_string($_) } @{$self->{list}} );
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

        result is INTERVAL, (min .. max)

=head2 Scalar functions:

    $i = $a->min;

    $i = $a->max;

    $i = $a->size;  

=head2 Overloaded Perl functions:

    print    

    sort, <=> 

=head2 Global functions:

    separators(@i)

        chooses the interval separators. 

        default are [ ] ( ) '..' ','.

    infinite($i)

        chooses 'infinite' name. default is 'inf'

    inf

        returns an 'Infinity' number.

    minus_inf

        returns '-Infinity' number.

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

    offset ( parameters )

        Offsets the subsets. Parameters: 

            value   - default=[0,0]
            mode    - default='offset'. Possible values are: 'offset', 'begin', 'end'.
            unit    - type of value. Can be 'days', 'weeks', 'hours', 'minutes', 'seconds'.

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

    $a->cleanup;

    $a->backtrack($b);

    $a->fixtype; 

    $a->numeric;

=head1 Notes on Dates

See module Date::Set for up-to-date information on date-sets. 

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

    the Reefknot project <http://reefknot.sf.net>

=head1 AUTHOR

    Flavio Soibelmann Glock <fglock@pucrs.br>

=cut

