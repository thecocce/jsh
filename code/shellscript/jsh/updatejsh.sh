echo "Changing to jsh root"
cd "$JPATH/code/shellscript/" || exit 1

echo "Updating files from cvs"
cvsupdate -AdP

if test ! "$1" = "-quick"
then

	echo "Linking files into PATH (do not interrupt, disable with -quick)"
	refreshtoollinks

	echo "jsh is up to date =)"

fi
