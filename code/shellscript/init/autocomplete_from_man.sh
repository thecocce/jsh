# @sourceme

## WARNING: If you try to source this script from some less-advanced shells (e.g. dash?), it may throw a syntax error when it tries to parse var=(...) array creation, even though it doesn't actually *run* that line!
# whichshell was reporting "zsh" although ZSH_NAME was not set.  Perhaps it was zsh running in a back-compat-mode?  Or whichshell was just wrong?  (This was when my .fluxbox/startup tried to load startj during a lightdm login on Ubuntu precise.)
#whichshell >&2
#echo "BASH=$BASH ZSH_NAME=$ZSH_NAME" >&2

# TO TEST: sometimes the first completion i try to make on a file with " "s in its name appears to break the args?  Is this our fault?

# TODO: Most annoying small bug is that occasionally we want to expand to a
# command not in cwd (e.g. when first call is et/withalldo/...), but most of
# the time we won't want the commands, only what is in cwd.

# TODO: Worse than being slow at the start, is being slow after a reboot.  So we Should keep the cache between reboots.  But we should also maintain it: refresh results once a month, delete unused removed commands.

## BIGGEST TODO: Some of the most obvious commands, eg. cd (which defaults to dirs only),
##               should not perform autocomplete_from_man (which currently overrides defaults for all commands with the same COMPCTL_OPTS).
##               Where can we get a list of ones to avoid doing this on, and go via some other defined default?
##               Really autocomplete_from_man should only be for uncommon commands which don't already default completion rules.
## Simplified: make autocomplete_from_man a fallback from better completion rules.  Find some better completion rules!

## TODO: this should go elsewhere: Does this script have the power to change the user's terminal shell environment?  If so, this technology could be useful, e.g. to reload functions from files when the files are changed, and other things to keep the shell fresh and avoid having to start a subshell or a whole new shell in order to get the latest dev version.

## autocomplete_from_man: Adds to bash or zsh the ability to use tab-completion for the - and -- options of the current command (provided it has a man page installed).
## eg.: source this script with ". ./autocomplete_from_man", then type: tar --<Tab>

## OK now I discovered zsh and bash both come with cool completion scripts (zsh u have to set it up using /usr/share/zsh/4.2.0/functions/Completion/compinstall)
## So if those scripts are on your system, it will source them, and will not bother to setup joeyComplete.
## If you have very old packages then you might not get so much from those scripts.

## CONSIDER: could get filename/type regexps from mimetypes!

## PROBLEM: with zsh at least, is that the command is post-aliased so if eg. the user type "man -"<Tab> then they get options for aliased jman script, not man itself.  (Since at time of writing, alias man=jman)

# jsh-depends: extractpossoptsfrommanpage
# jsh-ext-depends: sed find

## For Kipz; after testing, should be default off, user option to turn it on
# export SHOW_COMMAND_INFO=true

show_command_info () {
	if [ "$ARGS" = "" ] || [ "$ARGS" = - ]
	then
		if [ -n "$SHOW_COMMAND_INFO" ]
		then
			FOUND=
			if ( builtin "$COMMAND" ) >/dev/null 2>&1 ## This may be running the bash version; zsh's version of builtin may differ
			then printf "%s\n" " `cursegreen;cursebold`[$COMMAND is a shell builtin]`cursenorm`" >&2 ; FOUND=true
			fi
			if alias "$COMMAND" >/dev/null 2>&1
			then printf "%s\n" " `curseyellow`[$COMMAND is an alias to: ` alias "$COMMAND" 2>&1 | afterfirst "=" `]`cursenorm`" >&2 ; FOUND=true
			fi
			if declare -f "$COMMAND" >/dev/null 2>&1
			# if declare -f "$COMMAND" 2>/dev/null | grep . > /dev/null
			then printf "%s\n" " `cursecyan`[$COMMAND is a function: declare -F $COMMAND]`cursenorm`" >&2 ; FOUND=true
			fi
			if [ -e "$JPATH/tools/$COMMAND" ] ## BUG: this line causes "bad pattern" errors in zsh if an uncompleted [ is in the command
			# then printf "%s\n" " `cursered``cursebold`[$COMMAND is a jsh script]`cursenorm`" >&2 ; FOUND=true
			then printf "%s\n" " `cursered``cursebold`[$COMMAND is a jsh script (type jdoc $COMMAND for more info)]`cursenorm`" >&2 ; FOUND=true
			fi
			if [ ! "$FOUND" ]
			then
				# list_commands_in_path | grep "/$COMMAND$" ||
				which "$COMMAND" >/dev/null 2>&1 && printf "%s\n" " `cursegreen;cursebold`[`which "$COMMAND"`]`cursenorm`" >&2 ||
				printf "%s\n" " `cursered`[Could not find $COMMAND]`cursenorm`" >&2
			fi
		fi
	fi
}

## This is expensive, so memo it!  OK that wasn't working, so I disabled the filters below for the moment.
list_commands_in_path () {
		echo "$PATH" | tr ':' '\n' |
		# (EFF) removeduplicatelines |
		while read DIR
		# do [ -r "$DIR" ] && verbosely find "$DIR" -type f -maxdepth 1
		# do [ -r "$DIR" ] && find "$DIR" -maxdepth 1 | filter_list_with test -e | filter_list_with test -x
		do [ -r "$DIR" ] && find "$DIR" -maxdepth 1 # (EFF) disabled until efficient (memoed): | filter_list_with test -e | filter_list_with test -x
		done | sed 's+.*/++' # (EFF) | removeduplicatelines
}

## bash version:
if [ -n "$BASH" ]
then

	. jgettmpdir -top
	export BASH_COMPLETION_STORAGE_DIR="$HOME/.cache/autocomplete_from_man.bash"
	mkdir -p "$BASH_COMPLETION_STORAGE_DIR"
	## TODO: it appears this directory is being created but never used!

	## -g -s removed for odin's older bash

	joeyComplete () {
		COMMAND="$1"
		shift
		ARGS="$*"
		# memo show_command_info ## not working :| (jsh hasn't started?)
		show_command_info
		CURRENT=${COMP_WORDS[COMP_CWORD]}
		WORDS="--help "`
			MEMO_SHOW_INFO= NOINFO=1 MEMO_IGNORE_DIR=1 IKNOWIDONTHAVEATTY=1 MEMOFILE="$BASH_COMPLETION_STORAGE_DIR"/"$COMMAND".cached 'memo' -t '1 month' extractpossoptsfrommanpage "$COMMAND"
		`
		## Fix for bug: "it shows you the options, but doesn't let you complete them!" (because it's returning all options, not those which apply to $CURRENT)
		## Also acts as a cache, so future calls are faster:
		complete -W "$WORDS" -a -b -c -d -f -j -k -u "$COMMAND"
		# COMPREPLY=($WORDS)
		COMPREPLY=( $(compgen -W "$WORDS" -a -b -c -d -f -j -k -u -- "$CURRENT") )
	}

	## Since bash only runs completion on named commands, we must go and get the names of all commands in $PATH:
	# (Turned off all alternative completion types until I find a subset which works) ## -g not even possible on odin
	# complete -F joeyComplete `
	complete -a -b -c -d -f -g -j -k -s -u -F joeyComplete `list_commands_in_path`

## zsh version: I could not prevent named matches from continuing on to the glob function, despite use of "-tn".
## So I added an heuristic and simple caching to make it fast.
elif [ -n "$ZSH_NAME" ]
then

	. jgettmpdir -top
	export ZSH_COMPLETION_STORAGE_DIR="$HOME/.cache/autocomplete_from_man.zsh"
	mkdir -p "$ZSH_COMPLETION_STORAGE_DIR"

	joeyComplete () {
		read -c COMMAND ARGS
		## Heuristic:
		if [ -z "$ARGS" ]
		then
			reply=
		else
			# memo show_command_info ## not working :| (jsh hasn't started?)
			show_command_info
			## Cache:
			MEMOFILE="$ZSH_COMPLETION_STORAGE_DIR"/"$COMMAND".cached
			if [ ! -f "$MEMOFILE" ] || [ "$REMEMO" ]
			then
				mkdir -p `dirname "$MEMOFILE"` ## This works even if COMMAND is an alias with '/'s in path.
				#MEMO_SHOW_INFO= NOINFO=1 MEMO_IGNORE_DIR=1 IKNOWIDONTHAVEATTY=1 'memo' extractpossoptsfrommanpage "$COMMAND" > "$MEMOFILE"
				extractpossoptsfrommanpage "$COMMAND" > "$MEMOFILE"
			fi
			#AC_CHECK_ALIASES=true
			## This feature is rather annoying.  It might be useful as a warning, but it appears in the middle of your command!  We could hide it again, but it might flash so fast that we wouldn't see it.
			if [ -n "$AC_CHECK_ALIASES" ]
			then
				if alias "$COMMAND" >/dev/null 2>&1
				then echo -n "`curseyellow`<$COMMAND is an alias!>`cursenorm`" >/dev/stderr
				fi
			fi
			## The single brackets means an array
			reply=( "--help" $(cat "$MEMOFILE") )
			## Ne marche pas: compctl -f -c -u -r -k "($reply)" -H 0 '' "$COMMAND" -tn
		fi
	}

	## compctl is the old completion system.
	## This command used to work fine for me on Debian, but on more recent Ubuntu systems adding our own completion rule here stops completion from working properly on (in) filenames with spaces.
	## (I think compctl is preventing fallback to compsys, which usually handles such filenames well.)
	compctl -f -c -u -r -K joeyComplete "*" -tn
	## History made directory /s not work and was in general quite annoying for me:
	# -H 0 '' 

	## We could switch to using the new completion system, if I could work it out!  It is somewhat more complex.
	## Friendly guide: http://zsh.sourceforge.net/Guide/zshguide06.html
	## Official guide: http://zsh.sourceforge.net/Doc/Release/Completion-System.html
	#zstyle ":completion::*:*:*:" tag-order local-directories path-directories "(_alternative _cd)"

else

	echo "autocomplete_from_man does not know how add completion to this shell." >&2

fi
