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
;;; Profi-5E monitor ROM at 0x0fa8 or to 0x2000 for testing

	title	"Intel-HEX Reader"

	include	"profi-5e-library.def"
	include	"profi-5e-display.def"

	IFDEF	EMBED
	;; 	Patch F-0 to point to 0x2000 for testing
	org	0027CH
	dw	02000H
	;;	Patch F-E to point to start address
	org	00298H
	dw	00FA8H
	;; 	Code starts at 0x0FA8
	org	00FA8H
	ELSE
	;;	For testing set start address to second ROM,
	;; 	reachable with patched monitor ROM via F-0
	org	02000H
	ENDIF

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
	call pstart
.linestart:
	;;   START OF RECORD
	mvi  a, DIS_SD
	sta  DIS_C8
	call ASCII
	cpi  ':'
	jnz  .linestart				; wait for start of record (':')
	;;   LENGTH
	mvi  a, DIS_SE
	sta  DIS_C8
	call rxbyte
	rc					; return on error
	mov  l, a				; length
	mov  h, a				; init checksum
	;;   ADDRESS
	mvi  a, DIS_SF
	sta  DIS_C8
	call rxbyte
	rc					; return on error
	mov  d, a				; destination byte 1
	add  h					; update checksum
	mov  h, a				; move to checksum register
	mvi  a, DIS_SA
	sta  DIS_C8
	call rxbyte
	rc					; return on error
	mov  e, a				; destination byte 2
	add  h					; update checksum
	mov  h, a				; move to checksum register
	;;   TYPE
	mvi  a, DIS_SB
	sta  DIS_C8
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
	mvi  a, DIS_SC
	sta  DIS_C8
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
	mvi  a, DIS_SD | DIS_DP
	sta  DIS_C8
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

pstart:
	push b
	lxi  b, tstart
	call TEXT8
	pop  b
	ret
tstart:
	db   DIS_L, DIS_O, DIS_A, DIS_D, DIS_E, DIS_R, 00, DIS_D

pend:
	push b
	lxi  b, tend
	call TEXT8
	pop  b
	ret
tend:
	db   DIS_L, DIS_O, DIS_A, DIS_D, 00h, DIS_E, DIS_N, DIS_D

perr:
	push b
	lxi  b, terr
	call TEXT8
	pop  b
	ret
terr:
	db   DIS_L, DIS_O, DIS_A, DIS_D, 00h, DIS_E, DIS_R, DIS_R


