
use Set::Infinite;
Set::Infinite::type('Set::Infinite::Date');

$filename = './schedule.dat';
$filename = './eg/schedule.dat' unless -e $filename;
open (FILE, $filename);

@event = ();
@schedule = ();
@room = ();
$n = -1;

# $last_event = '';

foreach(<FILE>) {
	if (/event:\s+(.*)$/) {
		# print "... $schedule[$n] \n";
		$n++;
		$event[$n] = $1;
		$schedule[$n] = Set::Infinite->new();
	}
	elsif (/room:\s+(.*)$/) { 
		$room[$n] = $1; 
	}
	elsif (/hour:\s+(.*)\.\.(.*)$/) {
		#print " event $event[$n] room $room[$n] Hour: $1 - $2\n";
		$schedule[$n] = $schedule[$n]->union($1,$2);
	}

}

# print "... $schedule[$n] \n";

foreach $i ( 0 .. $n ) {
	foreach $j ( $i + 1 .. $n ) {
		if (($room[$i] eq $room[$j]) and ($schedule[$i]->intersects($schedule[$j]))) {
			print "Two events scheduled at same time for room $room[$i]\n";
			print "\t$event[$i] and\n";
			print "\t$event[$j] at\n";
			print "\t", $schedule[$i]->intersection($schedule[$j]), "\n";
		}
	}
}

exit(0);
