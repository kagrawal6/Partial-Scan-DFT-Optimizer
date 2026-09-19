# =============================================================================
# nonscan_ff_list.tcl — Flip-flops excluded from the scan chain (K = 20)
#
# Selected as the highest-SCOAP difficulty set that maximized M under a single
# scan chain. Edit this list to explore other K-sets, then re-run synthesis.
# =============================================================================

set NONSCAN_FF_LIST {
    reg1_reg[3]
    reg1_reg[4]
    reg1_reg[5]
    reg1_reg[6]
    reg1_reg[7]
    reg1_reg[8]
    reg1_reg[9]
    reg1_reg[10]
    reg1_reg[11]
    reg1_reg[12]
    reg1_reg[13]
    reg1_reg[14]
    reg1_reg[15]
    reg1_reg[16]
    reg1_reg[17]
    reg1_reg[18]
    reg1_reg[19]
    B_reg
    d_reg[0]
    d_reg[1]
}
