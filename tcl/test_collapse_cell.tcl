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

# ---- MASTER auto-detect ----
# If MASTER is already set (e.g. from caller), use it.
# Otherwise, query all available 'master' services and pick one.
if {[info exists MASTER]} {
    puts "Using user-specified MASTER path:"
    puts "  $MASTER"
} else {
    set paths [get_service_paths master]
    if {[llength $paths] == 0} {
        error "No 'master' services found. Is the JTAG cable connected and the design programmed?"
    } elseif {[llength $paths] == 1} {
        set MASTER [lindex $paths 0]
        puts "Auto-detected MASTER path:"
        puts "  $MASTER"
    } else {
        # Multiple masters: prefer one that looks like the DE-SoC,
        # otherwise just take the first.
        set MASTER ""
        foreach p $paths {
            if {[string match *DE-SoC* $p]} {
                set MASTER $p
                break
            }
        }
        if {$MASTER eq ""} {
            set MASTER [lindex $paths 0]
        }
        puts "Multiple 'master' services found. Using:"
        puts "  $MASTER"
    }
}

# ---- Register map ----
set OFF_DATA0   0x00
set OFF_ADDR    0x04
set OFF_INIT    0x08
set OFF_TRIG    0x0C
set OFF_STATUS  0x10
set OFF_CTRL    0x14
set OFF_ID      0x18

set ADDR_COUNT  1024     ;# number of cells in collapse_bank
set NUM_CELLS   10       ;# how many random cells to test
set EXTRA_READS 4        ;# after wrong-basis collapse
set WAIT_MS     3        ;# small settle delay
set PROGRESS    1

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

# ---- Hardware read helper ----
#  Sets CTRL basis, pulses TRIG, reads DATA0 + STATUS
proc do_read {basis} {
    global OFF_CTRL OFF_TRIG OFF_DATA0 OFF_STATUS WAIT_MS
    # write full byte basis
    set ctrl [expr {$basis & 0xFF}]
    W32 $OFF_CTRL $ctrl
    after $WAIT_MS

    # pulse TRIG
    W32 $OFF_TRIG 1
    after $WAIT_MS

    set d0 [R32 $OFF_DATA0]
    set st [R32 $OFF_STATUS]
    return [list $d0 $st]
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
puts "==========================================================="
puts "  Collapse cell test: INIT, correct read, wrong read, etc."
puts "===========================================================\n"

# ---- Main test loop ----
for {set n 0} {$n < $NUM_CELLS} {incr n} {

    # Random address, init value, init basis (bytes)
    set a      [expr {int(rand() * $ADDR_COUNT)}]
    set v_init [randbyte]
    set b_init [randbyte]

    puts "------------------------------------------------------"
    puts [format "CELL %d: addr = %d" $n $a]
    puts [format "  init_value = %s" [hex8 $v_init]]
    puts [format "  init_basis = %s" [hex8 $b_init]]

    # Program address
    W32 $OFF_ADDR $a
    after $WAIT_MS

    # INIT word: [7:0]=value, [15:8]=basis
    set init_word [expr {($v_init & 0xFF) | (($b_init & 0xFF) << 8)}]
    W32 $OFF_INIT $init_word
    after $WAIT_MS

    # ----- READ 0: correct basis (should return init_value) -----
    lassign [do_read $b_init] d0 st0
    set d0_byte [expr {$d0 & 0xFF}]

    if {$d0_byte == $v_init} {
        set res "PASS"
    } else {
        set res "FAIL"
    }

    puts [format "READ 0 (first, correct basis): %s  -> %s" [hex8 $d0_byte] $res]
    puts [format "  STATUS0 = %s" [hex32 $st0]]

    # ----- READ 1: first WRONG basis → should be TRNG collapse path -----
    # pick any basis != b_init
    set b_wrong [randbyte]
    if {$b_wrong == $b_init} {
        set b_wrong [expr {($b_wrong + 1) & 0xFF}]
    }

    lassign [do_read $b_wrong] d1 st1
    set d1_byte [expr {$d1 & 0xFF}]
    puts [format "READ 1 (first WRONG basis, TRNG expected): %s" [hex8 $d1_byte]]
    puts [format "  STATUS1 = %s" [hex32 $st1]]

    # ----- READ 2..N: same wrong basis → PRNG evolution -----
    for {set k 2} {$k <= [expr {1 + $EXTRA_READS}]} {incr k} {
        lassign [do_read $b_wrong] dN stN
        set dN_byte [expr {$dN & 0xFF}]
        puts [format "READ %d (after collapse, PRNG evolution): %s" $k [hex8 $dN_byte]]
        puts [format "  STATUS%d = %s" $k [hex32 $stN]]
    }

    puts ""
}

catch {close_service master $H}
puts "=== DONE collapse-cell test ==="
