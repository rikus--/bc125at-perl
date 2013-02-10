#!/usr/bin/perl

use ExtUtils::MakeMaker;

use lib 'lib';
use Bc125At::Version;

WriteMakefile(
    NAME      => 'Bc125At',
    VERSION   => $Bc125At::Version::version,
    PMLIBDIRS => ['lib'],
    EXE_FILES => ['bc125at-perl'],
    PREREQ_PM => {
        'Device::SerialPort' => '0',
        'Gtk2'               => '0',
    },
);

