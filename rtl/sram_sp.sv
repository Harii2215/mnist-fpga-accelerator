// =============================================================================
// sram_sp.sv -- generic single-port synchronous SRAM, inferable as BRAM.
//
// Synthesis notes:
// - One write port, one read port, both registered (standard BRAM template).
// - Read-during-write returns OLD data ("read-first") -- safest for FSMs that
//   would otherwise see X on the read path during the write cycle.
// - Optional INIT_FILE loads $readmemh at elaboration; useful for sim and
//   for FPGA bring-up where weights live in BRAM init.
// =============================================================================
`timescale 1ns/1ps
module sram_sp #(
    parameter int    DATA_W     = 8,
    parameter int    DEPTH      = 1024,
    parameter int    ADDR_W     = (DEPTH<=1) ? 1 : $clog2(DEPTH),
    // NOTE: declared WITHOUT the `string` keyword. Vivado synthesis
    // ([Synth 8-27] "string type not supported") rejects `parameter string`.
    // An untyped string-literal parameter works for $readmemh and synthesizes.
    parameter        INIT_FILE  = "",
    // NEW: number of low words to expose for read-back. 0 = feature disabled.
    parameter int    PEEK_WORDS = 0
) (
    input  logic                clk,
    input  logic                en,
    input  logic                we,
    input  logic [ADDR_W-1:0]   addr,
    input  logic [DATA_W-1:0]   din,
    output logic [DATA_W-1:0]   dout,
    // NEW: flattened, synthesizable read-back of the first PEEK_WORDS entries.
    // The width is clamped to >=1 bit so the port stays legal when PEEK_WORDS==0.
    output logic [((PEEK_WORDS>0 ? PEEK_WORDS : 1)*DATA_W)-1:0] peek_flat
);

    // Memory array -- synthesis tools will infer BRAM for DEPTH >= ~512.
    (* ram_style = "block" *) logic [DATA_W-1:0] mem [0:DEPTH-1];

    // Optional memory initialization from a hex file. Wrapped in a generate
    // guard so the $readmemh path is only elaborated when an INIT_FILE is
    // actually given -- keeps Vivado happy with the untyped string param.
    generate
        if (INIT_FILE != "") begin : g_init
            initial begin
                $display("[sram_sp] $readmemh from %s", INIT_FILE);
                $readmemh(INIT_FILE, mem);
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (en) begin
            if (we) mem[addr] <= din;
            dout <= mem[addr];   // read-first
        end
    end

    // ---- synthesizable read-back of the first PEEK_WORDS words ----
    genvar p;
    generate
        if (PEEK_WORDS > 0) begin : g_peek
            for (p = 0; p < PEEK_WORDS; p++) begin : g_peek_word
                assign peek_flat[p*DATA_W +: DATA_W] = mem[p];
            end
        end else begin : g_no_peek
            assign peek_flat = '0;
        end
    endgenerate

endmodule
