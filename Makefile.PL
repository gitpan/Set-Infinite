use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'ABSTRACT'          => 'Infinite Sets math',
    'AUTHOR'            => 'Flavio S. Glock - fglock@pucrs.br',
    'NAME'      		=> 'Set::Infinite',
    'VERSION_FROM'  	=> 'lib/Set/Infinite.pm', 
    'EXCLUDE_EXT'       => 'Makefile gz LOG',
    'PREREQ_PM'         => { 'HTTP::Date' => 0, 'Time::Local' => 0 },
    'dist'          	=> { 'COMPRESS' => 'gzip' },
);

