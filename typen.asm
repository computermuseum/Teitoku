BasicUpstart2(start)

#import "zeropage.inc"

.const screen = $0400

start:
	// set to 25 line text mode and turn on the screen
	lda #$1B
	sta $D011

	// disable SHIFT-Commodore
	lda #$80
	sta $0291

	// set screen memory ($0400) and charset bitmap offset ($2000)
	lda #$18
	sta $D018

	// set border color
	lda #$0E
	sta $D020

	// set background color
	lda #$06
	sta $D021

	// draw screen
	lda #$00
	sta $fb
	sta $fd
	sta $f7

	lda #$28
	sta $fc

	lda #$04
	sta $fe

	lda #$e8
	sta $f9
	lda #$2b
	sta $fa

	lda #$d8
	sta $f8

	ldx #$00
	ldy #$00
	lda ($fb),y
	sta ($fd),y
	lda ($f9),y
	sta ($f7),y
	iny
	bne *-9

	inc $fc
	inc $fe
	inc $fa
	inc $f8

	inx
	cpx #$04
	bne *-24

init:
	sei

	// use all RAM available
	lda #$35
	sta $1

	// set dummy irqs
	lda #<irq_dummy
	sta $fffa
	sta $fffc
	sta $fffe
	lda #>irq_dummy
	sta $fffb
	sta $fffd
	sta $ffff

	// setup vic stuff
	lda #$1b
	sta $d011

	lda #$01
	sta $d01a
	// init timers
	lda #$7f
	sta $dc0d
	sta $dd0d
	lda $dc0d
	lda $dd0d
	// purge pending interrupts
	asl $d019

	cli

	// initialise zeropage memory
	lda #0
	sta cursor_x
	sta cursor_y

	lda #<screen
	sta rowptr + 0
	lda #>screen
	sta rowptr + 1

main:
	jsr Keyboard
	bcs !done+

	cmp #$ff         // Keyboard returns ff if special key
	beq !done+       // we don't parse special keys, go to end

	// mask higher bits just in case to prevent out of bounds access
	and #$3f
	cmp #$1f
	// if not found, acc will be zero. if zero, check for consonant
	tax
	lda tbl_aieuo, x // a = tbl_aieuo[x]

	beq !consonant+

	jsr putchar
	jmp main

!consonant:
	// if key == 'k'
	cpx #$0b
	bne !+
	inc $d020 // debug statement
	jmp kconsonant
!:
	// key != 'k'
	lda tbl_consonant, x
	beq !done+

	// print ka,ki,ku,ke,ko
	jsr putchar
	jmp main

!done:
	jmp main

	// remove character and move back cursor. wraps around
!erase:
	ldy cursor_x
	dey
	bpl !+           // check if --cursor_x >= 0
	ldy #40 - 1      // cursor_x is negative, wrap around
!:
	lda #0
	sta (rowptr),y   // store 0 at screen position

	sty cursor_x     // update cursor_x
	jmp main

	rts

kconsonant:
	// doesnt work yet as the key is still being pressed
	// maybe the carry set and A value can be used as in kbd.asm
	jsr Keyboard
	bcs !done+

	cmp #$ff         // Keyboard returns ff if special key
	beq !done+       // we don't parse special keys, go to end

	// mask higher bits just in case to prevent out of bounds access
	and #$3f
	cmp #$1f

	tax
	lda tbl_kcons, x

	inc $d020

	bne !done+
	jsr putchar
!done:
	jmp main

putchar:
	ldy cursor_x     // load offset cursor_x
	sta (rowptr),y   // mem[*rowptr + cursor_x] = a

	iny              // if (++cursor_x >= 40) cursor_x = 0
	cpy #40
	bmi !+
	ldy #0
!:
	sty cursor_x
	rts

irq_dummy:
	asl $d019 // acknowledge interrupt
	rti

// lookup table for keyboard codes to character rom codes
// zero means unused/invalid
tbl_aieuo:
	.byte 0, $8f, 0, 0, 0, $bf, 0, 0
	.byte 0, $9f, 0, 0, 0, 0, 0, $cf
	.byte 0, 0, 0, 0, 0, $af, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0

// first letters of syllables starting with consonant:
//   k s t n h m y r w n

// alphabetic:
//   h k m n r s t w y
tbl_consonant:
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte $8a, 0, 0, $8e, 0, $89, $8b, 0
	.byte 0, 0, $87, $8d, $8c, 0, 0, $86
	.byte 0, $88, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0

tbl_kcons:
	.byte 0, $8e, 0, 0, 0, $be, 0, 0
	.byte 0, $9e, 0, 0, 0, 0, 0, $ce
	.byte 0, 0, 0, 0, 0, $ae, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0

.pc = * "keyboard driver"

#import "kbd.asm"

// Character bitmap definitions 2k
*=$2000 "charrom"
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$E0, $A0, $E0, $00, $F0, $60, $40, $80
	.byte	$A0, $A0, $00, $00, $F0, $60, $40, $80
	.byte	$00, $00, $00, $00, $F0, $60, $40, $80
	.byte	$00, $00, $00, $00, $B0, $D0, $40, $20
	.byte	$A0, $A0, $00, $00, $00, $00, $00, $00
	.byte	$40, $20, $00, $02, $04, $18, $60, $00
	.byte	$00, $7E, $42, $42, $04, $08, $30, $00
	.byte	$38, $00, $7C, $04, $04, $08, $30, $00
	.byte	$20, $7E, $22, $24, $10, $10, $10, $00
	.byte	$00, $7E, $02, $24, $18, $08, $04, $00
	.byte	$00, $24, $24, $22, $42, $42, $00, $00
	.byte	$08, $08, $7E, $08, $08, $08, $30, $00
	.byte	$20, $3E, $22, $4A, $04, $0A, $30, $00
	.byte	$24, $7E, $24, $24, $04, $08, $30, $00
	.byte	$10, $7E, $12, $12, $22, $22, $46, $00
	.byte	$7E, $02, $14, $10, $10, $20, $40, $00
	.byte	$E0, $A0, $E0, $00, $20, $40, $C0, $40
	.byte	$A0, $A0, $00, $00, $20, $40, $C0, $40
	.byte	$00, $00, $00, $00, $20, $40, $C0, $40
	.byte	$00, $00, $00, $00, $00, $C0, $40, $E0
	.byte	$E0, $A0, $E0, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $44, $44, $44, $44, $04, $18, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$18, $06, $30, $0C, $60, $18, $04, $00
	.byte	$00, $40, $44, $78, $40, $40, $3C, $00
	.byte	$00, $3C, $00, $00, $00, $7E, $00, $00
	.byte	$08, $30, $10, $7C, $10, $10, $20, $00
	.byte	$20, $10, $40, $22, $04, $18, $60, $00
	.byte	$20, $3C, $70, $10, $1E, $78, $08, $00
	.byte	$02, $04, $18, $68, $08, $08, $08, $00
	.byte	$E0, $A0, $E0, $00, $40, $E0, $20, $40
	.byte	$A0, $A0, $00, $00, $40, $E0, $20, $40
	.byte	$00, $00, $00, $00, $40, $E0, $20, $40
	.byte	$00, $00, $00, $E0, $20, $E0, $20, $E0
	.byte	$E0, $A0, $E0, $00, $B0, $D0, $40, $20
	.byte	$A0, $A0, $00, $00, $B0, $D0, $40, $20
	.byte	$00, $28, $28, $28, $2A, $4C, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $78, $08, $08, $08, $08, $7E, $00
	.byte	$10, $10, $20, $24, $44, $7E, $02, $00
	.byte	$00, $7E, $02, $02, $04, $08, $30, $00
	.byte	$00, $7E, $02, $14, $08, $14, $60, $00
	.byte	$00, $02, $52, $54, $04, $08, $10, $00
	.byte	$00, $7C, $04, $04, $08, $14, $62, $00
	.byte	$20, $3E, $22, $42, $04, $08, $30, $00
	.byte	$10, $7C, $44, $04, $04, $08, $30, $00
	.byte	$E0, $A0, $E0, $00, $00, $E0, $40, $E0
	.byte	$A0, $A0, $00, $00, $00, $E0, $40, $E0
	.byte	$00, $00, $00, $00, $00, $E0, $40, $E0
	.byte	$78, $48, $48, $78, $48, $48, $78, $00
	.byte	$E0, $A0, $E0, $00, $00, $C0, $40, $E0
	.byte	$A0, $A0, $00, $00, $00, $C0, $40, $E0
	.byte	$00, $20, $20, $20, $22, $2C, $30, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $04, $14, $08, $08, $14, $20, $00
	.byte	$00, $00, $30, $48, $04, $02, $00, $00
	.byte	$10, $7C, $04, $08, $38, $54, $10, $00
	.byte	$00, $38, $00, $7C, $10, $10, $20, $00
	.byte	$20, $7E, $22, $24, $20, $20, $1E, $00
	.byte	$20, $3E, $28, $48, $08, $10, $20, $00
	.byte	$7C, $10, $10, $10, $10, $7C, $00, $00
	.byte	$E0, $A0, $E0, $20, $F0, $60, $A0, $40
	.byte	$A0, $A0, $00, $20, $F0, $60, $A0, $40
	.byte	$00, $00, $00, $20, $F0, $60, $A0, $40
	.byte	$78, $48, $78, $48, $78, $48, $88, $00
	.byte	$E0, $A0, $E0, $E0, $20, $E0, $20, $E0
	.byte	$A0, $A0, $00, $E0, $20, $E0, $20, $E0
	.byte	$00, $7E, $02, $3E, $04, $08, $30, $00
	.byte	$00, $7E, $42, $42, $42, $7E, $42, $00
	.byte	$00, $7C, $04, $7C, $04, $7C, $04, $00
	.byte	$7C, $10, $10, $7C, $10, $10, $0E, $00
	.byte	$10, $FE, $10, $54, $92, $10, $30, $00
	.byte	$00, $04, $04, $08, $08, $10, $20, $00
	.byte	$10, $10, $18, $14, $10, $10, $10, $00
	.byte	$00, $02, $22, $24, $04, $08, $10, $00
	.byte	$00, $7E, $02, $02, $02, $02, $7E, $00
	.byte	$08, $7E, $18, $18, $28, $48, $18, $00
	.byte	$00, $3C, $42, $42, $42, $42, $3C, $00
	.byte	$00, $00, $00, $FE, $00, $00, $00, $00
	.byte	$00, $7C, $00, $00, $00, $FE, $00, $00
	.byte	$00, $7C, $00, $38, $00, $FE, $00, $00
	.byte	$FE, $AA, $AA, $AA, $CE, $82, $FE, $00
	.byte	$FE, $10, $7C, $14, $24, $44, $FE, $00
	.byte	$10, $FE, $00, $28, $28, $44, $82, $00
	.byte	$20, $20, $26, $F8, $20, $22, $3C, $00
	.byte	$00, $1C, $04, $24, $24, $42, $42, $00
	.byte	$20, $20, $FC, $24, $24, $24, $42, $00
	.byte	$10, $10, $10, $FE, $10, $10, $10, $00
	.byte	$7E, $10, $3C, $24, $3C, $24, $3C, $00
	.byte	$0C, $70, $10, $7C, $10, $10, $10, $00
	.byte	$00, $7E, $10, $1C, $24, $24, $4C, $00
	.byte	$06, $04, $04, $04, $00, $00, $00, $00
	.byte	$00, $00, $00, $20, $20, $20, $60, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $80, $40, $00
	.byte	$00, $00, $00, $00, $E0, $A0, $E0, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00
	.byte	$00, $00, $00, $00, $00, $00, $00, $00

// screen character data
*=$2800 "screen"
	.byte	$20, $20, $20, $20, $20, $20, $20, $20, $20, $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $20, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $00, $00, $8F, $9F, $AF, $BF, $CF, $00, $00, $00, $00, $00, $00, $20, $00, $00, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $00, $00, $8E, $9E, $AE, $BE, $CE, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $8D, $9D, $AD, $BD, $CD, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $8C, $9C, $AC, $BC, $CC, $20, $20, $20, $20, $20, $20, $20, $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $00, $8B, $9B, $AB, $BB, $CB, $20, $20, $20, $20, $20, $20, $01, $01, $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $8A, $9A, $AA, $BA, $CA, $20, $20, $20, $20, $20, $20, $20, $20, $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $89, $99, $A9, $B9, $C9, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $88, $20, $A8, $20, $C8, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $87, $96, $A6, $B6, $C7, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $86, $20, $00, $20, $C6, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $D0, $D1, $D2, $D3, $D4, $D5, $D6, $D7, $D8, $D9, $DA, $DB, $DC, $DD, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $00, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.byte	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

// screen color data
*=$2be8 "color"
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
	.byte	$0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
