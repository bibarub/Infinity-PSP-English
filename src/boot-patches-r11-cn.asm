.psp
.relativeinclude off

.open "BOOT.BIN.patched", 0x08803F60

; Do not call sceImposeSetLanguageMode to avoid overriding language settings
.orga 0x7620
.area 4
        addu v0, zero, zero
.endarea

; Decrease line spacing in fullscreen text.
;.org 0x881CCB0
;.area 4
;	addiu a2, v0, -0x1
;.endarea

; Fix the text bug for "All Choices:". (Inlined strcpy didn't copy the last char)
.org 0x8828084
.area 4*3, 0
	lw    v0, 0x14(v1)
	blez  s1,0x08828498
	sw    v0, 0x14(s0)
.endarea


; Increases the size of the glyph buffer for choice lines from 22 to 44
; (Caused some choice lines to be overwritten by the following ones)
.org 0x0881FE54
.area 4*2, 0
	sll	v0,a2,0x6
	sll	a2,a2,0x2
.endarea

.close
