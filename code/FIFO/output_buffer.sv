`timescale 1ns / 1ps

// -----------------------------------------------------------------------
// output_buffer
//
// Implements output_buffer_if.buf_ports. Sits between the systolic array
// output edge (clk_accel, parallel array_data/array_valid/array_ready/
// array_last) and the DMA write channel (clk_sys, AXI-Stream
// tdata/tvalid/tready/tlast).
//
// DATA_WIDTH / NUM_CHANNELS here must match the values used to
// instantiate the output_buffer_if interface this module is bound to.
//
// array_last IS forwarded through to tlast -- both sides have a "last"
// signal here, so it's packed alongside the data vector to survive the
// clock-domain crossing in lock-step with the word it marks.
// -----------------------------------------------------------------------
module output_buffer #(
    parameter DATA_WIDTH = 8,
    parameter NUM_CHANNELS = 8,
    parameter DEPTH = 16
)(
    input logic clk_sys,
    input logic rst_sys_n,
    input logic clk_accel,
    input logic rst_accel_n,

    input logic [NUM_CHANNELS-1:0][DATA_WIDTH-1:0] array_data,
    input logic array_valid,
    output logic array_ready,
    input logic array_last,

    output logic [(DATA_WIDTH*NUM_CHANNELS)-1:0] tdata,
    output logic tvalid,
    input logic tready,
    output logic tlast
);

localparam VEC_WIDTH=DATA_WIDTH*NUM_CHANNELS;

logic fifo_full;
logic fifo_empty;

logic [VEC_WIDTH-1:0] flat_data;

logic [VEC_WIDTH:0] wr_data;
logic [VEC_WIDTH:0] rd_data;

genvar i;
generate
for(i=0;i<NUM_CHANNELS;i=i+1)
begin

assign flat_data[(i*DATA_WIDTH)+:DATA_WIDTH]=array_data[i];

end
endgenerate

assign wr_data={array_last,flat_data};

assign array_ready=!fifo_full;

wire tfire = tvalid && tready;
async_fifo #(
.DATA_WIDTH(VEC_WIDTH+1),
.DEPTH(DEPTH)
)
fifo
(
.wr_clk(clk_accel),
.wr_rst_n(rst_accel_n),
.wr_en(array_valid),
.wr_data(wr_data),
.full(fifo_full),

.rd_clk(clk_sys),
.rd_rst_n(rst_sys_n),
.rd_en(tfire),
.rd_data(rd_data),
.empty(fifo_empty)
);

assign tvalid=!fifo_empty;
assign tlast=rd_data[VEC_WIDTH];
assign tdata=rd_data[VEC_WIDTH-1:0];

endmodule
