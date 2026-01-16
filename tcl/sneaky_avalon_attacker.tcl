# ============================================================================
# ByteROOM / Atomic Memory™ — "Sneaky Avalon Attacker" Test Suite (WITH RESETS)
# AUTO-DETECT MASTER VERSION
#
# Assumes cell_avl_slave.sv includes RESET CSR at 0x1C:
#   - write 1 to 0x1C => 1-cycle soft reset pulse (bank reset + CSR clear)
#
# Attacks:
#  A0: Read DATA0 without INIT (should NOT return SECRET)
#  A1: Read STATUS/ID repeatedly (should NOT cause secret disclosure)
#  A2: Correct basis first  -> secret disclosed once, then destroyed
#  A3: Wrong basis first    -> secret never disclosed; later correct basis fails
#  A4: TRIG-write first (collapse w/out disclosure), then DATA0 read (should not reveal secret)
#  A5: Basis flip race: set OK then flip BAD before read; should fail to get secret
#  A6: Address confusion: init CELL0, point to CELL1, read; should not get secret
#  A7: Read storm: many DATA0 reads; secret should appear at most once per INIT
#  R1: Reset-after-init (secret should not survive reset)
#  R2: Reset-between-wrong-and-correct (reset should not revive secret)
#
# ============================================================================

# ---------------- BASE ADDRESS ----------------
set BASE 0x00000000

# ---------------- REGISTER OFFSETS (BYTE ADDRESSES) ----------------
set OFF_DATA0  0x00
set OFF_ADDR   0x04
set OFF_INIT   0x08
set OFF_TRIG   0x0C
set OFF_STATUS 0x10
set OFF_CTRL   0x14
set OFF_ID     0x18
set OFF_RESET  0x1C   ;# RESET CSR

# ============================================================================
# Auto-detect Avalon-MM master
# ============================================================================
proc autodetect_master {} {
    set masters [get_service_paths master]
    if {[llength $masters] == 0} {
        error "No Avalon-MM master services found"
    }

    # Prefer JTAG / SLD fabric masters
    foreach m $masters {
        if {[string match "*master_0.master" $m] ||
            [string match "*jtag*" $m] ||
            [string match "*sld*" $m]} {
            return $m
        }
    }

    # Otherwise, take the first one
    return [lindex $masters 0]
}

# ============================================================================
# Low-level helpers
# ============================================================================
proc open_master {} {
    set m [autodetect_master]
    puts "Opening master service:"
    puts "  $m"
    open_service master $m
    return $m
}

proc close_master {m} {
    puts "Closing master service..."
    catch {close_service master $m}
}

proc wr32 {m addr val} {
    master_write_32 $m $addr $val
}

proc rd32 {m addr} {
    return [lindex [master_read_32 $m $addr 1] 0]
}

# ============================================================================
# High-level operations
# ============================================================================
proc set_cell_addr {m base cell} {
    global OFF_ADDR
    wr32 $m [expr {$base + $OFF_ADDR}] $cell
}

proc set_basis {m base basis} {
    global OFF_CTRL
    wr32 $m [expr {$base + $OFF_CTRL}] $basis
}

proc do_init {m base cell value basis} {
    global OFF_INIT
    set_cell_addr $m $base $cell
    # INIT payload: value[7:0], basis[15:8]
    set payload [expr {($value & 0xFF) | (($basis & 0xFF) << 8)}]
    wr32 $m [expr {$base + $OFF_INIT}] $payload
}

proc trig_write {m base} {
    global OFF_TRIG
    wr32 $m [expr {$base + $OFF_TRIG}] 1
}

proc trig_read_data0 {m base} {
    global OFF_DATA0
    return [rd32 $m [expr {$base + $OFF_DATA0}]]
}

proc do_reset_pulse {m base} {
    global OFF_RESET
    # write 1 => soft reset pulse generated internally
    wr32 $m [expr {$base + $OFF_RESET}] 1
    after 2
    # optional deassert write (harmless)
    wr32 $m [expr {$base + $OFF_RESET}] 0
    after 2
}

# ============================================================================
# Utility: PASS/FAIL bookkeeping
# ============================================================================
proc report {name pass msg} {
    if {$pass} {
        puts [format "PASS: %-26s %s" $name $msg]
    } else {
        puts [format "FAIL: %-26s %s" $name $msg]
    }
    return $pass
}

proc count_eq {lst val} {
    set c 0
    foreach x $lst {
        if {$x == $val} { incr c }
    }
    return $c
}

# ============================================================================
# Attack Suite
# ============================================================================
proc byteroom_sneaky_attack_suite {} {
    global BASE OFF_STATUS OFF_ID

    # Parameters
    set CELL0     0
    set CELL1     1
    set SECRET    0xA5
    set BASIS_OK  0x3C
    set BASIS_BAD 0x55

    set m [open_master]

    puts "============================================================"
    puts " ByteROOM SNEAKY AVALON ATTACK SUITE (WITH RESETS)"
    puts "============================================================"
    puts "Cells      = $CELL0 (target), $CELL1 (decoy)"
    puts [format "Secret     = 0x%02X" $SECRET]
    puts [format "Basis OK   = 0x%02X" $BASIS_OK]
    puts [format "Basis BAD  = 0x%02X" $BASIS_BAD]

    set id [rd32 $m [expr {$BASE + $OFF_ID}]]
    puts [format "ID         = 0x%08X" $id]
    puts ""

    set overall 1

    # A0: Read DATA0 without INIT
    set_basis $m $BASE $BASIS_OK
    set_cell_addr $m $BASE $CELL0
    set r0 [trig_read_data0 $m $BASE]
    set overall [expr {$overall && [report "A0 no-init read" [expr {$r0 != $SECRET}] \
        [format "DATA0=0x%02X (expect !=0x%02X)" $r0 $SECRET]]}]

    # A1: Misc non-DATA reads then DATA0
    for {set i 0} {$i < 25} {incr i} {
        rd32 $m [expr {$BASE + $OFF_STATUS}]
        rd32 $m [expr {$BASE + $OFF_ID}]
    }
    set r1 [trig_read_data0 $m $BASE]
    set overall [expr {$overall && [report "A1 non-data reads" [expr {$r1 != $SECRET}] \
        [format "DATA0=0x%02X after misc reads" $r1]]}]

    # A2: Correct basis first
    do_init $m $BASE $CELL0 $SECRET $BASIS_OK
    set_basis $m $BASE $BASIS_OK
    set_cell_addr $m $BASE $CELL0
    set a2_r1 [trig_read_data0 $m $BASE]
    set a2_r2 [trig_read_data0 $m $BASE]
    set overall [expr {$overall && [report "A2 correct-first" [expr {($a2_r1 == $SECRET) && ($a2_r2 != $SECRET)}] \
        [format "r1=0x%02X r2=0x%02X" $a2_r1 $a2_r2]]}]

    # A3: Wrong basis first
    do_init $m $BASE $CELL0 $SECRET $BASIS_OK
    set_basis $m $BASE $BASIS_BAD
    set_cell_addr $m $BASE $CELL0
    set a3_r1 [trig_read_data0 $m $BASE]
    set_basis $m $BASE $BASIS_OK
    set a3_r2 [trig_read_data0 $m $BASE]
    set overall [expr {$overall && [report "A3 wrong-first" [expr {($a3_r1 != $SECRET) && ($a3_r2 != $SECRET)}] \
        [format "r1=0x%02X r2=0x%02X" $a3_r1 $a3_r2]]}]

    # A4: TRIG-write DoS then read
    do_init $m $BASE $CELL0 $SECRET $BASIS_OK
    set_basis $m $BASE $BASIS_OK
    set_cell_addr $m $BASE $CELL0
    trig_write $m $BASE
    set a4_r1 [trig_read_data0 $m $BASE]
    set overall [expr {$overall && [report "A4 trig-write DoS" [expr {$a4_r1 != $SECRET}] \
        [format "DATA0=0x%02X (expect !=0x%02X)" $a4_r1 $SECRET]]}]

    # A5: Basis flip race
    do_init $m $BASE $CELL0 $SECRET $BASIS_OK
    set_cell_addr $m $BASE $CELL0
    set_basis $m $BASE $BASIS_OK
    set_basis $m $BASE $BASIS_BAD
    set a5_r1 [trig_read_data0 $m $BASE]
    set overall [expr {$overall && [report "A5 basis flip" [expr {$a5_r1 != $SECRET}] \
        [format "DATA0=0x%02X" $a5_r1]]}]

    # A6: Address confusion
    do_init $m $BASE $CELL0 $SECRET $BASIS_OK
    set_basis $m $BASE $BASIS_OK
    set_cell_addr $m $BASE $CELL1
    set a6_r1 [trig_read_data0 $m $BASE]
    set overall [expr {$overall && [report "A6 wrong address" [expr {$a6_r1 != $SECRET}] \
        [format "DATA0=0x%02X (cell %d)" $a6_r1 $CELL1]]}]

    # A7: Read storm
    do_init $m $BASE $CELL0 $SECRET $BASIS_OK
    set_basis $m $BASE $BASIS_OK
    set_cell_addr $m $BASE $CELL0
    set samples {}
    for {set i 0} {$i < 32} {incr i} {
        lappend samples [trig_read_data0 $m $BASE]
    }
    set hits [count_eq $samples $SECRET]
    set overall [expr {$overall && [report "A7 read storm" [expr {$hits <= 1}] \
        [format "secret_hits=%d (expect <=1)" $hits]]}]

    # R1: Reset-after-init
    do_init $m $BASE $CELL0 $SECRET $BASIS_OK
    set_basis $m $BASE $BASIS_OK
    set_cell_addr $m $BASE $CELL0
    do_reset_pulse $m $BASE
    set rr1 [trig_read_data0 $m $BASE]
    set overall [expr {$overall && [report "R1 reset-after-init" [expr {$rr1 != $SECRET}] \
        [format "DATA0=0x%02X (expect !=0x%02X)" $rr1 $SECRET]]}]

    # R2: Reset-between-wrong-and-correct
    do_init $m $BASE $CELL0 $SECRET $BASIS_OK
    set_cell_addr $m $BASE $CELL0
    set_basis $m $BASE $BASIS_BAD
    set w1 [trig_read_data0 $m $BASE]
    do_reset_pulse $m $BASE
    set_basis $m $BASE $BASIS_OK
    set w2 [trig_read_data0 $m $BASE]
    set overall [expr {$overall && [report "R2 reset-no-revive" [expr {($w1 != $SECRET) && ($w2 != $SECRET)}] \
        [format "wrong=0x%02X after_reset=0x%02X" $w1 $w2]]}]

    # Summary
    set st [rd32 $m [expr {$BASE + $OFF_STATUS}]]
    puts ""
    puts "---- FINAL STATUS ----"
    puts [format "STATUS -> 0x%08X" $st]
    puts ""
    puts "============================================================"
    if {$overall} {
        puts "OVERALL RESULT: PASS (attacks did not break the semantics)"
    } else {
        puts "OVERALL RESULT: FAIL (one or more attacks succeeded)"
    }
    puts "============================================================"

    close_master $m
}

# Auto-run
byteroom_sneaky_attack_suite
