# Droidspaces OpenWrt IPSet rootfs

This repository builds an Android-compatible Droidspaces OpenWrt 24.10 rootfs
for legacy `iptables`/`fw3` environments. Its `dnsmasq-full` is compiled with
legacy **IPSet** support and without **nftset** support.

## Build outputs

Every push to `main` creates an Actions artifact containing the rootfs archive
and its SHA-256 checksum. Run the workflow manually with release publishing
enabled to create downloadable GitHub release assets.

## Compatibility

- Target: `armsr/armv8`; package ABI: `aarch64_generic`.
- Firewall: `fw3` + `iptables-legacy`; nftables is deliberately absent.
- Transparent proxy: includes the `TPROXY`, `socket`, and `CONNMARK` xtables
  user-space extensions for Android kernels that already expose the matching
  netfilter targets. OpenWrt `.ko` kernel modules are intentionally not kept
  in the rootfs because Droidspaces uses the Android host kernel.
- Userland `ipset` is used instead of OpenWrt's `kmod-ipt-ipset`, because the
  Droidspaces container shares Android's host kernel.
- Do not later install the repository `dnsmasq-full`, which can replace this
  IPSet-only build with the stock `no-ipset nftset` variant.
