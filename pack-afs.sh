#!/bin/bash

[ -z "$GAME" ] && export GAME=e17

ISO_RES_DIR=${GAME}_iso_extracted/PSP_GAME/USRDIR
ISO_BIN_DIR=${GAME}_iso_extracted/PSP_GAME/SYSDIR
WORKDIR=./workdir-${GAME}
COMPRESS=./bin/compressbip
REPACK_AFS=./bin/repack_afs
REPACK_SCENE=text/repack_scene.py
ARMIPS=./tools/armips
SIGN_NP=./tools/sign_np # placeholder
PY=python3
if [ "$(uname)" = "Darwin" ]; then
	ARMIPS=./tools/armips_osx
	SIGN_NP=./tools/sign_np_osx # placeholder
elif [ "$(uname)" = "Linux" ]; then
	ARMIPS=./tools/armips_lin64
	SIGN_NP=./tools/sign_np_lin64
fi

# change this for other translations
# set to "en" if unset
[ -z "$TL_SUFFIX" ] && export TL_SUFFIX=en

# Repack mac.afs (texts)
repack_mac_afs () {
	repack_scene () {
		[ $# -ge 2 ] && in=$2 || in=text/tmp-${GAME}/mac-psp-${TL_SUFFIX}/$1.txt
		$REPACK_SCENE $in ${GAME}_mac/$1.SCN ${GAME}_mac_${TL_SUFFIX}/$1.SCN
		$COMPRESS ./${GAME}_mac_${TL_SUFFIX}/$1.{SCN,BIP}
	}

	mkdir -p ${GAME}_mac_${TL_SUFFIX}/
	mkdir -p text/tmp-${GAME}/mac-psp-jp-${TL_SUFFIX}-names

	$PY ./py-src/apply_shortcuts_translation.py text/other-psp-${GAME}-${TL_SUFFIX}/SHORTCUT.SCN.txt ${GAME}_mac/SHORTCUT.SCN ${GAME}_mac_${TL_SUFFIX}/SHORTCUT.SCN ${TL_SUFFIX} || exit 1
	$COMPRESS ./${GAME}_mac_${TL_SUFFIX}/SHORTCUT.{SCN,BIP}
	if [ -e text/other-psp-${GAME}-${TL_SUFFIX}/APPEND.SCN.txt ]; then
		$PY ./py-src/apply_shortcuts_translation.py text/other-psp-${GAME}-${TL_SUFFIX}/APPEND.SCN.txt ${GAME}_mac/APPEND.SCN ${GAME}_mac_${TL_SUFFIX}/APPEND.SCN ${TL_SUFFIX} -a || exit 1
		$COMPRESS ./${GAME}_mac_${TL_SUFFIX}/APPEND.{SCN,BIP}
	fi

	for i in text/tmp-${GAME}/mac-psp-${TL_SUFFIX}/*.txt ; do
		echo Repacking $i
		repack_scene $(basename $i .txt) #& WAITPIDS="$! "$WAITPIDS
	done
	for i in text/tmp-${GAME}/mac-psp-jp/USER[0-9]*.txt ; do
		[ ! -f $i ] && break
		[ -e text/tmp-${GAME}/mac-psp-${TL_SUFFIX}/$(basename $i) ] && continue
		echo Patching $i
		f=$(basename $i .txt)
		$PY ./py-src/patch_speaker.py $i text/tmp-${GAME}/mac-psp-jp-${TL_SUFFIX}-names/$f.txt
		repack_scene $f text/tmp-${GAME}/mac-psp-jp-${TL_SUFFIX}-names/$f.txt
	done
	# wait $WAITPIDS &> /dev/null
	echo "Finished repacking scenes"

	if [ -f ${GAME}_mac_${TL_SUFFIX}/SL2D4_3.SCN ]; then
		echo "Fixing SL2D4_3.SCN"
 		printf "\x05" | dd oflag=seek_bytes conv=notrunc seek=160 of=./${GAME}_mac_${TL_SUFFIX}/SL2D4_3.SCN
	 	$COMPRESS ./${GAME}_mac_${TL_SUFFIX}/SL2D4_3.{SCN,BIP}
	fi

	$REPACK_AFS $WORKDIR/mac.afs $WORKDIR/mac-repacked.afs ./${GAME}_mac_${TL_SUFFIX} || exit 1
	mv -f $WORKDIR/mac-repacked.afs $ISO_RES_DIR/mac.afs
}

# Compose and repack font
# compose_font builds the font file
compose_font () {
	mkdir -p ${GAME}_etc_${TL_SUFFIX}
	cd text/font/${GAME}
	cp -f ../glyphs-new/* glyphs/
	if [ "cn" == "$TL_SUFFIX" ]; then
		7z x ../glyphs-cn.7z
		mv -f ../glyphs-cn/* glyphs/
	else
		cp ../glyphs-en/* glyphs/
	fi
	$PY ../../../py-src/extract_font.py repack glyphs/ || exit 1
	cp FONT00.NEW ../../../${GAME}_etc_${TL_SUFFIX}/FONT00.NEW
	cd ../../..
}

# repack_etc_afs repacks etc.afs with the new font file from "compose_font"
repack_etc_afs () {
	compose_font

	if [ -f ${GAME}_etc_${TL_SUFFIX}/FONT00.NEW ]; then
	$COMPRESS ${GAME}_etc_${TL_SUFFIX}/FONT00.NEW ${GAME}_etc_${TL_SUFFIX}/FONT00.FOP
	$REPACK_AFS $WORKDIR/etc.afs $WORKDIR/etc-repacked.afs ${GAME}_etc_${TL_SUFFIX} || exit 1
	mv -f $WORKDIR/etc-repacked.afs $ISO_RES_DIR/etc.afs
	fi
}

# Repack init.bin
repack_init_bin () {
	echo "Applying translation to init.bin"
	# Apply init.bin strings
	$PY ./py-src/apply_init_translation.py text/other-psp-${GAME}-${TL_SUFFIX}/init.bin.utf8.txt $WORKDIR/init.dec $WORKDIR/init.dec.${TL_SUFFIX} ${TL_SUFFIX} || exit 1

	INIT_SRC=$WORKDIR/init.dec.${TL_SUFFIX}
	if [ ! -f $INIT_SRC ]; then
		# If modified file does not exist, just repack the original one.
		# Used for testing purposes
		INIT_SRC=$WORKDIR/init.dec
	fi
	echo "Compressing $INIT_SRC -> $WORKDIR/init.${TL_SUFFIX}.bin"
	$COMPRESS $INIT_SRC $WORKDIR/init.${TL_SUFFIX}.bin || exit 1
	mv -f $WORKDIR/init.${TL_SUFFIX}.bin $ISO_RES_DIR/init.bin
}

# Patch BOOT.BIN
patch_boot_bin () {
	# Apply translation
	echo "Applying translation to BOOT"
	$PY ./py-src/apply_boot_translation.py text/other-psp-${GAME}-${TL_SUFFIX}/BOOT.utf8.txt $WORKDIR/BOOT.BIN $WORKDIR/BOOT.BIN.${TL_SUFFIX} ${TL_SUFFIX} || exit 1

	echo "Applying other patches to BOOT"
	mv -f $WORKDIR/BOOT.BIN.${TL_SUFFIX} $WORKDIR/BOOT.BIN.patched
	if [ "cn" == "${TL_SUFFIX}" ]; then
		$ARMIPS src/boot-patches-${GAME}-cn.asm -root $WORKDIR/ || exit 1
	else
		$ARMIPS src/boot-patches-${GAME}.asm -root $WORKDIR/ || exit 1
	fi
	mv -f $WORKDIR/BOOT.BIN.patched $WORKDIR/BOOT.BIN.${TL_SUFFIX}

	rm -f $ISO_BIN_DIR/BOOT.BIN
	rm -f $ISO_BIN_DIR/EBOOT.BIN
	cp -f $WORKDIR/BOOT.BIN.${TL_SUFFIX} $ISO_BIN_DIR/BOOT.BIN
	cp $ISO_BIN_DIR/BOOT.BIN $ISO_BIN_DIR/EBOOT.BIN
	if command -v $SIGN_NP >/dev/null 2>&1; then
		$SIGN_NP -elf $ISO_BIN_DIR/BOOT.BIN $ISO_BIN_DIR/EBOOT.BIN 1
	fi
}

repack_e17_se_afs () {
	[ -d "e17_x360_BGM" ] && [ -f "$WORKDIR/se.afs" ] || return
	mkdir -p e17_se_mod
	for i in $(seq -w 1 22) 24
	do
		cp e17_x360_BGM/bgm${i}.adx e17_se_mod/ADX${i}.ADX
		cp e17_x360_BGM/bgm${i}nl.adx e17_se_mod/ADX${i}NL.ADX
	done
	cp e17_x360_BGM/bgm25.adx e17_se_mod/ADX26.ADX
	cp e17_x360_BGM/bgm25nl.adx e17_se_mod/ADX26NL.ADX
	$REPACK_AFS $WORKDIR/se.afs $WORKDIR/se_mod.afs e17_se_mod || exit 1
	mv -f $WORKDIR/se_mod.afs $ISO_RES_DIR/se.afs
}

repack_bg_afs () {
	mkdir -p ${GAME}_bg_${TL_SUFFIX}
	for i in bg-${GAME}-${TL_SUFFIX}/*.R11 ; do
		[ ! -f $i ] && break
		$COMPRESS $i ${GAME}_bg_${TL_SUFFIX}/$(basename $i .R11).BIP || exit 1
	done
	for i in bg-${GAME}-${TL_SUFFIX}/*.GIM ; do
		[ ! -f $i ] && break
		$COMPRESS $i ${GAME}_bg_${TL_SUFFIX}/$(basename $i .GIM).T2P || exit 1
	done

	$REPACK_AFS $WORKDIR/bg.afs $WORKDIR/bg-repacked.afs ./${GAME}_bg_${TL_SUFFIX} || exit 1
	mv -f $WORKDIR/bg-repacked.afs $ISO_RES_DIR/bg.afs
}

repack_ev_afs () {
	mkdir -p ${GAME}_ev_${TL_SUFFIX}
	for i in ev-${GAME}-${TL_SUFFIX}/*.R11 ; do
		[ ! -f $i ] && break
		$COMPRESS $i ${GAME}_ev_${TL_SUFFIX}/$(basename $i .R11).BIP || exit 1
	done
	for i in ev-${GAME}-${TL_SUFFIX}/*.GIM ; do
		[ ! -f $i ] && break
		$COMPRESS $i ${GAME}_ev_${TL_SUFFIX}/$(basename $i .GIM).T2P || exit 1
	done

	$REPACK_AFS $WORKDIR/ev.afs $WORKDIR/ev-repacked.afs ./${GAME}_ev_${TL_SUFFIX} || exit 1
	mv -f $WORKDIR/ev-repacked.afs $ISO_RES_DIR/ev.afs
}

# Actually running above functions
[ "$GAME" = "e17" ] && repack_e17_se_afs
[ -e $WORKDIR/bg.afs ] && repack_bg_afs
[ -e $WORKDIR/ev.afs ] && repack_ev_afs
repack_mac_afs
repack_etc_afs
repack_init_bin
patch_boot_bin
