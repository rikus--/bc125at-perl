#!/usr/bin/perl

use ExtUtils::MakeMaker;

use lib 'lib';
use Bc125At::Version;

WriteMakefile(
    NAME      => 'Bc125At',
    VERSION   => $Bc125At::Version::version,
    PMLIBDIRS => ['Bc125At'],
    EXE_FILES => ['bc125at-perl'],
);
