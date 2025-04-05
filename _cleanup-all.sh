#!/bin/sh

./_cleanup-e17-x360.sh
for i in e17 n7 r11; do
	for j in en cn; do
		GAME=$i TL_SUFFIX=$j ./cleanup.sh
	done
done
