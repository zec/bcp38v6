#!/bin/sh

IPSET_ROOT=bcp38v6
IPT_CHAIN=BCP38-IPv6

. /lib/functions.sh

config_load bcp38v6

get_iface() {
	local section="$1"
	local enabled
	local iface
	config_get_bool enabled "$section" enabled 1
	config_get iface "$section" interface

	if [ "x$enabled" '=' x1 -a -n "$iface" ] ; then
		# Get UCI interface name and associated kernel interface name
		echo "$iface" "$(uci -P/var/state get network."$iface".ifname)"
	fi
}

# Remove the jump if it already exists
ip6tables -D forwarding_rule -j "$IPT_CHAIN" 2>/dev/null

ip6tables -N "$IPT_CHAIN" 2>/dev/null
ip6tables -F "$IPT_CHAIN" 2>/dev/null

ip6tables -I forwarding_rule -j "$IPT_CHAIN"

config_foreach get_iface filter | sort | uniq | while read I N ; do
	ipset create "${IPSET_ROOT}-stage-${I}" hash:net family ipv6 2>/dev/null
	ipset create "${IPSET_ROOT}-in-${I}" hash:net family ipv6 2>/dev/null
	ipset create "${IPSET_ROOT}-out-${I}" hash:net family ipv6 2>/dev/null

	ip6tables -A "$IPT_CHAIN" -o "$N" -m set '!' --match-set "${IPSET_ROOT}-out-${I}" src -j REJECT --reject-with icmp6-addr-unreachable
	ip6tables -A "$IPT_CHAIN" -i "$N" -m set '!' --match-set "${IPSET_ROOT}-in-${I}"  dst -j DROP

	INTERFACE="$I" /root/update-bcp38v6.lua
done
