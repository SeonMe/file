#!/bin/bash

mkdir -p nginx && cd nginx

pkglist="build-essential autoconf libtool automake unzip"
for package in ${pkglist}; do
  apt-get install -y ${package}

id -u www >/dev/null 2>&1
  [ $? -ne 0 ] && useradd -M -s /sbin/nologin www

[ ! -d "/usr/local/nginx" ] && mkdir -p /usr/local/nginx
[ ! -d "/data/wwwroot" ] && mkdir -p /data/wwwroot
[ ! -d "/data/wwwlogs" ] && mkdir -p /data/wwwlogs

nginx_version=1.12.1
pcre_version=8.41
openssl_version=1_0_2l
luajit_version=2.1.0-beta3
nginx_ct_version=1.3.2

wget -c https://nginx.org/download/nginx-${nginx_version}.tar.gz && tar zxf nginx-${nginx_version}.tar.gz
wget -c https://sourceforge.net/projects/pcre/files/pcre/${pcre_version}/pcre-${pcre_version}.tar.gz && tar zxf pcre-${pcre_version}.tar.gz
wget -c https://github.com/openssl/openssl/archive/OpenSSL_${openssl_version}.tar.gz && tar zxf OpenSSL_${openssl_version}.tar.gz && mv openssl-OpenSSL_${openssl_version} openssl-${openssl_version}
wget -c https://github.com/grahamedgecombe/nginx-ct/archive/v${nginx_ct_version}.zip && unzip v${nginx_ct_version}.zip

git clone https://github.com/bagder/libbrotli
cd libbrotli && ./autogen.sh && ./configure
make && make install && cd ../

git clone https://github.com/google/ngx_brotli.git
cd ngx_brotli && git submodule update --init
cd ../

wget -c http://luajit.org/download/LuaJIT-${luajit_version}.zip && unzip LuaJIT-${luajit_version}.zip
cd LuaJIT-${luajit_version} && make && make install && cd ../

export LUAJIT_LIB=/usr/local/lib
export LUAJIT_INC=/usr/local/include/luajit-2.1

git clone https://github.com/simpl/ngx_devel_kit.git
git clone https://github.com/openresty/lua-nginx-module.git

cd nginx-${nginx_version}
./configure --prefix=/usr/local/nginx \
	--user=www --group=www \
	--with-http_stub_status_module \
	--with-http_v2_module \
	--with-http_ssl_module \
	--with-http_realip_module \
	--with-http_flv_module \
	--with-http_mp4_module \
	--with-openssl=../openssl-${openssl_version} \
	--with-pcre=../pcre-${pcre_version} \
	--with-pcre-jit \
	--with-ld-opt="-ljemalloc" \
	--add-module=../ngx_brotli \
	--add-module=../nginx-ct-${nginx_ct_version} \
	--add-module=../lua-nginx-module \
	--add-module=../ngx_devel_kit \
	--with-ld-opt="-Wl,-rpath,/usr/local/lib/" \
	--without-http_gzip_module
make -j2 && make install && cd ../

[ -z "`grep ^'export PATH=' /etc/profile`" ] && echo "export PATH=/usr/local/nginx/sbin:\$PATH" >> /etc/profile
[ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep /usr/local/nginx /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=/usr/local/nginx/sbin:\1@" /etc/profile
. /etc/profile

git clone https://github.com/SeonMe/file.git
/bin/cp file/Nginx-init /etc/init.d/nginx && chmod +x /etc/init.d/nginx && update-rc.d nginx defaults

sed -i "s@/usr/local/nginx@/usr/local/nginx@g" /etc/init.d/nginx

mv /usr/local/nginx/conf/nginx.conf{,_bk}
/bin/cp file/nginx.conf /usr/local/nginx/conf/nginx.conf

cat > /usr/local/nginx/conf/proxy.conf << EOF
proxy_connect_timeout 300s;
proxy_send_timeout 900;
proxy_read_timeout 900;
proxy_buffer_size 32k;
proxy_buffers 4 64k;
proxy_busy_buffers_size 128k;
proxy_redirect off;
proxy_hide_header Vary;
proxy_set_header Accept-Encoding '';
proxy_set_header Referer \$http_referer;
proxy_set_header Cookie \$http_cookie;
proxy_set_header Host \$host;
proxy_set_header X-Real-IP \$remote_addr;
proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
EOF

sed -i "s@/data/wwwroot/default@/data/wwwroot/default@" /usr/local/nginx/conf/nginx.conf
sed -i "s@/data/wwwlogs@/data/wwwlogs@g" /usr/local/nginx/conf/nginx.conf
sed -i "s@^user www www@user www www@" /usr/local/nginx/conf/nginx.conf

cat > /etc/logrotate.d/nginx << EOF
/data/wwwlogs/*nginx.log {
  daily
  rotate 5
  missingok
  dateext
  compress
  notifempty
  sharedscripts
  postrotate
  [ -e /var/run/nginx.pid ] && kill -USR1 \`cat /var/run/nginx.pid\`
  endscript
}
EOF

 ldconfig

cd ../ && rm -rf nginx

service nginx start
