# jsh-depends: memo rememo importshfn jgettmpdir jshinfo
# this-script-does-not-depend-on-jsh: jsh
## jsh-help: Uses onelinedescription to build an apropos-like database for jsh

## Check out 'whatis'

case "$1" in

	-builddb)

		## TODO: factor this out as "prepare_fast_memoing":
		. jgettmpdir -top
		. importshfn rememo
		. importshfn memo
		export IKNOWIDONTHAVEATTY=true
		export MEMO_IGNORE_DIR=true

		case "$2" in

			jsh-man)

				. importshfn onelinedescription

				'ls' "$JPATH/tools/" |
				catwithprogress |
				while read SCRIPT
				do
					# echo -e -n "$SCRIPT(jsh)\t- "
					# printf "%s(jsh)\t- " "$SCRIPT"
					DIRNAME=`realpath "$JPATH/tools/$SCRIPT" | beforelast / | afterlast /`
					printf "%s\t- " "$DIRNAME/$SCRIPT(jsh)"
					# memo onelinedescription "$SCRIPT"
					## Since we are memoing the whole thing externally, little point running memo again internally (here)
					onelinedescription "$SCRIPT"
					# memo -f "$JPATH/tools/$SCRIPT" onelinedescription "$SCRIPT"
					# memo -f `realpath "$JPATH/tools/$SCRIPT" onelinedescription "$SCRIPT"
				done

			;;

			executable-commands)

				echo "$PATH" | tr : "\n" |
				removeduplicatelines |
				catwithprogress |
				while read DIR
				do
					find "$DIR"/
				done |
				filter_list_with test -f | ## file or symlink to existing file
				filter_list_with test -x

			;;

			system-apropos-db)
				# `jwhich apropos` .
				unj apropos .
			;;

			*)
				jshwarn "No such db: $2"
			;;

		esac

			# system-packages)
				# # findpkg -all . | drop 5
				# COLUMNS=300 verbosely findpkg -all . | striptermchars | tee /tmp/xxx | sed 's+\(   \) *+	+g' | drop 5
			# ;;

	;;

	*)
		[ "$2" ] && jshwarn "Only using first arg \"$1\", discarding \"$2\" ..."

		export MEMO_IGNORE_DIR=true

		echo ; sleep 1 ## I think stderr was coming before stdout, due to | highlight
		jshinfo "System packages:"
		# verbosely memo -c true aproposjsh -builddb system-packages | grep -i -u "$@" |
		# columnise -on "	"
		# findpkg -all "$@" | striptermchars
		findpkg -all "$@" | striptermchars | highlight -bold "^.i" green

		echo
		## This one should duplicates system apropos and jsh manpages, with maybe a few extras.
		jshinfo "Executable commands on PATH:"
		memo aproposjsh -builddb executable-commands | grep -i -u ".*/[^/]*$@"

		echo
		jshinfo "System apropos:"
		memo aproposjsh -builddb system-apropos-db | grep -i -u "$@"

		echo
		jshinfo "Jsh apropos:"
		memo aproposjsh -builddb jsh-man | grep -i -u "$@"

		echo
	;;

esac
