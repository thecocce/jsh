TARGET="$1"

[ "$TARGET" ] || exit 1



### Initialise

chroot "$TARGET" mount -t proc /proc proc

mv "$TARGET"/dev/null "$TARGET"/dev/null.b4
touch "$TARGET"/dev/null
chmod ugo+rw "$TARGET"/dev/null

mv "$TARGET"/dev/zero "$TARGET"/dev/zero.b4
dd if=/dev/zero bs=1024 count=100 of="$TARGET"/dev/zero
chmod ugo+r "$TARGET"/dev/zero

## Bind all the same mounts
for MNTPNT in /mnt/*
do
	if [ -d "$MNTPNT" ] && [ -d "$TARGET"/"$MNTPNT" ]
	then mount --bind "$MNTPNT" "$TARGET"/"$MNTPNT"
	fi
done



### Chroot

chroot "$@"



### Cleanup (should only do this if we are the last chroot to leave this TARGET)

chroot "$TARGET" umount -lf /proc

mv -f $TARGET/dev/null.b4 $TARGET/dev/null
mv -f $TARGET/dev/zero.b4 $TARGET/dev/zero

for MNTPNT in /mnt/*
do
	if [ -d "$MNTPNT" ] && [ -d "$TARGET"/"$MNTPNT" ] && df | grep "^$MNTPNT[ 	].*$TARGET/$MNTPNT$"
	then umount "$TARGET"/"$MNTPNT"
	fi
done
