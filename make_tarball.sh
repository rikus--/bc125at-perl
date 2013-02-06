#!/bin/sh

version=`perl -MBc125At::Version -e 'print "$Bc125At::Version::version\n"'`

mkdir ../tarballs 2>/dev/null

if [ -e ../tarballs/bc125at-perl-$version -o -e ../tarballs/bc125at-perl-$version.tar.gz ]; then
    echo already exists
    exit 1
fi
mkdir -p ../tarballs/bc125at-perl-$version/{Bc125At,t}
cp -pf README ChangeLog ../tarballs/bc125at-perl-$version/
cp -pf bc125at-perl ../tarballs/bc125at-perl-$version/
cp -pf Bc125At/*.pm ../tarballs/bc125at-perl-$version/Bc125At/
cp -pf t/*.t ../tarballs/bc125at-perl-$version/t/

cd ../tarballs
tar zcvpf bc125at-perl-$version.tar.gz bc125at-perl-$version
