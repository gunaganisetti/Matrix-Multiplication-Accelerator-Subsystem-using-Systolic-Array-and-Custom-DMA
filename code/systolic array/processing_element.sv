module processing_element #(
    parameter int DATA_WIDTH = 4,
    parameter int PSUM_WIDTH = 10   // wide enough: 2*DATA_WIDTH + clog2(MATRIX_SIZE)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic pe_en,
    input  logic [DATA_WIDTH-1:0] in,
    input  logic [DATA_WIDTH-1:0] weight,
    input  logic [PSUM_WIDTH-1:0] psum_in,
    output logic [DATA_WIDTH-1:0] a_out,
    output logic [PSUM_WIDTH-1:0] psum_out
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            psum_out <= '0;
            a_out    <= '0;
        end
        else if (pe_en) begin
            // full-width multiply, accumulated in full-width psum -- no truncation mid-chain
            psum_out <= psum_in + (PSUM_WIDTH'(weight) * PSUM_WIDTH'(in));
            a_out    <= in;
        end
    end
endmodule