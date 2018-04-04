#!/bin/bash

# clean  up namespaces
for i in `ip netns | egrep 'qdhcp|qrouter' |  cut -d " " -f 1`; do ip netns del $i; done

# clean up VMs
virsh list | grep instance- | awk '{print $2}' | xargs -I '{}' virsh destroy '{}'
virsh list --all | grep instance- | awk '{print $2}' | xargs -I '{}' virsh undefine '{}'

# clean up bridges
brctl show | grep brq | awk '{print $1}' | xargs -I '{}' ip link set dev '{}' down
brctl show | grep brq | awk '{print $1}' | xargs  -I '{}' brctl delbr '{}'

# remove all vxlan interfaces
ip a s | grep -e 'vxlan-[0-9]\{5\}' | cut -d":" -f 2 | xargs -I '{}' ip link delete {}

# delete br-ex if exists
# brctl show | grep -wq br-ex && { ip link set dev br-ex down; brctl delbr br-ex; } || true
