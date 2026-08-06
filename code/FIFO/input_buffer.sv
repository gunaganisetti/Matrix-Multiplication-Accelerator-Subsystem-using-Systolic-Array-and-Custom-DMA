module input_buffer #(
    parameter int DATA_WIDTH   = 4,
    parameter int NUM_CHANNELS = 1,
    parameter int DEPTH        = 64
)(
    input  logic clk_sys, rst_sys_n,
    input  logic clk_accel, rst_accel_n,
    input  logic [(DATA_WIDTH*NUM_CHANNELS)-1:0] tdata,
    input  logic tvalid, tlast,
    output logic tready,
    output logic [NUM_CHANNELS-1:0][DATA_WIDTH-1:0] array_data,
    output logic array_valid,
    input  logic array_ready
);
    localparam int VEC_WIDTH = DATA_WIDTH * NUM_CHANNELS;

    logic fifo_full, fifo_empty;
    logic [VEC_WIDTH:0] wr_data, rd_data;

    assign tready  = !fifo_full;
    wire   in_fire = tvalid && tready;
    assign wr_data = {tlast, tdata};
    wire   rd_fire = !fifo_empty && array_ready;

    async_fifo #(
        .DATA_WIDTH(VEC_WIDTH + 1),
        .DEPTH(DEPTH)
    ) fifo (
        .wr_clk(clk_sys),   .wr_rst_n(rst_sys_n),
        .wr_en(in_fire),    .wr_data(wr_data), .full(fifo_full),
        .rd_clk(clk_accel), .rd_rst_n(rst_accel_n),
        .rd_en(rd_fire),    .rd_data(rd_data), .empty(fifo_empty)
    );

    assign array_valid = !fifo_empty;

    genvar i;
    generate
        for (i = 0; i < NUM_CHANNELS; i++)
            assign array_data[i] = rd_data[(i*DATA_WIDTH) +: DATA_WIDTH];
    endgenerate
endmodule