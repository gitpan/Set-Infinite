#!/bin/perl
`cat lib/Set/Infinite.pm | pod2html > Set-Infinite.html`;
print "Check that you have pod2html in your path\n" unless -s 'Set-Infinite.html';
