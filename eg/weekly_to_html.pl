#!/perl

use Set::Infinite;
Set::Infinite::type('Set::Infinite::Date');

@evento = ();
@horario = ();
@sala = ();
$n = -1;

$filename = './schedule.dat';
$filename = './eg/schedule.dat' unless -e $filename;
$data_inicial = '2001-04';

($ano, $mes) = $data_inicial =~ /(\d*)[-\/](\d*)/;

print "<body bgcolor=lightyellow>\n";
print "<h2><center>Planilha $mes/$ano</center></h2>\n";

open(FILE, "<$filename") or print " ERROR! $filename ";
foreach(<FILE>) {
	if (/event:\s+(.*)$/) {
		$n++;
		$evento[$n] = $1;
		$horario[$n] = Set::Infinite->new();
	}
	elsif (/room:\s+(.*?)\s*$/) { 
		$sala[$n] = $1; 
	}
	elsif (/hour:\s+(.*)\.\.(.*)$/) {
		$horario[$n] = $horario[$n]->union($1,$2);
	}
}

close(FILE);

($horario_mes) = Set::Infinite->new("$ano-$mes-01")->quantize('months', 1)->list;

print "<table border=1>";
print "<tr>";
	foreach (1..7) {
			print "<td><pre>";
			print $_;
			print "</td>\n";
	}
print "</tr>\n";

Set::Infinite::Date::date_format("day");

foreach $week ( $horario_mes->quantize('weeks', 1)->list ) {
	if ($week) {
		print "<tr>";
		foreach $dia ( $week->quantize('days', 1)->list ) {
			if ($dia) {
				print "<td valign=top><b>",$dia->{a},"</b><br>";
				foreach $curso (0 .. $n) {
					if ($horario[$curso]->intersects($dia)) {
						print "x";
					}
				}
				print "</td>\n";
			}
		} # days
		print "</tr>\n";
	}
} # weeks
print "</table>";
print "</body>";

1;
