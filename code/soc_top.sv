`timescale 1ns / 1ps

module soc_top #(
    parameter int MATRIX_SIZE = 4,
    parameter int DATA_WIDTH  = 4,
    parameter int PSUM_WIDTH  = 10,
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32,
    parameter int BRAM_DEPTH     = 48   // depth of the internal shared "DRAM"
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_sys CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi_lite:s_dram_axi_lite, ASSOCIATED_RESET rst_sys_n" *)
    input  logic        clk_sys,
    input  logic        rst_sys_n,

    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_accel CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET rst_accel_n" *)
    input  logic        clk_accel,
    input  logic        rst_accel_n,

    // ===== DMA control/status register port (host/RISC configures DMA) =====
    input  logic [31:0] s_axi_lite_awaddr,
    input  logic        s_axi_lite_awvalid,
    output logic        s_axi_lite_awready,
    input  logic [31:0] s_axi_lite_wdata,
    input  logic        s_axi_lite_wvalid,
    output logic        s_axi_lite_wready,
    output logic [1:0]  s_axi_lite_bresp,
    output logic        s_axi_lite_bvalid,
    input  logic        s_axi_lite_bready,
    input  logic [31:0] s_axi_lite_araddr,
    input  logic        s_axi_lite_arvalid,
    output logic        s_axi_lite_arready,
    output logic [31:0] s_axi_lite_rdata,
    output logic [1:0]  s_axi_lite_rresp,
    output logic        s_axi_lite_rvalid,
    input  logic        s_axi_lite_rready,

    // ===== NEW: RISC direct access to shared on-chip DRAM (AXI4-Lite) =====
    input  logic [AXI_ADDR_WIDTH-1:0]     s_dram_axi_lite_awaddr,
    input  logic                          s_dram_axi_lite_awvalid,
    output logic                          s_dram_axi_lite_awready,
    input  logic [AXI_DATA_WIDTH-1:0]     s_dram_axi_lite_wdata,
    input  logic [(AXI_DATA_WIDTH/8)-1:0] s_dram_axi_lite_wstrb,
    input  logic                          s_dram_axi_lite_wvalid,
    output logic                          s_dram_axi_lite_wready,
    output logic [1:0]                    s_dram_axi_lite_bresp,
    output logic                          s_dram_axi_lite_bvalid,
    input  logic                          s_dram_axi_lite_bready,
    input  logic [AXI_ADDR_WIDTH-1:0]     s_dram_axi_lite_araddr,
    input  logic                          s_dram_axi_lite_arvalid,
    output logic                          s_dram_axi_lite_arready,
    output logic [AXI_DATA_WIDTH-1:0]     s_dram_axi_lite_rdata,
    output logic [1:0]                    s_dram_axi_lite_rresp,
    output logic                          s_dram_axi_lite_rvalid,
    input  logic                          s_dram_axi_lite_rready
);

    localparam int IN_BITS  = 2 * MATRIX_SIZE * MATRIX_SIZE * DATA_WIDTH;
    localparam int OUT_BITS = MATRIX_SIZE * MATRIX_SIZE * DATA_WIDTH;

    logic [3:0] mm2s_tdata;
    logic       mm2s_tvalid;
    logic       mm2s_tready;

    logic [3:0] s2mm_tdata;
    logic       s2mm_tvalid;
    logic       s2mm_tready;

    logic [0:0][3:0] in_array_data;
    logic            in_array_valid;
    logic            in_array_ready;

    logic [0:0][3:0] out_array_data;
    logic            out_array_valid;
    logic            out_array_ready;
    logic            out_array_last;

    logic [IN_BITS-1:0]  systolic_in_data;
    logic [OUT_BITS-1:0] systolic_out_data;
    logic                systolic_start;
    logic                systolic_valid;

    // -------------------------------------------------------------------
    // Internal AXI4 (full) master <-> shared DRAM slave wires.
    // These used to be top-level m_axi_* ports; now the DMA's master
    // interface plugs straight into bram_axi_top's AXI4 slave port
    // instead of leaving memory external to the SoC.
    // -------------------------------------------------------------------
    logic [AXI_ADDR_WIDTH-1:0] m_axi_araddr;
    logic [7:0]                m_axi_arlen;
    logic [2:0]                m_axi_arsize;
    logic [1:0]                m_axi_arburst;
    logic                      m_axi_arvalid;
    logic                      m_axi_arready;
    logic [AXI_DATA_WIDTH-1:0] m_axi_rdata;
    logic [1:0]                m_axi_rresp;
    logic                      m_axi_rlast;
    logic                      m_axi_rvalid;
    logic                      m_axi_rready;

    logic [AXI_ADDR_WIDTH-1:0] m_axi_awaddr;
    logic [7:0]                m_axi_awlen;
    logic [2:0]                m_axi_awsize;
    logic [1:0]                m_axi_awburst;
    logic                      m_axi_awvalid;
    logic                      m_axi_awready;
    logic [AXI_DATA_WIDTH-1:0] m_axi_wdata;
    logic [(AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb;
    logic                      m_axi_wvalid;
    logic                      m_axi_wlast;
    logic                      m_axi_wready;
    logic [1:0]                m_axi_bresp;
    logic                      m_axi_bvalid;
    logic                      m_axi_bready;

    // ---------------------------------------------------------------
    // DMA engine
    // ---------------------------------------------------------------
    dma #(
        .ADDR_WIDTH   (AXI_ADDR_WIDTH),
        .DATA_WIDTH   (AXI_DATA_WIDTH),
        .STREAM_WIDTH (4)
    ) u_dma (
        .clk                   (clk_sys),
        .rst_n                 (rst_sys_n),

        .s_axi_lite_awaddr     (s_axi_lite_awaddr),
        .s_axi_lite_awvalid    (s_axi_lite_awvalid),
        .s_axi_lite_awready    (s_axi_lite_awready),
        .s_axi_lite_wdata      (s_axi_lite_wdata),
        .s_axi_lite_wvalid     (s_axi_lite_wvalid),
        .s_axi_lite_wready     (s_axi_lite_wready),
        .s_axi_lite_bresp      (s_axi_lite_bresp),
        .s_axi_lite_bvalid     (s_axi_lite_bvalid),
        .s_axi_lite_bready     (s_axi_lite_bready),
        .s_axi_lite_araddr     (s_axi_lite_araddr),
        .s_axi_lite_arvalid    (s_axi_lite_arvalid),
        .s_axi_lite_arready    (s_axi_lite_arready),
        .s_axi_lite_rdata      (s_axi_lite_rdata),
        .s_axi_lite_rresp      (s_axi_lite_rresp),
        .s_axi_lite_rvalid     (s_axi_lite_rvalid),
        .s_axi_lite_rready     (s_axi_lite_rready),

        .m_axi_araddr          (m_axi_araddr),
        .m_axi_arlen           (m_axi_arlen),
        .m_axi_arsize          (m_axi_arsize),
        .m_axi_arburst         (m_axi_arburst),
        .m_axi_arvalid         (m_axi_arvalid),
        .m_axi_arready         (m_axi_arready),
        .m_axi_rdata           (m_axi_rdata),
        .m_axi_rresp           (m_axi_rresp),
        .m_axi_rlast           (m_axi_rlast),
        .m_axi_rvalid          (m_axi_rvalid),
        .m_axi_rready          (m_axi_rready),
        .m_axi_awaddr          (m_axi_awaddr),
        .m_axi_awlen           (m_axi_awlen),
        .m_axi_awsize          (m_axi_awsize),
        .m_axi_awburst         (m_axi_awburst),
        .m_axi_awvalid         (m_axi_awvalid),
        .m_axi_awready         (m_axi_awready),
        .m_axi_wdata           (m_axi_wdata),
        .m_axi_wstrb           (m_axi_wstrb),
        .m_axi_wvalid          (m_axi_wvalid),
        .m_axi_wlast           (m_axi_wlast),
        .m_axi_wready          (m_axi_wready),
        .m_axi_bresp           (m_axi_bresp),
        .m_axi_bvalid          (m_axi_bvalid),
        .m_axi_bready          (m_axi_bready),

        .m_axis_mm2s_tdata     (mm2s_tdata),
        .m_axis_mm2s_tvalid    (mm2s_tvalid),
        .m_axis_mm2s_tready    (mm2s_tready),
        .s_axis_s2mm_tdata     (s2mm_tdata),
        .s_axis_s2mm_tvalid    (s2mm_tvalid),
        .s_axis_s2mm_tready    (s2mm_tready)
    );

    // ---------------------------------------------------------------
    // Shared on-chip "DRAM" - dual-port BRAM behind an AXI4 (DMA side,
    // priority) and AXI4-Lite (RISC side) arbiter. This is the piece
    // that used to be commented out / external in the testbench; it
    // now lives inside the SoC and is what m_axi_* actually drives.
    // ---------------------------------------------------------------
    bram_axi_top #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .BRAM_DEPTH     (BRAM_DEPTH)
    ) u_dram (
        .clk                  (clk_sys),
        .rst_n                (rst_sys_n),

        // AXI4 slave port <- DMA master (internal, no longer top-level)
        .s_axi_awaddr         (m_axi_awaddr),
        .s_axi_awlen          (m_axi_awlen),
        .s_axi_awsize         (m_axi_awsize),
        .s_axi_awburst        (m_axi_awburst),
        .s_axi_awvalid        (m_axi_awvalid),
        .s_axi_awready        (m_axi_awready),
        .s_axi_wdata          (m_axi_wdata),
        .s_axi_wstrb          (m_axi_wstrb),
        .s_axi_wlast          (m_axi_wlast),
        .s_axi_wvalid         (m_axi_wvalid),
        .s_axi_wready         (m_axi_wready),
        .s_axi_bresp          (m_axi_bresp),
        .s_axi_bvalid         (m_axi_bvalid),
        .s_axi_bready         (m_axi_bready),
        .s_axi_araddr         (m_axi_araddr),
        .s_axi_arlen          (m_axi_arlen),
        .s_axi_arsize         (m_axi_arsize),
        .s_axi_arburst        (m_axi_arburst),
        .s_axi_arvalid        (m_axi_arvalid),
        .s_axi_arready        (m_axi_arready),
        .s_axi_rdata          (m_axi_rdata),
        .s_axi_rresp          (m_axi_rresp),
        .s_axi_rlast          (m_axi_rlast),
        .s_axi_rvalid         (m_axi_rvalid),
        .s_axi_rready         (m_axi_rready),

        // AXI4-Lite slave port <- RISC master (exposed at top level)
        .s_axi_lite_awaddr    (s_dram_axi_lite_awaddr),
        .s_axi_lite_awvalid   (s_dram_axi_lite_awvalid),
        .s_axi_lite_awready   (s_dram_axi_lite_awready),
        .s_axi_lite_wdata     (s_dram_axi_lite_wdata),
        .s_axi_lite_wstrb     (s_dram_axi_lite_wstrb),
        .s_axi_lite_wvalid    (s_dram_axi_lite_wvalid),
        .s_axi_lite_wready    (s_dram_axi_lite_wready),
        .s_axi_lite_bresp     (s_dram_axi_lite_bresp),
        .s_axi_lite_bvalid    (s_dram_axi_lite_bvalid),
        .s_axi_lite_bready    (s_dram_axi_lite_bready),
        .s_axi_lite_araddr    (s_dram_axi_lite_araddr),
        .s_axi_lite_arvalid   (s_dram_axi_lite_arvalid),
        .s_axi_lite_arready   (s_dram_axi_lite_arready),
        .s_axi_lite_rdata     (s_dram_axi_lite_rdata),
        .s_axi_lite_rresp     (s_dram_axi_lite_rresp),
        .s_axi_lite_rvalid    (s_dram_axi_lite_rvalid),
        .s_axi_lite_rready    (s_dram_axi_lite_rready)
    );

    accel_buffer_top #(
        .IN_DATA_WIDTH    (4),
        .IN_NUM_CHANNELS  (1),
        .IN_DEPTH         (32),
        .OUT_DATA_WIDTH   (4),
        .OUT_NUM_CHANNELS (1),
        .OUT_DEPTH        (32)
    ) u_accel_buffer (
        .clk_sys          (clk_sys),
        .rst_sys_n        (rst_sys_n),
        .clk_accel        (clk_accel),
        .rst_accel_n      (rst_accel_n),
        .in_tdata         (mm2s_tdata),
        .in_tvalid        (mm2s_tvalid),
        .in_tready        (mm2s_tready),
        .in_tlast         (1'b0),
        .in_array_data    (in_array_data),
        .in_array_valid   (in_array_valid),
        .in_array_ready   (in_array_ready),
        .out_array_data   (out_array_data),
        .out_array_valid  (out_array_valid),
        .out_array_ready  (out_array_ready),
        .out_array_last   (out_array_last),
        .out_tdata        (s2mm_tdata),
        .out_tvalid       (s2mm_tvalid),
        .out_tready       (s2mm_tready),
        .out_tlast        ()
    );

    logic [5:0] in_nibble_cnt;
    logic [3:0] out_nibble_cnt;
    localparam int OUT_NIBBLES = OUT_BITS/4;  // = 16 for your config

    typedef enum logic [1:0] {S_COLLECT, S_COMPUTE, S_STREAM} state_t;
    state_t state;

    always_ff @(posedge clk_accel or negedge rst_accel_n) begin
        if (!rst_accel_n) begin
            state            <= S_COLLECT;
            in_nibble_cnt    <= '0;
            out_nibble_cnt   <= '0;
            systolic_in_data <= '0;
            systolic_start   <= 1'b0;
            in_array_ready   <= 1'b0;
            out_array_valid  <= 1'b0;
            out_array_last   <= 1'b0;
            out_array_data   <= '0;
        end else begin
            case (state)
                S_COLLECT: begin
                    in_array_ready  <= 1'b1;
                    out_array_valid <= 1'b0;
                    out_array_last  <= 1'b0;
                    systolic_start  <= 1'b0;
                    if (in_array_valid && in_array_ready) begin
                        systolic_in_data <= {
                            systolic_in_data[IN_BITS-DATA_WIDTH-1:0],
                            in_array_data[0]
                        };
                        if (in_nibble_cnt == (IN_BITS/4 - 1)) begin
                            in_nibble_cnt  <= '0;
                            in_array_ready <= 1'b0;
                            systolic_start <= 1'b1;
                            state          <= S_COMPUTE;
                        end else begin
                            in_nibble_cnt <= in_nibble_cnt + 1'b1;
                        end
                    end
                end

                S_COMPUTE: begin
    systolic_start <= 1'b0;
    if (systolic_valid == 1'b1) begin
        state              <= S_STREAM;
        out_nibble_cnt     <= '0;
        out_array_valid    <= 1'b1;
        out_array_data[0]  <= systolic_out_data[(OUT_NIBBLES-1)*4 +: 4]; // nibble 0
        out_array_last     <= (OUT_NIBBLES == 1); // true only if single-nibble output

        $display("[%0t] SOC S_COMPUTE->S_STREAM  systolic_out_data=%h  nibble_cnt=0 slice=[%0d +: 4]=%h",
                  $time, systolic_out_data,
                  (OUT_NIBBLES-1)*4, systolic_out_data[(OUT_NIBBLES-1)*4 +: 4]);
    end
end

S_STREAM: begin
    if (out_array_valid && out_array_ready) begin
        if (out_array_last) begin
            out_array_valid <= 1'b0;
            state           <= S_COLLECT;
            $display("[%0t] SOC S_STREAM  nibble_cnt=%0d (last) emitted=%h",
                      $time, out_nibble_cnt, out_array_data[0]);
        end else begin
            out_nibble_cnt     <= out_nibble_cnt + 1'b1;
            out_array_data[0]  <= systolic_out_data[(OUT_NIBBLES - (out_nibble_cnt+2))*4 +: 4];
            out_array_last     <= (out_nibble_cnt + 1 == OUT_NIBBLES - 1);

            $display("[%0t] SOC S_STREAM  nibble_cnt=%0d emitted=%h  next_nibble_cnt=%0d next_slice=[%0d +: 4]=%h",
                      $time, out_nibble_cnt, out_array_data[0],
                      out_nibble_cnt+1,
                      (OUT_NIBBLES - (out_nibble_cnt+2))*4,
                      systolic_out_data[(OUT_NIBBLES - (out_nibble_cnt+2))*4 +: 4]);
        end
    end
end

                default: state <= S_COLLECT;
            endcase
        end
    end

    systolic #(
        .MATRIX_SIZE (MATRIX_SIZE),
        .DATA_WIDTH  (DATA_WIDTH),
        .PSUM_WIDTH  (PSUM_WIDTH)
    ) u_systolic_core (
        .clk         (clk_accel),
        .rst_n       (rst_accel_n),
        .start       (systolic_start),
        .input_data  (systolic_in_data),
        .output_data (systolic_out_data),
        .valid       (systolic_valid)
    );

endmodule

//`timescale 1ns / 1ps

//module soc_top #(
//    parameter int MATRIX_SIZE = 4,
//    parameter int DATA_WIDTH  = 4,
//    parameter int PSUM_WIDTH  = 10
//)(
//    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_sys CLK" *)
//    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi_lite:m_axi, ASSOCIATED_RESET rst_sys_n" *)
//    input  logic        clk_sys,
//    input  logic        rst_sys_n,

//    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_accel CLK" *)
//    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET rst_accel_n" *)
//    input  logic        clk_accel,
//    input  logic        rst_accel_n,

//    input  logic [31:0] s_axi_lite_awaddr,
//    input  logic        s_axi_lite_awvalid,
//    output logic        s_axi_lite_awready,
//    input  logic [31:0] s_axi_lite_wdata,
//    input  logic        s_axi_lite_wvalid,
//    output logic        s_axi_lite_wready,
//    output logic [1:0]  s_axi_lite_bresp,
//    output logic        s_axi_lite_bvalid,
//    input  logic        s_axi_lite_bready,
//    input  logic [31:0] s_axi_lite_araddr,
//    input  logic        s_axi_lite_arvalid,
//    output logic        s_axi_lite_arready,
//    output logic [31:0] s_axi_lite_rdata,
//    output logic [1:0]  s_axi_lite_rresp,
//    output logic        s_axi_lite_rvalid,
//    input  logic        s_axi_lite_rready,

//    output logic [31:0] m_axi_araddr,
//    output logic [7:0]  m_axi_arlen,
//    output logic [2:0]  m_axi_arsize,
//    output logic [1:0]  m_axi_arburst,
//    output logic        m_axi_arvalid,
//    input  logic        m_axi_arready,
//    input  logic [31:0] m_axi_rdata,
//    input  logic [1:0]  m_axi_rresp,
//    input  logic        m_axi_rlast,
//    input  logic        m_axi_rvalid,
//    output logic        m_axi_rready,
    
//    output logic [31:0] m_axi_awaddr,
//    output logic [7:0]  m_axi_awlen,
//    output logic [2:0]  m_axi_awsize,
//    output logic [1:0]  m_axi_awburst,
//    output logic        m_axi_awvalid,
//    input  logic        m_axi_awready,
//    output logic [31:0] m_axi_wdata,
//    output logic [3:0]  m_axi_wstrb,
//    output logic        m_axi_wvalid,
//    output logic        m_axi_wlast,
//    input  logic        m_axi_wready,
//    input  logic [1:0]  m_axi_bresp,
//    input  logic        m_axi_bvalid,
//    output logic        m_axi_bready
//);

//    localparam int IN_BITS  = 2 * MATRIX_SIZE * MATRIX_SIZE * DATA_WIDTH;
//    localparam int OUT_BITS = MATRIX_SIZE * MATRIX_SIZE * DATA_WIDTH;

//    logic [3:0] mm2s_tdata;
//    logic       mm2s_tvalid;
//    logic       mm2s_tready;

//    logic [3:0] s2mm_tdata;
//    logic       s2mm_tvalid;
//    logic       s2mm_tready;

//    logic [0:0][3:0] in_array_data;
//    logic            in_array_valid;
//    logic            in_array_ready;

//    logic [0:0][3:0] out_array_data;
//    logic            out_array_valid;
//    logic            out_array_ready;
//    logic            out_array_last;

//    logic [IN_BITS-1:0]  systolic_in_data;
//    logic [OUT_BITS-1:0] systolic_out_data;
//    logic                systolic_start;
//    logic                systolic_valid;

//    dma u_dma (
//        .clk                  (clk_sys),
//        .rst_n                (rst_sys_n),
//        .s_axi_lite_awaddr    (s_axi_lite_awaddr),
//        .s_axi_lite_awvalid   (s_axi_lite_awvalid),
//        .s_axi_lite_awready   (s_axi_lite_awready),
//        .s_axi_lite_wdata     (s_axi_lite_wdata),
//        .s_axi_lite_wvalid    (s_axi_lite_wvalid),
//        .s_axi_lite_wready    (s_axi_lite_wready),
//        .s_axi_lite_bresp     (s_axi_lite_bresp),
//        .s_axi_lite_bvalid    (s_axi_lite_bvalid),
//        .s_axi_lite_bready    (s_axi_lite_bready),
//        .s_axi_lite_araddr    (s_axi_lite_araddr),
//        .s_axi_lite_arvalid   (s_axi_lite_arvalid),
//        .s_axi_lite_arready   (s_axi_lite_arready),
//        .s_axi_lite_rdata     (s_axi_lite_rdata),
//        .s_axi_lite_rresp     (s_axi_lite_rresp),
//        .s_axi_lite_rvalid    (s_axi_lite_rvalid),
//        .s_axi_lite_rready    (s_axi_lite_rready),
//        .m_axi_araddr         (m_axi_araddr),
//        .m_axi_arlen          (m_axi_arlen),
//        .m_axi_arsize         (m_axi_arsize),
//        .m_axi_arburst        (m_axi_arburst),
//        .m_axi_arvalid        (m_axi_arvalid),
//        .m_axi_arready        (m_axi_arready),
//        .m_axi_rdata          (m_axi_rdata),
//        .m_axi_rresp          (m_axi_rresp),
//        .m_axi_rlast          (m_axi_rlast),
//        .m_axi_rvalid         (m_axi_rvalid),
//        .m_axi_rready         (m_axi_rready),
//        .m_axi_awaddr         (m_axi_awaddr),
//        .m_axi_awlen          (m_axi_awlen),
//        .m_axi_awsize         (m_axi_awsize),
//        .m_axi_awburst        (m_axi_awburst),
//        .m_axi_awvalid        (m_axi_awvalid),
//        .m_axi_awready        (m_axi_awready),
//        .m_axi_wdata          (m_axi_wdata),
//        .m_axi_wstrb          (m_axi_wstrb),
//        .m_axi_wvalid         (m_axi_wvalid),
//        .m_axi_wlast          (m_axi_wlast),
//        .m_axi_wready         (m_axi_wready),
//        .m_axi_bresp          (m_axi_bresp),
//        .m_axi_bvalid         (m_axi_bvalid),
//        .m_axi_bready         (m_axi_bready),
//        .m_axis_mm2s_tdata    (mm2s_tdata),
//        .m_axis_mm2s_tvalid   (mm2s_tvalid),
//        .m_axis_mm2s_tready   (mm2s_tready),
//        .s_axis_s2mm_tdata    (s2mm_tdata),
//        .s_axis_s2mm_tvalid   (s2mm_tvalid),
//        .s_axis_s2mm_tready   (s2mm_tready)
//    );

//    accel_buffer_top #(
//        .IN_DATA_WIDTH    (4),
//        .IN_NUM_CHANNELS  (1),
//        .IN_DEPTH         (32),
//        .OUT_DATA_WIDTH   (4),
//        .OUT_NUM_CHANNELS (1),
//        .OUT_DEPTH        (32)
//    ) u_accel_buffer (
//        .clk_sys          (clk_sys),
//        .rst_sys_n        (rst_sys_n),
//        .clk_accel        (clk_accel),
//        .rst_accel_n      (rst_accel_n),
//        .in_tdata         (mm2s_tdata),
//        .in_tvalid        (mm2s_tvalid),
//        .in_tready        (mm2s_tready),
//        .in_tlast         (1'b0),
//        .in_array_data    (in_array_data),
//        .in_array_valid   (in_array_valid),
//        .in_array_ready   (in_array_ready),
//        .out_array_data   (out_array_data),
//        .out_array_valid  (out_array_valid),
//        .out_array_ready  (out_array_ready),
//        .out_array_last   (out_array_last),
//        .out_tdata        (s2mm_tdata),
//        .out_tvalid       (s2mm_tvalid),
//        .out_tready       (s2mm_tready),
//        .out_tlast        ()
//    );

// logic [5:0] in_nibble_cnt;
//    logic [3:0] out_nibble_cnt;
//    localparam int OUT_NIBBLES = OUT_BITS/4;  // = 16 for your config

//    typedef enum logic [1:0] {S_COLLECT, S_COMPUTE, S_STREAM} state_t;
//    state_t state;

//    always_ff @(posedge clk_accel or negedge rst_accel_n) begin
//        if (!rst_accel_n) begin
//            state            <= S_COLLECT;
//            in_nibble_cnt    <= '0;
//            out_nibble_cnt   <= '0;
//            systolic_in_data <= '0;
//            systolic_start   <= 1'b0;
//            in_array_ready   <= 1'b0;
//            out_array_valid  <= 1'b0;
//            out_array_last   <= 1'b0;
//            out_array_data   <= '0;
//        end else begin
//            case (state)
//                S_COLLECT: begin
//                    in_array_ready  <= 1'b1;
//                    out_array_valid <= 1'b0;
//                    out_array_last  <= 1'b0;
//                    systolic_start  <= 1'b0;
//                    if (in_array_valid && in_array_ready) begin
//                        systolic_in_data <= {
//                            systolic_in_data[IN_BITS-DATA_WIDTH-1:0],
//                            in_array_data[0]
//                        };
//                        if (in_nibble_cnt == (IN_BITS/4 - 1)) begin
//                            in_nibble_cnt  <= '0;
//                            in_array_ready <= 1'b0;
//                            systolic_start <= 1'b1;
//                            state          <= S_COMPUTE;
//                        end else begin
//                            in_nibble_cnt <= in_nibble_cnt + 1'b1;
//                        end
//                    end
//                end

//                S_COMPUTE: begin
//                    systolic_start <= 1'b0;
//                    if (systolic_valid == 1'b1) begin
//                        state              <= S_STREAM;
//                        out_nibble_cnt     <= '0;
//                        out_array_valid    <= 1'b1;
//                        out_array_data[0]  <= systolic_out_data[(OUT_NIBBLES-1)*4 +: 4]; // nibble 0
//                        out_array_last     <= (OUT_NIBBLES == 1); // true only if single-nibble output
//                    end
//                end

//                S_STREAM: begin
//                    if (out_array_valid && out_array_ready) begin
//                        if (out_array_last) begin
//                            out_array_valid <= 1'b0;
//                            state           <= S_COLLECT;
//                        end else begin
//                            out_nibble_cnt     <= out_nibble_cnt + 1'b1;
//                            out_array_data[0]  <= systolic_out_data[(OUT_NIBBLES - (out_nibble_cnt+2))*4 +: 4];
//                            out_array_last     <= (out_nibble_cnt + 1 == OUT_NIBBLES - 1);
//                        end
//                    end
//                end

//                default: state <= S_COLLECT;
//            endcase
//        end
//    end
//systolic #(
//    .MATRIX_SIZE (MATRIX_SIZE),
//    .DATA_WIDTH  (DATA_WIDTH),
//    .PSUM_WIDTH  (PSUM_WIDTH)
//) u_systolic_core (
//    .clk         (clk_accel),
//    .rst_n         (rst_accel_n),
//    .start       (systolic_start),
//    .input_data  (systolic_in_data),
//    .output_data (systolic_out_data),
//    .valid       (systolic_valid)
//);
//endmodule
