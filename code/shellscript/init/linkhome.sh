if test "$1" = "-diff"; then
	shift
	SHOWDIFFS=true
fi

cd "$JPATH/code/home" &&
find . |
	grep -v "/CVS$" | grep -v "/CVS/" |
	sed "s+^./++" | grep -v "^\.$" |
	while read X; do
		NICESOURCE="~/$X"
		SOURCE="$JPATH/code/home/$X"
		DEST="$HOME/$X"
		if test ! -d "$DEST" && test ! -f "$DEST"; then
			echo "~/$X <- $SOURCE"
			ln -sf "$SOURCE" "$DEST"
		else
			if test ! `realpath "$DEST"` = `realpath "$SOURCE"`; then
				echo "problem: $NICESOURCE is in the way of $DEST"
				if test ! -d "$SOURCE" && test $SHOWDIFFS; then
					gvimdiff "$DEST" "$SOURCE"
				fi
			else
				echo "ok: $NICESOURCE"
			fi
		fi
	done
