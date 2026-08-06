module dff #(
    parameter DATA_WIDTH = 4
)(
    input  logic clk,
    input  logic rst_n,     // Active-low reset

    input  logic en,

    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= '0;
        end
        else if (en) begin
            dout <= din;
        end
    end

endmodule