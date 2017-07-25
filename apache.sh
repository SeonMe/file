#!/bin/bash
mkdir -p apache && cd apache

pkglist="build-essential libexpat1-dev"
for package in ${pkglist}; do
  apt-get -y install ${package}
done

pcre_version=8.41
nghttp2_version=1.24.0
apr_version=1.6.2
apr_util_version=1.6.0
httpd_version=2.4.27
openssl_version=1_0_2l

# Pcre
wget -c https://sourceforge.net/projects/pcre/files/pcre/${pcre_version}/pcre-${pcre_version}.tar.gz
tar zxf pcre-${pcre_version}.tar.gz
cd pcre-${pcre_version}
./configure && make -j2 && make install
cd ../

# openssl
if [ ! -e "/usr/local/openssl/lib/libcrypto.a" ]; then
  wget -c https://github.com/openssl/openssl/archive/OpenSSL_${openssl_version}.tar.gz && tar zxf OpenSSL_${openssl_version}.tar.gz
cd openssl-OpenSSL_${openssl_version}
make clean
./config --prefix=/usr/local/openssl -fPIC shared zlib-dynamic
make -j2 && make install
cd ../
if [ -f "/usr/local/openssl/lib/libcrypto.a" ]; then
  echo "openssl installed successfully!"
  wget -c http://curl.haxx.se/ca/cacert.pem
/bin/cp cacert.pem /usr/local/openssl/ssl/cert.pem
echo "/usr/local/openssl/lib" > /etc/ld.so.conf.d/openssl.conf
ldconfig
else
  echo "openssl install failed"
  kill -9 $$
fi
fi


# nghttp2
if [ ! -e "/usr/local/lib/libnghttp2.so" ]; then
  wget -c https://github.com/nghttp2/nghttp2/releases/download/v${nghttp2_version}/nghttp2-${nghttp2_version}.tar.gz
  tar zxf nghttp2-${nghttp2_version}.tar.gz
  cd nghttp2-${nghttp2_version}
  ./configure && make -j2 && make install
  cd ../
  echo '/usr/local/lib' > /etc/ld.so.conf.d/local.conf; ldconfig
fi

# Httpd
wget -c http://www-eu.apache.org/dist//apr/apr-${apr_version}.tar.gz && tar zxf apr-${apr_version}.tar.gz
sed -i 's@$RM "$cfgfile"@$RM -f "$cfgfile"@' apr-${apr_version}/configure
wget -c http://www-eu.apache.org/dist//apr/apr-util-${apr_util_version}.tar.gz && tar zxf apr-${apr_util_version}.tar.gz
wget -c http://www-us.apache.org/dist//httpd/httpd-${httpd_version}.tar.gz && tar zxf httpd-${httpd_version}.tar.gz
cd httpd-${httpd_version}
[ ! -d "/usr/local/apache" ] && mkdir -p /usr/local/apache
/bin/cp -R ../apr-${apr_version} ./srclib/apr
/bin/cp -R ../apr-util-${apr_util_version} ./srclib/apr-util
LDFLAGS=-ldl LD_LIBRARY_PATH=/usr/local/openssl/lib ./configure --prefix=/usr/local/apache \
--with-mpm=prefork \
--with-included-apr \
--enable-headers \
--enable-deflate \
--enable-so \
--enable-dav \
--enable-rewrite \
--enable-ssl \
--with-ssl=/usr/local/openssl
--enable-http2 \
--with-nghttp2=/usr/local \
--enable-expires \
--enable-static-support \
--enable-suexec \
--enable-modules=all \
--enable-mods-shared=all
make -j2 && make install
unset LDFLAGS
if [ -e "/usr/local/apache/conf/httpd.conf" ]; then
  echo "Apache installed successfully!"
  cd ../
else
  rm -rf /usr/local/apache
  echo "Apache install failed!"
  kill -9 $$
fi

[ -z "`grep ^'export PATH=' /etc/profile`" ] && echo "export PATH=/usr/local/apache/bin:\$PATH" >> /etc/profile
[ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep /usr/local/apache /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=/usr/local/apache/bin:\1@" /etc/profile
. /etc/profile

/bin/cp /usr/local/apache/bin/apachectl /etc/init.d/httpd
sed -i '2a # chkconfig: - 85 15' /etc/init.d/httpd
sed -i '3a # description: Apache is a World Wide Web server. It is used to serve' /etc/init.d/httpd
chmod +x /etc/init.d/httpd && update-rc.d httpd defaults

sed -i "s@^User daemon@User www@" /usr/local/apache/conf/httpd.conf
sed -i "s@^Group daemon@Group www@" /usr/local/apache/conf/httpd.conf
sed -i 's/^#ServerName www.example.com:80/ServerName 127.0.0.1:9080/' /usr/local/apache/conf/httpd.conf
sed -i 's@^Listen.*@Listen 127.0.0.1:9080@' /usr/local/apache/conf/httpd.conf
sed -i "s@AddType\(.*\)Z@AddType\1Z\n    AddType application/x-httpd-php .php .phtml\n    AddType application/x-httpd-php-source .phps@" /usr/local/apache/conf/httpd.conf
sed -i "s@#AddHandler cgi-script .cgi@AddHandler cgi-script .cgi .pl@" /usr/local/apache/conf/httpd.conf
sed -ri 's@^#(.*mod_suexec.so)@\1@' /usr/local/apache/conf/httpd.conf
sed -ri 's@^#(.*mod_vhost_alias.so)@\1@' /usr/local/apache/conf/httpd.conf
sed -ri 's@^#(.*mod_rewrite.so)@\1@' /usr/local/apache/conf/httpd.conf
sed -ri 's@^#(.*mod_deflate.so)@\1@' /usr/local/apache/conf/httpd.conf
sed -ri 's@^#(.*mod_expires.so)@\1@' /usr/local/apache/conf/httpd.conf
sed -ri 's@^#(.*mod_ssl.so)@\1@' /usr/local/apache/conf/httpd.conf
sed -ri 's@^#(.*mod_http2.so)@\1@' /usr/local/apache/conf/httpd.conf
sed -i 's@DirectoryIndex index.html@DirectoryIndex index.html index.php@' /usr/local/apache/conf/httpd.conf
sed -i "s@^DocumentRoot.*@DocumentRoot \"/data/wwwroot/default\"@" /usr/local/apache/conf/httpd.conf
sed -i "s@^<Directory \"/usr/local/apache/htdocs\">@<Directory \"/data/wwwroot/default\">@" /usr/local/apache/conf/httpd.conf
sed -i "s@^#Include conf/extra/httpd-mpm.conf@Include conf/extra/httpd-mpm.conf@" /usr/local/apache/conf/httpd.conf

#logrotate apache log
cat > /etc/logrotate.d/apache << EOF
/data/wwwlogs/*apache.log {
daily
rotate 5
missingok
dateext
compress
notifempty
sharedscripts
postrotate
  [ -e /var/run/httpd.pid ] && kill -USR1 \`cat /var/run/httpd.pid\`
endscript
}
EOF

cat >> /usr/local/apache/conf/httpd.conf <<EOF
<IfModule mod_headers.c>
AddOutputFilterByType DEFLATE text/html text/plain text/css text/xml text/javascript
<FilesMatch "\.(js|css|html|htm|png|jpg|swf|pdf|shtml|xml|flv|gif|ico|jpeg)\$">
  RequestHeader edit "If-None-Match" "^(.*)-gzip(.*)\$" "\$1\$2"
  Header edit "ETag" "^(.*)-gzip(.*)\$" "\$1\$2"
</FilesMatch>
DeflateCompressionLevel 6
SetOutputFilter DEFLATE
</IfModule>

ProtocolsHonorOrder On
PidFile /var/run/httpd.pid
ServerTokens ProductOnly
ServerSignature Off
Include conf/vhost/*.conf
EOF

  cat > /usr/local/apache/conf/extra/httpd-remoteip.conf << EOF
LoadModule remoteip_module modules/mod_remoteip.so
RemoteIPHeader X-Forwarded-For
RemoteIPInternalProxy 127.0.0.1
EOF
  sed -i "s@Include conf/extra/httpd-mpm.conf@Include conf/extra/httpd-mpm.conf\nInclude conf/extra/httpd-remoteip.conf@" /usr/local/apache/conf/httpd.conf
  sed -i "s@LogFormat \"%h %l@LogFormat \"%h %a %l@g" /usr/local/apache/conf/httpd.conf

ldconfig
service httpd start
cd ../ && rm -rf apache
