// ============================================================================
// collapse_cell.sv — Atomic Memory™ collapse cell (no local RO)
// Copyright (c) 2025  Francis X. Cunnane III / QSymbolic LLC
//
// RELEASED FOR: academic, research, evaluation, and non-commercial use ONLY.
// You may use, copy, or modify this file for NON-COMMERCIAL purposes,
// provided this notice remains intact.
//
// PROHIBITED WITHOUT LICENSE:
//   • commercial use
//   • incorporation into a commercial product
//   • redistribution in commercial tools or silicon
//
// Commercial licensing is available from QSymbolic LLC.
//
// Atomic Memory™ is a trademark of QSymbolic LLC.
//
// THIS IMPLEMENTATION IS PROVIDED “AS IS,” WITHOUT WARRANTY OF ANY KIND.
// ============================================================================

`timescale 1ns/1ps

module collapse_cell #(
    parameter int DATA_W  = 8,
    parameter int BASIS_W = 8
)(
    input  wire                  clk,
    input  wire                  rst,

    // INIT interface
    input  wire                  init_en,
    input  wire [DATA_W-1:0]     init_value,
    input  wire [BASIS_W-1:0]    init_basis,

    // READ / collapse interface
    input  wire                  read_pulse,
    input  wire [BASIS_W-1:0]    basis_in,

    // Shared entropy input (from bank-level core)
    input  wire [DATA_W-1:0]     entropy_in,

    // Data output
    output logic [DATA_W-1:0]    data_o
);

    // -------------------------------------------------------------------------
    // Internal state
    // -------------------------------------------------------------------------
    logic [DATA_W-1:0]  value_q;
    logic [BASIS_W-1:0] basis_q;

    logic               armed_q;
    logic               collapsed_q;
    logic               basis_valid_q;

    wire basis_match = basis_valid_q && (basis_in == basis_q);

    // -------------------------------------------------------------------------
    // Atomic Memory™ collapse logic
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            value_q       <= '0;
            basis_q       <= '0;
            basis_valid_q <= 1'b0;
            armed_q       <= 1'b0;
            collapsed_q   <= 1'b0;
            data_o        <= '0;
        end else begin

            // -------------------- INIT --------------------
            if (init_en) begin
                value_q       <= init_value;
                basis_q       <= init_basis;
                basis_valid_q <= 1'b1;
                armed_q       <= 1'b1;
                collapsed_q   <= 1'b0;
                // data_o unchanged on INIT
            end

            // ---------------- READ / COLLAPSE --------------
            if (read_pulse) begin
                if (!armed_q) begin
                    // Unarmed → behave like collapsed
                    data_o  <= entropy_in;
                    value_q <= entropy_in;

                end else begin
                    if (!collapsed_q) begin
                        // ---------- FIRST MEASUREMENT ----------
                        if (basis_match) begin
                            // Correct basis → return stored value
                            // but collapse to entropy
                            data_o  <= value_q;
                            value_q <= entropy_in;
                        end else begin
                            // Wrong basis → direct entropy
                            data_o  <= entropy_in;
                            value_q <= entropy_in;
                        end

                        collapsed_q   <= 1'b1;
                        basis_valid_q <= 1'b0;
                        armed_q       <= 1'b0;

                    end else begin
                        // ---------- POST-COLLAPSE ----------
                        data_o  <= entropy_in;
                        value_q <= entropy_in;
                    end
                end
            end
        end
    end

endmodule
