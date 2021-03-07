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

;;;
;;; Return with carry flag clear as success indicator
;;;
retok	MACRO
	stc
	cmc
	ret
	ENDM

;;;
;;; Return with carry flag set as error indicator
;;;
reterr	MACRO
	stc
	ret
	ENDM

;;;
;;; Entry Point
;;;
main:
	call BAUD		; call system function to set serial timers
	call hexload		; call main function to load ihex
	jc   .err
	jmp  ENDE
.err:
	call FEHLN
	jmp  MLOOP

;;;
;;; Read Intel-HEX from serial port and write to memory
;;; Example:
;;;          len(2) addr(4) type(2) data(n)  checksum(2)
;;;          :04    8000    00      12345678 68
;;;          :00    0000    01               FF
;;; Type:
;;;   00 - Data
;;;   01 - End
;;;
;;; Registers:
;;;   B  - Record Type
;;;   C  - Flag for storing start address
;;;   DE - Destination
;;;   H  - Checksum
;;;   L  - Length
;;;
hexload:
	call pload
	mvi  c, 01h
.linestart:
	;;   START OF RECORD
	call ASCII
	cpi  ':'
	jnz  .linestart		; wait for start of record (':')
	;;   LENGTH
	call pprog
	call rxbyte
	rc			; return on error
	mov  l, a		; length
	mov  h, a		; init checksum
	;;   ADDRESS
	call rxbyte
	rc			; return on error
	mov  d, a		; destination byte 1
	add  h			; update checksum
	mov  h, a		; move to checksum register
	call rxbyte
	rc			; return on error
	mov  e, a		; destination byte 2
	add  h			; update checksum
	mov  h, a		; move to checksum register
	;;   store address
	sub  a
	ora  c
	jz   .skipaddr		; address has been stored already
	mvi  c, 00h
	mov  a, e
	sta  087e0h		; store start address to monitor ROM
	mov  a, d		; memory cells so that G or E key
	sta  087e1h		; will work right away
.skipaddr:
	;;   TYPE
	call rxbyte
	rc			; return on error
	mov  b, a		; record type
	add  h
	mov  h, a
	mov  a, b
	cpi  00h		; record 0 => read bytes
	jz   .loaddata
	cpi  01h		; record 1 => checksum
	jz   .checksum
	jmp  .err		; unkown record type => error
.loaddata:
	call pprog
.nextbyte:
	;;   DATA
	mov  a, l
	call rxbyte
	rc			; return on error
	stax d
	inx  d
	add  h			; update checksum
	mov  h, a
	dcr  l
	jnz  .nextbyte		; next byte of len > 0
.checksum:
	;;   CHECKSUM
	mov  a, h
	cma
	inr  a
	mov  h, a
	call rxbyte
	rc			; return on error
	cmp  h
	jnz  .err
	mov  a, b
	cpi  01h
	jnz  .linestart
	retok
.err:
	reterr

;;;
;;; Read an ASCII encoded byte from serial (two characters)
;;; end convert to binary
;;; Example: 3F
;;; Result: A, Carry on error
;;;
rxbyte:
	push b
	call ASCII
	call hexcnv
	jc   .err		; return on conversion error
	rlc
	rlc
	rlc
	rlc
	mov  b, a
	call ASCII
	call hexcnv
	jc   .err		; return on conversion error
	ora  b
	pop  b
	retok
.err:
	pop  b
	reterr


;;;
;;; Convert ASCII encoded HEX digit in A to value
;;; Result: A, Carry on error
;;;
hexcnv:
	cpi '0'
	jc  .err		; error when <= '0'
	cpi '9' + 1
	jnc .alphaupper		; continue with alpha when > '9'
	sui '0'
	retok
.alphaupper:
	cpi 'A'
	jc  .err		; error when <= 'A'
	cpi 'F' + 1
	jnc .alphalower		; continue with lower alpha when > 'F'
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
	reterr

;;;
;;; Print progress animation
;;;
pprog:
	lda  DIS_C8
.next1:	cpi  DIS_SD
	jnz  .next2
	mvi  a, DIS_SE
	sta  DIS_C8
	sta  DIS_C1
	ret
.next2: cpi  DIS_SE
	jnz  .next3
	mvi  a, DIS_SG
	sta  DIS_C8
	sta  DIS_C1
	ret
.next3:	cpi  DIS_SG
	jnz  .next4
	mvi  a, DIS_SC
	sta  DIS_C8
	sta  DIS_C1
	ret
.next4: mvi  a, DIS_SD
	sta  DIS_C8
	sta  DIS_C1
	ret

;;;
;;; Print text "_ LadE _"
;;;
pload:	push b
	lxi  b, ploads
	call TEXT8
	pop  b
	ret
ploads:
	db   DIS_SD, 0, DIS_L, DIS_A, DIS_D, DIS_E, 0, DIS_SD
