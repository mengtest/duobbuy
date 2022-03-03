#sysctl.sh
#/bin/bash
echo -e "net.ipv4.ip_forward = 0" >/etc/sysctl.conf
echo -e "net.core.somaxconn = 262144" >> /etc/sysctl.conf
echo -e "net.core.netdev_max_backlog = 262144" >> /etc/sysctl.conf
echo -e "net.core.wmem_default = 8388608" >> /etc/sysctl.conf
echo -e "net.core.rmem_default = 8388608" >> /etc/sysctl.conf
echo -e "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
echo -e "net.core.wmem_max = 16777216" >> /etc/sysctl.conf
echo -e "net.ipv4.route.gc_timeout = 20" >> /etc/sysctl.conf
echo -e "net.ipv4.ip_local_port_range = 1025 65535" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_retries2 = 5" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_fin_timeout = 30" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_syn_retries = 1" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_synack_retries = 1" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_timestamps = 0" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_tw_recycle = 1" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_tw_reuse = 1" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_keepalive_time = 120" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_keepalive_probes = 3" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_keepalive_intvl = 15" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_max_tw_buckets = 200000" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_max_orphans = 3276800" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_max_syn_backlog = 262144" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_wmem = 8192 131072 16777216" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_rmem = 32768 131072 16777216" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_mem = 94500000 915000000 927000000" >> /etc/sysctl.conf
#5.8以上
echo -e "net.nf_conntrack_max = 25000000" >> /etc/sysctl.conf
echo -e "net.netfilter.nf_conntrack_max = 25000000" >> /etc/sysctl.conf
echo -e "net.netfilter.nf_conntrack_tcp_timeout_established = 180" >> /etc/sysctl.conf
echo -e "net.netfilter.nf_conntrack_tcp_timeout_time_wait = 1" >> /etc/sysctl.conf
echo -e "net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60" >> /etc/sysctl.conf
echo -e "net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120" >> /etc/sysctl.conf
modprobe nf_conntrack
modprobe ip_conntrack
#5.8及以下
#echo -e "net.ipv4.ip_conntrack_max = 25000000" >> /etc/sysctl.conf
#echo -e "net.ipv4.netfilter.ip_conntrack_max = 25000000" >> /etc/sysctl.conf
#echo -e "net.ipv4.netfilter.ip_conntrack_tcp_timeout_established = 180" >> /etc/sysctl.conf
#echo -e "net.ipv4.netfilter.ip_conntrack_tcp_timeout_time_wait = 1" >> /etc/sysctl.conf
#echo -e "net.ipv4.netfilter.ip_conntrack_tcp_timeout_close_wait = 60" >> /etc/sysctl.conf
#echo -e "net.ipv4.netfilter.ip_conntrack_tcp_timeout_fin_wait = 120" >> /etc/sysctl.conf
modprobe ip_conntrack
sysctl -p
