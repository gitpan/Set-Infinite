NAME

Set::Infinite - makes sets of intervals

INSTALLATION

	Copy contents of Set/ to perl/site/lib/Set/

SYNOPSIS

	use Set::Infinite;

	$a = Set::Infinite->new(1,2);
	print $a->union(5,6);

DESCRIPTION

Set::Infinite is a Set Theory module for infinite sets. 

It works on strings, reals or integers.
You can provide your own objects or let it make them for you
using the `type' method.

It works very well on dates, providing schedule checks (intersections)
and unions.

USAGE

	$a = Set::Infinite->new();
	$a = Set::Infinite->new(1);
	$a = Set::Infinite->new(1,2);
	$a = Set::Infinite->new($b);
	$a = Set::Infinite->new([1], [1,2], [$b]);

Mode functions:	

	$a->real;

	$a->integer;

Logic functions:

	$logic = $a->intersects($b);

	$logic = $a->contains($b);

Sets functions:

	$i = $a->union($b);	

	$i = $a->intersection($b);

	$i = $a->complement;
	$i = $a->complement($b);

	$i = $a->span;   

		result is INTERVAL, (min .. max)

	$a->add($b);   

		This is a short for:

		$a = $a->union($b);

Scalar functions:

	$i = $a->min;

	$i = $a->max;

	$i = $a->size;  

Perl functions:

	@b = sort @a;

	print $a;

Global functions:

	separators(@i)

		chooses the interval separators. 

		default are [ ] ( )  '..' ','

	null($i)		

		chooses 'null' name. default is 'null'

	infinite($i)

		chooses 'infinite' name. default is 'inf'

	infinite

		returns an 'infinite' number.

	minus_infinite

		returns '-infinite' number.

	null

		returns 'null'.

	type($i)

		chooses an object data type. 

		default is none (a normal perl SCALAR).

		examples: 

		type('Math::BigFloat');
		type('Math::BigInt');
		type('Set::Infinite::Date');

	tolerance(0)	defaults to real sets (default)
	tolerance(1)	defaults to integer sets

	real			defaults to real sets (default)

	integer			defaults to integer sets

Internal functions:

	$a->cleanup;

CAVEATS

	$a = Set::Infinite->new(1,2,3,4);
		Invalid: ",3,4" will be ignored. Use [1,2],[3,4] instead.

	$a = Set::Infinite->new(1..2);
		Invalid: "1..2" will be ignored. Use [1,2] instead.

AUTHOR

	Flavio Soibelmann Glock <fglock@pucrs.br>