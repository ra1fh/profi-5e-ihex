;;;
;;; Copyright (c) 2021 Ralf Horstmann <ralf@ackstorm.de>
;;;
;;; Permission to use, copy, modify, and distribute this software for any
;;; purpose with or without fee is hereby granted, provided that the above
;;; copyright notice and this permission notice appear in all copies.
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
;;; WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
;;; MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
;;; ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
;;; WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
;;; ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
;;; OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
;;;

;;; IHEX reader that can be installed into a unused location of the
;;; Profi-5E monitor ROM at 0x0fa8

			title	"Intel-HEX Reader"
	IFDEF	EMBED
	org	00fa8h
	ELSE
	org	02000h
	ENDIF

	include	"profi-5e-library.def"
	include	"profi-5e-display.def"

retok	MACRO
	stc
	cmc
	ret
	ENDM

;;;
;;; Entry Point
;;;
main:
	call BAUD
	call hexload
	jc   .err
	call pend
	hlt
.err:
	call perr
	hlt

;;;
;;; Read Intel-HEX from serial port and write to memory
;;; Example:
;;;           len(2) addr(4) type(2) data(n) checksum(2)
;;;           :048000001234567868
;;; 	      :00000001FF
;;; Type:
;;;   00 - Data
;;;   01 - End
;;;
;;; Registers:
;;;   B  - Record Type
;;;   DE - Destination
;;;   H  - Checksum
;;;   L  - Length
;;;
hexload:
.linestart:
	;;   START OF RECORD
	call pstat1
	call ASCII
	cpi  ':'
	jnz  .linestart				; wait for start of record (':')
	;;   LENGTH
	call pstat2
	call rxbyte
	rc					; return on error
	mov  l, a				; length
	mov  h, a				; init checksum
	;;   ADDRESS
	call pstat3
	call rxbyte
	call pstat4
	rc					; return on error
	mov  d, a				; destination byte 1
	add  h					; update checksum
	mov  h, a				; move to checksum register
	call rxbyte
	rc					; return on error
	mov  e, a				; destination byte 2
	add  h					; update checksum
	mov  h, a				; move to checksum register
	;;   TYPE
	call pstat5
	call rxbyte
	rc					; return on error
	mov  b, a				; record type
	add  h
	mov  h, a
	mov  a, b
	cpi  00h				; record 0 => read bytes
	jz   .nextbyte
	cpi  01h				; record 1 => checksum
	jz   .checksum
	jmp  .err				; unkown record type => error
	mov  a, l
	cpi  00h				; in case record length is 0
	jz   .checksum				; jump to checksum validation
.nextbyte:
	;;   DATA
	call pstat6
	call rxbyte
	rc					; return on error
	stax d
	inx  d
	add  h					; update checksum
	mov  h, a
	dcr  l
	jnz  .nextbyte				; next byte of len > 0
.checksum:
	;;   CHECKSUM
	mov  a, h
	cma
	inr  a
	mov  h, a
	call pstat7
	call rxbyte
	rc					; return on error
	cmp  h
	jnz  .err
	mov  a, b
	cpi  01h
	jnz  .linestart
	retok
.err:
	stc
	ret

;;;
;;; Read an ASCII encoded byte from serial (two characters)
;;; end convert to binary
;;; Example: 3F
;;; Result: A, Carry on error
;;;
;;; Clobbers register c in order to be able to use rc
;;;
rxbyte:
	call ASCII
	call hexcnv
	rc					; return on conversion error
	rlc
	rlc
	rlc
	rlc
	mov c, a
	call ASCII
	call hexcnv
	rc					; return on conversion error
	ora c
	retok

;;;
;;; Convert ASCII encoded HEX digit in A to value
;;; Result: A, Carry on error
;;;
hexcnv:
	cpi '0'
	jc  .err				; error when <= '0'
	cpi '9' + 1
	jnc .alphaupper				; continue with alpha when > '9'
	sui '0'
	retok
.alphaupper:
	cpi 'A'
	jc  .err				; error when <= 'A'
	cpi 'F' + 1
	jnc .alphalower				; continue with lower alpha when > 'F'
	sui 'A' - 10
	retok
.alphalower:
	cpi 'a'
	jc  .err
	cpi 'f' + 1
	jnc .err
	sui 'a' - 10
	retok
.err:
	stc
	ret

;;;
;;; Print status to display
;;;

pend:
	push b
	lxi b, tend
	call TEXT8
	pop b
	ret
tend:
	db	DIS_L, DIS_O, DIS_A, DIS_D, 00h, DIS_E, DIS_N, DIS_D

perr:
	push b
	lxi b, terr
	call TEXT8
	pop b
	ret
terr:
	db	DIS_L, DIS_O, DIS_A, DIS_D, 00h, DIS_E, DIS_R, DIS_R

pstat1:
	push b
	lxi	 b, tstat1
	call TEXT8
	pop b
	ret
tstat1:
	db	DIS_L, DIS_O, DIS_A, DIS_D, DIS_E, DIS_R, 00, DIS_1

pstat2:
	push b
	lxi	 b, tstat2
	call TEXT8
	pop b
	ret
tstat2:
	db	DIS_L, DIS_O, DIS_A, DIS_D, DIS_E, DIS_R, 00, DIS_2

pstat3:
	push b
	lxi	 b, tstat3
	call TEXT8
	pop b
	ret
tstat3:
	db	DIS_L, DIS_O, DIS_A, DIS_D, DIS_E, DIS_R, 00, DIS_3

pstat4:
	push b
	lxi	 b, tstat4
	call TEXT8
	pop b
	ret
tstat4:
	db	DIS_L, DIS_O, DIS_A, DIS_D, DIS_E, DIS_R, 00, DIS_4

pstat5:
	push b
	lxi	 b, tstat5
	call TEXT8
	pop b
	ret
tstat5:
	db	DIS_L, DIS_O, DIS_A, DIS_D, DIS_E, DIS_R, 00, DIS_5

pstat6:
	push b
	lxi	 b, tstat6
	call TEXT8
	pop b
	ret
tstat6:
	db	DIS_L, DIS_O, DIS_A, DIS_D, DIS_E, DIS_R, 00, DIS_6

pstat7:
	push b
	lxi	 b, tstat7
	call TEXT8
	pop b
	ret
tstat7:
	db	DIS_L, DIS_O, DIS_A, DIS_D, DIS_E, DIS_R, 00, DIS_7

	END
