## traffic_shaping
## Works by sending all non-interactive (i.e. low priority) traffic through a pipe which is 3/4rs (or 1/2lf for 56kmodems) the size of your actual connection
## This should leave a large enough gap for responsive web browsing, ssh sessions, email, etc.

## Sorry, this isn't adaptive, ie. it doesn't shrink the non-interactive pipe when you are using the net interactively, and then grow it when you are idle or away.
## It puts a constant reduction on your non-priority traffic (PROPORTION_TO_ALLOW).
## But since it works and can be used all the time, I find it means I can send more non-interactive traffic by leaving it running constantly through this form of shaping.
## A dynamic size pipe would be good though...

## On my cable modem: monitoriflow reports the largest outgoing bytes per second at about 22000
##                    (actually it can reach 25000/26000 but above 22000 incoming appears to suffer!)
##                    But for shaping, I tend to use two limited pipes of 40kbit (50kbit peak),
##                    which tends to allow around 17000 of non-interactive traffic through.

## The core of this script was ripped from a webpage somewhere I think.

## NOTE: you can view the various pipes at work by running the traffic_shaping_monitor script.
##       monitoriflow (or any network traffic monitor) on a busy network can also give a good indication of how the shaping rules are working.

## I decided to create a third throttled pipe for my webserver, because if it goes full whack, it floods my outgoing filesharing packets and severely reduces their incoming responses.


### >>>>>>>>>>>>>>>>>>>> Config

# INTERFACE=ppp0
# INTERFACE=eth0
# INTERFACE=eth1

## This is actually the max output bytes per second you can observe from monitoriflow running without shaping
BANDWIDTH_OUT=20000
# BANDWIDTH_OUT=25000

# PROPORTION_SMALL_PIPE="15"
# PROPORTION_WEBSERVER="45"
# PROPORTION_LARGE_PIPE="35"
# PROPORTION_SMALL_PIPE="15"
# PROPORTION_WEBSERVER="35"
# PROPORTION_LARGE_PIPE="40"
PROPORTION_SMALL_PIPE="15"
PROPORTION_WEBSERVER="40"
PROPORTION_LARGE_PIPE="40"

INTERFACE=`/home/joey/j/jsh ifonline`



## Stats can be accessed with: /sbin/tc -s qdisc ls dev eth1
## In jsh I use: jwatchchanges /sbin/tc -s qdisc ls dev eth1 "|" trimempty
## I also use: monitoriflow
## Actually now I recommend: traffic_shaping_monitor

## TODO:
##   - I don't know if we are affecting ingress at all.  man tc suggests that we can.
##   - It'd be good to attempt to limit ingress of irrelevant services, to leave room for important ones.
##   - Should we adapt the specified rate of the less important packages so that it makes more space when important streams are wanting more.  ATM they only get what the tbf leaves free, but I want the tbf to shrink to make space.
##   - debug stats pfifo handle 12: is showing up bytes (esp. at rule creation) but I don't know where they come from.  I do not believed it is being pointed to anywhere (at least not intentionally!).
##   - I have separated into a number of different discs/bands? for debugging of what's going where.  But probably we only need four bands total...

## OK finally realised that the disc #s are hex, so we can probably have max f of them, not 9!



function filter_port () {
	TYPE="$1"
	PORTDIR="$2"
	PORT="$3"
	DESTDISC="$4"
	[ "$5" ] && PRIO="$5" || PRIO="$DESTDISC"
	if [ "$DESTDISC" = 2 ]
	then error "[traffic_shaping] filter_port $1 $2 $3 $4 : Don't use disc 2 it's dodgy!  (I don't know why but it gets packets without rules!)"
	fi
	/sbin/tc filter add dev "$INTERFACE" parent 1:0 prio $PRIO protocol ip u32 match ip $PORTDIR $PORT 0xffff flowid 1:$DESTDISC
}

case "$1" in

		start)
			echo -n "shaping: "
			[ "$DEBUG" ] && echo ## to make later debug calls neat!
			## configure "$INTERFACE" so that there is a bandwidth cap on large packets going up the DSL line
			## and then garp advertising the true gateway's IP, so that other hosts use us rather than it



			## >>>>>>>>>>>>>>>>>>>> Initialisation

			[ "$PROPORTION_TO_ALLOW" ] && BANDWIDTH_OUT=`expr "$BANDWIDTH_OUT" '*' $PROPORTION_TO_ALLOW`

			[ "$BUT_ALLOW_WEBSERVER_TWICE" ] || BUT_ALLOW_WEBSERVER_TWICE=1

			set -e
			# [ "$DEBUG" ] && set -x
			SMALL_PIPE_BPS=`expr $BANDWIDTH_OUT '*' $PROPORTION_SMALL_PIPE / 100`
			LARGE_PIPE_BPS=`expr $BANDWIDTH_OUT '*' $PROPORTION_LARGE_PIPE / 100`
			WEBSERVER_BPS=`expr $BANDWIDTH_OUT '*' $PROPORTION_WEBSERVER / 100`
			SMALL_PIPE_PEAKBPS=`expr $SMALL_PIPE_BPS '*' 5 / 4`
			LARGE_PIPE_PEAKBPS=`expr $LARGE_PIPE_BPS '*' 5 / 4`
			WEBSERVER_PEAKBPS=`expr $WEBSERVER_BPS '*' 5 / 4`
			# [ "$DEBUG" ] && set +x
			set +e

			if [ "$SMALL_PIPE_BPS" -lt 1 ]
			then
				jshwarn "[traffic_shaping] Limit $SMALL_PIPE_BPS too low, setting 1."
				SMALL_PIPE_BPS=1
				SMALL_PIPE_PEAKBPS=2
			fi
			if [ "$SMALL_PIPE_BPS" -gt 0 ] && [ "$SMALL_PIPE_BPS" -lt 99999999999 ]
			then :
			else
				jshwarn "[traffic_shaping] Calculation failed producing \"$SMALL_PIPE_BPS\","
				SMALL_PIPE_BPS=44
				SMALL_PIPE_PEAKBPS=55
				jshwarn "[traffic_shaping] using $SMALL_PIPE_BPS instead."
			fi
			## If peak == bps then tc throws error on creation!
			[ "$SMALL_PIPE_PEAKBPS" -gt "$SMALL_PIPE_BPS" ] || SMALL_PIPE_PEAKBPS=`expr "$SMALL_PIPE_BPS" + 1`

			if [ "$LARGE_PIPE_BPS" -lt 1 ]
			then
				jshwarn "[traffic_shaping] Limit $LARGE_PIPE_BPS too low, setting 1."
				LARGE_PIPE_BPS=1
				LARGE_PIPE_PEAKBPS=2
			fi
			if [ "$LARGE_PIPE_BPS" -gt 0 ] && [ "$LARGE_PIPE_BPS" -lt 99999999999 ]
			then :
			else
				jshwarn "[traffic_shaping] Calculation failed producing \"$LARGE_PIPE_BPS\","
				LARGE_PIPE_BPS=44
				LARGE_PIPE_PEAKBPS=55
				jshwarn "[traffic_shaping] using $LARGE_PIPE_BPS instead."
			fi
			## If peak == bps then tc throws error on creation!
			[ "$LARGE_PIPE_PEAKBPS" -gt "$LARGE_PIPE_BPS" ] || LARGE_PIPE_PEAKBPS=`expr "$LARGE_PIPE_BPS" + 1`

			[ "$DEBUG" ] && debug "[traffic_shaping] Will create small pipe of size $SMALL_PIPE_BPS bps (peak $SMALL_PIPE_PEAKBPS)"
			[ "$DEBUG" ] && debug "[traffic_shaping]             large pipe of size $LARGE_PIPE_BPS bps (peak $LARGE_PIPE_PEAKBPS)"
			[ "$DEBUG" ] && debug "[traffic_shaping]            webserver pipe size $WEBSERVER_BPS bps (peak $WEBSERVER_PEAKBPS)"

			## These and the |sort below allow me to re-order the priority of the pipes, but the webserver connections all die unless i put the webserver first.  Strange.
			WEBSERVER_DISC=7
			SMALL_DISC=8
			REST_DISC=9
			# SMALL_DISC=7
			# WEBSERVER_DISC=8
			# REST_DISC=9
			## This doesn't work.  I think the webserved packets get caught into disc 8 regardless.
			# SMALL_DISC=7
			# REST_DISC=8
			# WEBSERVER_DISC=9



			## >>>>>>>>>>>>>>>>>>>> Start IP forwarding rules (disabled here):

			## enable ip forwarding
			# echo 1 >/proc/sys/net/ipv4/ip_forward 

			## Joey: I guess this should be commented out too!
			## disable sending of icmp redirects (after all, we are deliberatly causing the hosts to use us instead of the true gateway)
			# echo 0 >/proc/sys/net/ipv4/conf/all/send_redirects
			# echo 0 >/proc/sys/net/ipv4/conf/"$INTERFACE"/send_redirects



			## >>>>>>>>>>>>>>>>>>>> Add the shaping rules to the stack or wherever they go!

			## clear whatever is attached to "$INTERFACE"
			## this can fail if there is nothing attached, btw, but that is fine
			/sbin/tc qdisc del dev "$INTERFACE" root 2>/dev/null

			## add default 4-band priority qdisc to "$INTERFACE"
			/sbin/tc qdisc add dev "$INTERFACE" root handle 1: prio bands 9

			(

			## add a <128kbit rate limit (matches DSL upstream bandwidth) with a very deep buffer to the bulk band (#3)
			## 99 kbit/s == 8 1500 byte packets/sec, so a latency of 5 sec means we will buffer up to 40 of these big
			## ones before dropping. a buffer of 1600 tokens means that at any time we are ready to burst one of
			## these big ones (at the peakrate, 128kbit/s). the mtu of 1518 instead of 1514 is in case I ever start
			## using vlan tagging, because if mtu is too low (like 1500) then all traffic blocks
			# # /sbin/tc qdisc add dev "$INTERFACE" parent 1:3 handle 13: tbf rate 20kbit buffer 1600 peakrate "$PIPE_BPS"kbit mtu 1518 mpu 64 latency 50ms
			# # /sbin/tc qdisc add dev "$INTERFACE" parent 1:3 handle 13: tbf rate 80kbit buffer 1600 peakrate 100kbit mtu 1518 mpu 64 latency 50ms
			# # /sbin/tc qdisc add dev "$INTERFACE" parent 1:3 handle 13: tbf rate 60kbit buffer 1600 peakrate 75kbit mtu 1518 mpu 64 latency 50ms
			# /sbin/tc qdisc add dev "$INTERFACE" parent 1:$REST_DISC handle 1$REST_DISC: tbf rate 80kbit buffer 1600 peakrate 90kbit mtu 1518 mpu 64 latency 50ms
			# # /sbin/tc qdisc add dev "$INTERFACE" parent 1:$REST_DISC handle 1$REST_DISC: tbf rate 80kbit buffer 1600 peakrate 100kbit mtu 1518 mpu 64 latency 50ms
			# # # /sbin/tc qdisc add dev "$INTERFACE" parent 1:$REST_DISC handle 1$REST_DISC: tbf rate 80kbit buffer 1600 peakrate 120kbit mtu 1518 mpu 64 latency 50ms
			## Decided they should have equal weighting:
			# /sbin/tc qdisc add dev "$INTERFACE" parent 1:$REST_DISC handle 1$REST_DISC: tbf rate 60kbit buffer 1600 peakrate 70kbit mtu 1518 mpu 64 latency 50ms
			# /sbin/tc qdisc add dev "$INTERFACE" parent 1:$REST_DISC handle 1$REST_DISC: tbf rate 50kbit buffer 1600 peakrate 60kbit mtu 1518 mpu 64 latency 50ms

			# /sbin/tc qdisc add dev "$INTERFACE" parent 1:$REST_DISC handle 1$REST_DISC: tbf rate 50kbit buffer 1600 peakrate 60kbit mtu 1518 mpu 64 latency 50ms
			echo "$REST_DISC /sbin/tc qdisc add dev $INTERFACE parent 1:$REST_DISC handle 1$REST_DISC: tbf rate $SMALL_PIPE_BPS""bps buffer 1600 peakrate $SMALL_PIPE_PEAKBPS""bps mtu 1518 mpu 64 latency 50ms"
			# /sbin/tc qdisc add dev "$INTERFACE" parent 1:$REST_DISC handle 1$REST_DISC: tbf rate 30kbit buffer 1600 peakrate 40kbit mtu 1518 mpu 64 latency 50ms
			# /sbin/tc qdisc add dev "$INTERFACE" parent 1:$REST_DISC handle 1$REST_DISC: tbf rate 20kbit buffer 1600 peakrate 30kbit mtu 1518 mpu 64 latency 50ms

			## For small packets:
			# /sbin/tc qdisc add dev "$INTERFACE" parent 1:$SMALL_DISC handle 1$SMALL_DISC: tbf rate 20kbit buffer 1600 peakrate 30kbit mtu 1518 mpu 64 latency 50ms
			# # /sbin/tc qdisc add dev "$INTERFACE" parent 1:$SMALL_DISC handle 1$SMALL_DISC: tbf rate 30kbit buffer 1600 peakrate 40kbit mtu 1518 mpu 64 latency 50ms
			# # # /sbin/tc qdisc add dev "$INTERFACE" parent 1:$SMALL_DISC handle 1$SMALL_DISC: tbf rate 20kbit buffer 1600 peakrate 120kbit mtu 1518 mpu 64 latency 50ms
			## Decided they should have equal weighting:
			# /sbin/tc qdisc add dev "$INTERFACE" parent 1:$SMALL_DISC handle 1$SMALL_DISC: tbf rate "$PIPE_BPS"kbit buffer 1600 peakrate 50kbit mtu 1518 mpu 64 latency 50ms
			# /sbin/tc qdisc add dev "$INTERFACE" parent 1:$SMALL_DISC handle 1$SMALL_DISC: tbf rate 50kbit buffer 1600 peakrate 60kbit mtu 1518 mpu 64 latency 50ms

			# /sbin/tc qdisc add dev "$INTERFACE" parent 1:$SMALL_DISC handle 1$SMALL_DISC: tbf rate 50kbit buffer 1600 peakrate 60kbit mtu 1518 mpu 64 latency 50ms
			echo "$SMALL_DISC /sbin/tc qdisc add dev $INTERFACE parent 1:$SMALL_DISC handle 1$SMALL_DISC: tbf rate $LARGE_PIPE_BPS""bps buffer 1600 peakrate $LARGE_PIPE_PEAKBPS""bps mtu 1518 mpu 64 latency 50ms"
			# /sbin/tc qdisc add dev "$INTERFACE" parent 1:$SMALL_DISC handle 1$SMALL_DISC: tbf rate 30kbit buffer 1600 peakrate 40kbit mtu 1518 mpu 64 latency 50ms
			# /sbin/tc qdisc add dev "$INTERFACE" parent 1:$SMALL_DISC handle 1$SMALL_DISC: tbf rate 20kbit buffer 1600 peakrate 30kbit mtu 1518 mpu 64 latency 50ms

			echo "$WEBSERVER_DISC /sbin/tc qdisc add dev $INTERFACE parent 1:$WEBSERVER_DISC handle 1$WEBSERVER_DISC: tbf rate $WEBSERVER_BPS""bps buffer 1600 peakrate $WEBSERVER_PEAKBPS""bps mtu 1518 mpu 64 latency 50ms"

			) | sort -r -n -k 1 | sed 's+^[^ ]*[ ]*++' | sh

			## add fifos to the other bands so we can have some stats
			for SUBDISC in `seq 6 -1 1`
			do
				# if [ "$SUBDISC" = 6 ]
				# then
					# /sbin/tc qdisc add dev "$INTERFACE" parent 1:$SUBDISC handle 1$SUBDISC: tbf rate 240kbit buffer 1600 peakrate 280kbit mtu 1518 mpu 64 latency 50ms
				# else
					/sbin/tc qdisc add dev "$INTERFACE" parent 1:$SUBDISC handle 1$SUBDISC: pfifo
				# fi
			done

			## add a filter so DIP's within the house go to prio band #1 instead of being assigned by TOS
			## thus traffic going to an inhouse location has top priority
			# /sbin/tc filter add dev "$INTERFACE" parent 1:0 prio 1 protocol ip u32 match ip dst 192.168.168.0/24 flowid 1:1
			## Joey TODO: I guess this assumes your network is 10.0.0.*
			/sbin/tc filter add dev "$INTERFACE" parent 1:0 prio 1 protocol ip u32 match ip dst 10.0.0.0/24 flowid 1:1

			## multicasts also go into band #1, since they are all inhouse (and we don't want to delay ntp packets and mess up time)
			/sbin/tc filter add dev "$INTERFACE" parent 1:0 prio 1 protocol ip u32 match ip dst 224.0.0.0/4 flowid 1:1

			# On the TOS field, to select interactive, minimum delay traffic: (apparently some apps lie in this field :-( )
			/sbin/tc filter add dev "$INTERFACE" parent 1:0 prio 1 protocol ip u32 match ip tos 0x10 0xff flowid 1:3
			## Use 0x08 0xff for bulk traffic.

			## This filters by IP (and sends to the pipe of big packets!)
			## (to match a whole network, end ip .0/24)
			## This filtered out multicom's network for a while:
			# /sbin/tc filter add dev "$INTERFACE" parent 1:0 prio 1 protocol ip u32 match ip dst 195.188.198.196/32 flowid 1:9

			### Critical:

			## Games:
			##          unreal....most................
			for PORT in 7775 7776 7777 7778 7779 27900
			do
				filter_port batch$PORT sport $PORT 1
				filter_port batch$PORT dport $PORT 1
			done

			## Hwi's mail services:
			filter_port smtp     sport 25   3
			filter_port ssmtp    sport 465  3
			filter_port imap2    sport 143  3
			filter_port imap3    sport 220  3
			filter_port imaps    sport 993  3
			filter_port pop2     sport 109  3
			filter_port pop3     sport 110  3
			filter_port pop3s    sport 995  3
			# ## Remote mail:
			## Make sure email gets out, but doesn't flood the connection:
			filter_port smtp     dport 25   "$WEBSERVER_DISC" 3
			filter_port ssmtp    dport 465  "$WEBSERVER_DISC" 3
			filter_port imap2    dport 143  "$WEBSERVER_DISC" 3
			filter_port imap3    dport 220  "$WEBSERVER_DISC" 3
			filter_port imaps    dport 993  "$WEBSERVER_DISC" 3
			filter_port pop2     dport 109  "$WEBSERVER_DISC" 3
			filter_port pop3     dport 110  "$WEBSERVER_DISC" 3
			filter_port pop3s    dport 995  "$WEBSERVER_DISC" 3
			# ## Spamassassin or razor, dunno:
			filter_port razor    dport 773  "$WEBSERVER_DISC" 3

			## Peercast:
			filter_port peercast dport 7144 4
			filter_port peercast sport 7144 4
			filter_port peercast dport 7145 4
			filter_port peercast sport 7145 4
			## Dialect:
			filter_port peercast dport 7900 4
			filter_port peercast sport 7900 4
			## Dialect's remote port:
			filter_port peercast dport 7100 4
			filter_port peercast sport 7100 4

			### Interactive:

			## Unfortunately ssh is not at highest because rsync, scp, and other things can run across it
			## apparently, one "could tell ssh from scp; scp sets the IP diffserv flags to indicate bulk traffic"
			## but i don't know how to do this.  And what about rsync?  Maybe we can deal with large packets differently...?
			filter_port ssh      sport 22   4
			filter_port ssh      dport 22   4
			## My friends sometimes port-forward on 220:
			filter_port ssh      sport 220  4
			filter_port ssh      dport 220  4
			filter_port ssh      sport 222  4
			filter_port ssh      dport 222  4
			filter_port ssh      sport 2200  4
			filter_port ssh      dport 2200  4

			## Vnc-http, Vnc, and X
			## Oh but it gets eMule too!
			# for VNCPORT in `seq 5800 5899` `seq 5900 5999` `seq 6000 6010`
			# for VNCPORT in `seq 5800 5849`
			for VNCPORT in `seq 5800 5899` `seq 5900 5999`
			do
				filter_port vnc sport $VNCPORT 4
				# filter_port vnc dport $VNCPORT 4
			done

			## Realplay
			filter_port realplay sport 554 4
			filter_port realplay dport 554 4

			## Webcam
			filter_port webcam   sport 9192   5
			filter_port webcam   dport 9192   5

			## You probably want your webserver to go reasonably fast (compared to file sharing networks for example).
			## If you prefer to choke your webserver too, you can send it to band 8 or 9 instead.  (9 seems great but sometimes tails off!)
			## Or I could set up a third sub-pipe for webserver throttling...
			## Lower priority webserver:
			filter_port http   sport 80   $WEBSERVER_DISC
			filter_port https  sport 443  $WEBSERVER_DISC
			## Fast websurfing:
			filter_port http   dport 80   5
			filter_port https  dport 443  5

			## Experiment to test whether torrents were flooding gnutella:
			# filter_port gtkgnut sport 6346 $WEBSERVER_DISC
			# filter_port gtkgnut dport 6346 $WEBSERVER_DISC
			# filter_port mutella sport 6350 $WEBSERVER_DISC
			# filter_port mutella dport 6350 $WEBSERVER_DISC
			## But strangely it <d the outgoing traffic when I expected it to >= it!

			## DNS:
			filter_port domain dport 53   6
			filter_port domain sport 53   6

			## CVS:
			filter_port cvs    dport 2401 6
			filter_port cvs    sport 2401 6

			## And all the smeggin rest:
			## I gave up on socks line 217 of /etc/services, resume there?  I don't really know which ones are needed.  rsync might be preferably batched.  irc probably needs higher priority, unless it's being used for d/l'ing!
			##          ftp telnet dhcp gopher finger hostnames rtelnet sftp nntp ntp! snmp irc ldap snpp talk ntalk rsync ftps ftps-data telnets ircs webcam socks
			for PORT in 21  23     67   70     79     101       107     115  119  123  161  194 389  444  517  518   873   990  989       992     994  9192   1080
			do
				# filter_port batch$PORT sport $PORT 6
				filter_port batch$PORT dport $PORT 6
			done

			## Joey says: for some reason the original author split small and large packets up,
			## (presumably to ensure one class didn't swamp the other?), so I haven't changed it.

			## small IP packets go to band #2 (Joey: #3)
			## by small I mean <128 bytes in the IP datagram, or in other words, the upper 9 bits of the iph.tot_len are 0
			## note: this completely fails to do the right thing with fragmented packets. However
			## we happen to not have many (any? icmp maybe, but tcp?) fragmented packets going out the DSL line
			# /sbin/tc filter add dev "$INTERFACE" parent 1:0 prio 2 protocol ip u32 match u16 0x0000 0xff80 at 2 flowid 1:2
			## Joey finds there are too many, at least when running multiple bittorrents.  CONSIDER: make abother tbf for the small packets?
			/sbin/tc filter add dev "$INTERFACE" parent 1:0 prio $SMALL_DISC protocol ip u32 match u16 0x0000 0xff80 at 2 flowid 1:$SMALL_DISC

			## a final catch-all filter that redirects all remaining ip packets to band #4
			## presumably all that is left are large packets headed out the DSL line, which are
			## precisly those we wish to rate limit in order to keep them from filling the
			## DSL modem's uplink egress queue and keeping the shorter 'interactive' packets from
			## getting through
			## the dummy match is required to make the command parse
			/sbin/tc filter add dev "$INTERFACE" parent 1:0 prio $REST_DISC protocol ip u32 match u8 0 0 at 0 flowid 1:$REST_DISC

			## have the rest of the house think we are the gateway
			## the reason I use arpspoofing is that I want automatic failover to the real gateway
			## should this machine go offline, and since the real gateway does not do vrrp, I hack
			## the network and steal its arp address instead
			## It takes 5-10 seconds for the failback to happen, but it works :-)
			# /usr/sbin/arpspoof -i "$INTERFACE" 192.168.168.1 >/dev/null 2>&1 &
			# echo $! >/var/run/shapedsl.arpspoof.pid
			echo "startified"
		;;

			## Couldn't get red to work:
			# /sbin/tc qdisc add dev "$INTERFACE" parent 1:9 handle 19: red limit "$PIPE_PEAKBPS"kbit min "1"kbit max "$PIPE_PEAKBPS"kbit avpkt 1000 burst 2000 probability 0.01 bandwidth 100kbit

		start-simple)
			# /sbin/tc qdisc add dev "$INTERFACE" root tbf rate 0.5mbit burst 5kb latency 70ms peakrate 1mbit minburst 1540
			## From: http://lartc.org/lartc.html#AEN691
			/sbin/tc qdisc add dev "$INTERFACE" root tbf rate 99kbit burst 2000 latency 50ms
			## Note: if I change burst to 1000, ssh slows down dramatically, why?
			echo "startified"
		;;

		stop)
			/sbin/tc qdisc del dev "$INTERFACE" root # 2>/dev/null
			# if [ -r /var/run/shapedsl.arpspoof.pid ]
			# then
				# kill `cat /var/run/shapedsl.arpspoof.pid`
				# rm /var/run/shapedsl.arpspoof.pid
			# fi
		;;

		restart)
			$0 stop
			$0 start
		;;

		*)
			echo "Usage: $0 [start|stop|restart]"
			exit 1
		;;

esac

exit 0

