use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Set::Infinite',
    'VERSION_FROM'	=> 'lib/Set/Infinite.pm', 
    'dist'         	=> { 'COMPRESS' => 'gzip' },
);
