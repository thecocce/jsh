## To find what external (and internal) programs a jsh script depends on, run this.  Without arguments, finds dependencies for all jsh scripts.  You need to do this to find reverse-dependencies (scripts which depend on a particular script).
## Note: you need to have all the programs on your system (!), otherwise add them to $LIST below.
## Hence, this script will eventually export the dependency info, so it can be useful on machines without those programs.
## (Eg. installj and updatejsh will remove scripts from $JPATH/tools if their dependencies are not met.)
## (Or: a . checkdependencies call will be added at the to of each script.)
## But it is often worth knowing the reverse dependencies too (what depends on me?) eg. to check if functionality change is ok.

## Note: We only examine .sh scripts for good reason.  TODO: I need to rename those .sh's which do not yet have an extension!

## TODO: Once dependencies for a script are found, allow insertion of dependency meta-info block in script.
##       Will it be a code block or will it actually be a call that checks?!
## TODO: Somehow we want efficient lookup of which package binaries come from.

PATHS_TO_SYSTEM_BINARIES="/bin /usr/bin /sbin"

## Ever-present programs which we don't want to observe dependencies on:
## TODO: turn this into a line-delimited list, and check which packages the progs belong to.
EVER_PRESENT='^\('
EVER_PRESENT="$EVER_PRESENT"'printf\|echo\|test\|clear\|cp\|mv\|ln\|rm\|ls\|kill\|'
EVER_PRESENT="$EVER_PRESENT"'touch\|mkdir\|tr\|sh\|nice\|sleep\|date\|'
EVER_PRESENT="$EVER_PRESENT"'chmod\|chgroup\|chown\|cat\|more\|head\|tail\|grep\|egrep\|du\|'
EVER_PRESENT="$EVER_PRESENT"'true\|false\|'
# EVER_PRESENT="$EVER_PRESENT"'mount\|sed\|cksum\|'
EVER_PRESENT="$EVER_PRESENT"'\)$'

## Will show up jsh programs as well as /bin ones.  (Faster without; even faster if specialised out!)
## Note: sometimes you will get duplicates, eg. 'lynx' and 'lynx (jsh)' in which case we have to decide whether on not the jsh one is really a dependency.
BOTHER_JSH=true
DISCRIMINATE_JSH=true
if test ! $BOTHER_JSH; then DISCRIMINATE_JSH=; fi



### Compile a list of programs which scripts could possibly depend on:

LIST=`jgettmp possdepslist`

(
	## TODO: Haven't yet included $HOME/bin (could just use $PATH!)
	find $PATHS_TO_SYSTEM_BINARIES -maxdepth 1 -type f
	test $BOTHER_JSH && (
		find $JPATH/tools -maxdepth 1 -type l |
		( test $DISCRIMINATE_JSH && sed 's+$+ (jsh)+' || cat )
	)
) |
afterlast / |
grep -v "$EVER_PRESENT" |
cat > $LIST

echo "There are `countlines $LIST` possible dependencies!"



### For each script, extract its words, and grep the proglist for the words:

TMPEXPR=`jgettmp findjshdeps_expr_partway`

if $DISCRIMINATE_JSH
then 
	endregexp () {
		printf '\\)\( \|$\)'
	}
else
	endregexp () {
		printf '\\)$'
	}
fi

if test "$*"
then

  for X
  do echo `realpath \`which "$X"\``
  done

else

  cd $JPATH/code/shellscript
  find . -type f -name "*.sh" -not -path "*/CVS/*"

fi |

while read SCRIPT
do
	
	## Extract all words in the script, and create a regexp from them:

	REGEXP=`
		printf '^\\('
		cat "$SCRIPT" |
		sed 's+#.*++' | ## Removes all comments from file (does get false-positives though)
		extractregex '[A-Za-z0-9_\-.]+' | ## couldn\'t get \<...\> to work
		removeduplicatelines |
		## Note: no need to remove shell builtin words because any which were in the proglist have been removed by EVER_PRESENT.
		tee $TMPEXPR |
		sed 's+$+\\\|+' |
		tr -d '\n' |
		sed 's+\\\|$++'
		endregexp
	`

	## Use the RE to extract any progs from the proglist which this scripts refers to:

	## A fix because grep does not handle big regexps well!
	NUMLINES=`cat $TMPEXPR | countlines`
	if test $NUMLINES -lt 200
	then
		grep "$REGEXP" "$LIST" &&
		echo "  is/are needed for $SCRIPT" ||
		echo "$SCRIPT is pure sh (or its dependencies are not present)"
		echo
	else
		error "skipping $SCRIPT because it has $NUMLINES words in it!"
	fi

done

## TODO: Show reverse dependencies.
