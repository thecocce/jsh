## Still too high for Boris:
# vncserver -geometry 980x680
## Better for Boris:
# vncserver -geometry 800x480
## Try for Boris:
# vncserver -geometry 800x520

## Nice and big:
# I wanted -dpi 80 but Gnome (xscreensaver) lost its fonts
# vncserver -depth 16 -geometry 1024x768 -dpi 75
# vncserver -depth 16 -geometry 1024x768 -dpi 100
ADDRESS=`
	vncserver -depth 16 -geometry 800x600 -dpi 75 2>&1 |
	pipeboth |
	grep "desktop is " | after "desktop is "
`

# echo "Found: >$ADDRESS<"

if xisrunning
then sleep 5; xvncviewer "$ADDRESS"
else sleep 5; svncviewer "$ADDRESS"
fi
