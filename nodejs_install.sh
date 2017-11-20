#!/bin/bash
# Author: Seon <support AT seon.me>
# Site: https://seon.me

# NodeJS Version
nodejs_version=8.9.1

# NodeJS Installed DIR
nodejs_install_dir=/usr/local/node

# OS BIT
if [ "$(getconf WORD_BIT)" == "32" ] && [ "$(getconf LONG_BIT)" == "64" ]; then
  OS_BIT=x64
else
  OS_BIT=x32
fi

mkdir -p nodejs && cd nodejs

# Download
wget -c https://nodejs.org/dist/v${nodejs_version}/node-v${nodejs_version}-linux-${OS_BIT}.tar.gz && tar zvxf node-v${nodejs_version}-linux-${OS_BIT}.tar.gz

# Installed
[ ! -d "${nodejs_install_dir}" ] && mkdir -p ${nodejs_install_dir}
mv node-v${nodejs_version}-linux-${OS_BIT}/* ${nodejs_install_dir} && chown -R root:staff ${nodejs_install_dir}

if [ -d "${nodejs_install_dir}/bin" ]; then
  cd ../
  rm -rf nodejs
  echo "NodeJS installed successfully!"
else
  rm -rf ${nodejs_install_dir}
  echo "NodeJS install failed."
  kill -9 $$
fi

[ -z "`grep ^'export PATH=' /etc/profile`" ] && echo "export PATH=/usr/local/node/bin:\$PATH" >> /etc/profile
[ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep /usr/local/node /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=/usr/local/node/bin:\1@" /etc/profile
. /etc/profile

echo "
#################################################################################
#      If you enter "node -v" does not output version information, Please       #
# manually implement the ". /etc/profile" environment variables to take effect. #
#################################################################################
"
