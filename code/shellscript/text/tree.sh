# runhugs $JPATH/code/haskell/tools/treelist.hs "$@"
TMPFILE=`jgettmp tree`
cat "$@" > $TMPFILE
$JPATH/code/haskell/tools/treelist.hs $TMPFILE |
vi - -R +":so ~/.vim/joey/joeyfolding.vim"
jdeltmp $TMPFILE

################# OLD STUFF (is it worth anything or should it be chucked?)
exit 0
#################

filetodiff () {
	echo "$1" > /tmp/1
	echo "$2" > /tmp/2
	CHARS=`
		cmp /tmp/1 /tmp/2 |
		sed "s/.*char \([^,]*\), line 1/\1/"
	`
	# cmp /tmp/1 /tmp/2
	# echo ">>> %%% >$CHARS<" > /dev/stderr
	if test "$CHARS" = ""; then
		printf "0"
	else
		# Needed since cmp only seems to start at char 2!
		CHARS=`expr "$CHARS" - 2`
		cat /tmp/1 | sed "s/\(.\)/\1\\
/g" | head -$CHARS | tr -d "\n"
	fi
}

STACK=""
CURRENT=""
LASTLINE=""
N=0

while read LINE; do
	echo ">>> "
	echo ">>> !!! $N >$CURRENT<" > /dev/stderr
	echo ">>> >>> $LINE"
	TODROP=""
	while ! startswith "$LINE" "$CURRENT"; do
		echo ">>> *** not inside current"
		N=`expr "$N" - 1`
		CURRENT=`echo "$STACK" | tail -1`
		STACK=`echo "SSTACK" | chop 1`
		echo ">>> ### end"
		TODROP="$TODROP
}"
	done
	if test ! "$TODROP" = ""; then
		echo "$LASTLINE $TODROP"
	else
		echo ">>> *** inside current"
		echo ">>> ((( $LASTLINE"
		DIFF=`
			filetodiff "$LASTLINE" "$LINE" |
			sed "s^$CURRENT"
		`
		EXTRACHARS=`echo "$DIFF" | awk ' { print length($0) } '`
		echo ">>> @@@ $EXTRACHARS $DIFF"
		if test "$DIFF" = "" || test "$EXTRACHARS" -lt 2; then
			echo ">>> ### normal"
			echo "$LASTLINE"
		else
			N=`expr "$N" + 1`
			STACK="$STACK
$CURRENT"
			echo ">>> ### start $DIFF"
			echo "{ + $DIFF"
			echo "$LASTLINE"
			CURRENT="$CURRENT$DIFF"
		fi
	fi
	LASTLINE="$LINE"
done

echo "$CURRENT"
while test "$N" -gt "0"; do
	N=`expr "$N" - 1`
	echo "} # for good measure"
done
