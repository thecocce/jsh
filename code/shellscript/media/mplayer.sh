#!/bin/sh
# jsh-ext-depends: killall
# jsh-ext-depends-ignore: expand xscreensaver
# jsh-depends: unj verbosely

# if [ "$USE_SCREEN_LIKE_MADPLAY" ]
# then
	# echo "Called: mplayer $*" >> /tmp/mplayer_script.log
	# madplay "$@"; exit
# fi

## See also: new versions of mplayer have a -stop-xscreensaver option
## consider: could killall -STOP it, then unhalt it at end.
killall xscreensaver && XSCREENSAVER_WAS_RUNNING=true
## Despite Debian accepting the -stop-xscreensaver option now, xscreensaver still appears!

OPTS="-vo gl,xv,x11" ## under gentoo this selects x11 which is slow
# OPTS="-vo x11" ## No acceleration, always works.  Lets me adjust contrast.
# OPTS="-vo xv" ## I thought this allowed us to adjust contrast but it doesn't right now.
# OPTS="-vo sdl" ## good if the machine is slow (but not so pretty)
## OK all -vo options turned off.  Recommend setting in /etc/mplayer/mplayer.conf or ~/.mplayer.conf
## Audio driver defaults to /etc/mplayer.conf or ~/.mplayer/config?
# OPTS="$OPTS -ao sdl -zoom -idx"
OPTS="$OPTS -zoom -idx"  # -vf scale
OPTS="$OPTS -stop-xscreensaver"
OPTS="$OPTS -cache 8192"

while true
do
	case "$1" in
		-turbo)
			OPTS="$OPTS -vo sdl"; shift
		;;
		-louder)
			OPTS="$OPTS -af volume=+20dB"; shift
		;;
		-putsubsbelow)
			OPTS="$OPTS -vf expand=0:-140:0:+70 -subpos 100"; shift
		;;
		-fast)
			FAST=1 ; shift
		;;
		-faster)
			FAST=2 ; shift
		;;
		*)
			break
		;;
	esac
done

## Some highly compressed videos can be too slow to fully decompress!
# FAST=1
## Mplayer recommends:
# [ "$FAST" ] && OPTS="$OPTS -ao sdl -vfm ffmpeg -lavdopts lowres=1:fast:skiploopfilter=all"
## But I found this was enough for me and not so bad quality (autoq/sync may not be needed):
## G's A:
[ "$FAST" = 0 ] && OPTS="$OPTS -ao sdl -vfm ffmpeg -autoq 5 -autosync 5"
## KMD under Compiz:
# [ "$FAST" ] && OPTS="$OPTS -ao sdl -vfm ffmpeg -autoq 5 -autosync 5 -framedrop -hardframedrop"
## BSG S3:
# [ "$FAST" ] && OPTS="$OPTS -ao sdl -vfm ffmpeg -lavdopts lowres=1:fast -autoq 5 -autosync 5"
## Enterprise:
# [ "$FAST" ] && OPTS="$OPTS -ao sdl -vfm ffmpeg -lavdopts lowres=2:fast -autoq 5 -autosync 5"
## BSG S4.  lowres has no affect, -vo sdl helped SMPlayer under a busy compiz
## but prevents gamma correction (works ok in smplayer anyway):
## -vo x11 appears to work better than -vo xv under compiz.  sometimes with xv
## we get "X11 error: BadAlloc (insufficient resources for operation)"
# [ "$FAST" ] && OPTS="$OPTS -ao sdl -vo x11 -vfm ffmpeg -autoq 5 -autosync 5 -framedrop"
## Others (Sunny highly compress h264):
# [ "$FAST" ] && OPTS="$OPTS -nobps -ni -forceidx -mc 0"
[ "$FAST" = 1 ] && OPTS="$OPTS -vfm ffmpeg -lavdopts lowres=0:fast:skiploopfilter=all -autoq 5 -autosync 5" # -framedrop 
## Note that -framedrop can be undesirable if the video is a highly-compressed
## h264 - it will cause us to frequently lose large chunks!
## A heavy flv from YouTube (crashes on HTLGI video!):
[ "$FAST" = 2 ] && OPTS="$OPTS -vfm ffmpeg -lavdopts lowres=1:fast:skiploopfilter=all"

## AFAIK VNC only works with the x11 vo:
if [ "$VNCDESKTOP" = "X" ]
then OPTS="$OPTS -vo x11"
fi
## xv is more efficient though

## Graphic equalizer
[ "$EQ" ] || EQ="none"
[ "$EQ" = wireless ]   && OPTS="$OPTS -af equalizer=0:0:1:1:2:2:3:3:4:4" ## Louder middle and treble
[ "$EQ" = headphones ] && OPTS="$OPTS -af equalizer=4:3:2:1:1:0:0:0:0:0" ## Louder bass
[ "$EQ" = speakers ]   && OPTS="$OPTS -af equalizer=2:3:3:2:1:0:0:0:0:0" ## Louder bass and middle

#                     gam:con:bri:sat:rg :gg :bg :weight
# OPTS="$OPTS -vf eq2=1.0:1.0:0.0:1.0:0.6:1.0:1.0"  ## Fix red gamma on hwi
# OPTS="$OPTS -vf eq2=1.0:1.0:0.0:1.0:0.7:1.0:1.0"  ## Fix red gamma on hwi
# OPTS="$OPTS -vf eq2=1.0:1.2:0.0:1.0:0.8:1.1:1.1"  ## Fix red gamma on hwi and increase contrast
# OPTS="$OPTS -vf eq2=1.2:1.0:0.0:1.0:1.0:1.1:1.1"  ## Fix red gamma on hwi and increase gamma
# OPTS="$OPTS -vo x11" ## keeps my x gamma fixes, but doesn't scale (don't use this and eq2!)
# OPTS="$OPTS -vo gl"  ## keeps x fixes, but a little blue just like eq2

[ "$MPLAYER" ] || MPLAYER=mplayer
verbosely unj $MPLAYER $OPTS "$@"

[ "$XSCREENSAVER_WAS_RUNNING" ] && xscreensaver -no-splash &
