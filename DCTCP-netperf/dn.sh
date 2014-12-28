#!/usr/local/bin/bash

cmd=$1
srcip=$2
dstip=$3
ecn=$4
ipfw="ipfw -qf"

if [ -z $ecn ]; then
	echo "$0 <cmd(flush/add/del)> <src> <dst> <ecn>"
	exit
fi

# configure dummynet to set some delay and loss
red_opt=1/6/6/0.0
delay=20ms
q=20
bw=2Mbit/s
n=9994
n2=9995


del_rule() {
	ipfw pipe $n delete
	ipfw pipe $n2 delete
	ipfw $n delete
	ipfw $n2 delete
}

if [ "$ipfw" ]; then
	if [ "$cmd" = "flush" ]; then
		$ipfw flush
		$ipfw pipe flush
		echo flush rules
	elif [ "$cmd" = "add" ]; then
		# delete current rule for safety
		del_rule

		# enable ip forwarding
		sysctl net.inet.ip.forwarding=1 > /dev/null

		# don't ipfw-treat the ssh and netperf control traffic
		# wellknown port : nfs(tcp/udp 2049, 111?), dns(udp 53)
		if [ "$ecn" = 1 ]; then
			$ipfw pipe $n config queue $q bw $bw delay $delay red $red_opt ecn
			$ipfw pipe $n2 config queue $q bw $bw delay $delay red $red_opt ecn
		else
			$ipfw pipe $n config queue $q bw $bw delay $delay
			$ipfw pipe $n2 config queue $q bw $bw delay $delay 
		fi
		$ipfw add $n pipe $n ip from $srcip not 2049,22,5999 to $dstip not 2049,22,5999 out
		$ipfw add $n2 pipe $n2 ip from $dstip not 2049,22,5999 to $srcip not 2049,22,5999 out
		$ipfw add allow ip from $srcip not 2049,22,5999 to $dstip not 2049,22,5999 in
		$ipfw add allow ip from $dstip not 2049,22,5999 to $srcip not 2049,22,5999 in
	elif [ "$cmd" = "del" ]; then
		del_rule
	fi
fi
