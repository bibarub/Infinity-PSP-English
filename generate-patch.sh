#!/bin/sh

[ -z "$GAME" ] && export GAME=e17
[ -z "$TL_SUFFIX" ] && export TL_SUFFIX=en
REPACKED_ISO=./iso/${GAME}-${TL_SUFFIX}.iso
PATCH_FILE=./patch/${GAME}-${TL_SUFFIX}.xdelta
if [ "$GAME" = "r11" ]; then
	ORIGINAL_ISO=./iso/Remember11-jap.iso
elif [ "$GAME" = "n7" ]; then
	ORIGINAL_ISO=./iso/Never7-jap.iso
else
	ORIGINAL_ISO=./iso/Ever17-jap.iso
fi

rm $PATCH_FILE 2>/dev/null

echo "generating $(basename $PATCH_FILE)"
xdelta3 -v -e -S lzma -9 -B 2147483648 -A -s $ORIGINAL_ISO $REPACKED_ISO $PATCH_FILE || exit 1
echo "done!"
