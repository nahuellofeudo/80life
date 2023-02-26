;        org 100h
        org 00h

        ld SP, 0xfff0 
        jp start

;------------ Constants
; Screen definition
width:  equ 80
height: equ 25

; Size of the screen buffer = 80*25
buflen: equ width * height

; Escape codes
CR:     equ '\n'
LF:     equ '\r'
HOME:   db 27
        db "[1;1H$"
CLRSCR: db 27
        db "[2J$"

; System calls (unused for now, will be needed for CP/M version)
BDOS:           equ 05
C_WRITE:        equ 2

; Constants for states of individual cells
alive:          equ 1
dead:           equ 0

born_char:      equ '.'
alive_char:     equ 'O'
dead_char:      equ ' '
dying_char:     equ '*'


;------------ Buffers for current and previous states
buf0:   equ 0x4000
buf1:   equ 0x6000


; Variables used by the PRNG
rngx:   db 01h
rngy:   db 53h
rngz:   db 22h
rngi:   db 0

; -------- end variables

;-----------------------------------------------------
; Print a character in E
printchar:
        push AF
        push BC
        push DE
        push HL

        ; Uncomment to use CP/M I/O routines
        ;ld C, C_WRITE
        ;call BDOS
        ;jp printchar_end


        ; Wait until the line is clear
        ld C, 1

printchar_wait:
        in A, (0)
        bit 3, A
        jp Z, printchar_wait
        ; Output character
        out (C), E

printchar_end:
        pop HL
        pop DE
        pop BC
        pop AF
        ret

;-----------------------------------------------------
; Print a string pointed at by DE
printstr:
        push AF
        push DE
        push HL

        ; Move DE into HL (E is used by printchar)
        push DE
        pop HL

        ; Put $ into D
        ld D, '$'

        ; If (HL) isn't $, call printchar
printstr_loop:
        ld A, (HL)
        cp D
        jp Z, printstr_end
        ld E, A
        call printchar
        inc HL
        jp printstr_loop

printstr_end:

        pop HL
        pop DE
        pop AF
        ret


; Initialize both buffers
start:  
        call clear_screen
        ; Initialize both buffers
        ld IX, buf0
        ld IY, buf1

        call initbuf    ; Initialize (IX)
        call copybuf    ; Copy (IX) --> (IY)

life_loop:
        call go_home
        call updatebuf   ; Update state (IY) --> (IX)
        call printbuf    ; Print diff (IX, IY)
        ;halt
        call copybuf     ; Copy (IX) --> (IY)
        ;halt
        jp life_loop


;-----------------------------------------------------
; Initialize buffer in IX
; uses DE as 16-bit counter
initbuf:
        push AF
        push DE
        push IX
        ld DE, buflen
initbuf_loop:

        call genrand
        bit 0, A
        jr nz, initbuf_alive

initbuf_dead:
        ld A, dead
        jr initbuf_set

initbuf_alive:
        ld A, alive

initbuf_set:
        ld (IX + 0), A

        ; Increment HL
        inc IX
        
        ; Decrement DE by 1
        dec DE

        ; end if DE's bit 7 is on (number is negative)
        bit 7, D
        jp z, initbuf_loop
    
initbuf_end:
        pop IX
        pop DE
        pop AF
        ret
;-----------------------------------------------------    


;-----------------------------------------------------
; Copies buffer pointed at by IX into buffer pointed at by IY
copybuf:
        push AF
        push BC
        push IX
        push IY

        ld BC, buflen

copybuf_loop:
        ld A, (IX+0)
        ld (IY + 0), A
        inc IX
        inc IY
        dec BC
        bit 7, B
        jp Z, copybuf_loop

        pop IY
        pop IX
        pop BC
        pop AF

        ret



;-----------------------------------------------------
; Generate a Pseudo-random number
; Return it in A
genrand:
        push BC

        ;   i++ 
        ld A, (rngi)
        inc A
        ld (rngi), A

        ;   x = (x xor z xor i) 
        ld A, (rngx)
        ld B, A
        ld A, (rngz)
        ld C, A
        ld A, (rngi)
        xor B
        xor C
        ld (rngx), A

        ;   y = (y + x) 
        ld A, (rngy)
        ld B, A
        ld A, (rngx)
        add B
        ld (rngy), A

        ;   z = (z + (y >> 1) ^ x)
        ld A, (rngy)
        rr A
        ld B, A 
        ld A, (rngx)
        xor B
        ld B, A
        ld A, (rngz)
        add B
        ld (rngz), A

        ; return z
        ; z is already in A
        pop BC

        ret
        
;-----------------------------------------------------

;-----------------------------------------------------
; Calculate the state of one cell
; Parameters:
; IX: The current cell in the current buffer
; IY: Start of the previous buffer
; B: line
; C: column
; Return A = 1 if alive, A = 0 if dead
calculate_position:
        push BC
        push DE
        push IY

        ; Initialize E as the counter
        ld E, 0

        ; Add the row:column offset to IY
        ;call calc_offset_iy

calculate_position_top:
        ; If line == 0, jump to the bottom line
        ld A, 0
        cp B
        jp Z, calculate_position_bottom

        ; --- add IY - 80
calculate_position_top_middle:
        push BC
        push IY
        dec B
        call calc_offset_iy
        ld A, E
        add A, (IY + 0)
        ld E, A
        pop IY
        pop BC

        ; --- if column > 0 add IY - 81
calculate_position_top_left:
        ld A, 0
        cp C
        jp Z, calculate_position_top_right
        push BC
        push IY
        dec B
        dec C
        call calc_offset_iy
        ld A, E
        add A, (IY + 0)
        ld E, A
        pop IY
        pop BC
       
        ; --- if column < 79 add IY - 79
calculate_position_top_right:
        ld A, 79
        cp C
        jp Z, calculate_position_bottom
        push BC
        push IY
        dec B
        inc C
        call calc_offset_iy
        ld A, E
        add A, (IY + 0)
        ld E, A
        pop IY
        pop BC

calculate_position_bottom:
        ; if line == 24, jump to the middle line
        ld A, 24
        cp B
        jp Z, calculate_position_middle

        ; --- add IY + 80
calculate_position_bottom_middle:
        push BC
        push IY
        inc B
        call calc_offset_iy
        ld A, E
        add A, (IY + 0)
        ld E, A
        pop IY
        pop BC

        ; --- if column > 0 add IY + 79
calculate_position_bottom_left:
        ld A, 0
        cp C
        jp Z, calculate_position_bottom_right
        push BC
        push IY
        inc B
        dec C
        call calc_offset_iy
        ld A, E
        add A, (IY + 0)
        ld E, A
        pop IY
        pop BC

        ; --- if column < 79 add  IY + 81
calculate_position_bottom_right:
        ld A, 79
        cp C
        jp Z, calculate_position_middle
        push BC
        push IY
        inc B
        inc C
        call calc_offset_iy
        ld A, E
        add A, (IY + 0)
        ld E, A
        pop IY
        pop BC


calculate_position_middle:        
calculate_position_middle_left:
        ; if column > 0 add IY - 1
        ld A, 0
        cp C
        jp Z, calculate_position_middle_right
        push IY
        call calc_offset_iy
        dec IY
        ld A, E
        add A, (IY + 0)
        ld E, A
        pop IY

calculate_position_middle_right:
        ; if column < 79 add IY + 1
        ld A, 79
        cp C
        jp Z, calculate_position_end_neighbors
        push IY
        call calc_offset_iy
        inc IY
        ld A, E
        add A, (IY + 0)
        ld E, A
        pop IY

calculate_position_end_neighbors:
        ; Check the state of the cell itself. IX already points to the current cell
        ld A, (IX + 0)
        jp Z, calculate_position_dead
        
calculate_position_alive: 
        ; The cell is alive
        ; Any live cell with two or three live neighbours lives on to the next generation.
        ld A, 2
        cp E
        jp Z, calculate_position_lives

        ld A, 3
        cp E
        jp Z, calculate_position_lives

        ; Any live cell with fewer than two live neighbours dies, as if by underpopulation.
        ; Any live cell with more than three live neighbours dies, as if by overpopulation.
        jp calculate_position_dies

calculate_position_dead: 
        ; The cell is dead
        ; Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
        ld A, 3
        cp E
        jp Z, calculate_position_lives
        jp calculate_position_dies

calculate_position_lives:
        ld A, 1
        jp calculate_position_end

calculate_position_dies:
        ld A, 0

calculate_position_end:
        pop IY
        pop DE
        pop BC
        ret


; Calculate buffer offset and add it to IX
; IX = IX + B * 80 + C
calc_offset:
        push AF
        push BC
        push DE
        
        ld DE, 80

        ld A, 0
        cp B
        jp z, calc_offset_add_c

calc_offset_loop:
        add IX, DE
        djnz calc_offset_loop

calc_offset_add_c:
        ld B, 0
        add IX, BC

        pop DE
        pop BC
        pop AF
        ret


; Same as calc_offset, but for IY instead of IX
calc_offset_iy:
        push IX
        push IY
        pop IX
        call calc_offset
        push IX
        pop IY
        pop IX
        ret


;-----------------------------------------------------
; Update the state of buffer 0 with the state from buffer 1
; Parameters:
; IX: previous buffer
; IY: new buffer
; Variables:
; B: line
; C: column

updatebuf:
        push AF
        push BC
        push DE

        ; Begin outer loop
        ld B, 24

updatebuf_start_inner_loop:
        LD C, 79

        ; Inner loop
        ; Update cell in buffer IX from data in buffer IY
updatebuf_inner_loop:
        push IX
        call calc_offset
        call calculate_position
        ld (IX+0), A
        pop IX 
 
        ; move to the next cell
        dec C
        bit 7, C
        jp Z, updatebuf_inner_loop

        ; Move to the next line
updatebuf_next_line:
        dec B
        bit 7, B
        jp Z, updatebuf_start_inner_loop


updatebuf_end:
        pop DE
        pop BC
        pop AF

        ret


;-----------------------------------------------------
; Print the screen buffer pointed to by IX
; 80 characters per line
; 25 lines
printbuf:
        push AF
        push BC
        push DE
        push IX
        push IY

        ; Loop through all the lines
        ld D, height

        ; Print a single line
printbuf_line:
        ld B, width
printbuf_line_loop:
        ld E, (IX + 0)
        bit 0, E
        jp NZ, printbuf_alive

printbuf_dead:
        ; Check the previous state
        ld E, (IY + 0)
        bit 0, E
        jp Z, printbuf_dead_dead

printbuf_dead_dying:
        ld E, dying_char
        jp printbuf_print

printbuf_dead_dead:
        ld E, dead_char
        jp printbuf_print


printbuf_alive:
        ld E, (IY + 0)
        bit 0, E
        jp Z, printbuf_alive_born

printbuf_alive_alive:
        ld E, alive_char
        jp printbuf_print

printbuf_alive_born:
        ld E, born_char

printbuf_print:
        call printchar

        inc IX
        inc IY
        dec B
        jr  nz, printbuf_line_loop

        ; Print CR;LF
        ld  E, CR
        call printchar

        ld  E, LF
        call printchar


        ; Next line
        dec D
        jr nz, printbuf_line

        pop IY
        pop IX
        pop DE
        pop BC
        pop AF
        ret

clear_screen:
        push DE
        ld DE, CLRSCR
        call printstr

        pop DE
        ret

go_home:
        push DE
        ld DE, HOME
        call printstr

        pop DE
        ret
 
 prog_end:
 


