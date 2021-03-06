; Elite C64 disassembly / Elite : Harmless, cc-by-nc-sa 2018-2019,
; see LICENSE.txt. "Elite" is copyright / trademark David Braben & Ian Bell,
; All Rights Reserved. <github.com/Kroc/elite-harmless>
;===============================================================================

; clear the screen entirely. the HUD will be drawn or erased according to the
; current screen (main / menu) so this handles the transition between the two
;
clear_screen:                                                           ;$B21A
;===============================================================================
        ; reset the colour-map (the colour-nybbles held in the text screen)
        ;-----------------------------------------------------------------------
        ; set starting position in top-left of the centred
        ; 32-char (256px) viewport Elite uses
        lda #< (ELITE_MENUSCR_ADDR + .scrpos( 0, 4 ))
        sta ZP_TEMP_ADDR1_LO
        lda #> (ELITE_MENUSCR_ADDR + .scrpos( 0, 4 ))
        sta ZP_TEMP_ADDR1_HI

        ldx # 24                        ; colour 24 rows

@row:   lda # .color_nybble( WHITE, BLACK )                             ;$B224
        ldy # ELITE_VIEWPORT_COLS-1     ; 32 columns (0-31)

        ; colour one row
:       sta [ZP_TEMP_ADDR1], y                                          ;$B228
        dey
        bpl :-

        ; move to the next row
        lda ZP_TEMP_ADDR1_LO    ; get the row lo-address
        clc
        adc # 40                ; add 40 chars (one screen row)
        sta ZP_TEMP_ADDR1_LO
        bcc :+                  ; remains under 255?
        inc ZP_TEMP_ADDR1_HI    ; if not, increase the hi-address

:       dex                     ; decrement remaining row count         ;$B238
        bne @row

        ;-----------------------------------------------------------------------
        ; erase the bitmap area above the HUD,
        ; i.e. the viewport
        ;
        ; calculate the number of bytes in the bitmap above the HUD
        erase_bytes             = .bmppos( ELITE_HUD_TOP_ROW, 0 )
        ; from this calculate the number of bytes in *whole* pages
        erase_bytes_pages       = (erase_bytes / 256) * 256
        ; and the remaining bytes that don't fill one page
        erase_bytes_remain      = erase_bytes - erase_bytes_pages

        ldx #> ELITE_BITMAP_ADDR
:       jsr erase_page                                                  ;$B23D
        inx
        cpx #> (ELITE_BITMAP_ADDR + erase_bytes_pages)
        bne :-

        ; erase the non-whole-page remainder
        ldy #< (ELITE_BITMAP_ADDR + erase_bytes_pages + erase_bytes_remain - 1)
        jsr erase_page_from
        sta [ZP_TEMP_ADDR1], y

        ; set cursor position to row/col 2 on Elite's screen
        lda # 1
        sta ZP_CURSOR_COL
        sta ZP_CURSOR_ROW
        
        lda ZP_SCREEN           ; are we in the cockpit-view?
       .bze :+                  ; yes -- HUD will be redrawn

        cmp # $0d               ;?
        bne @_b25d

:       jmp _b301                                                       ;$B25A

@_b25d:                                                                 ;$B25D
        ;-----------------------------------------------------------------------
        ; will switch to menu screen during the interrupt
        lda # ELITE_VIC_MEMORY_MENUSCR
        sta _a8db

        lda # $c0               ; default value
        sta _a8e1

        ; erase bitmap to end?
        ; TODO: fix for VIC bank 3
:       jsr erase_page                                                  ;$B267
        inx
        cpx #> (ELITE_BITMAP_ADDR + $2000)
        bne :-

        ldx # $00
        stx _1d01               ;?
        stx _1d04               ;?

        ; set text-cursor to row/col 2
        inx
        stx ZP_CURSOR_COL
        stx ZP_CURSOR_ROW

.ifdef  OPTION_ORIGINAL
        ;///////////////////////////////////////////////////////////////////////
        jsr fill_sides          ; fills outside the viewport!?
.endif  ;///////////////////////////////////////////////////////////////////////
        jsr hide_all_ships
        jsr disable_sprites

        ldy # ELITE_VIEWPORT_COLS-1
        lda # .color_nybble( YELLOW, BLACK )

:       sta ELITE_MENUSCR_ADDR + .scrpos( 0, 4 ), y                     ;$B289
        dey
        bpl :-

        ldx ZP_SCREEN
        cpx # $02
        beq _b2a5

        cpx # $40
        beq _b2a5
        cpx # $80
        beq _b2a5

        ldy # ELITE_VIEWPORT_COLS-1

:       sta ELITE_MENUSCR_ADDR + .scrpos( 2, 4 ), y                     ;$B29F
        dey
        bpl :-

_b2a5:                                                                  ;$B2A5
        ldx # 199               ; last pixel row
        jsr _b2d5               ; draw the bottom screen border

        ;???
        lda # %11111111
        sta ELITE_BITMAP_ADDR + 7 + .bmppos( 24, 35 )                   ;=$5F1F

        ldx # $19
        ; this causes the next instruction to become a meaningless `bit`
        ; instruction, a very handy way of skipping without branching
       .bit

_b2b2:                                                                  ;$B2B2
        ldx # $12
        stx ZP_C0

        ldy # 3 * 8             ; 3rd char in bitmap cells
        sty ZP_TEMP_ADDR1_LO
        ldy #> ELITE_BITMAP_ADDR
        lda # %00000011
        jsr _b2e1

        ldy #< (ELITE_BITMAP_ADDR + .bmppos( 0, 36 ))   ;=$4120
        sty ZP_TEMP_ADDR1_LO

        ldy #> (ELITE_BITMAP_ADDR + .bmppos( 0, 36 ))   ;=$4120
        lda # %11000000
        ldx ZP_C0
        jsr _b2e1

        lda # $01
        sta ELITE_BITMAP_ADDR + .bmppos( 0, 35 )                        ;=$4118

        ldx # $00

_b2d5:                                                                  ;$B2D5
        ;-----------------------------------------------------------------------
        ; draw the horizontal border
        ; X = pixel row (i.e. 0 or 199)
        ;
        stx ZP_VAR_Y            ; first pixel row
        ldx # $00
        stx ZP_VAR_X1           ; X1 = 0
        dex                     ; $00 -> $FF
        stx ZP_VAR_X2           ; X2 = 255
        jmp draw_straight_line

_b2e1:                                                                  ;$B2E1
        ;-----------------------------------------------------------------------
        ; draw the vertical border
        sta ZP_BE
        sty ZP_TEMP_ADDR1_HI
@loop:                                                                  ;$B2E5
        ldy # $07
:       lda ZP_BE                                                       ;$B2E7
        eor [ZP_TEMP_ADDR1], y
        sta [ZP_TEMP_ADDR1], y
        dey
        bpl :-
        lda ZP_TEMP_ADDR1_LO
        clc
        adc # $40
        sta ZP_TEMP_ADDR1_LO
        lda ZP_TEMP_ADDR1_HI
        adc # $01
        sta ZP_TEMP_ADDR1_HI

        dex
        bne @loop

        rts

;;.else   ;///////////////////////////////////////////////////////////////////////
;;        ; improved screen-clearing code for elite-harmless
;;        ; (doesn't erase the bytes outside of the 256px-wide viewport)
;;        ;-----------------------------------------------------------------------
;;        ; erase the bitmap area above the HUD,
;;        ; i.e. the viewport
;;        ;
;;.ifndef USE_ILLEGAL_OPCODES
;;
;;        ; erasing bitmap bits...
;;        lda # %00000000
;;
;;        ; we need to loop a full 256 times and we want to keep the exit check
;;        ; fast (so testing for zero/non-zero). starting at $FF won't do, as a
;;        ; zero-check at the bottom will exit out before the 0'th loop has been
;;        ; done. ergo, we start at 0, the `dex` at the bottom will underflow
;;        ; back to $FF and we loop around until back to $00 where the loop
;;        ; will exit without repeating the 0'th iteration
;;        ;
;;        tax 
;;.else
;;        ; as above, but using a single (illegal) opcode
;;        lax # %00000000
;;.endif
;;:       ; begin loop, erasing one byte
;;        ; of all viewport rows at once
;;        ;
;;        sta (ELITE_BITMAP_ADDR + ( 0 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( 1 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( 2 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( 3 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( 4 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( 5 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( 6 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( 7 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( 8 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( 9 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + (10 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + (11 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + (12 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + (13 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + (14 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + (15 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + (16 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + (17 * 320) + (4 * 8)), x
;;        dex 
;;       .bnz :-
;;
;;        ; are we in the cockpit-view?
;;        ldy ZP_SCREEN           ; (Y is used here to keep A & X = $00)
;;       .bze :+                  ; yes -- HUD will be redrawn
;;
;;        cpy # $0d               ;?
;;        bne @hud
;;
;;        ; redraw the HUD
;;:       jmp _b301
;;
;;        ; erase the HUD to make way for the menu screen:
;;@hud:   ; begin loop, erasing one byte of all HUD rows at once
;;        sta (ELITE_BITMAP_ADDR + ( ELITE_HUD_TOP_ROW + 0 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( ELITE_HUD_TOP_ROW + 1 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( ELITE_HUD_TOP_ROW + 2 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( ELITE_HUD_TOP_ROW + 3 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( ELITE_HUD_TOP_ROW + 4 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( ELITE_HUD_TOP_ROW + 5 * 320) + (4 * 8)), x
;;        sta (ELITE_BITMAP_ADDR + ( ELITE_HUD_TOP_ROW + 6 * 320) + (4 * 8)), x
;;        dex 
;;       .bnz @hud
;;
;;        ; (note that X will be $00 due to loop condition above)
;;        stx _1d01               ;?
;;        stx _1d04               ;?
;;
;;        ; set text-cursor to row/col 2
;;        ; (note that X will be $00 due to loop condition above)
;;        inx                     ; X = $01
;;        stx ZP_CURSOR_COL
;;        stx ZP_CURSOR_ROW
;;        
;;        ; will switch to menu screen during the interrupt
;;        lda # ELITE_VIC_MEMORY_MENUSCR
;;        sta _a8db
;;
;;        lda # $c0               ; default value
;;        sta _a8e1
;;
;;        jsr hide_all_ships
;;        jsr disable_sprites
;;
;;        ; in progress
;;        ;...
;;
;;_b2a5:                                                                 ;$B2A5
;;        ldx # 199               ; last pixel row
;;        jsr _b2d5               ; draw the bottom screen border
;;
;;        ;???
;;        lda # %11111111
;;        sta ELITE_BITMAP_ADDR + 7 + .bmppos( 24, 35 )                   ;=$5F1F
;;
;;        ldx # $19
;;        ; this causes the next instruction to become a meaningless `bit`
;;        ; instruction, a very handy way of skipping without branching
;;       .bit
;;
;;_b2b2:                                                                  ;$B2B2
;;        ldx # $12
;;        stx ZP_C0
;;
;;        ldy # 3 * 8             ; 3rd char in bitmap cells
;;        sty ZP_TEMP_ADDR1_LO
;;        ldy #> ELITE_BITMAP_ADDR
;;        lda # %00000011
;;        jsr _b2e1
;;
;;        ldy #< (ELITE_BITMAP_ADDR + .bmppos( 0, 36 ))   ;=$4120
;;        sty ZP_TEMP_ADDR1_LO
;;
;;        ldy #> (ELITE_BITMAP_ADDR + .bmppos( 0, 36 ))   ;=$4120
;;        lda # %11000000
;;        ldx ZP_C0
;;        jsr _b2e1
;;
;;        lda # $01
;;        sta ELITE_BITMAP_ADDR + .bmppos( 0, 35 )                        ;=$4118
;;
;;        ldx # $00
;;
;;_b2d5:                                                                  ;$B2D5
;;        ;-----------------------------------------------------------------------
;;        ; draw the horizontal border
;;        ; X = pixel row (i.e. 0 or 199)
;;        ;
;;        stx ZP_VAR_Y            ; first pixel row
;;        ldx # $00
;;        stx ZP_VAR_X1           ; X1 = 0
;;        dex                     ; $00 -> $FF
;;        stx ZP_VAR_X2           ; X2 = 255
;;        jmp draw_straight_line
;;
;;_b2e1:                                                                  ;$B2E1
;;        ;-----------------------------------------------------------------------
;;        ; draw the vertical border
;;        sta ZP_BE
;;        sty ZP_TEMP_ADDR1_HI
;;@loop:                                                                  ;$B2E5
;;        ldy # $07
;;:       lda ZP_BE                                                       ;$B2E7
;;        eor [ZP_TEMP_ADDR1], y
;;        sta [ZP_TEMP_ADDR1], y
;;        dey
;;        bpl :-
;;        lda ZP_TEMP_ADDR1_LO
;;        clc
;;        adc # $40
;;        sta ZP_TEMP_ADDR1_LO
;;        lda ZP_TEMP_ADDR1_HI
;;        adc # $01
;;        sta ZP_TEMP_ADDR1_HI
;;
;;        dex
;;        bne @loop
;;
;;
;;.endif  ;///////////////////////////////////////////////////////////////////////

_b301:                                                                  ;$B301
        jsr _b2b2

        lda # $91
        sta _a8db               ; default value is $81

        lda # $d0
        sta _a8e1               ; default value is $C0

        lda _1d04               ; is HUD visible? (main or menu screen?)
        bne _b335

        ; reset the HUD graphics from the copy kept in RAM
        ;-----------------------------------------------------------------------
        ; the HUD is a 256px wide bitmap (with borders on the outside though).
        ; this routine 'clears' the HUD by restoring a clean copy from RAM
        ;
.import __HUD_COPY_RUN__

.ifdef  OPTION_ORIGINAL
        ;///////////////////////////////////////////////////////////////////////
        ; the original Elite code does a rather inefficient byte-by-byte copy.
        ; for every byte copied, additional cycles are spent on decrementing
        ; the 16-bit address pointers and the slower indirect-X addressing
        ; mode is used -- but in a rather rediculous case of this being a
        ; rushed port from the BBC this routine also copies all the blank
        ; space left and right of the HUD *every frame*!
        ;
        ldx # 8                 ; number of pages to copy (8*256)
        lda #< __HUD_COPY_RUN__
        sta ZP_TEMP_ADDR3_LO
        lda #> __HUD_COPY_RUN__
        sta ZP_TEMP_ADDR3_HI

        hud_bmp = ELITE_BITMAP_ADDR + .bmppos( ELITE_HUD_TOP_ROW, 0 )   ;=$5680

        lda #< hud_bmp
        sta ZP_TEMP_ADDR1_LO
        lda #> hud_bmp
        sta ZP_TEMP_ADDR1_HI
        jsr block_copy

        ldy # $c0               ; remainder bytes?
        ldx # $01
        jsr block_copy_from

.else   ;///////////////////////////////////////////////////////////////////////
        ;
        ; improved HUD-copy for Elite : Harmless
        ;
        ; we need to loop a full 256 times and we want to keep the exit check
        ; fast (so testing for zero/non-zero). starting at $FF won't do, as a
        ; zero-check at the bottom will exit out before the 0'th loop has been
        ; done. ergo, we start at 0, the `dex` at the bottom will underflow
        ; back to $FF and we loop around until back to $00 where the loop
        ; will exit without repeating the 0'th iteration
        ;
        ldx # $00

        ; here we copy one byte of 7 bitmap rows at a time. note that the
        ; bitmap data is stored in 256px strips (in Elite : Harmless),
        ; not 320px. doing 7 copies per loop reduces the cost of loop-testing
        ; (very slow to exit-test for every byte copied!) and also allows us
        ; to use the absolute-X adressing mode which costs 5 cycles each rather
        ; than 6 for the original code's use of indirect-X addressing
        ;
        bmp = ELITE_BITMAP_ADDR

        ; TODO: we could `.repeat` this for the number of rows defined by
        ;       `ELITE_HUD_HEIGHT_ROWS`
        ;
:       lda __HUD_COPY_RUN__, x         ; read from row 1 of backup HUD
        sta bmp + .bmppos( 18, 4 ), x   ; write to row 18 of bitmap screen
        lda __HUD_COPY_RUN__ + $100 , x ; read from row 2 of backup HUD
        sta bmp + .bmppos( 19, 4 ), x   ; write to row 19 of bitmap screen
        lda __HUD_COPY_RUN__ + $200, x  ; read from row 3 of backup HUD
        sta bmp + .bmppos( 20, 4 ), x   ; write to row 20 of bitmap screen
        lda __HUD_COPY_RUN__ + $300, x  ; read from row 4 of backup HUD
        sta bmp + .bmppos( 21, 4 ), x   ; write to row 21 of bitmap screen
        lda __HUD_COPY_RUN__ + $400, x  ; read from row 5 of backup HUD
        sta bmp + .bmppos( 22, 4 ), x   ; write to row 22 of bitmap screen
        lda __HUD_COPY_RUN__ + $500, x  ; read from row 6 of backup HUD
        sta bmp + .bmppos( 23, 4 ), x   ; write to row 23 of bitmap screen
        lda __HUD_COPY_RUN__ + $600, x  ; read from row 7 of backup HUD
        sta bmp + .bmppos( 24, 4 ), x
        dex
       .bnz :-

        ; borders to the left and right of the HUD lay outside the 256px
        ; centred HUD.
        ;
        ; TODO: this should be drawn only once during initialisation,
        ;       as with the new HUD-copying method it never gets erased
        ;
        ldx # $08
:       dex
        lda # %00000010                 ; yellow multi-color pixel on the right
        sta bmp + .bmppos( 18, 3 ), x   ; draw left-border on bitmap row 18
        sta bmp + .bmppos( 19, 3 ), x   ; draw left-border on bitmap row 19
        sta bmp + .bmppos( 20, 3 ), x   ; draw left-border on bitmap row 20
        sta bmp + .bmppos( 21, 3 ), x   ; draw left-border on bitmap row 21
        sta bmp + .bmppos( 22, 3 ), x   ; draw left-border on bitmap row 22
        sta bmp + .bmppos( 23, 3 ), x   ; draw left-border on bitmap row 23
        sta bmp + .bmppos( 24, 3 ), x   ; draw left-border on bitmap row 24
        lda # %10000000                 ; yellow multi-color pixel on the left
        sta bmp + .bmppos( 18, 36 ), x  ; draw right-border on bitmap row 18
        sta bmp + .bmppos( 19, 36 ), x  ; draw right-border on bitmap row 19
        sta bmp + .bmppos( 20, 36 ), x  ; draw right-border on bitmap row 20
        sta bmp + .bmppos( 21, 36 ), x  ; draw right-border on bitmap row 21
        sta bmp + .bmppos( 22, 36 ), x  ; draw right-border on bitmap row 22
        sta bmp + .bmppos( 23, 36 ), x  ; draw right-border on bitmap row 23
        sta bmp + .bmppos( 24, 36 ), x  ; draw right-border on bitmap row 24
        txa
        bne :-

.endif  ;///////////////////////////////////////////////////////////////////////

        jsr hide_all_ships
        jsr _2ff3

_b335:                                                                  ;$B335
.ifdef  OPTION_ORIGINAL
        ;///////////////////////////////////////////////////////////////////////
        jsr fill_sides          ; fills outside the viewport!
.endif  ;///////////////////////////////////////////////////////////////////////
        jsr disable_sprites

        lda # $ff
        sta _1d04

        rts

hide_all_ships:                                                         ;$B341
;===============================================================================
; appears to make all entities invisible to the radar scanner.
;
        ; search through the poly objects in-play
        ldx # $00

@next:  lda SHIP_SLOTS, x       ; what type of entitiy is here?         ;$B343
       .bze @rts                ; no more ships once we hit a $00 marker
        bmi :+                  ; skip over planets/suns

        jsr get_polyobj         ; get address of entity storage

        ; make the entitiy invisible to the radar!

        ldy # PolyObject::visibility
        lda [ZP_POLYOBJ_ADDR], y
        and # visibility::scanner ^$FF  ;=%11101111
        sta [ZP_POLYOBJ_ADDR], y

:       inx                                                             ;$B355
        bne @next

@rts:   rts                                                             ;$B358

.ifdef  OPTION_ORIGINAL
;///////////////////////////////////////////////////////////////////////////////
; fills the borders down the sides of the viewport!
;
; (probably used to clip the explosion sprite -- it appears below graphics --
;  but that doesn't cover the borders to the sides of the viewport)
;
fill_sides:                                                             ;$B359

        ; first the left-hand-side
        ; cols 0, 1, 2
        ldx #< ELITE_BITMAP_ADDR
        ldy #> ELITE_BITMAP_ADDR
        jsr @fill

        ; fill the right-hand-side
        ; cols 37, 38, 39
        ldx #< (ELITE_BITMAP_ADDR + .bmppos( 0, 37 ))
        ldy #> (ELITE_BITMAP_ADDR + .bmppos( 0, 37 ))

@fill:  ;                                                               ;$B364
        ; put the given address in the zero-page
        stx ZP_TEMP_ADDR1_LO
        sty ZP_TEMP_ADDR1_HI
        ldx # 18                ; 17 rows
@row:                                                                   ;$B36A
        ldy # (3 * 8) - 1       ; 3 chars, 24 bytes, 0-23

:       lda # %11111111         ; set all bitmap bits                   ;$B36C
        sta [ZP_TEMP_ADDR1], y  ; write to the bitmap
        dey                     ; move to next byte
        bpl :-                  ; keep going until $00->$FF

        ; move to the next bitmap char-row
        lda ZP_TEMP_ADDR1_LO
        clc
        adc #< 320
        sta ZP_TEMP_ADDR1_LO
        lda ZP_TEMP_ADDR1_HI
        adc #> 320
        sta ZP_TEMP_ADDR1_HI

        dex                     ; row complete
        bne @row                ; more rows to do? (exits at $00)

        rts

;///////////////////////////////////////////////////////////////////////////////
.endif

;===============================================================================
; clear screen?
;
_b384:                                                                  ;$B384
        ldx # 8
        ldy # 0
        clc
_b389:                                                                  ;$B389
        lda row_to_bitmap_lo, x
        sta ZP_TEMP_ADDR1_LO
        lda row_to_bitmap_hi, x
        sta ZP_TEMP_ADDR1_HI

        tya

:       sta [ZP_TEMP_ADDR1], y                                          ;$B394
        dey
        bne :-

        txa
        adc # $08
        tax
        cmp # $c0
        bcc _b389

        iny
        sty ZP_CURSOR_COL
        sty ZP_CURSOR_ROW

        rts

erase_page:                                                             ;$B3A7
        ;=======================================================================
        ; erase a page (256 bytes, aligned to $00...$FF)
        ;
        ;       X = page-number, i.e. hi-address
        ;
        ldy # $00
        sty ZP_TEMP_ADDR1_LO

erase_page_from:                                                        ;$B3AB
        ;=======================================================================
        ; erase some bytes:
        ;
        ;     $07 = lo-address
        ;       X = hi-address
        ;       Y = offset
        ;
        lda # $00
        stx ZP_TEMP_ADDR1_HI

:       sta [ZP_TEMP_ADDR1], y                                          ;$B3AF
        dey
        bne :-

        rts

erase_page_to_end:                                                      ;$B3B5
        ;=======================================================================
        lda # $00
:       sta [ZP_TEMP_ADDR1], y                                          ;$B3B7
        iny
        bne :-

        rts

; unreferenced / unused?
;$b3bd:
        sta ZP_CURSOR_COL
        rts

_b3c0:                                                                  ;$B3C0
        sta ZP_CURSOR_ROW
        rts

.ifdef  OPTION_ORIGINAL
;///////////////////////////////////////////////////////////////////////////////
;
; does a large block-copy of bytes. used to wipe the HUD
; by copying over a clean copy of the HUD in RAM.
;
; [ZP_TEMP_ADDR3] = from address
; [ZP_TEMP_ADDR1] = to address
;               X = number of pages to copy
;
; the copy method is replaced with a faster alternative
; in elite-harmless, so this routine is no longer used
;
block_copy:                                                             ;$B3C3
        ;-----------------------------------------------------------------------
        ; start copying from the beginning of the page
        ldy # $00

block_copy_from:                                                        ;$B3C5
        ;-----------------------------------------------------------------------
        lda [ZP_TEMP_ADDR3], y  ; read from
        sta [ZP_TEMP_ADDR1], y  ; write to
        dey                     ; roll the byte-counter
       .bnz block_copy_from     ; keep going until it looped

        ; move to the next page
        inc ZP_TEMP_ADDR3_HI
        inc ZP_TEMP_ADDR1_HI
        dex                     ; one less page to copy
       .bnz block_copy_from     ; still pages to do?

        rts

;///////////////////////////////////////////////////////////////////////////////
.endif