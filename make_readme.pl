#!/bin/perl
`cat lib/Set/Infinite.pm | pod2text > README`;
print "Check that you have pod2text in your path\n" unless -s 'README';
