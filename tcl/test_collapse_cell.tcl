# ============================================================
# test_collapse_cell.tcl
#  - Assumes cell_avl_slave map:
#      0x00 DATA0  (R)
#      0x04 ADDR   (RW)
#      0x08 INIT   (W)  [7:0]=value, [15:8]=basis
#      0x0C TRIG   (W)  any write pulses read_pulse
#      0x10 STATUS (R)
#      0x14 CTRL   (RW) CTRL[7:0] = basis_in[7:0]
#      0x18 ID     (R)  0x524F4F4D "ROOM"
# ============================================================

# ---- User config ----
set MASTER {/devices/5CSEBA6(.|ES)|5CSEMA6|..@2#USB-1#DE-SoC/(link)/JTAG/alt_sld_fab_sldfabric.node_0/phy_0/master_0.master}

set OFF_DATA0   0x00
set OFF_ADDR    0x04
set OFF_INIT    0x08
set OFF_TRIG    0x0C
set OFF_STATUS  0x10
set OFF_CTRL    0x14
set OFF_ID      0x18

set ADDR_COUNT  650      ;# number of cells in collapse_bank
set NUM_CELLS   10       ;# how many random cells to test
set EXTRA_READS 4        ;# extra reads per scenario
set WAIT_MS     3        ;# small settle delay

# ---- Utils ----
proc hex8 {v}  { return [format "0x%02X" [expr {$v & 0xFF}]] }
proc hex32 {v} { return [format "0x%08X" [expr {$v & 0xFFFFFFFF}]] }

proc W32 {addr data} {
    global MASTER
    master_write_32 $MASTER $addr [list $data]
}
proc R32 {addr} {
    global MASTER
    return [lindex [master_read_32 $MASTER $addr 1] 0]
}

# Simple byte RNG
expr {srand([clock clicks])}
proc randbyte {} {
    return [expr {int(rand()*256)}]
}

# ---- Hardware helpers ----

# Initialize a cell: program address, then INIT with value/basis
proc do_init {addr v_init b_init} {
    global OFF_ADDR OFF_INIT WAIT_MS

    # Program address
    W32 $OFF_ADDR $addr
    after $WAIT_MS

    # INIT word: [7:0]=value, [15:8]=basis
    set init_word [expr {($v_init & 0xFF) | (($b_init & 0xFF) << 8)}]
    W32 $OFF_INIT $init_word
    after $WAIT_MS
}

# Perform a read with a given basis:
#  - write CTRL basis
#  - pulse TRIG
#  - read DATA0 and STATUS
proc do_read {basis} {
    global OFF_CTRL OFF_TRIG OFF_DATA0 OFF_STATUS WAIT_MS

    set ctrl [expr {$basis & 0xFF}]
    W32 $OFF_CTRL $ctrl
    after $WAIT_MS

    W32 $OFF_TRIG 1
    after $WAIT_MS

    set d0 [R32 $OFF_DATA0]
    set st [R32 $OFF_STATUS]
    return [list $d0 $st]
}

# Choose a wrong basis != given basis
proc pick_wrong_basis {b_init} {
    set b_wrong [randbyte]
    if {$b_wrong == $b_init} {
        set b_wrong [expr {($b_wrong + 1) & 0xFF}]
    }
    return $b_wrong
}

# ---- Open master ----
if {[catch {set H [open_service master $MASTER]} e]} {
    puts "OPEN FAILED: $e"
    return
}
if {$H eq ""} {
    puts "Using path-as-handle mode (MASTER path)."
} else {
    puts "Master handle opened: $H"
}

# ---- ID check ----
set id [R32 $OFF_ID]
puts [format "ID: %s" [hex32 $id]]
if {$id != 0x524F4F4D} {
    puts "!! WARNING: ID is not 'ROOM' (0x524F4F4D)"
}

puts ""
puts "===================================================================="
puts "  Collapse cell multi-test: right-first, wrong-first, mixed, etc."
puts "  NUM_CELLS   = $NUM_CELLS"
puts "  EXTRA_READS = $EXTRA_READS"
puts "===================================================================="
puts ""

# ---- Main test loop over random cells ----
for {set n 0} {$n < $NUM_CELLS} {incr n} {

    # Random cell address
    set a [expr {int(rand() * $ADDR_COUNT)}]

    puts "================================================================"
    puts [format "CELL %d: addr = %d" $n $a]
    puts "================================================================"

    # ================================================================
    # Scenario 1: correct-basis first read, then wrong basis, then PRNG
    # ================================================================
    set v1 [randbyte]
    set b1 [randbyte]
    set b1_wrong [pick_wrong_basis $b1]

    puts "---- Scenario 1: CORRECT-basis first, then WRONG, then PRNG ----"
    puts [format "  init_value = %s" [hex8 $v1]]
    puts [format "  init_basis = %s" [hex8 $b1]]
    puts [format "  wrong_basis= %s" [hex8 $b1_wrong]]

    do_init $a $v1 $b1

    # READ 0: correct basis (expect init_value)
    lassign [do_read $b1] d0 st0
    set d0_byte [expr {$d0 & 0xFF}]
    set res0 [expr {$d0_byte == $v1 ? "PASS" : "FAIL"}]
    puts [format "  READ 0 (first, correct basis): %s  -> %s" [hex8 $d0_byte] $res0]
    puts [format "    STATUS0 = %s" [hex32 $st0]]

    # READ 1: first WRONG basis -> TRNG expected
    lassign [do_read $b1_wrong] d1 st1
    set d1_byte [expr {$d1 & 0xFF}]
    puts [format "  READ 1 (first WRONG basis, TRNG expected): %s" [hex8 $d1_byte]]
    puts [format "    STATUS1 = %s" [hex32 $st1]]

    # READ 2..N: same wrong basis → PRNG evolution
    for {set k 2} {$k <= [expr {1 + $EXTRA_READS}]} {incr k} {
        lassign [do_read $b1_wrong] dN stN
        set dN_byte [expr {$dN & 0xFF}]
        puts [format "  READ %d (WRONG basis, PRNG evolution): %s" $k [hex8 $dN_byte]]
        puts [format "    STATUS%d = %s" $k [hex32 $stN]]
    }

    puts ""

    # ================================================================
    # Scenario 2: WRONG-basis first read, then correct basis
    # ================================================================
    set v2 [randbyte]
    set b2 [randbyte]
    set b2_wrong [pick_wrong_basis $b2]

    puts "---- Scenario 2: WRONG-basis first, then CORRECT, then repeats ----"
    puts [format "  init_value = %s" [hex8 $v2]]
    puts [format "  init_basis = %s" [hex8 $b2]]
    puts [format "  wrong_basis= %s" [hex8 $b2_wrong]]

    do_init $a $v2 $b2

    # READ 0: WRONG basis first
    lassign [do_read $b2_wrong] d0b st0b
    set d0b_byte [expr {$d0b & 0xFF}]
    puts [format "  READ 0 (first WRONG basis, TRNG expected): %s" [hex8 $d0b_byte]]
    puts [format "    STATUS0b = %s" [hex32 $st0b]]

    # READ 1: CORRECT basis after a wrong-basis read
    lassign [do_read $b2] d1b st1b
    set d1b_byte [expr {$d1b & 0xFF}]
    set res1b [expr {$d1b_byte == $v2 ? "MATCH_INIT" : "DIFF"}]
    puts [format "  READ 1 (CORRECT basis after wrong): %s  -> %s" [hex8 $d1b_byte] $res1b]
    puts [format "    STATUS1b = %s" [hex32 $st1b]]

    # READ 2..N: CORRECT basis again
    for {set k 2} {$k <= [expr {1 + $EXTRA_READS}]} {incr k} {
        lassign [do_read $b2] dNb stNb
        set dNb_byte [expr {$dNb & 0xFF}]
        puts [format "  READ %d (CORRECT basis, post-collapse): %s" $k [hex8 $dNb_byte]]
        puts [format "    STATUS%db = %s" $k [hex32 $stNb]]
    }

    puts ""

    # ================================================================
    # Scenario 3: CORRECT, CORRECT, then WRONG
    # ================================================================
    set v3 [randbyte]
    set b3 [randbyte]
    set b3_wrong [pick_wrong_basis $b3]

    puts "---- Scenario 3: CORRECT, CORRECT, then WRONG basis ----"
    puts [format "  init_value = %s" [hex8 $v3]]
    puts [format "  init_basis = %s" [hex8 $b3]]
    puts [format "  wrong_basis= %s" [hex8 $b3_wrong]]

    do_init $a $v3 $b3

    # READ 0: CORRECT
    lassign [do_read $b3] d0c st0c
    set d0c_byte [expr {$d0c & 0xFF}]
    set res0c [expr {$d0c_byte == $v3 ? "PASS" : "FAIL"}]
    puts [format "  READ 0 (first CORRECT basis): %s  -> %s" [hex8 $d0c_byte] $res0c]
    puts [format "    STATUS0c = %s" [hex32 $st0c]]

    # READ 1: CORRECT again
    lassign [do_read $b3] d1c st1c
    set d1c_byte [expr {$d1c & 0xFF}]
    puts [format "  READ 1 (second CORRECT basis): %s" [hex8 $d1c_byte]]
    puts [format "    STATUS1c = %s" [hex32 $st1c]]

    # READ 2..N: WRONG basis after multiple correct reads
    for {set k 2} {$k <= [expr {1 + $EXTRA_READS}]} {incr k} {
        lassign [do_read $b3_wrong] dNc stNc
        set dNc_byte [expr {$dNc & 0xFF}]
        puts [format "  READ %d (WRONG basis after correct reads): %s" $k [hex8 $dNc_byte]]
        puts [format "    STATUS%dc = %s" $k [hex32 $stNc]]
    }

    puts ""
}

catch {close_service master $H}
puts "=== DONE collapse-cell multi-test ==="
