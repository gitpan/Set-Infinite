package Set::Infinite;

# Copyright (c) 2001, 2002 Flavio Soibelmann Glock. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

require 5.005_03;
use strict;

require Exporter;
use Set::Infinite::Basic;
    # These methods are inherited from Set::Infinite::Basic "as-is":
    #   type list fixtype numeric min max integer real new span copy
use Carp;
# use Data::Dumper; 

use vars qw( @ISA @EXPORT_OK @EXPORT $VERSION 
    $TRACE $DEBUG_BT $PRETTY_PRINT $inf $minus_inf $neg_inf 
    %_first %_last
    $too_complex $backtrack_depth 
    $max_backtrack_depth $max_intersection_depth
    $trace_level %level_title );
@ISA = qw( Set::Infinite::Basic Exporter );

@EXPORT_OK = qw(inf $inf trace_open trace_close);
@EXPORT = ();

use Set::Infinite::Arithmetic;

use overload
    '<=>' => \&spaceship,
    qw("" as_string),
;


$inf            = 100**100**100;
$neg_inf = $minus_inf  = -$inf;


# obsolete methods - included for backward compatibility
sub inf ()            { $inf }
sub minus_inf ()      { $minus_inf }
*no_cleanup = \&Set::Infinite::Basic::_no_cleanup;
*type       = \&Set::Infinite::Basic::type;
sub compact { @_ }


BEGIN {
    $VERSION = 0.5306;
    $TRACE = 0;         # enable basic trace method execution
    $DEBUG_BT = 0;      # enable backtrack tracer
    $PRETTY_PRINT = 0;  # 0 = print 'Too Complex'; 1 = describe functions
    $trace_level = 0;   # indentation level when debugging

    $too_complex =    "Too complex";
    $backtrack_depth = 0;
    $max_backtrack_depth = 10;    # _backtrack()
    $max_intersection_depth = 5;  # first()
}

 
sub trace { # title=>'aaa'
    return $_[0] unless $TRACE;
    my ($self, %parm) = @_;
    my @caller = caller(1);
    # print "self $self ". ref($self). "\n";
    print "" . ( ' | ' x $trace_level ) .
            "$parm{title} ". $self->copy .
            ( exists $parm{arg} ? " -- " . $parm{arg}->copy : "" ).
            " $caller[1]:$caller[2] ]\n" if $TRACE == 1;
    return $self;
}

sub trace_open { 
    return $_[0] unless $TRACE;
    my ($self, %parm) = @_;
    my @caller = caller(1);
    print "" . ( ' | ' x $trace_level ) .
            "\\ $parm{title} ". $self->copy .
            ( exists $parm{arg} ? " -- ". $parm{arg}->copy : "" ).
            " $caller[1]:$caller[2] ]\n";
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
            " $caller[1]:$caller[2] ]\n";
    $trace_level--;
    return $self;
}


# creates a 'function' object that can be solved by _backtrack()
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
        return $self->$method($arg, @_);
    }
    my $b = $self->new();
    $b->{too_complex} = 1;
    $b->{parent} = [ $self, $arg ];
    $b->{method} = $method;
    $b->{param}  = [ @_ ];
    return $b;
}


sub quantize {
    my $self = shift;
    $self->trace_open(title=>"quantize") if $TRACE; 
    my @min = $self->min_a;
    my @max = $self->max_a;
    if (($self->{too_complex}) or 
        (defined $min[0] && $min[0] == $neg_inf) or 
        (defined $max[0] && $max[0] == $inf)) {

        return $self->_function( 'quantize', @_ );
    }

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

    unless (defined $min) {
        $self->trace_close( arg => $b ) if $TRACE;
        return $b;    
    }

    $rule{fixtype} = 1 unless exists $rule{fixtype};
    $Set::Infinite::Arithmetic::Init_quantizer{$rule{unit}}->(\%rule);

    $rule{sub_unit} = $Set::Infinite::Arithmetic::Offset_to_value{$rule{unit}};
    carp "Quantize unit '".$rule{unit}."' not implemented" unless ref( $rule{sub_unit} ) eq 'CODE';

    my ($max, $open_end) = $parent->max_a;
    $rule{offset} = $Set::Infinite::Arithmetic::Value_to_offset{$rule{unit}}->(\%rule, $min);
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
        }
        next if ( $rule{strict} and not $rule{strict}->intersects($tmp));
        push @a, $tmp;
    }

    $b->{list} = \@a;        # change data
    $b->{cant_cleanup} = 1;     
    $self->trace_close( arg => $b ) if $TRACE;
    return $b;
}


sub _first_n {
    my $self = shift;
    my $n = shift;
    my $tail = $self->copy;
    my @result;
    my $first;
    for ( 1 .. $n )
    {
        ( $first, $tail ) = $tail->first if $tail;
        push @result, $first;
    }
    return $tail, @result;
}

sub _last_n {
    my $self = shift;
    my $n = shift;
    my $tail = $self->copy;
    my @result;
    my $last;
    for ( 1 .. $n )
    {
        ( $last, $tail ) = $tail->last if $tail;
        unshift @result, $last;
    }
    return $tail, @result;
}


sub select {
    my $self = shift;
    $self->trace_open(title=>"select") if $TRACE;

    my %param = @_;
    die "select() - parameter 'freq' is deprecated" if exists $param{freq};

    my $res;
    my $count;
    my @by;
    @by = @{ $param{by} } if exists $param{by}; 
    $count = delete $param{count} || $inf;
    # warn "select: count=$count by=[@by]";

    if ($count <= 0) {
        $self->trace_close( arg => $res ) if $TRACE;
        return $self->new();
    }

    my @set;
    my $tail;
    my $first;
    my $last;
    if ( @by ) 
    {
        my @res;
        if ( ! $self->is_too_complex ) 
        {
            $res = $self->new;
            @res = @{ $self->{list} }[ @by ] ;
        }
        else
        {
            my ( @pos_by, @neg_by );
            for ( @by ) {
                ( $_ < 0 ) ? push @neg_by, $_ :
                             push @pos_by, $_;
            }
            my @first;
            if ( @pos_by ) {
                @pos_by = sort { $a <=> $b } @pos_by;
                ( $tail, @set ) = $self->_first_n( 1 + $pos_by[-1] );
                @first = @set[ @pos_by ];
            }
            my @last;
            if ( @neg_by ) {
                @neg_by = sort { $a <=> $b } @neg_by;
                ( $tail, @set ) = $self->_last_n( - $neg_by[0] );
                @last = @set[ @neg_by ];
            }
            @res = map { $_->{list}[0] } ( @first , @last );
        }

        $res = $self->new;
        @res = sort { $a->{a} <=> $b->{a} } grep { defined } @res;
        my $last;
        my @a;
        for ( @res ) {
            push @a, $_ if ! $last || $last->{a} != $_->{a};
            $last = $_;
        }
        $res->{list} = \@a;
        $res->{cant_cleanup} = 1;
    }
    else
    {
        $res = $self;
    }

    return $res if $count == $inf;
    my $count_set = $self->new();
    $count_set->{cant_cleanup} = 1;
    if ( ! $self->is_too_complex )
    {
        my @a;
        @a = grep { defined } @{ $res->{list} }[ 0 .. $count - 1 ] ;
        $count_set->{list} = \@a;
    }
    else
    {
        my $last;
        while ( $res ) {
            ( $first, $res ) = $res->first;
            last unless $first;
            last if $last && $last->{a} == $first->{list}[0]{a};
            $last = $first->{list}[0];
            push @{$count_set->{list}}, $first->{list}[0];
            $count--;
            last if $count <= 0;
        }
    }
    return $count_set;
}

BEGIN {
  %_first = (
    'complement' =>
        sub {
            my $self = $_[0];
            my @parent_min = $self->{parent}->first;
            unless ( defined $parent_min[0] ) {
                return (undef, 0);
            }
            my $parent_complement;
            my $first;
            my @next;
            my $parent;
            if ( $parent_min[0]->min == $neg_inf ) {
                my @parent_second = $parent_min[1]->first;
                #    (-inf..min)        (second..?)
                #            (min..second)   = complement
                $first = $self->new( $parent_min[0]->complement );
                $first->{list}[0]{b} = $parent_second[0]->{list}[0]{a};
                $first->{list}[0]{open_end} = ! $parent_second[0]->{list}[0]{open_begin};
                @{ $first->{list} } = () if 
                    ( $first->{list}[0]{a} == $first->{list}[0]{b}) && 
                        ( $first->{list}[0]{open_begin} ||
                          $first->{list}[0]{open_end} );
                @next = $parent_second[0]->max_a;
                $parent = $parent_second[1];
            }
            else {
                #            (min..?)
                #    (-inf..min)        = complement
                $parent_complement = $parent_min[0]->complement;
                $first = $self->new( $parent_complement->{list}[0] );
                @next = $parent_min[0]->max_a;
                $parent = $parent_min[1];
            }
            my @no_tail = $self->new($neg_inf,$next[0]);
            $no_tail[0]->{list}[0]{open_end} = $next[1];
            my $tail = $parent->union($no_tail[0])->complement;  
            return ($first, $tail);
        },  # end: first-complement
    'intersection' =>
        sub {
            my $self = $_[0];
            my @parent = @{ $self->{parent} };
            # warn "$method parents @parent";
            my $retry_count = 0;
            my (@first, @min, $which, $first1, $intersection);
            SEARCH: while ($retry_count++ < $max_intersection_depth) {
                return undef unless defined $parent[0];
                return undef unless defined $parent[1];
                @{$first[0]} = $parent[0]->first;
                @{$first[1]} = $parent[1]->first;
                unless ( defined $first[0][0] ) {
                    # warn "don't know first of $method";
                    $self->trace_close( arg => 'undef' ) if $TRACE;
                    return undef;
                }
                unless ( defined $first[1][0] ) {
                    # warn "don't know first of $method";
                    $self->trace_close( arg => 'undef' ) if $TRACE;
                    return undef;
                }
                @{$min[0]} = $first[0][0]->min_a;
                @{$min[1]} = $first[1][0]->min_a;
                unless ( defined $min[0][0] && defined $min[1][0] ) {
                    return undef;
                } 
                # $which is the index to the bigger "first".
                $which = ($min[0][0] < $min[1][0]) ? 1 : 0;  
                for my $which1 ( $which, 1 - $which ) {
                  my $tmp_parent = $parent[$which1];
                  ($first1, $parent[$which1]) = @{ $first[$which1] };
                  if ( $first1->is_null ) {
                    # warn "first1 empty! count $retry_count";
                    # trace_close;
                    # return $first1, undef;
                    $intersection = $first1;
                    $which = $which1;
                    last SEARCH;
                  }
                  $intersection = $first1->intersection( $parent[1-$which1] );
                  # warn "intersection with $first1 is $intersection";
                  unless ( $intersection->is_null ) { 
                    # $self->trace( title=>"got an intersection" );
                    if ( $intersection->is_too_complex ) {
                        $parent[$which1] = $tmp_parent;
                    }
                    else {
                        $which = $which1;
                        last SEARCH;
                    }
                  };
                }
            }
            if ( $#{ $intersection->{list} } > 0 ) {
                my $tail;
                ($intersection, $tail) = $intersection->first;
                $parent[$which] = $parent[$which]->union( $tail );
            }
            my $tmp;
            if ( defined $parent[$which] and defined $parent[1-$which] ) {
                $tmp = $parent[$which]->intersection ( $parent[1-$which] );
            }
            return ($intersection, $tmp);
        }, # end: first-intersection
    'union' =>
        sub {
            my $self = $_[0];
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
                $self->trace_close( arg => "@{$first[1]}" ) if $TRACE;
                return @{$first[1]}
            }
            unless ( defined $min[1][0] ) {
                $self->trace_close( arg => "@{$first[0]}" ) if $TRACE;
                return @{$first[0]}
            }

            my $which = ($min[0][0] < $min[1][0]) ? 0 : 1;
            my $first = $first[$which][0];

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
                my $method = $self->{method};
                $tail = $parent1->$method( $parent2 );
            }
            $self->trace_close( arg => "$first $tail" ) if $TRACE;
            return ($first, $tail);
        }, # end: first-union
    'iterate' =>
        sub {
            my $self = $_[0];
            my $parent = $self->{parent};
            my @first = $parent->first;
            $first[0] = $first[0]->iterate( @{$self->{param}} ) if ref($first[0]);
            $first[1] = $first[1]->_function( 'iterate', @{$self->{param}} ) if ref($first[1]);
            return @first;
        },
    'until' =>
        sub {
            my $self = $_[0];
            my ($a1, $b1) = @{ $self->{parent} };
            $a1->trace( title=>"computing first()" );
            my @first1 = $a1->first;
            my @first2 = $b1->first;
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
            return ($first, $tail);
        },
    'offset' =>
        sub {
            my $self = $_[0];
            my ($first, $tail) = $self->{parent}->first;
            $first = $first->offset( @{$self->{param}} );
            $tail  = $tail->_function( 'offset', @{$self->{param}} );
            my $more;
            ($first, $more) = $first->first;
            $tail = $tail->_function2( 'union', $more ) if defined $more;
            return ($first, $tail);
        },
    'quantize' =>
        sub {
            my $self = $_[0];
            my @min = $self->{parent}->min_a;
            if ( $min[0] == $neg_inf || $min[0] == $inf ) {
                return ( $self->new( $min[0] ) , $self->copy );
            }
            my $first = $self->new( $min[0] )->quantize( @{$self->{param}} );
            return ( $first,
                     $self->{parent}->
                        _function2( 'intersection', $first->complement )->
                        _function( 'quantize', @{$self->{param}} ) );
        },
    'tolerance' =>
        sub {
            my $self = $_[0];
            my ($first, $tail) = $self->{parent}->first;
            $first = $first->tolerance( @{$self->{param}} );
            $tail  = $tail->tolerance( @{$self->{param}} );
            return ($first, $tail);
        },
  );  # %_first

  %_last = (
    'complement' =>
        sub {
            my $self = $_[0];
            my @parent_max = $self->{parent}->last;
            unless ( defined $parent_max[0] ) {
                return (undef, 0);
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
            my @no_tail = $self->new($next[0], $inf);
            $no_tail[0]->{list}[-1]{open_begin} = $next[1];
            my $tail = $parent->union($no_tail[-1])->complement;
            return ($last, $tail);
        },
    'intersection' =>
        sub {
            my $self = $_[0];
            my @parent = @{ $self->{parent} };
            # TODO: check max1/max2 for undef

            my $retry_count = 0;
            my (@last, @max, $which, $last1, $intersection);

            SEARCH: while ($retry_count++ < $max_intersection_depth) {
                return undef unless defined $parent[0];
                return undef unless defined $parent[1];

                @{$last[0]} = $parent[0]->last;
                @{$last[1]} = $parent[1]->last;
                unless ( defined $last[0][0] ) {
                    $self->trace_close( arg => 'undef' ) if $TRACE;
                    return undef;
                }
                unless ( defined $last[1][0] ) {
                    $self->trace_close( arg => 'undef' ) if $TRACE;
                    return undef;
                }
                @{$max[0]} = $last[0][0]->max_a;
                @{$max[1]} = $last[1][0]->max_a;
                unless ( defined $max[0][0] && defined $max[1][0] ) {
                    $self->trace( title=>"can't find max()" ) if $TRACE;
                    $self->trace_close( arg => 'undef' ) if $TRACE;
                    return undef;
                }

                # $which is the index to the smaller "last".
                $which = ($max[0][0] > $max[1][0]) ? 1 : 0;

                for my $which1 ( $which, 1 - $which ) {
                  my $tmp_parent = $parent[$which1];
                  ($last1, $parent[$which1]) = @{ $last[$which1] };
                  if ( $last1->is_null ) {
                    $which = $which1;
                    $intersection = $last1;
                    last SEARCH;
                  }
                  $intersection = $last1->intersection( $parent[1-$which1] );

                  unless ( $intersection->is_null ) {
                    # $self->trace( title=>"got an intersection" );
                    if ( $intersection->is_too_complex ) {
                        $self->trace( title=>"got a too_complex intersection" ) if $TRACE; 
                        # warn "too complex intersection";
                        $parent[$which1] = $tmp_parent;
                    }
                    else {
                        $self->trace( title=>"got an intersection" ) if $TRACE;
                        $which = $which1;
                        last SEARCH;
                    }
                  };
                }
            }
            $self->trace( title=>"exit loop" ) if $TRACE;
            if ( $#{ $intersection->{list} } > 0 ) {
                my $tail;
                ($intersection, $tail) = $intersection->last;
                $parent[$which] = $parent[$which]->union( $tail );
            }
            my $tmp;
            if ( defined $parent[$which] and defined $parent[1-$which] ) {
                $tmp = $parent[$which]->intersection ( $parent[1-$which] );
            }
            return ($intersection, $tmp);
        },
    'union' =>
        sub {
            my $self = $_[0];
            my (@last, @max);
            my @parent = @{ $self->{parent} };
            @{$last[0]} = $parent[0]->last;
            @{$last[1]} = $parent[1]->last;
            @{$max[0]} = $last[0][0]->max_a;
            @{$max[1]} = $last[1][0]->max_a;
            unless ( defined $max[0][0] ) {
                return @{$last[1]}
            }
            unless ( defined $max[1][0] ) {
                return @{$last[0]}
            }

            my $which = ($max[0][0] > $max[1][0]) ? 0 : 1;
            my $last = $last[$which][0];
            # find out the tail
            my $parent1 = $last[$which][1];
            # warn $self->{parent}[$which]." - $last = $parent1";
            my $parent2 = ($max[0][0] == $max[1][0]) ?
                $self->{parent}[1-$which]->complement($last) :
                $self->{parent}[1-$which];
            my $tail;
            if (( ! defined $parent1 ) || $parent1->is_null) {
                $tail = $parent2;
            }
            else {
                my $method = $self->{method};
                $tail = $parent1->$method( $parent2 );
            }
            return ($last, $tail);
        },
    'until' =>
        sub {
            my $self = $_[0];
            my ($a1, $b1) = @{ $self->{parent} };
            $a1->trace( title=>"computing last()" );
            my @last1 = $a1->last;
            my @last2 = $b1->last;
            my ($last, $tail);
            if ( $last2[0] <= $last1[0] ) {
                # added ->last because it returns 2 spans if $a1 == $a2
                $last = $last2[0]->until( $a1 )->last;
                $tail = $a1->_function2( "until", $last2[1] );
            }
            else {
                $last = $a1->new( $last1[0] )->until( $last2[0] );
                if ( defined $last1[1] ) {
                    $tail = $last1[1]->_function2( "until", $last2[1] );
                }
                else {
                    $tail = undef;
                }
            }
            return ($last, $tail);
        },
    'iterate' =>
        sub {
            my $self = $_[0];
            my $parent = $self->{parent};
            my @last = $parent->last;
            $last[0] = $last[0]->iterate( @{$self->{param}} ) if ref($last[0]);
            $last[1] = $last[1]->_function( 'iterate', @{$self->{param}} ) if ref($last[1]);
            return @last;
        },
    'offset' =>
        sub {
            my $self = $_[0];
            my ($last, $tail) = $self->{parent}->last;
            $last = $last->offset( @{$self->{param}} );
            $tail  = $tail->_function( 'offset', @{$self->{param}} );
            my $more;
            ($last, $more) = $last->last;
            $tail = $tail->_function2( 'union', $more ) if defined $more;
            return ($last, $tail);
        },
    'quantize' =>
        sub {
            my $self = $_[0];
            my @max = $self->{parent}->max_a;
            if (( $max[0] == $neg_inf ) || ( $max[0] == $inf )) {
                return ( $self->new( $max[0] ) , $self->copy );
            }
            my $last = $self->new( $max[0] )->quantize( @{$self->{param}} );
            if ($max[1]) {  # open_end
                    if ( $last->min <= $max[0] ) {
                        $last = $self->new( $last->min - 1e-9 )->quantize( @{$self->{param}} );
                    }
            }
            return ( $last, $self->{parent}->
                        _function2( 'intersection', $last->complement )->
                        _function( 'quantize', @{$self->{param}} ) );
        },
    'tolerance' =>
        sub {
            my $self = $_[0];
            my ($last, $tail) = $self->{parent}->last;
            $last = $last->tolerance( @{$self->{param}} );
            $tail  = $tail->tolerance( @{$self->{param}} );
            return ($last, $tail);
        },
  );  # %_last
} # BEGIN

sub first {
    my $self = $_[0];
    unless ( exists $self->{first} ) {
        $self->trace_open(title=>"first") if $TRACE;
        if ( $self->{too_complex} ) {
            my $method = $self->{method};
            # warn "method $method ". ( exists $_first{$method} ? "exists" : "does not exist" );
            if ( exists $_first{$method} ) {
                @{$self->{first}} = $_first{$method}->($self);
            }
            else {
                my $redo = $self->{parent}->$method ( @{ $self->{param} } );
                @{$self->{first}} = $redo->first;
            }
        }
        else {
            return $self->SUPER::first;
        }
    }
    return wantarray ? @{$self->{first}} : $self->{first}[0];
}


sub last {
    my $self = $_[0];
    unless ( exists $self->{last} ) {
        $self->trace(title=>"last") if $TRACE;
        if ( $self->{too_complex} ) {
            my $method = $self->{method};
            if ( exists $_last{$method} ) {
                @{$self->{last}} = $_last{$method}->($self);
            }
            else {
                my $redo = $self->{parent}->$method ( @{ $self->{param} } );
                @{$self->{last}} = $redo->last;
            }
        }
        else {
            return $self->SUPER::last;
        }
    }
    return wantarray ? @{$self->{last}} : $self->{last}[0];
}


# offset: offsets subsets
sub offset {
    my $self = shift;
    if ($self->{too_complex}) {
        return $self->_function( 'offset', @_ );
    }
    $self->trace_open(title=>"offset") if $TRACE;

    my @a;
    my %param = @_;
    my $b1 = $self->new();    
    my ($interval, $ia, $i);
    $param{mode} = 'offset' unless $param{mode};

    # optimization for 1-parameter offset
    if (($param{mode} eq 'begin') and ($#{$param{value}} == 1) and
        ($param{value}[0] == $param{value}[1]) and
        ($param{value}[0] == 0) ) {
            # offset == zero
            $b1->{list} = [ 
                 map { { a => $_->{a} , b => $_->{a},
                         open_begin => 0 , open_end => 0 
                       } }  @{ $self->{list} } ];
            $b1->{cant_cleanup} = 1;
            $self->trace_close( arg => $b1 ) if $TRACE;
            return $b1;
    }

    unless (ref($param{value}) eq 'ARRAY') {
        $param{value} = [0 + $param{value}, 0 + $param{value}];
    }
    $param{unit} =    'one'  unless $param{unit};
    my $parts    =    ($#{$param{value}}) / 2;
    my $sub_unit =    $Set::Infinite::Arithmetic::subs_offset2{$param{unit}};
    my $sub_mode =    $Set::Infinite::Arithmetic::_MODE{$param{mode}};

    carp "unknown unit $param{unit} for offset()" unless defined $sub_unit;
    carp "unknown mode $param{mode} for offset()" unless defined $sub_mode;

    my ($j);
    my ($cmp, $this, $next, $ib, $part, $open_begin, $open_end, $tmp);

    my @value;
    foreach $j (0 .. $parts) {
        push @value, [ $param{value}[$j+$j], $param{value}[$j+$j + 1] ];
    }

    foreach $interval ( @{ $self->{list} } ) {
        $ia =         $interval->{a};
        $ib =         $interval->{b};
        $open_begin = $interval->{open_begin};
        $open_end =   $interval->{open_end};
        foreach $j (0 .. $parts) {
            # print " [ofs($ia,$ib)] ";
            ($this, $next) = $sub_mode->( $sub_unit, $ia, $ib, @{$value[$j]} );
            next if ($this > $next);    # skip if a > b
            if ($this == $next) {
                $open_end = $open_begin;
            }
            # skip this if don't need to "fixtype"
            if ($self->{fixtype}) {
                # bless results into 'type' class
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
    $self->trace_close( arg => $b1 ) if $TRACE;
    return $b1;
}


sub is_null {
    $_[0]->{too_complex} ? 0 : $_[0]->SUPER::is_null;
}


sub is_too_complex {
    $_[0]->{too_complex} ? 1 : 0;
}


# shows how a 'compacted' set looks like after quantize
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
            $self->trace_close( arg => $res ) if $TRACE;
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


sub _backtrack {
    my ($self, $method, $arg) = @_;
    return $self->$method ($arg) unless $self->{too_complex};
    $self->trace_open( title => 'backtrack '.$self->{method} ) if $TRACE;

    $backtrack_depth++;
    if ($backtrack_depth > $max_backtrack_depth) {
        carp (__PACKAGE__ . ": Backtrack too deep (more than " . $max_backtrack_depth . " levels)");
    }

    # backtrack on parent sets
    if (ref($self->{parent}) eq 'ARRAY') {
        # has 2 parents (intersection, union, until ...)
        # data structure: {method} - method name, {parent} - array, parent list

        $self->trace( title=>"array - method is $method" );
        if ($self->{method} eq 'until') {
            my $before = $self->{parent}[0]->intersection( $neg_inf, $arg->min )->max;
            $before = $arg->min unless $before;
            my $after = $self->{parent}[1]->intersection( $arg->max, $inf )->min;
            $after = $arg->max unless $after;
            $arg = $arg->new( $before, $after );
        }

        my $result1 = $self->{parent}[0];
        $result1 = $result1->_backtrack($method, $arg) if $result1->{too_complex};
        my $result2 = $self->{parent}[1];
        $result2 = $result2->_backtrack($method, $arg) if $result2->{too_complex};
        if ( $result1->{too_complex} or $result2->{too_complex} ) {
            # backtrack failed...
            $backtrack_depth--;
            $self->trace_close( arg => $self ) if $TRACE;
            # return the simplified version
            return $result1->_function2( $self->{method}, $result2 );
        }

        # apply {method}
        my $method = $self->{method};
        my $result = $result1->$method ($result2);

        $backtrack_depth--;
        $self->trace_close( arg => $result ) if $TRACE;
        return $result;
    }  # parent is ARRAY

    # has 1 parent and parameters (offset, select, quantize)
    # data structure: {method} - method name, {param} - array, param list

    my $result1 = $self->{parent};
    my @param = @{$self->{param}};
    my $my_method = $self->{method};
    my $backtrack_arg2 = $arg;

    # quantize() and offset() require special treatment because 
    # they may result in weird min/max values

    if ($my_method eq 'quantize') {
        if ($arg->{too_complex}) {
            $backtrack_arg2 = $arg;
        }
        else {
            $backtrack_arg2 = $arg->quantize(@param)->_quantize_span;
        }
    }
    elsif ($my_method eq 'offset') {
        # offset - apply offset with negative values
        my %tmp = @param;
        my @values = sort @{$tmp{value}};

        $backtrack_arg2 = $arg->offset( unit => $tmp{unit}, mode => $tmp{mode}, value => [- $values[-1], - $values[0]] );

        $backtrack_arg2 = $arg->union( $backtrack_arg2 );   # fixes some problems with 'begin' mode
    }

    $result1 = $result1->_backtrack($method, $backtrack_arg2); 
    $method = $self->{method};
    my $result = $result1->$method (@param);
    $backtrack_depth--;
    $self->trace_close( arg => $result ) if $TRACE;
    return $result;
}


sub intersects {
    my $a = shift;
    my $b;
    if (ref ($_[0]) eq ref($a) ) { 
        $b = shift;
    } 
    else {
        $b = $a->new(@_);  
    }
    $a->trace(title=>"intersects");
    if ($a->{too_complex}) {
        $a = $a->_backtrack('intersection', $b);
    }  # don't put 'else' here
    if ($b->{too_complex}) {
        $b = $b->_backtrack('intersection', $a);
    }
    if (($a->{too_complex}) or ($b->{too_complex})) {
        return undef;   # we don't know the answer!
    }
    return $a->SUPER::intersects( $b );
}


sub iterate {
    my $self = shift;
    if ($self->{too_complex}) {
        $self->trace(title=>"iterate:backtrack") if $TRACE;
        return $self->_function( 'iterate', @_ );
    }
    $self->trace(title=>"iterate") if $TRACE;
    return $self->SUPER::iterate( @_ );
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
        $a1 = $a1->_backtrack('intersection', $b1) unless $b1->{too_complex};
    }  # don't put 'else' here
    if ($b1->{too_complex}) {
        $b1 = $b1->_backtrack('intersection', $a1) unless $a1->{too_complex};
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
    if (($a1->{too_complex}) or ($b1->{too_complex})) {
        return $a1->_function2( 'until', $b1 );
    }
    return $a1->SUPER::until( $b1 );
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
    my $self = $_[0];
    return @{$self->{min}} if exists $self->{min};
    if ($self->{too_complex}) {
        my @first = $self->first;
        return @{$self->{min}} = $first[0]->min_a if defined $first[0];
        return @{$self->{min}} = (undef, 0);
    }
    return $self->SUPER::min_a;
};


sub max_a { 
    my $self = $_[0];
    return @{$self->{max}} if exists $self->{max};
    if ($self->{too_complex}) {
        my @last = $self->last;
        return @{$self->{max}} = $last[0]->max_a if defined $last[0];
        return @{$self->{max}} = (undef, 0);
    }
    return $self->SUPER::max_a;
};


sub count {
    my $self = $_[0];
    return $inf if $self->{too_complex};
    return $self->SUPER::count;
}


sub size { 
    my $self = $_[0];
    if ($self->{too_complex}) {
        my @min = $self->min_a;
        my @max = $self->max_a;
        return undef unless defined $max[0] && defined $min[0];
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


sub _cleanup {
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
        return $self->SUPER::tolerance( $tmp );
    }
    # global
    __PACKAGE__->SUPER::tolerance( $tmp ) if defined($tmp);
    return __PACKAGE__->SUPER::tolerance;   
}


sub _pretty_print {
    my $self = shift;
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
    $self->_cleanup;
    return $self->SUPER::as_string;
}


sub DESTROY {}

1;

__END__


=head1 NAME

Set::Infinite - Sets of intervals

=head1 SYNOPSIS

  use Set::Infinite;

  $a = Set::Infinite->new(1,2);    # [1..2]
  print $a->union(5,6);            # [1..2],[5..6]

=head1 DESCRIPTION

Set::Infinite is a Set Theory module for infinite sets.

It works with reals, integers, and objects (such as dates).


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

See also: C<count>.

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

default is none (a normal Perl SCALAR).


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

        Returns an ordered set of equal-sized subsets.

        Example: 

            $a = Set::Infinite->new([1,3]);
            print join (" ", $a->quantize( quant => 1 ) );

        Gives: 

            [1..2) [2..3) [3..4)

=head2 select

    select( parameters )

Selects set members based on their ordered positions

C<select> has a behaviour similar to an array C<slice>.

            by       - default=All
            count    - default=Infinity

 0  1  2  3  4  5  6  7  8      # original set
 0  1  2                        # count => 3 
    1              6            # by => [ -2, 1 ]

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

In scalar context returns the first or last interval of a set.

In list context returns the first or last interval of a set, 
and the remaining set (the 'tail').

=head2 type

    type($i)

Chooses a default object data type. 

default is none (a normal perl SCALAR).


=head1 INTERNAL FUNCTIONS

=head2 _cleanup

    $a->_cleanup;

Internal function to fix the internal set representation.
This is used after operations that might return invalid
values.

=head2 _backtrack

    $a->_backtrack( 'intersection', $b );

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

See modules DateTime::Set, DateTime::Event::Recurrence, and
DateTime::Event::ICal for up-to-date information on date-sets.

C<DateTime::Set>

The perl-date-time project <http://datetime.perl.org> 


=head1 AUTHOR

Flavio Soibelmann Glock <fglock@pucrs.br>

=head1 COPYRIGHT

Copyright (c) 2003 Flavio Soibelmann Glock.  All rights reserved.  
This program is free software; you can redistribute it and/or modify 
it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included
with this module.

=cut

