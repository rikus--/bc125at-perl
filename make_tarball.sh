#!/bin/sh

version=`perl -Ilib -MBc125At::Version -e 'print "$Bc125At::Version::version\n"'`

mkdir ../tarballs 2>/dev/null

if [ -e ../tarballs/bc125at-perl-$version -o -e ../tarballs/bc125at-perl-$version.tar.gz ]; then
    echo $version tarball already exists
    exit 1
fi
mkdir -p ../tarballs/bc125at-perl-$version/{lib,t}
mkdir -p ../tarballs/bc125at-perl-$version/lib/Bc125At/GUI
mkdir -p ../tarballs/bc125at-perl-$version/driver-helper
cp -pf README LICENSE ChangeLog MANIFEST Makefile.PL ../tarballs/bc125at-perl-$version/
cp -pf bc125at-perl ../tarballs/bc125at-perl-$version/
cp -pf lib/*.pm ../tarballs/bc125at-perl-$version/lib/
cp -pf lib/Bc125At/*.pm ../tarballs/bc125at-perl-$version/lib/Bc125At/
cp -pf lib/Bc125At/GUI/*.pm ../tarballs/bc125at-perl-$version/lib/Bc125At/GUI/
cp -pf t/*.t ../tarballs/bc125at-perl-$version/t/
cp -pf driver-helper/{Makefile,bc125at-perl-driver-helper.c} ../tarballs/bc125at-perl-$version/driver-helper

cd ../tarballs
tar zcvpf bc125at-perl-$version.tar.gz bc125at-perl-$version
