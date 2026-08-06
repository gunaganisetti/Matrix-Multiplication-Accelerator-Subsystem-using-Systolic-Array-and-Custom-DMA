`timescale 1ns / 1ps

// -----------------------------------------------------------------------
// accel_buffer_top (Fully Corrected)
//
// Combines input_buffer (DMA -> Array) and output_buffer (Array -> DMA)
// into a single module with flattened ports.
// -----------------------------------------------------------------------

module accel_buffer_top #(
    // Input path parameters configured for a 4-bit nibble stream (1 channel)
    parameter int IN_DATA_WIDTH    = 4,    // 4-bit nibble matching DMA stream width
    parameter int IN_NUM_CHANNELS  = 1,    // Single channel stream
    parameter int IN_DEPTH         = 64,   // FIFO depth: power of 2

    // Output path parameters configured for a 4-bit nibble stream (1 channel)
    parameter int OUT_DATA_WIDTH   = 4,    // 4-bit nibble matching adapter stream width
    parameter int OUT_NUM_CHANNELS = 1,    // Single channel stream
    parameter int OUT_DEPTH        = 64    // FIFO depth: power of 2
)(
    // Dual-clock domain control signals
    input  logic clk_sys,      // System/DMA clock domain
    input  logic rst_sys_n,    // System/DMA active-low reset
    input  logic clk_accel,    // Accelerator/Array clock domain
    input  logic rst_accel_n,  // Accelerator/Array active-low reset

    // ================= INPUT BUFFER (DMA -> Array) =================
    // AXI-Stream Read Channel (Driven by DMA Master)
    input  logic [(IN_DATA_WIDTH*IN_NUM_CHANNELS)-1:0]    in_tdata,   // Data payload bus
    input  logic                                          in_tvalid,  // Data valid handshake
    output logic                                          in_tready,  // Buffer ready to accept data
    input  logic                                          in_tlast,   // Packet boundary indicator

    // Parallel Vector Output Channel (Driven to Systolic Array/Adapter)
    output logic [IN_NUM_CHANNELS-1:0][IN_DATA_WIDTH-1:0] in_array_data,  // Unpacked data elements
    output logic                                          in_array_valid, // Output data valid flag
    input  logic                                          in_array_ready, // Array ready to consume data

    // ================= OUTPUT BUFFER (Array -> DMA) =================
    // Parallel Vector Input Channel (Driven by Systolic Array/Adapter)
    input  logic [OUT_NUM_CHANNELS-1:0][OUT_DATA_WIDTH-1:0] out_array_data,  // Computed data elements
    input  logic                                           out_array_valid, // Array data valid flag
    output logic                                           out_array_ready, // Buffer ready for output
    input  logic                                           out_array_last,  // Matrix block boundary indicator

    // AXI-Stream Write Channel (Driven to DMA Slave)
    output logic [(OUT_DATA_WIDTH*OUT_NUM_CHANNELS)-1:0]  out_tdata,   // Packed stream output data
    output logic                                          out_tvalid,  // Stream valid handshake
    input  logic                                          out_tready,  // DMA write channel ready
    output logic                                          out_tlast    // Propagated packet completion token
);

    // -----------------------------------------------------------------
    // Input buffer (DMA -> Array Path)
    // -----------------------------------------------------------------
    input_buffer #(
        .DATA_WIDTH   (IN_DATA_WIDTH),
        .NUM_CHANNELS (IN_NUM_CHANNELS),
        .DEPTH        (IN_DEPTH)
    ) u_input_buffer (
        .clk_sys     (clk_sys),
        .rst_sys_n   (rst_sys_n),
        .clk_accel   (clk_accel),
        .rst_accel_n (rst_accel_n),

        // DMA/AXI-Stream Interface
        .tdata       (in_tdata),
        .tvalid      (in_tvalid),
        .tlast       (in_tlast),
        .tready      (in_tready),

        // Array Interface
        .array_data  (in_array_data),
        .array_valid (in_array_valid),
        .array_ready (in_array_ready)
    );

    // -----------------------------------------------------------------
    // Output buffer (Array -> DMA Path)
    // -----------------------------------------------------------------
    output_buffer #(
        .DATA_WIDTH   (OUT_DATA_WIDTH),
        .NUM_CHANNELS (OUT_NUM_CHANNELS),
        .DEPTH        (OUT_DEPTH)
    ) u_output_buffer (
        .clk_sys     (clk_sys),
        .rst_sys_n   (rst_sys_n),
        .clk_accel   (clk_accel),
        .rst_accel_n (rst_accel_n),

        // Array Interface
        .array_data  (out_array_data),
        .array_valid (out_array_valid),
        .array_ready (out_array_ready),
        .array_last  (out_array_last),

        // DMA/AXI-Stream Interface
        .tdata       (out_tdata),
        .tvalid      (out_tvalid),
        .tready      (out_tready),
        .tlast       (out_tlast)
    );

endmodule


// -----------------------------------------------------------------------
// Corrected input_buffer Module
// -----------------------------------------------------------------------
module input_buffer #(
    parameter int DATA_WIDTH   = 8,
    parameter int NUM_CHANNELS = 8,
    parameter int DEPTH        = 16
)(
    input  logic clk_sys,
    input  logic rst_sys_n,
    input  logic clk_accel,
    input  logic rst_accel_n,

    input  logic [(DATA_WIDTH*NUM_CHANNELS)-1:0] tdata,
    input  logic tvalid,
    input  logic tlast,
    output logic tready,

    output logic [NUM_CHANNELS-1:0][DATA_WIDTH-1:0] array_data,
    output logic array_valid,
    input  logic array_ready
);

    localparam int VEC_WIDTH = DATA_WIDTH * NUM_CHANNELS;

    logic fifo_full;
    logic fifo_empty;
    logic [VEC_WIDTH:0] wr_data;
    logic [VEC_WIDTH:0] rd_data;

    // Ready signal backpressure to DMA Master
    assign tready  = !fifo_full;
    wire   in_fire = tvalid && tready;

    // Pack tlast alongside tdata through the Async FIFO
    assign wr_data = {tlast, tdata};

    // Correct Handshake Logic:
    // Read fire occurs ONLY when FIFO has data AND array is ready to consume
    wire rd_fire = !fifo_empty && array_ready;

    async_fifo #(
        .DATA_WIDTH(VEC_WIDTH + 1), // Extra +1 bit for tlast
        .DEPTH(DEPTH)
    ) fifo (
        .wr_clk(clk_sys),
        .wr_rst_n(rst_sys_n),
        .wr_en(in_fire),
        .wr_data(wr_data),
        .full(fifo_full),

        .rd_clk(clk_accel),
        .rd_rst_n(rst_accel_n),
        .rd_en(rd_fire),
        .rd_data(rd_data),
        .empty(fifo_empty)
    );

    // Array Valid output is active whenever FIFO has data
    assign array_valid = !fifo_empty;

    // Unflatten array data payload
    genvar i;
    generate
        for (i = 0; i < NUM_CHANNELS; i = i + 1) begin : gen_unflatten
            assign array_data[i] = rd_data[(i*DATA_WIDTH) +: DATA_WIDTH];
        end
    endgenerate

endmodule


// -----------------------------------------------------------------------
// Corrected output_buffer Module
// -----------------------------------------------------------------------
module output_buffer #(
    parameter int DATA_WIDTH   = 8,
    parameter int NUM_CHANNELS = 8,
    parameter int DEPTH        = 16
)(
    input  logic clk_sys,
    input  logic rst_sys_n,
    input  logic clk_accel,
    input  logic rst_accel_n,

    input  logic [NUM_CHANNELS-1:0][DATA_WIDTH-1:0] array_data,
    input  logic array_valid,
    output logic array_ready,
    input  logic array_last,

    output logic [(DATA_WIDTH*NUM_CHANNELS)-1:0] tdata,
    output logic tvalid,
    input  logic tready,
    output logic tlast
);

    localparam int VEC_WIDTH = DATA_WIDTH * NUM_CHANNELS;

    logic fifo_full;
    logic fifo_empty;

    logic [VEC_WIDTH-1:0] flat_data;
    logic [VEC_WIDTH:0]   wr_data;
    logic [VEC_WIDTH:0]   rd_data;

    // Flatten multi-channel input array
    genvar i;
    generate
        for (i = 0; i < NUM_CHANNELS; i = i + 1) begin : gen_flatten
            assign flat_data[(i*DATA_WIDTH) +: DATA_WIDTH] = array_data[i];
        end
    endgenerate

    // Combine last signal and flattened payload
    assign wr_data     = {array_last, flat_data};
    assign array_ready = !fifo_full;

    // Guarded write: write to FIFO ONLY when valid AND not full
    wire wr_fire = array_valid && array_ready;

    // Read fire on AXI-Stream output
    wire tfire   = tvalid && tready;

    async_fifo #(
        .DATA_WIDTH(VEC_WIDTH + 1),
        .DEPTH(DEPTH)
    ) fifo (
        .wr_clk(clk_accel),
        .wr_rst_n(rst_accel_n),
        .wr_en(wr_fire),             // Guarded write
        .wr_data(wr_data),
        .full(fifo_full),

        .rd_clk(clk_sys),
        .rd_rst_n(rst_sys_n),
        .rd_en(tfire),
        .rd_data(rd_data),
        .empty(fifo_empty)
    );

    assign tvalid = !fifo_empty;
    assign tlast  = rd_data[VEC_WIDTH];
    assign tdata  = rd_data[VEC_WIDTH-1:0];

endmodule