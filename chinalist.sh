#!/bin/sh
opkg remove dnsmasq && opkg install dnsmasq-full ipset
[ ! -d "/etc/dnsmasq.d" ] && mkdir -p /etc/dnsmasq.d
cd ~ && curl -L -o generate_dnsmasq_chinalist.sh https://github.com/cokebar/openwrt-scripts/raw/master/generate_dnsmasq_chinalist.sh
chmod +x generate_dnsmasq_chinalist.sh
sh generate_dnsmasq_chinalist.sh -d 114.114.114.114 -p 53 -s ss_spec_dst_bp -o /etc/dnsmasq.d/accelerated-domains.china.conf
