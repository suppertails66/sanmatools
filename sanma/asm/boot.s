
;.include "sys/pce_arch.s"
;.include "base/macros.s"

.memorymap
   defaultslot     1
   
   ;===============================================
   ; RAM area
   ;===============================================
   
   slotsize        $800
   slot            0       $0000
   slotsize        $2000
   slot            1       $6000
   
   ;===============================================
   ; ROM area
   ;===============================================
   
   slotsize        $2000
   slot            2       $8000
   slot            3       $A000
   slotsize        $2000
   slot            4       $C000
   slot            5       $E000
.endme

.rombankmap
  bankstotal 32
  banksize $2000
  banks 32
.endro

.emptyfill $FF

.background "sanma.nes"

; unbackground expanded ROM space
.unbackground $32000 $3BFFF

.define PPUCTRL $2000
.define PPUMASK $2001
.define PPUSTATUS $2002
.define OAMADDR $2003
.define OAMDATA $2004
.define PPUSCROLL $2005
.define PPUADDR $2006
.define PPUDATA $2007
.define OAMDMA $4014

;===============================================
; Constants
;===============================================

.define activeLowBank $0026
.define scriptRegionNum $0056
.define scriptStringNum $0048
.define scriptPpuBaseHi $0049
.define scriptPpuBaseLo $004A
.define playerName $0086
.define currentCharaId $003E

.define changeBanks $C194

;===============================================
; Script
;===============================================

  .bank $00 slot 2
  .org $0000
  .section "script 0" overwrite
    .incbin "out/script/script_0.bin"
  .ends
  
  .bank $01 slot 2
  .org $0000
  .section "script 2" overwrite
    .incbin "out/script/script_2.bin"
  .ends
  
  .bank $02 slot 2
  .org $0000
  .section "script 4" overwrite
    .incbin "out/script/script_4.bin"
  .ends
  
  .bank $03 slot 2
  .org $0000
  .section "script 6" overwrite
    .incbin "out/script/script_6.bin"
  .ends

  .bank $10 slot 2
  .org $0000
  .section "script 1" overwrite
    .incbin "out/script/script_1.bin"
  .ends

  .bank $11 slot 2
  .org $0000
  .section "script 3" overwrite
    .incbin "out/script/script_3.bin"
  .ends

  .bank $12 slot 2
  .org $0000
  .section "script 5" overwrite
    .incbin "out/script/script_5.bin"
  .ends

  .bank $13 slot 2
  .org $0000
  .section "script 7" overwrite
    .incbin "out/script/script_7.bin"
  .ends

  ; this is actually the second half of bank2-0, split for lack of space
  .bank $14 slot 2
  .org $0000
  .section "script 8" overwrite
    .incbin "out/script/script_8.bin"
  .ends

;===============================================
; Use new script
;===============================================

.bank $0D slot 3
.org $04CD
.section "use new script" overwrite
  
  selectScriptBank:
  
  ; region 0 = bank 0
  ; region 1 = bank 2
  ; region 2 = bank 3-0
  ; region 3 = bank 1
  ; region >=4 = bank 3-1
  
  ldx scriptRegionNum
  cpx #$01
  beq @region1
  cpx #$02
  beq @region2
  cpx #$04
  bcs @region4
  
  
  @otherRegion:
    ; add 0x10 to banknum if scriptnum >= 0x80
    ldx scriptStringNum
    
    bpl +
      clc
      adc #$10
    +:
    
    jmp @bankSelected
  
  @region1:
    ; strings from 40 to 7F go to bank $14
    ldx scriptStringNum
    bmi @otherRegion
    cpx #$40
    bcc @otherRegion
    lda #$14
    bne @bankSelected
  
  @region2:
    ; target bank 3
    lda #$03
    bne @bankSelected
    
  @region4:
    ; target bank 19
    lda #$13
;    bne @bankSelected
    
  @bankSelected:
    ; change bank if active bank is not same as target
    cmp activeLowBank
    beq +
      sta activeLowBank
      jsr changeBanks
    +:
    
    ; X = stringNum * 2, in preparation for address table lookup
    lda scriptStringNum
    asl
    tax
    
    ; read from index at start of bank
    lda $8000,X
    sta $0028
    lda $8001,X
    sta $0029
  
  @pointerLoaded:
    jmp $A566
    
  ; unbackground the space we've freed up by eliminating the complex switching
  ; on the region number
  .unbackground $1A529 $1A565  
  
.ends

; use correct bank after resuming from a script pause
.bank $0D slot 3
.org $047B
.section "use new script on resume" overwrite
  ; move this logic up
  lda #$00
  sta $04A8
  lda $04A9
  sta $0028
  lda $04AA
  sta $0029
  inc $004B
  ; get bank through new logic, not table
  ldy $0056
  lda $A79D,Y
  jmp selectScriptBank
.ends

;===============================================
; No diacritics
;===============================================

.bank $0D slot 3
.org $0626
.section "skip diacritic checks" overwrite
  nop
  nop
  
  .unbackground $1A62E $1A654
.ends

; default transfer size = 4
.bank $0D slot 3
.org $0655
.section "skip diacritic checks 2" overwrite
  lda #$04
.ends

;===============================================
; Use extended names
;===============================================

.define scriptTerminator $FA
.define colonIndex $3D
.define spaceIndex $3F
.define nameBufferStart $00A7
.define playerNameBuffer $0086

.slot 2
.section "new character name table" superfree
  newCharaNameTable:
    .incbin "out/script/names.bin"
  
  prepCharaName:
    
    ; get raw attribution index
    ldy #$00
    ldx currentCharaId
    ; 1F = player's name
    cpx #$1F
    bne @standardName
;    inx
    
    @playerName:
      -:
        lda playerNameBuffer,Y
        sta nameBufferStart,Y
        iny
        cpy #$04
        bne -
      jmp @done
    
    @standardName:
    
    ; multiply by 8 to get offset
    txa
    asl
    asl
    asl
    tax
    
    ; copy up to 8 characters, or fewer if terminator found
    @nameCopyLoop:
      lda newCharaNameTable.w,X
      
      ; FD = character of player's name
      cmp #$FD
      beq @copyPlayerNameChar
      
      ; FA = terminator
      cmp #scriptTerminator
      beq @done
      
      @transferChar:
        sta nameBufferStart,Y
        iny 
        inx 
        
        ; up to 8 characters
        cpy #$08
        bne @nameCopyLoop
        beq @done
      
      ; copy from player's name
      @copyPlayerNameChar:
        lda $0086,Y
        jmp @transferChar
    
    @done:
    
    ; add colon
    lda #colonIndex
    sta nameBufferStart,Y
    iny
    
    @pad:
    
    ; pad to 10 characters with spaces
    lda #spaceIndex
    -:
      sta nameBufferStart,Y
      iny
      cpy #$0A
      bne -
    
      
    ; flag name transfer as completed
    lda #$FF
    sta $0084
    
    ; total transfer size = 17 bytes
    lda #$11
    sta $0032
    
    rts
  
.ends

.bank $0D slot 3
.org $0663
.section "use long character names dlg" overwrite
  ; set up 10-byte transfer at A4
  ; <command> <ppulo> <ppuhi> <data>
  lda #$0A
  sta $00A4
  
  ; PPU target: 22A7
  lda #$A7
  sta $00A5
  lda #$22
  sta $00A6
  
  ; load bank containing new character name stuff
  lda activeLowBank
  pha
    lda #:newCharaNameTable
    sta activeLowBank
    jsr changeBanks
    jsr prepCharaName
  pla
  sta activeLowBank
  jsr changeBanks
  
  jmp $A696
  
  
.ends

.bank $0D slot 3
.org $1B72
.section "fix dialogue attribution 1" overwrite
  sta $00B1,Y
.ends

.bank $0D slot 3
.org $1B7A
.section "fix dialogue attribution 2" overwrite
  lda #$15
.ends

;===============================================
; Adjust linebreaks to single-spacing
;===============================================

.bank $0D slot 3
.org $05A1
.section "new linebreak logic" overwrite
  lda linebreakTableHi.w,X
  sta scriptPpuBaseHi
  lda linebreakTableLo.w,X
  sta scriptPpuBaseLo
.ends

.bank $0D slot 3
.section "new linebreak table" free
;  .define linebreakAddr0 $22C7
;  .define linebreakAddr1 $2307
;  .define linebreakAddr2 $2347
;  .define linebreakAddr3 $2387

  .define linebreakAddr0 $22C7
  .define linebreakAddr1 $22E7
  .define linebreakAddr2 $2307
  .define linebreakAddr3 $2327
  .define linebreakAddr4 $2347
  .define linebreakAddr5 $2367
  .define linebreakAddr6 $2387
  
  linebreakTableLo:
    .db <linebreakAddr0, <linebreakAddr1, <linebreakAddr2, <linebreakAddr3
    .db <linebreakAddr4, <linebreakAddr5, <linebreakAddr6
  
  linebreakTableHi:
    .db >linebreakAddr0, >linebreakAddr1, >linebreakAddr2, >linebreakAddr3
    .db >linebreakAddr4, >linebreakAddr5, >linebreakAddr6
  
.ends

; move the "more dialogue" cursor to a hardcoded position instead of
; basing it on the current line number
.bank $1F slot 5
.org $1AB9
.section "set 'more dialogue' cursor position" overwrite
  lda #$23
  sta $0041
  lda #$24
  sta $0043
  jmp $FAC7
.ends

;===============================================
; Menus
;===============================================

.bank $17 slot 2
.org $0000
.section "menus 0" overwrite
  menus_0:
    .incbin "out/script/menus_0.bin"
  
  menuStartLogic:
    ; make up work
    inc $004D
    ldy #$00
    lda $0035
    cmp #$29
    bcc +
    cmp #$3A
    bcs +
    lda $040C
    sta $008D
    +:
    
    rts
  
.ends

.bank $17 slot 2
.org $0C00
.section "menus 1" overwrite
  menus_1:
    .incbin "out/script/menus_1.bin"
  
.ends

.bank $17 slot 2
.org $1000
.section "menus 2" overwrite
  menus_cmd:
    .incbin "out/script/menus_cmd.bin"
  
.ends

;===============================================
; Use 2-line format for menus
;===============================================

.define currentMenuDrawItem $0036

.bank $0D slot 3
.section "banking stuff" free
  
  loadNewMenuBank:
    lda #:menus_0
  
  loadBankLow:
    sta activeLowBank
    jmp changeBanks
    
.ends

.bank $0D slot 3
.org $02D4
.section "read from new menus 1" overwrite
  ; switch to bank with new menus
  
  ; save old bank
  lda activeLowBank
  pha
    jsr loadNewMenuBank
    jsr menuStartLogic
    jmp $A2E7
.ends

.bank $0D slot 3
.org $0307
.section "read from new menus 2" overwrite
  ; menus 1 pointers target new bank
  lda menus_1.w,X
  sta $0028
  lda (menus_1+1).w,X
  sta $0029
.ends

.bank $0D slot 3
.org $0332
.section "read from new menus 3" overwrite
  ; menus 0 pointers target new bank
  lda menus_0.w,X
  sta $0028
  lda (menus_0+1).w,X
  sta $0029
.ends

.bank $0D slot 3
.org $0340
.section "new menu draw logic" overwrite
  ; clear PPU transfer queue with spaces
  ldx #$16
  lda #spaceIndex
  -:
    dex
    sta $00A0,X
    bne -
  
  ; retrieve current menu item num
  ldx currentMenuDrawItem
    
  ; set up 2 transfers of 8 bytes each
  lda #$08
  sta $00A0
  sta $00AB
  
  ; get PPU target for item num from tables at 1A400 and 1A408
  lda $A400,X
  sta $00A2
  sta $00AD
  lda $A408,X
  sta $00A1
    
  ; subtract 0x20 from PPU addr for top line
  sec 
  sbc #$20
  sta $00AC
  bcs +
    dec $00AD
  +:
  ; increment getpos
  inc $0065
  ldy $0065
  
  ; copy to upper line first
  ldx #$0B
  @copyNextCharLoop:
    
    ; fetch next byte
    lda ($0028),Y
    
    ; done if linebreak
    cmp #$FF
    beq @copyCharsDone
    
    ; if sub-linebreak, move to lower row
    cmp #$FB
    bne +
      ldx #$00
;      beq @copyNextCharLoop
      beq @copyCharLoopEndInc2
    +:
    
      ; copy character to queue
      sta $00A3,X
;      jmp @copyCharLoopEndInc
    
    @copyCharLoopEndInc:
    ; increment putpos/getpos
    inx
    @copyCharLoopEndInc2:
    iny
    
    @copyCharLoopEnd:
    ; check if 8 chars written
;    cpx #$08
;    beq @copyCharsDone
    lda ($0028),Y
    cmp #$FF
    bne @copyNextCharLoop
  
  @copyCharsDone:
  
  ; restore normal bank
  pla
  jsr loadBankLow
  
  ; resume normal logic
  jmp $A3B0
  
.ends

; move PPU targets down a row
.bank $0D slot 3
.org $0400
.section "new PPU menu targets" overwrite
;  .define menuPpuTarget0 $2095
;  .define menuPpuTarget1 $20D5
;  .define menuPpuTarget2 $2115
;  .define menuPpuTarget3 $2155
;  .define menuPpuTarget4 $2195
;  .define menuPpuTarget5 $21D5
;  .define menuPpuTarget6 $2215
;  .define menuPpuTarget7 $2255
  .define menuPpuTarget0 $2095+$20
  .define menuPpuTarget1 $20D5+$20
  .define menuPpuTarget2 $2115+$20
  .define menuPpuTarget3 $2155+$20
  .define menuPpuTarget4 $2195+$20
  .define menuPpuTarget5 $21D5+$20
  .define menuPpuTarget6 $2215+$20
  .define menuPpuTarget7 $2255+$20

  .db >menuPpuTarget0,>menuPpuTarget1,>menuPpuTarget2,>menuPpuTarget3
  .db >menuPpuTarget4,>menuPpuTarget5,>menuPpuTarget6,>menuPpuTarget7
  .db <menuPpuTarget0,<menuPpuTarget1,<menuPpuTarget2,<menuPpuTarget3
  .db <menuPpuTarget4,<menuPpuTarget5,<menuPpuTarget6,<menuPpuTarget7
.ends

;===============================================
; speed up text
;===============================================

.bank $1F slot 5
.org $0C2A
.section "speed up text" overwrite
  ; original
;  .db $06, $04, $05, $0A

  ; (approximately) double speed
  .db $03, $02, $02, $05
  
  ; max speed
;  .db $01, $01, $01, $01
.ends

.bank $0D slot 3
.org $0499
.section "b button text speedup" overwrite
  jmp bTextSpeedupCheck
.ends

.bank $0D slot 3
.section "b button text speedup stuff" free
  bTextSpeedupCheck:
    ; make up work
    jsr $EC0B
    
    ; check if B button pressed
    lda $0015
    and #$02
    beq +
      ; continue delay countdown
      jmp $A4A3
    +:
    ; immediately print next character
    jmp $A49C
.ends

;===============================================
; Use precomposed glyphs for character names in
; portrait selection menu
;===============================================

.bank $1F slot 5
.org $1549
.section "update portrait charname base content 0" overwrite
  ; Ayako
  .db $45,$46,$47,   $E3
.ends

.bank $1F slot 5
.org $1551
.section "update portrait charname base content 1" overwrite
  ; Takayuki
  .db $49,$4A,$4B,$4C
.ends

.bank $1F slot 5
.org $1559
.section "update portrait charname base content 2" overwrite
  ; Bunchin
  .db $4E,$4F,$50,$51
.ends

.bank $1F slot 5
.org $1561
.section "update portrait charname base content 3" overwrite
  ; Hanshin
  .db $52,$53,$50,$51
.ends

.bank $1F slot 5
.org $1569
.section "update portrait charname base content 4" overwrite
  ; Kyojin
  .db $54,$55,$56,   $E3
.ends

.bank $1F slot 5
.org $1571
.section "update portrait charname base content 5" overwrite
  ; Saburo
  .db $57,$58,$59,   $E3
.ends

.bank $1F slot 5
.org $1579
.section "update portrait charname base content 6" overwrite
  ; Shiro
  .db $5A,$5B,$5C,   $E3
.ends

; note: empty map for arrow here

.bank $1F slot 5
.org $1589
.section "update portrait charname base content 7" overwrite
  ; Ikuyo
  .db $5D,$5E,$47,   $E3
.ends

.bank $1F slot 5
.org $1591
.section "update portrait charname base content 8" overwrite
  ; Kuruyo
  .db $5F,$61,$62,   $E3
.ends

.bank $1F slot 5
.org $1599
.section "update portrait charname base content 9" overwrite
  ; Shinsuke
  .db $41,$66,$67,$68
.ends

.bank $1F slot 5
.org $15A1
.section "update portrait charname base content 10" overwrite
  ; Norio
  .db $69,$6A,$5C,   $E3
.ends

.bank $1F slot 5
.org $15A9
.section "update portrait charname base content 11" overwrite
  ; Yasushi
  .db $6B,$6C,$6D,$6E
.ends

.bank $1F slot 5
.org $15B1
.section "update portrait charname base content 12" overwrite
  ; Chatha
  .db $6F,$70,$71,$72
.ends

;===============================================
; Use new item menu
;===============================================

.unbackground $3FCA0 $3FE3F

; load bank with new menus
.bank $1F slot 5
.org $1890
.section "use new item menu 1" overwrite
  lda activeLowBank
  pha
  jsr triggerItemMenuLoad
.ends

; unload bank with new menus
.bank $1F slot 5
.org $18DC
.section "use new item menu 2" overwrite
  pla
  jsr untriggerItemMenuLoad
  
.ends

; use new menu pointer
.bank $1F slot 5
.org $18AB
.section "use new item menu 3" overwrite
  lda menus_cmd.w,X
  sta $0028
  lda (menus_cmd+1).w,X
  sta $0029
.ends

.bank $1F slot 5
.section "new item menu logic" free
  
  loadNewMenuBank_item:
    lda #:menus_cmd
  
  loadBankLowFree_item:
    sta activeLowBank
    jmp changeBanks
  
  triggerItemMenuLoad:
    jsr loadNewMenuBank_item
    
    ; original game turns the vertical menu cursor from selecting "examine",
    ; etc. off, but does not prevent it from being redrawn once the item
    ; menu is loaded. this causes a blank space to be drawn to e.g. PPU 20D4.
    ; in the original game this happens to already be blank, but may overwrite
    ; an item name in translation.
    ; thus we move the cursor to 2000 first so this doesn't happen.
    lda #$00
    sta $0044
    
    ; make up work
    lda #$7D
    sta $0045
    ldx #$00
    
    rts
  
  untriggerItemMenuLoad:
    jsr loadBankLowFree_item
    
    ; make up work
    ldx #$00
    ldy #$00
    
    rts
  
.ends

;.bank $18 slot 2
;.org $0000
;.section "new menu item stuff" overwrite
;  itemMenus:
;    .incbin "out/script/menus_cmd.bin"
;.ends

; change x-positions of item slots
.bank $1F slot 5
.org $1A4A
.section "new item tables" overwrite
  
  ; x-table
  .rept 4
    .db $20,$58,$90,$C8
  .endr
  
.ends

; use horizontal cursor

  ; cursor tile during update
  .bank $1F slot 5
  .org $1CAE
  .section "horizontal item menu cursor 1" overwrite
    lda #$7C
  .ends

  ; cursor tile at init
  .bank $1F slot 5
  .org $178F
  .section "horizontal item menu cursor 2" overwrite
    lda #$7C
  .ends
  
  ; PPU low at init
  .bank $1F slot 5
  .org $188C
  .section "horizontal item menu cursor 3" overwrite
    lda #$83
  .ends

  ; position tables
  .bank $1F slot 5
  .org $182D
  .section "horizontal item menu cursor 4" overwrite
    
;    .db $00,$04,$08,$0C
;    .db $20,$20,$21,$21
;    .db $62,$68,$6E,$74
    
    ; low byte offset table per row
    .db $00,$04,$08,$0C
    
    ; PPU addr high
    .db $20,$21,$21,$22
    
    ; PPU addr low
    .rept 4 index count
      .db ($83+(count*$80))#$100,($8A+(count*$80))#$100
      .db ($91+(count*$80))#$100,($98+(count*$80))#$100
;      .db $83,$8A,$91,$98
;    .db $03,$0A,$11,$18
    .endr
    
  .ends

; don't do vertical menu init on item menu

.bank $1E slot 5
.org $1545
.section "no vert init on item menu 1" overwrite
  jmp noVertOnItemMenuCheck
.ends

.bank $1F slot 5
.section "no vert init on item menu 2" free
  noVertOnItemMenuCheck:
;    lda $0374
;    cmp #$06
;    beq +
;      ; skip init
;      jmp $D52E
;    +:
;    
;    ; make up work
;    ldx $0040
;    lda $D549,X
;    jmp $D51F
    
    ; make up work
    sta $04B9
    
    lda $0374
;    cmp #$06
    beq +
      lda #$00
      sta $0043
    +:
    rts
    
.ends

;===============================================
; Reposition paging arrows on multi-page
; "use item" screen
;===============================================

.define newItemPagingArrowPpuAddr $2078

.bank $1F slot 5
.org $1B4F
.section "shift item menu paging arrows" overwrite
  lda #>newItemPagingArrowPpuAddr
  sta $2006
  lda #<newItemPagingArrowPpuAddr
  sta $2006
.ends

;===============================================
; New tilemaps
;===============================================

.bank $15 slot 2
.org $0000
.section "new tilemaps 1" overwrite
  newTilemaps1:
    .incbin "out/script/tilemaps1.bin"
  
  doNewTilemaps1:
    ; make up work
    lda #$06
    sta $2001
    lda #$30
    sta $2000
    lda #$00
    sta $0078
    jsr $A8CE
    lda #$0F
    sta $0023
    lda $0062
    
    ; look up pointer
    asl 
    tax 
    lda newTilemaps1.w,X
    sta $0028
    lda (newTilemaps1+1).w,X
    sta $0029
    ldy #$FF
    
    ; call normal copy loop
    jmp $A1B7
    
.ends

.bank $15 slot 2
.org $0400
.section "new tilemaps 2" overwrite
  newTilemaps2:
    .incbin "out/script/tilemaps2.bin"
  
  doNewTilemaps2:
    
    
    
.ends

.bank $15 slot 2
.org $1000
.section "new tilemaps 3" overwrite
  newTilemaps3:
    .incbin "out/script/tilemaps3.bin"
  
  doNewTilemaps3:
    ; make up work
    ldy #$00
    lda $0062
    asl 
    tax 
    
    ; look up pointer
    lda newTilemaps3.w,X
    sta $0028
    lda (newTilemaps3+1).w,X
    sta $0029
    lda ($0028),Y
    sta $0032
    ldx #$00
    
    ; call normal copy loop
    jmp $A11C
  
.ends

.bank $15 slot 2
.org $1F00
.section "new tilemaps 4" overwrite
  newTilemaps4:
    .incbin "out/script/tilemaps4.bin"
  
  doNewTilemaps4:
    ; make up work
    lda $001E
    lsr 
    lsr 
    lsr 
    asl 
    tax 
    
    ; look up pointer
    lda newTilemaps4.w,X
    sta $0028
    lda (newTilemaps4+1).w,X
    sta $0029
    ldy #$00
    
    ; call normal copy loop
    jmp $A815
  
.ends

;===============================================
; Use new tilemaps1
;===============================================

.bank $07 slot 3
.org $0192
.section "use new tilemaps1 1" overwrite
  lda activeLowBank
  pha
    lda #:newTilemaps1
    sta activeLowBank
    jsr changeBanks
    jsr doNewTilemaps1
  pla
  sta activeLowBank
  jmp changeBanks
    
.ends

;===============================================
; Use new tilemaps2
;===============================================

.bank $0D slot 3
.org $07AC
.section "use new tilemaps2 1" overwrite
  lda activeLowBank
  pha
    jsr doNewTilemaps2Start
    
.ends

.bank $0D slot 3
.org $07B6
.section "use new tilemaps2 2" overwrite
  lda newTilemaps2.w,X
  sta $0028
  lda (newTilemaps2+1).w,X
  sta $0029
.ends

.bank $0D slot 3
.org $07FC
.section "use new tilemaps2 3" overwrite
  pla
  sta activeLowBank
  jmp doNewTilemaps2End
    
.ends

.bank $1F slot 5
.section "new tilemaps2 logic" free
  doNewTilemaps2Start:
    ; make up work
    jsr $C1C5
    jsr $C1A4
    
    ; load bank
    lda #:newTilemaps2
    sta activeLowBank
    jmp changeBanks
  
  doNewTilemaps2End:
    jsr changeBanks
    
    ; make up work
    lda $0012
    sta $2000
    
    rts
  
.ends

;===============================================
; Use new tilemaps3
;===============================================

.bank $07 slot 3
.org $0106
.section "use new tilemaps3 1" overwrite
  lda activeLowBank
  pha
    lda #:newTilemaps3
    sta activeLowBank
    jsr changeBanks
    jsr doNewTilemaps3
  pla
  sta activeLowBank
  jmp changeBanks
    
.ends

;===============================================
; Use new tilemaps4
;===============================================

.bank $0D slot 3
.org $0802
.section "use new tilemaps4 1" overwrite
  lda activeLowBank
  pha
    lda #:newTilemaps4
    sta activeLowBank
    jsr changeBanks
    jsr doNewTilemaps4
  pla
  sta activeLowBank
  jmp changeBanks
    
.ends

;===============================================
; Add additional characters to name screen
; (and unfortunately also the password screen,
; since it shares code)
;===============================================

; free space from old index -> character ID mapping
.unbackground $1A9CE $1A9FE

.slot 2
.section "new name screen stuff" superfree
  newNameIndexTable:
    ; ABCDE abcde
    .db $00,$01,$02,$03,$04,  $1A,$1B,$1C,$1D,$1E
    ; FGHIJ fghij
    .db $05,$06,$07,$08,$09,  $1F,$20,$21,$22,$23
    ; KLMNO klmno
    .db $0A,$0B,$0C,$0D,$0E,  $24,$25,$26,$27,$28
    ; PQRST pqrst
    .db $0F,$10,$11,$12,$13,  $29,$2A,$2B,$2C,$2D
    ; UVWXY uvwxy
    .db $14,$15,$16,$17,$18,  $2E,$2F,$30,$31,$32
    ; Z     z  (END)
    .db $19,$3F,$3F,$3F,$3F,  $33,$3F,$3F,$FF,$FF
  
  
.ends

; new code
.bank $0D slot 3
.section "access new name screen stuff" free
  fetchNewNameIndex:
    lda activeLowBank
    pha
      lda #:newNameIndexTable
      sta activeLowBank
      jsr changeBanks
      
      ; fetch index
      ldx $0075
      lda newNameIndexTable.w,X
      ; save result
      sta $0074
      
    pla
    sta activeLowBank
    jsr changeBanks
    
    ; retrieve result
    lda $0074
    rts
  
.ends

; use new character table
.bank $0D slot 3
.org $0891
.section "use new name character table" overwrite
  jsr fetchNewNameIndex
  
.ends
.bank $0D slot 3
.org $092C
.section "name: first rts" overwrite
  nameFirstRts:
    rts
.ends

; fix "down" navigation
.bank $0D slot 3
.org $0948
.section "name: fix down" overwrite
  ; if PPU addr >= 2320, don't move down
  lda $0072
  cmp #$23
  bcc +
    lda $0073
    cmp #$20
    bcs nameFirstRts
  +:
  
  ; if index == 0x31, select "END"
  lda $0075
  cmp #$31
  bne +
    dec $0075
    dec $0073
    dec $0073
  +:
  
.ends

; fix "right" navigation
.bank $0D slot 3
.org $098F
.section "name: fix right" overwrite
  ; if PPU addr >= 2336, don't move right
  lda $0073
  cmp #$36
  bne +
    lda $0072
    cmp #$23
    bcs nameFirstRts
  lda $0073
  +:
  
.ends

;===============================================
; New tilemaps intro
;===============================================

.bank $16 slot 2
.org $0000
.section "new tilemaps intro" overwrite
  newTilemapsIntro:
    .incbin "out/script/tilemaps_intro.bin"
.ends

.unbackground $15860 $15EFF

.bank $0A slot 3
.org $02DE
.section "use new tilemaps intro 1" overwrite
  lda activeLowBank
  pha
    jsr useNewTilemapsIntro1
.ends

.bank $0A slot 3
.org $0319
.section "use new tilemaps intro 2" overwrite
  pla
  jmp useNewTilemapsIntro2
.ends

.bank $0A slot 3
.org $02E8
.section "use new tilemaps intro 3" overwrite
  lda newTilemapsIntro.w,X
  sta $0028
  lda (newTilemapsIntro+1).w,X
  sta $0029
.ends

.bank $0A slot 3
.section "new tilemaps intro code" free
  useNewTilemapsIntro1:
    ; make up work
    jsr $A2AE
    jsr $A28D

    lda #:newTilemapsIntro
    sta activeLowBank
    jsr changeBanks
    
    rts
  
  useNewTilemapsIntro2:
    sta activeLowBank
    jsr changeBanks
      
    ; finish normal routine
    lda $001E
    cmp #$06
    bcc +
      lda #$00
      sta $0077
      lda #$02
      sta $0052
      lda #$00
      sta $0079
      jsr $AFBB
    +:
    lda $0012
    sta $2000
    rts 
    
.ends

;===============================================
; New intro text
;===============================================

.bank $0A slot 3
.org $1F00
.section "new intro text" overwrite
  newIntroText:
    .incbin "out/script/intro_text.bin"
  
  linebreakTableIntroLo:
    .db <linebreakAddr0, <linebreakAddr1, <linebreakAddr2, <linebreakAddr3
    .db <linebreakAddr4, <linebreakAddr5, <linebreakAddr6
  
  linebreakTableIntroHi:
    .db >linebreakAddr0, >linebreakAddr1, >linebreakAddr2, >linebreakAddr3
    .db >linebreakAddr4, >linebreakAddr5, >linebreakAddr6
  
.ends

.bank $0A slot 3
.org $15ED
.section "use new intro text" overwrite
  lda newIntroText.w,X
  sta $0028
  lda (newIntroText+1).w,X
  sta $0029
.ends

.bank $0A slot 3
.org $15E2
.section "use new intro speedup" overwrite
  lda $0010
  and #$03
  beq +
    rts
  +:
.ends

.bank $0A slot 3
.org $160D
.section "use new intro linebreaks" overwrite
  ; speech bubble "pointer
  lda $B68A,X
  sta $00A9

  ; hi byte
  ; lower character
  ldx $0083
  lda linebreakTableIntroHi.w,X
  sta $00A2
  ; upper character
;  lda linebreakTableIntroHi.w,X
;  sta $00A6
  lda #$20
  sta $00A6
  nop
  
  ; lo byte
  ; lower character
  lda linebreakTableIntroLo.w,X
  clc
  adc $004A
  sta $00A1
  ; upper character
;  sec
;  sbc #$20
;  sta $00A5
  lda #$00
  sta $00A5
  nop
  
  
.ends



