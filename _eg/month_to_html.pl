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

# $filename = shift unless $filename;
# $data_inicial = shift unless $data_inicial;

($ano, $mes) = $data_inicial =~ /(\d*)[-\/](\d*)/;

print "<body bgcolor=lightyellow>\n";
print "<h2><center>Planilha $mes/$ano</center></h2>\n";

open(FILE, "<$filename") or print " ERROR! $filename ";
foreach(<FILE>) {
	if (/event:\s+(.*)$/) {
		$n++;
		$evento[$n] = $1;
		$horario[$n] = Set::Infinite->new();
		$colisao[$n] = Set::Infinite->new();
	}
	elsif (/room:\s+(.*?)\s*$/) { 
		$sala[$n] = $1; 
	}
	elsif (/hour:\s+(.*)\.\.(.*)$/) {
		$horario[$n] = $horario[$n]->union($1,$2);
	}
}

print "<PRE>";
Set::Infinite::Date::date_format("year-month-day hour:min");
foreach $i ( 0 .. $n ) {
	foreach $j ( $i + 1 .. $n ) {
		if (($sala[$i] eq $sala[$j]) and ($horario[$i]->intersects($horario[$j]))) {
			$tmp = $horario[$i]->intersection($horario[$j]);

			$colisao[$i] = $colisao[$i]->union($tmp);
			$colisao[$j] = $colisao[$j]->union($tmp);

			print "Colisao:      sala $sala[$i]\n";
			print "    evento:   $evento[$i]\n";
			print "    evento:   $evento[$j]\n";
			print "    horarios: $tmp\n";
		}
	}
}
close(FILE);
print "</PRE>";

# timetable

($horario_mes) = Set::Infinite->new("$ano-$mes-01")->quantize('months', 1)->list;
@horario_dia   = $horario_mes->quantize('days', 1)->list;

print "<table border=1>";

	# table header
	Set::Infinite::Date::date_format("day");
	print "<tr>";
		print "<td>";
		print "&nbsp;";
		print "</td>";
	foreach $dia (@horario_dia) {
		if ($dia) {
			print "<td><pre>";
			print $dia->{a};
			print "</td>\n";
		}
	}
	print "</tr>\n";

	# table lines
	foreach $curso (0 .. $n) {
	if ($horario[$curso]->intersects($horario_mes)) {
		print "<tr>";
		print "<td><pre>";
		print "$evento[$curso]";
		print "</td>";

		foreach $dia (@horario_dia) {
		  if ($dia) {
			if ($horario[$curso]->intersects($dia)) {
				# pinta
				if ($colisao[$curso]->intersects($dia)) {
					# colisao
					print "<td bgcolor=orange><pre>X</td>";
				}
				else {
					# confirmado
					print "<td bgcolor=blue><pre>C</td>";
				}
			}
			else {
				# nao pinta
				print "<td>&nbsp;</td>";
			}
		  }
		}
		print "</tr>\n";
	}
	}
print "</table>";
print "</body>\n";

1;
