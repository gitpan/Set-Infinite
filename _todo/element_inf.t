use Set::Infinite::Element_Inf qw(infinite);

print infinite,"\n";

print - infinite,"\n";

print 1 - infinite,"\n";

print 1 + infinite,"\n";

print &infinite - 1 ,"\n";

print + infinite - 1 ,"\n";

print - 1 + infinite ,"\n";

print + infinite + infinite ,"\n";

print + infinite - infinite,"\n";

print - infinite + infinite,"\n";

print - infinite - infinite,"\n";

@a = (
	1, 0, infinite,	3, 2, 0 - infinite, 5, 4, infinite
);

# print "Array", join(",", @a), "1,0,inf,3,2,-inf,5,4,inf","\n";
@b = sort @a;
print "Array", join(",", @b),"\n";