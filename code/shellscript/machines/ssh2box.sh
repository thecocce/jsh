# echo $0

if test "$1" = ""; then
	echo "ssh2box <user>@<address> [<extra-args>]"
	exit 1
fi

SSHCOM="ssh -C $@"
TITLE="$*"

# Problem: Unix hostname does not allow this!
SHORTHOSTNAME=`hostname`
DOMAIN=`host "$SHORTHOSTNAME" | sed "s/[^\.]*\.//;s/ .*//"`
if test "$DOMAIN" = `echo "$1" | afterfirst "\."`; then
	echo "Both on $DOMAIN: forwarding X session."
	SSHCOM="$SSHCOM -X"
fi

if xisrunning; then
	# xterm -bg "#500000" -title "$TITLE" -e $SSHCOM &
	# xterm -bg "#002800" -title "$TITLE" -e $SSHCOM &
	xterm -bg "#003000" -title "$TITLE" -e $SSHCOM &
else
	xttitle "$TITLE"
	$SSHCOM
fi
