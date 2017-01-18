#!/bin/bash
# Author:  Seon <seeuseon AT gmail.com>
# BLOG:  https://seon.me

jemalloc_version=4.4.0
THREAD=$(grep 'processor' /proc/cpuinfo | sort -u | wc -l)

wget -c https://github.com/jemalloc/jemalloc/releases/download/$jemalloc_version/jemalloc-$jemalloc_version.tar.bz2
tar xjf jemalloc-$jemalloc_version.tar.bz2

pushd jemalloc-$jemalloc_version
./configure
make -j$THREAD
make install

echo '/usr/local/lib' > /etc/ld.so.conf.d/local.conf
ldconfig
popd
rm -rf jemalloc-$jemalloc_version
rm -rf jemalloc-$jemalloc_version.tar.bz2
echo "Jemalloc installed successfully!"
