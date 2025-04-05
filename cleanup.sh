#!/bin/sh

[ -z "$GAME" ] && export GAME=e17
[ -z "$TL_SUFFIX" ] && export TL_SUFFIX=en

rm -rf ${GAME}_mac/ ${GAME}_etc/ ${GAME}_iso_extracted/ ${GAME}_mac_*/ ${GAME}_etc_*/ ${GAME}_se/ ${GAME}_se_mod/ ${GAME}_bg/ ${GAME}_bg_*/
rm -rf bin/
rm -rf workdir workdir-${GAME}
rm -rf text/mac-*-only*/ text/mac-${GAME}-*-only*/
rm -rf text/tmp-${GAME}
rm -rf text/font/${GAME}
rm -f patch/${GAME}-${TL_SUFFIX}.xdelta
rm -f iso/${GAME}-repacked.iso iso/${GAME}-${TL_SUFFIX}-repacked.iso
rm -f pbp/EBOOT-${GAME}-${TL_SUFFIX}.PBP
