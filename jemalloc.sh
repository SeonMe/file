#!/bin/bash

version=5.0.1

apt-get install install build-essential

mkdir -p ./jemalloc && cd jemalloc
wget -c https://github.com/jemalloc/jemalloc/releases/download/${version}/jemalloc-${version}.tar.bz2
tar xjf jemalloc-${version}.tar.bz2
cd jemalloc-${version} && ./configure && make -j2 && make install

echo '/usr/local/lib' > /etc/ld.so.conf.d/local.conf
ldconfig
cd ../ && rm -rf jemalloc
echo "jemalloc installed successfully! "
