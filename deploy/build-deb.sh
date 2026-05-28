#!/bin/bash -e
#
# Build a binary or (no arch)  .deb package
#
test $(id -u) == "0" || (echo "Run as root" && exit 1) # requires bash -e

#
# The package name
#
name=jamcrest
arch=$(uname -m)

cd $(dirname $0)/..
project_root=$PWD

#
# Create a temporary build directory
#
tmp_dir=/tmp/$name-debbuild
rm -rf $tmp_dir
mkdir -p $tmp_dir/DEBIAN $tmp_dir/usr/bin

. ./version
sed -e "s/@PACKAGE_VERSION@/$VERSION/" $project_root/deploy/DEBIAN/control.in > $tmp_dir/DEBIAN/control
cp -v target/jamcrest $tmp_dir/usr/bin/

size=$(du -sk $tmp_dir | cut -f 1)
sed -i -e "s/@SIZE@/$size/" $tmp_dir/DEBIAN/control

cp --archive -R $project_root/deploy/DEBIAN/p* $tmp_dir/DEBIAN

#
# setup conffiles
#
(
  cd $tmp_dir/
  find etc -type f | sed 's.^./.' > DEBIAN/conffiles
)

#
# Setup the installation package ownership here if it needs root
#
#chown -R root.root $tmp_dir/*
#chown root.root $tmp_dir/usr/bin/* 
#chown root.root \
#  $tmp_dir/root \
#  $tmp_dir/home \
#  $tmp_dir/usr/bin $tmp_dir/usr \

#
# Build the .deb
#
mkdir -p target/
dpkg-deb --build $tmp_dir target/$name-$VERSION-1.$arch.deb

test -f target/$name-$VERSION-1.$arch.deb

echo "built target/$name-$VERSION-1.$arch.deb"

if [ -n "$SUDO_USER" ]
then
  chown $SUDO_USER target/ target/$name-$VERSION-1.$arch.deb
fi

# test -d $tmp_dir && rm -rf $tmp_dir
