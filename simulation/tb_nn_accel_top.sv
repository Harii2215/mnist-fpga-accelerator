// =============================================================================
// tb_nn_accel_top.sv -- end-to-end self-checking testbench.
//
// Loads the same weights/bias/input that python/quantize.py emitted, runs the
// full accelerator, then compares the OSRAM contents against the Python
// golden output byte for byte and reports PASS / FAIL.
// =============================================================================

`timescale 1ns/1ps

module tb_nn_accel_top;
    import nn_pkg::*;

    // ---- clock / reset ------------------------------------------------------
    logic clk = 0;
    always #5 clk = ~clk;                          // 100 MHz
    logic rst_n = 0;

    // ---- DUT ports ----------------------------------------------------------
    logic        reg_we;
    logic [7:0]  reg_addr;
    logic [31:0] reg_wdata, reg_rdata;
    logic        irq;

    logic                       dram_re;
    logic [31:0]                dram_addr;
    logic [WSRAM_WORD_W-1:0]    dram_rdata;

    logic [OUTPUT_SIZE*DATA_WIDTH-1:0] out_logits_packed;
    logic                              out_valid;

    nn_accel_top dut (
        .clk(clk), .rst_n(rst_n),
        .reg_we(reg_we), .reg_addr(reg_addr),
        .reg_wdata(reg_wdata), .reg_rdata(reg_rdata),
        .irq(irq),
        .dram_re(dram_re), .dram_addr(dram_addr), .dram_rdata(dram_rdata),
        .out_logits_packed(out_logits_packed),
        .out_valid(out_valid)
    );

    dram_model #(
        .W_FILE("weights_packed.mem"),
        .B_FILE("bias_packed.mem"),
        .I_FILE("input_packed.mem")
    ) u_dram (
        .clk(clk), .re(dram_re), .addr(dram_addr), .rdata(dram_rdata)
    );

    // ---- golden ----
    logic [DATA_WIDTH-1:0]         golden_raw [0:OUTPUT_SIZE-1];
    logic signed [DATA_WIDTH-1:0]  golden     [0:OUTPUT_SIZE-1];
    initial begin
        $readmemh("golden_output.mem", golden_raw);
        for (int gi = 0; gi < OUTPUT_SIZE; gi++) golden[gi] = golden_raw[gi];
    end

    // ---- helpers ------------------------------------------------------------
    task automatic reg_write(input [7:0] a, input [31:0] d);
        @(posedge clk);
        reg_we    <= 1'b1;
        reg_addr  <= a;
        reg_wdata <= d;
        @(posedge clk);
        reg_we    <= 1'b0;
    endtask

    task automatic reg_read(input [7:0] a, output [31:0] d);
        @(posedge clk);
        reg_we    <= 1'b0;
        reg_addr  <= a;
        @(posedge clk);
        d = reg_rdata;
    endtask

















    // ---- main ---------------------------------------------------------------
    integer errors;
    integer wait_cycles;
    logic [31:0] rd;
    logic        done_seen;
    logic signed [DATA_WIDTH-1:0] got;
    int rtl_argmax, py_argmax;

    initial begin
        $dumpfile("nn_accel.vcd");
        $dumpvars(0, tb_nn_accel_top);

        reg_we = 0; reg_addr = 0; reg_wdata = 0;
        errors = 0;
        wait_cycles = 0;
        done_seen = 0;
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        // Program input pointer (DRAM input area starts at 0x20000)
        reg_write(8'h08, 32'h0002_0000);

        // Kick off
        $display("[TB] t=%0t : starting inference (writing CTRL.start)", $time);
        reg_write(8'h00, 32'h0000_0001);

        // Poll STATUS.done with a hard upper bound on cycles
        while (!done_seen && wait_cycles < 100000) begin
            reg_read(8'h04, rd);
            if (rd[1]) done_seen = 1'b1;
            wait_cycles = wait_cycles + 1;
        end

        if (!done_seen) begin
            $display("[TB] *** TIMEOUT after %0d poll iterations ***", wait_cycles);
            $finish;
        end

        $display("[TB] t=%0t : done detected after %0d poll iterations\n",
                 $time, wait_cycles);

        // Compare
        $display("=================================================");
        $display("[TB]        RTL OUTPUT vs PYTHON GOLDEN");
        $display("=================================================");
        $display("[TB]  idx |   RTL (hex /  dec) | GOLDEN (hex /  dec) | status");
        $display("[TB] -----+--------------------+---------------------+--------");
        for (int i = 0; i < OUTPUT_SIZE; i++) begin
            got = out_logits_packed[i*DATA_WIDTH +: DATA_WIDTH];
            $display("[TB]  %2d  |     %02h  / %4d    |     %02h  / %4d     | %s",
                     i,
                     got    & 8'hff, got,
                     golden[i] & 8'hff, golden[i],
                     (got === golden[i]) ? "OK" : "MISMATCH");
            if (got !== golden[i]) errors = errors + 1;
        end

        // signed argmax
        rtl_argmax = 0;
        py_argmax  = 0;
        for (int i = 1; i < OUTPUT_SIZE; i++) begin
            if ($signed(out_logits_packed[i*DATA_WIDTH +: DATA_WIDTH]) >
                $signed(out_logits_packed[rtl_argmax*DATA_WIDTH +: DATA_WIDTH]))
                rtl_argmax = i;
            if (golden[i] > golden[py_argmax]) py_argmax = i;
        end

        $display("\n[TB] RTL    argmax (predicted digit) = %0d", rtl_argmax);
        $display("[TB] Python argmax (predicted digit) = %0d", py_argmax);

        reg_read(8'h1C, rd);
        $display("[TB] cycle_count register = %0d cycles  (~%0d us @ 100 MHz)",
                 rd, rd / 100);

        if (errors == 0)
            $display("\n[TB] ***** PASS : %0d/%0d outputs match Python golden *****",
                     OUTPUT_SIZE, OUTPUT_SIZE);
        else
            $display("\n[TB] ***** FAIL : %0d mismatches *****", errors);

        $finish;
    end

endmodule
