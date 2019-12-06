# This is the only file that will be considered for grading

.data
# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

# memory-mapped I/O
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024

TIMER                   = 0xffff001c
ARENA_MAP               = 0xffff00dc

REQUEST_PUZZLE          = 0xffff00d0  ## Puzzle
SUBMIT_SOLUTION         = 0xffff00d4  ## Puzzle

BONK_INT_MASK           = 0x1000
BONK_ACK                = 0xffff0060

TIMER_INT_MASK          = 0x8000
TIMER_ACK               = 0xffff006c

REQUEST_PUZZLE_INT_MASK = 0x800       ## Puzzle
REQUEST_PUZZLE_ACK      = 0xffff00d8  ## Puzzle

GET_PAINT_BUCKETS       = 0xffff00e4
SWITCH_MODE             = 0xffff00f0

### Puzzle
GRIDSIZE = 8

.text
main:
    # Construct interrupt mask
    li      $t4, 0
    or      $t4, $t4, BONK_INT_MASK # request bonk
    or      $t4, $t4, REQUEST_PUZZLE_INT_MASK           # puzzle interrupt bit
    or      $t4, $t4, 1 # global enable
    mtc0    $t4, $12
    
    #Fill in your code here
infinite:
    li      $t0, 10     # max velocity
    sw      $t0, VELOCITY($0)

    li      $t1, 1
    sw      $t1, ENABLE_PAINT_BRUSH($0)

    jr $ra

.kdata
chunkIH:    .space 32
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
        move      $k1, $at        # Save $at
.set at
        la        $k0, chunkIH
        sw        $a0, 0($k0)        # Get some free registers
        sw        $v0, 4($k0)        # by storing them to a global variable
        sw        $t0, 8($k0)
        sw        $t1, 12($k0)
        sw        $t2, 16($k0)
        sw        $t3, 20($k0)
        sw $t4, 24($k0)
        sw $t5, 28($k0)

        mfc0      $k0, $13             # Get Cause register
        srl       $a0, $k0, 2
        and       $a0, $a0, 0xf        # ExcCode field
        bne       $a0, 0, non_intrpt



interrupt_dispatch:            # Interrupt:
    mfc0       $k0, $13        # Get Cause register, again
    beq        $k0, 0, done        # handled all outstanding interrupts

    and        $a0, $k0, BONK_INT_MASK    # is there a bonk interrupt?
    bne        $a0, 0, bonk_interrupt

    and        $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne        $a0, 0, timer_interrupt

    and     $a0, $k0, REQUEST_PUZZLE_INT_MASK
    bne     $a0, 0, request_puzzle_interrupt

    li        $v0, PRINT_STRING    # Unhandled interrupt types
    la        $a0, unhandled_str
    syscall
    j    done

bonk_interrupt:
    sw      $0, BONK_ACK
    #Fill in your code here
    j       interrupt_dispatch    # see if other interrupts are waiting

request_puzzle_interrupt:
    sw      $0, REQUEST_PUZZLE_ACK
    #Fill in your code here
    j   interrupt_dispatch

timer_interrupt:
    sw      $0, TIMER_ACK
    #Fill in your code here
    j        interrupt_dispatch    # see if other interrupts are waiting

non_intrpt:                # was some non-interrupt
    li        $v0, PRINT_STRING
    la        $a0, non_intrpt_str
    syscall                # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH
    lw      $a0, 0($k0)        # Restore saved registers
    lw      $v0, 4($k0)
    lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
    lw $t4, 24($k0)
    lw $t5, 28($k0)
.set noat
    move    $at, $k1        # Restore $at
.set at
    eret



# bool rule1(unsigned short* board) {
#   bool changed = false;
#   for (int y = 0 ; y < GRIDSIZE ; y++) {
#     for (int x = 0 ; x < GRIDSIZE ; x++) {
#       unsigned value = board[y*GRIDSIZE + x];
#       if (has_single_bit_set(value)) {
#         for (int k = 0 ; k < GRIDSIZE ; k++) {
#           // eliminate from row
#           if (k != x) {
#             if (board[y*GRIDSIZE + k] & value) {
#               board[y*GRIDSIZE + k] &= ~value;
#               changed = true;
#             }
#           }
#           // eliminate from column
#           if (k != y) {
#             if (board[k*GRIDSIZE + x] & value) {
#               board[k*GRIDSIZE + x] &= ~value;
#               changed = true;
#             }
#           }
#         }
#       }
#     }
#   }
#   return changed;
# }
# a0: board
# s0 = [y*GRIDSIZE + x]
# s1 = y
# s2 = x
# s3 = k
# t0 = changed
# t1 = 
.globl rule1
rule1:
        sub     $sp, $sp, 32    # allocate stack
        sw      $ra, 0($sp)
        sw      $a0, 4($sp)
        sw      $s0, 8($sp)
        sw      $s1, 12($sp)    # y
        sw	$s2, 16($sp)    # x	 
        sw	$s3, 20($sp)    # k
        sw      $s4, 24($sp)	# changed
        sw      $s5, 28($sp)    # value

        move    $s0, $a0        # store address in s0
        move    $s1, $0         # s1 = y = 0 
        move    $s4, $0         # s4 = changed = false
loop:
        bge     $s1, GRIDSIZE, ret
        move    $s2, $0         # s2 = x = 0
loop2:
        bge     $s2, GRIDSIZE, inc1
        mul     $t0, $s1, GRIDSIZE
        add     $t0, $t0, $s2   # t0 = y*GRIDSIZE + x
        mul     $t0, $t0, 2
        add     $t0, $t0, $s0
        lh      $s5, 0($t0)     # s5 = value
        move    $a0, $s5        # a0 = value 
        jal     has_single_bit_set
        beq     $v0, $0, inc2

        move    $s3, $0         # s3 = k = 0
loop3:
        bge     $s3, GRIDSIZE, inc2
        beq     $s3, $s2, if_2

        mul     $t0, $s1, GRIDSIZE
        add     $t0, $t0, $s3   # t0 = y*GRIDSIZE + k
        mul     $t0, $t0, 2
        add     $t0, $t0, $s0
        lh      $t1, 0($t0)     # t1 = board[y*GRIDSIZE + k]

        and     $t2, $t1, $s5   # t2 = t1 & value
        beq     $t2, $0, if_2

        nor     $t2, $s5, $0    # t2 = ~value
        and     $t3, $t1, $t2   # t1 = board[y*GRIDSIZE + k] &= ~value
        sh      $t3, 0($t0)     # 
        add     $t4, $0, 1
        move    $s4, $t4        # changed = true
if_2:
        beq     $s3, $s1, inc3 
        mul     $t0, $s3, GRIDSIZE
        add     $t0, $t0, $s2   # k * GRIDSIZE + x
        mul     $t0, $t0, 2
        add     $t0, $t0, $s0

        lh      $t1, 0($t0)

        and     $t2, $t1, $s5   # t2 = t1 & value
        beq     $t2, $0, inc3

        nor     $t2, $s5, $0    # t3 = ~value
        and     $t3, $t1, $t2   # t1 = board[y*GRIDSIZE + k] &= ~value
        sh      $t3, 0($t0)     # 
        add     $t4, $0, 1
        move    $s4, $t4        # changed = true
        j       inc3
inc1:
        add     $s1, $s1, 1     # s1 = ++y
        j       loop
inc2:
        add     $s2, $s2, 1     # s2 = ++x
        j       loop2
inc3:
        add     $s3, $s3, 1     # s3 = ++z
        j       loop3

ret:
        move    $v0, $s4        # return value = changed
        lw      $ra, 0($sp)
        lw      $a0, 4($sp)
        lw      $s0, 8($sp)
        lw      $s1, 12($sp)
        lw	$s2, 16($sp)	 
        lw	$s3, 20($sp)
        lw      $s4, 24($sp)	 
        lw      $s5, 28($sp)

        add     $sp, $sp, 32
        jr      $ra
    
# bool solve(unsigned short *current_board, unsigned row, unsigned col, Puzzle* puzzle) {
#     if (row >= GRIDSIZE || col >= GRIDSIZE) {
#         bool done = board_done(current_board, puzzle);
#         if (done) {
#             copy_board(current_board, puzzle->board);
#         }

#         return done;
#     }
#     current_board = increment_heap(current_board);

#     bool changed;
#     do {
#         changed = rule1(current_board);
#         changed |= rule2(current_board);
#     } while (changed);

#     short possibles = current_board[row*GRIDSIZE + col];
#     for(char number = 0; number < GRIDSIZE; ++number) {
#         // Remember & is a bitwise operator
#         if ((1 << number) & possibles) {
#             current_board[row*GRIDSIZE + col] = 1 << number;
#             unsigned next_row = ((col == GRIDSIZE-1) ? row + 1 : row);
#             if (solve(current_board, next_row, (col + 1) % GRIDSIZE, puzzle)) {
#                 return true;
#             }
#             current_board[row*GRIDSIZE + col] = possibles;
#         }
#     }
#     return false;
# }

.globl solve
solve:
        sub     $sp, $sp, 52    # allocate stack
        sw      $ra, 0($sp)
        sw      $a0, 4($sp)
        sw      $a1, 8($sp)
        sw      $a2, 12($sp)
        sw      $a3, 16($sp)
        sw      $s0, 20($sp)    # store a0 
        sw      $s1, 24($sp)    # store a1
        sw      $s2, 28($sp)    # store a2 
        sw      $s3, 32($sp)    # store a3
        sw      $s4, 36($sp)    # changed
        sw      $s5, 40($sp)    # possibles
        sw      $s6, 44($sp)    # number
        sw      $s7, 48($sp)    # done

        move    $s0, $a0
        move    $s1, $a1        # replace store addresses
        move    $s2, $a2
        move    $s3, $a3
        
        bge     $s1, GRIDSIZE, inside     
        bge     $s2, GRIDSIZE, inside
        j       not_if
inside:
        move    $a0, $s0
        move    $a1, $s3        # a1 = puzzle 
        jal     board_done
        move    $s7, $v0        # s7 = done = board_done(a0, a1)
        beq     $s7, $0, ret2   # go to r3eturn if not done 

        move    $a0, $s0
        move    $a1, $s3
        jal     copy_board
        move    $v0, $s7        # set v0 to done
        j       ret2
not_if:
        move    $a0, $s0
        jal     increment_heap 
        move    $s0, $v0        # current_board = increment_heap(a0)
        add     $s4, $0, $0     # s4 = changed
do_loop:
        move    $a0, $s0
        jal     rule1
        move    $s4, $v0        # s4 = changed = rule1(a0)
        move    $a0, $s0
        jal     rule2 
        or      $s4, $s4, $v0   # changed |= rule2(a0)
        beq     $s4, $0, after_do
        j       do_loop        
after_do:
        mul     $t0, $s1, GRIDSIZE
        add     $t0, $t0, $s2   # t0 = row*GRIDSIZE + col
        mul     $t0, $t0, 2     # short indices
        add     $t0, $t0, $s0   # t0 = current_board[t0]
        lh      $s5, 0($t0)     # s5 = possibles
        add     $s6, $0, $0     # s6 = number = 0
for_loop:
        bge     $s6, GRIDSIZE, end

        add     $t1, $0, 1      # t1 = 1
        sll     $t1, $t1, $s6   # t1 = 1 << number
        and     $t2, $t1, $s5   # t2 = (1 << number) & possibles
        beq     $t2, $0, inc4   # if t2 == false, go to inc4

        mul     $t2, $s1, GRIDSIZE
        add     $t2, $t2, $s2   # t2 = row * GRIDSIZE + col
        mul     $t2, $t2, 2
        add     $s7, $t2, $s0   # s7 = &current_board[row*GRIDSIZE + col]
        sh      $t1, 0($s7)     # s7 = 1 << number

        add     $t3, $0, 1      # t3 = 1
        sub     $t3, $t3, GRIDSIZE
        mul     $t3, $t3, -1    # t3 = GRIDSIZE - 1
        move    $a1, $s1
        bne     $s2, $t3, if_solve      # next_row = row

        add     $a1, $s1, 1     # next_row = row + 1

if_solve:
        move    $a0, $s0
        add     $t4, $s2, 1     # t4 = col + 1
        rem     $t4, $t4, GRIDSIZE
        move    $a2, $t4        # a2 = (col + 1) % GRIDSIZE
        move    $a3, $s3

        jal     solve
        bne     $v0, $0, ret2   # if true, return true
        
        mul     $t0, $s1, GRIDSIZE
        add     $t0, $t0, $s2   # t0 = row*GRIDSIZE + col
        mul     $t0, $t0, 2
        add     $t0, $t0, $s0   # t0 = current_board[t0]
        sh      $s5, 0($t0)     # current_board[row*GRIDSIZE + col] = possibles;

inc4:
        add     $s6, $s6, 1
        j       for_loop
end:
        add     $v0, $0, $0
ret2:
        lw      $ra, 0($sp)
        lw      $a0, 4($sp)
        lw      $a1, 8($sp)
        lw      $a2, 12($sp)
        lw      $a3, 16($sp)
        lw      $s0, 20($sp)    # store a0 
        lw      $s1, 24($sp)    # store a1
        lw      $s2, 28($sp)    # store a2 
        lw      $s3, 32($sp)    # store a3
        lw      $s4, 36($sp)    # changed
        lw      $s5, 40($sp)    # possibles
        lw      $s6, 44($sp)    # number
        sw      $s7, 48($sp) 
        add     $sp, $sp, 52
        jr      $ra 

