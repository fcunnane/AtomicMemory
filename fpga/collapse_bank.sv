// ============================================================================
// collapse_bank.sv — Atomic Memory™ bank of collapse cells with shared entropy
// Copyright (c) 2025  Francis X. Cunnane III / QSymbolic LLC
//
// RELEASED FOR: academic, research, evaluation, and non-commercial use ONLY.
// You may use, copy, or modify this file for NON-COMMERCIAL purposes,
// provided this notice remains intact.
//
// PROHIBITED WITHOUT LICENSE:
//   • commercial use
//   • inclusion in any commercial silicon, tool, board, or IP library
//   • redistribution as part of a commercial product
//
// Commercial licensing is available from QSymbolic LLC.
//
// Atomic Memory™ is a trademark of QSymbolic LLC.
//
// THIS IMPLEMENTATION IS PROVIDED “AS IS,” WITHOUT WARRANTY OF ANY KIND.
// ============================================================================

`timescale 1ns/1ps

module collapse_bank #(
    parameter int N        = 1024,
    parameter int DATA_W   = 8,
    parameter int BASIS_W  = 8,
    parameter int ADDR_W   = $clog2(N)
)(
    input  wire               clk,
    input  wire               rst,

    // --------------------- INIT INTERFACE -------------------------
    input  wire [ADDR_W-1:0]  init_addr,
    input  wire [DATA_W-1:0]  init_value,
    input  wire [BASIS_W-1:0] init_basis,
    input  wire               init_strobe,

    // --------------------- READ INTERFACE -------------------------
    input  wire [ADDR_W-1:0]  read_addr,
    input  wire [BASIS_W-1:0] basis_in,
    input  wire               read_pulse,

    // ----------------------- DATA OUTPUT --------------------------
    output logic [DATA_W-1:0] data_o
);

    // =====================================================================
    // ENTROPY CORE
    //   Two RO chains → XOR → synchronizer
    //   von Neumann sampler → debiased bit
    //   8-bit LFSR stirred by sampled bit
    //   Provides entropy_byte to every collapse_cell
    // =====================================================================

    //---------------------- RO chains -----------------------------
    wire ro0_raw, ro1_raw;
    wire ro_xor;

    ro_chain #(.STAGES(5)) URO0 (
        .en (1'b1),
        .ro (ro0_raw)
    );

    ro_chain #(.STAGES(5)) URO1 (
        .en (1'b1),
        .ro (ro1_raw)
    );

    assign ro_xor = ro0_raw ^ ro1_raw;

    //------------------ Synchronize into clk domain ----------------
    logic ro_sync1, ro_sync2;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ro_sync1 <= 1'b0;
            ro_sync2 <= 1'b0;
        end else begin
            ro_sync1 <= ro_xor;
            ro_sync2 <= ro_sync1;
        end
    end

    // ---------------- von Neumann debias sampler -----------------
    logic last_bit_q;
    logic have_last_q;
    logic vn_ready_q;
    logic vn_bit_q;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            last_bit_q  <= 1'b0;
            have_last_q <= 1'b0;
            vn_ready_q  <= 1'b0;
            vn_bit_q    <= 1'b0;
        end else begin
            vn_ready_q <= 1'b0;  // pulse when a valid pair arrives

            if (!have_last_q) begin
                last_bit_q  <= ro_sync2;
                have_last_q <= 1'b1;
            end else begin
                if (ro_sync2 != last_bit_q) begin
                    // 01 → 1, 10 → 0
                    vn_bit_q   <= ro_sync2;
                    vn_ready_q <= 1'b1;
                end
                have_last_q <= 1'b0;
            end
        end
    end

    // Select bit to stir LFSR:
    wire sample_bit = vn_ready_q ? vn_bit_q : ro_sync2;

    // ----------------------- 8-bit LFSR --------------------------
    logic [DATA_W-1:0] lfsr_q;
    wire feedback = lfsr_q[7] ^ lfsr_q[5] ^ lfsr_q[4] ^ lfsr_q[3] ^ sample_bit;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            lfsr_q <= 8'hA5;
        end else begin
            lfsr_q <= {lfsr_q[DATA_W-2:0], feedback};
        end
    end

    wire [DATA_W-1:0] entropy_byte = lfsr_q;

    // =====================================================================
    // DECODE: one-hot init & read strobes
    // =====================================================================
    logic [N-1:0] init_sel;
    logic [N-1:0] read_sel;

    genvar gi;
    generate
        for (gi = 0; gi < N; gi++) begin : DECODE
            assign init_sel[gi] = init_strobe && (init_addr == gi[ADDR_W-1:0]);
            assign read_sel[gi] = read_pulse  && (read_addr == gi[ADDR_W-1:0]);
        end
    endgenerate

    // =====================================================================
    // CELL ARRAY
    // =====================================================================
    logic [DATA_W-1:0] cell_data [N];

    genvar i;
    generate
        for (i = 0; i < N; i++) begin : CELLS
            collapse_cell #(
                .DATA_W (DATA_W),
                .BASIS_W(BASIS_W)
            ) U_CELL (
                .clk        (clk),
                .rst        (rst),

                .init_en    (init_sel[i]),
                .init_value (init_value),
                .init_basis (init_basis),

                .read_pulse (read_sel[i]),
                .basis_in   (basis_in),

                .entropy_in (entropy_byte),

                .data_o     (cell_data[i])
            );
        end
    endgenerate

    // =====================================================================
    // READ MUX — select cell output based on read_addr
    // =====================================================================
    always_comb begin
        data_o = '0;
        for (int k = 0; k < N; k++) begin
            if (read_addr == k[ADDR_W-1:0]) begin
                data_o = cell_data[k];
            end
        end
    end

endmodule


// ============================================================================
// ro_chain — Simple odd-length inverter ring oscillator
//   STAGES must be odd (3,5,7,...). 'en' gates oscillation.
// ============================================================================
module ro_chain #(
    parameter int STAGES = 5
)(
    input  wire en,
    output wire ro
);

    (* keep = "true", preserve = "true" *)
    wire [STAGES-1:0] n;

    assign n[0] = en ? ~n[STAGES-1] : 1'b0;

    genvar j;
    generate
        for (j = 1; j < STAGES; j++) begin : GEN_RO
            assign n[j] = ~n[j-1];
        end
    endgenerate

    assign ro = n[STAGES-1];

endmodule
