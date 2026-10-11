# Droidspaces OpenWrt 24.10 rootfs with an IPSet-only dnsmasq-full.
ARG OPENWRT_VERSION=24.10.7
# OpenWrt publishes this image with the nonstandard manifest architecture
# "aarch64_generic".  Pinning its platform manifest bypasses Buildx's normal
# linux/arm64 manifest lookup; RUN instructions still execute under QEMU arm64.
ARG OPENWRT_ROOTFS_DIGEST=sha256:96b2c09aa25a751946d1caa297fc7c5d7498f60d346f8350513f3ade878d4703

FROM --platform=linux/arm64 openwrt/rootfs@${OPENWRT_ROOTFS_DIGEST} AS upstream
FROM scratch AS customizer
COPY --from=upstream / /
COPY artifacts/dnsmasq-full-ipset.ipk /tmp/dnsmasq-full-ipset.ipk

RUN <<'EOF'
set -eux
mkdir -p /var/lock /var/run /tmp
opkg update
opkg remove --force-depends firewall4 nftables-json kmod-nft-offload kmod-nft-nat kmod-nft-fib kmod-nft-core || true
# Install LuCI explicitly.  The Docker rootfs base is intentionally minimal
# and does not promise to include a HTTP management service.  Avoid the broad
# `luci` meta package because it pulls the firewall UI package, which targets
# firewall4/nftables; the selected modules provide the normal admin UI while
# keeping fw3/iptables-legacy intact.
opkg install firewall iptables-zz-legacy ip6tables-zz-legacy ipset coreutils-base64 shadow-utils \
  uhttpd uhttpd-mod-ubus rpcd luci-base luci-mod-admin-full luci-theme-bootstrap
ln -sf /usr/sbin/iptables-legacy /usr/sbin/iptables
ln -sf /usr/sbin/ip6tables-legacy /usr/sbin/ip6tables

# The package is IPSet-only, with no Android-incompatible nftset support.
opkg remove --force-depends dnsmasq dnsmasq-full || true
opkg install /tmp/dnsmasq-full-ipset.ipk
dnsmasq --version | grep -q 'ipset'
dnsmasq --version | grep -q 'no-nftset'

grep -q '^aid_inet:' /etc/group || echo 'aid_inet:x:3003:root' >> /etc/group
grep -q '^aid_net_raw:' /etc/group || echo 'aid_net_raw:x:3004:root' >> /etc/group
grep -q '^aid_net_admin:' /etc/group || echo 'aid_net_admin:x:3005:root' >> /etc/group
usermod -a -G aid_inet,aid_net_raw root || true
opkg remove --force-depends shadow-utils

/etc/init.d/uhttpd enable

cat >/etc/config/network <<'NETEOF'
config interface 'loopback'
        option device 'lo'
        option proto 'static'
        option ipaddr '127.0.0.1'
        option netmask '255.0.0.0'
config interface 'wan'
        option device 'eth0'
        option proto 'dhcp'
config interface 'wan6'
        option device 'eth0'
        option proto 'dhcpv6'
        option reqaddress 'try'
        option reqprefix 'auto'
        option sourcefilter '0'
NETEOF

cat >/etc/config/firewall <<'FWEOF'
config defaults
        option syn_flood '1'
        option input 'ACCEPT'
        option output 'ACCEPT'
        option forward 'REJECT'
config zone
        option name 'lan'
        option input 'ACCEPT'
        option output 'ACCEPT'
        option forward 'ACCEPT'
config zone
        option name 'wan'
        list network 'wan'
        list network 'wan6'
        option input 'REJECT'
        option output 'ACCEPT'
        option forward 'REJECT'
        option masq '1'
        option mtu_fix '1'
config forwarding
        option src 'lan'
        option dest 'wan'
FWEOF

echo 'net.ipv4.ip_forward=1' >/etc/sysctl.d/30-droidspaces.conf
sed -i '/-t debugfs debugfs/d' /etc/init.d/boot
rm -rf /var/opkg-lists/* /tmp/dnsmasq-full-ipset.ipk
EOF

FROM scratch AS export
LABEL droidspaces.name="OpenWrt 24.10 - IPSet (iptables-legacy)" \
      droidspaces.distro="OpenWrt" \
      droidspaces.description="Droidspaces OpenWrt rootfs for Android kernels: fw3 and iptables-legacy with dnsmasq-full compiled for legacy IPSet only." \
      droidspaces.author="android-openwrt"
COPY --from=customizer / /
