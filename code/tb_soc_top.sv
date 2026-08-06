`timescale 1ns/1ps

module tb_soc_top;

parameter MATRIX_SIZE = 4;
parameter DATA_WIDTH  = 4;
parameter PSUM_WIDTH  = 10;
parameter BRAM_DEPTH  = 48;

 
// Clocks & Reset
 

logic clk_sys;
logic clk_accel;

logic rst_sys_n;
logic rst_accel_n;

initial begin
    clk_sys = 0;
    forever #5 clk_sys = ~clk_sys;      //100MHz
end

initial begin
    clk_accel = 0;
    forever #10 clk_accel = ~clk_accel; //50MHz
end

initial begin
    rst_sys_n   = 0;
    rst_accel_n = 0;

    #100;

    rst_sys_n   = 1;
    rst_accel_n = 1;
end

 
// DMA AXI-Lite Interface (control/status registers)
 

logic [31:0] s_axi_lite_awaddr;
logic        s_axi_lite_awvalid;
logic        s_axi_lite_awready;

logic [31:0] s_axi_lite_wdata;
logic        s_axi_lite_wvalid;
logic        s_axi_lite_wready;

logic [1:0]  s_axi_lite_bresp;
logic        s_axi_lite_bvalid;
logic        s_axi_lite_bready;

logic [31:0] s_axi_lite_araddr;
logic        s_axi_lite_arvalid;
logic        s_axi_lite_arready;

logic [31:0] s_axi_lite_rdata;
logic [1:0]  s_axi_lite_rresp;
logic        s_axi_lite_rvalid;
logic        s_axi_lite_rready;

 
// Shared DRAM AXI-Lite Interface (RISC-side direct access,
// used here by the TB to preload / read back memory contents)
 

logic [31:0] s_dram_axi_lite_awaddr;
logic        s_dram_axi_lite_awvalid;
logic        s_dram_axi_lite_awready;

logic [31:0] s_dram_axi_lite_wdata;
logic [3:0]  s_dram_axi_lite_wstrb;
logic        s_dram_axi_lite_wvalid;
logic        s_dram_axi_lite_wready;

logic [1:0]  s_dram_axi_lite_bresp;
logic        s_dram_axi_lite_bvalid;
logic        s_dram_axi_lite_bready;

logic [31:0] s_dram_axi_lite_araddr;
logic        s_dram_axi_lite_arvalid;
logic        s_dram_axi_lite_arready;

logic [31:0] s_dram_axi_lite_rdata;
logic [1:0]  s_dram_axi_lite_rresp;
logic        s_dram_axi_lite_rvalid;
logic        s_dram_axi_lite_rready;

 
// DUT
 

soc_top #(
    .MATRIX_SIZE(MATRIX_SIZE),
    .DATA_WIDTH(DATA_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .BRAM_DEPTH(BRAM_DEPTH)
) dut (

    .clk_sys(clk_sys),
    .rst_sys_n(rst_sys_n),

    .clk_accel(clk_accel),
    .rst_accel_n(rst_accel_n),

    //---------------- DMA control AXI-Lite ----------------

    .s_axi_lite_awaddr(s_axi_lite_awaddr),
    .s_axi_lite_awvalid(s_axi_lite_awvalid),
    .s_axi_lite_awready(s_axi_lite_awready),

    .s_axi_lite_wdata(s_axi_lite_wdata),
    .s_axi_lite_wvalid(s_axi_lite_wvalid),
    .s_axi_lite_wready(s_axi_lite_wready),

    .s_axi_lite_bresp(s_axi_lite_bresp),
    .s_axi_lite_bvalid(s_axi_lite_bvalid),
    .s_axi_lite_bready(s_axi_lite_bready),

    .s_axi_lite_araddr(s_axi_lite_araddr),
    .s_axi_lite_arvalid(s_axi_lite_arvalid),
    .s_axi_lite_arready(s_axi_lite_arready),

    .s_axi_lite_rdata(s_axi_lite_rdata),
    .s_axi_lite_rresp(s_axi_lite_rresp),
    .s_axi_lite_rvalid(s_axi_lite_rvalid),
    .s_axi_lite_rready(s_axi_lite_rready),

    //---------------- Shared DRAM AXI-Lite (RISC side) ----------------

    .s_dram_axi_lite_awaddr(s_dram_axi_lite_awaddr),
    .s_dram_axi_lite_awvalid(s_dram_axi_lite_awvalid),
    .s_dram_axi_lite_awready(s_dram_axi_lite_awready),

    .s_dram_axi_lite_wdata(s_dram_axi_lite_wdata),
    .s_dram_axi_lite_wstrb(s_dram_axi_lite_wstrb),
    .s_dram_axi_lite_wvalid(s_dram_axi_lite_wvalid),
    .s_dram_axi_lite_wready(s_dram_axi_lite_wready),

    .s_dram_axi_lite_bresp(s_dram_axi_lite_bresp),
    .s_dram_axi_lite_bvalid(s_dram_axi_lite_bvalid),
    .s_dram_axi_lite_bready(s_dram_axi_lite_bready),

    .s_dram_axi_lite_araddr(s_dram_axi_lite_araddr),
    .s_dram_axi_lite_arvalid(s_dram_axi_lite_arvalid),
    .s_dram_axi_lite_arready(s_dram_axi_lite_arready),

    .s_dram_axi_lite_rdata(s_dram_axi_lite_rdata),
    .s_dram_axi_lite_rresp(s_dram_axi_lite_rresp),
    .s_dram_axi_lite_rvalid(s_dram_axi_lite_rvalid),
    .s_dram_axi_lite_rready(s_dram_axi_lite_rready)
);

 
// Default values
 

initial begin

    //  DMA control AXI-Lite  

    s_axi_lite_awaddr  = 0;
    s_axi_lite_awvalid = 0;
    s_axi_lite_wdata   = 0;
    s_axi_lite_wvalid  = 0;
    s_axi_lite_bready  = 0;

    s_axi_lite_araddr  = 0;
    s_axi_lite_arvalid = 0;
    s_axi_lite_rready  = 0;

    //  Shared DRAM AXI-Lite  

    s_dram_axi_lite_awaddr  = 0;
    s_dram_axi_lite_awvalid = 0;

    s_dram_axi_lite_wdata   = 0;
    s_dram_axi_lite_wstrb   = 4'hF;
    s_dram_axi_lite_wvalid  = 0;

    s_dram_axi_lite_bready  = 0;

    s_dram_axi_lite_araddr  = 0;
    s_dram_axi_lite_arvalid = 0;

    s_dram_axi_lite_rready  = 0;

end


//   ---------------
// AXI-Lite Write/Read Tasks - shared DRAM port (TB acting as RISC)
//   ---------------

task automatic dram_axi_lite_write(
    input [31:0] addr,
    input [31:0] data
);
begin
    // ---- Address phase ----
    @(posedge clk_sys);
    s_dram_axi_lite_awaddr  <= addr;
    s_dram_axi_lite_awvalid <= 1'b1;

    wait (s_dram_axi_lite_awvalid && s_dram_axi_lite_awready);
    @(posedge clk_sys);
    s_dram_axi_lite_awvalid <= 1'b0;

    // ---- Data phase ----
    s_dram_axi_lite_wdata  <= data;
    s_dram_axi_lite_wstrb  <= 4'hF;
    s_dram_axi_lite_wvalid <= 1'b1;

    wait (s_dram_axi_lite_wvalid && s_dram_axi_lite_wready);
    @(posedge clk_sys);
    s_dram_axi_lite_wvalid <= 1'b0;

    // ---- Response phase ----
    s_dram_axi_lite_bready <= 1'b1;
    wait (s_dram_axi_lite_bvalid);
    @(posedge clk_sys);
    s_dram_axi_lite_bready <= 1'b0;

    $display("[%0t] DRAM WRITE Addr=%h Data=%h",
             $time, addr, data);
end
endtask

task automatic dram_axi_lite_read(
    input  [31:0] addr,
    output [31:0] data
);
begin
    @(posedge clk_sys);

    s_dram_axi_lite_araddr  <= addr;
    s_dram_axi_lite_arvalid <= 1'b1;

    wait (s_dram_axi_lite_arvalid && s_dram_axi_lite_arready);
    @(posedge clk_sys);
    s_dram_axi_lite_arvalid <= 1'b0;

    s_dram_axi_lite_rready <= 1'b1;
    wait (s_dram_axi_lite_rvalid);

    data = s_dram_axi_lite_rdata;

    @(posedge clk_sys);
    s_dram_axi_lite_rready <= 1'b0;

    $display("[%0t] DRAM READ  Addr=%h Data=%h",
             $time, addr, data);
end
endtask

//   ---------------
// AXI-Lite Write/Read Tasks - DMA control/status port
//   ---------------

task automatic dma_axi_lite_write(
    input [31:0] addr,
    input [31:0] data
);
begin
    @(posedge clk_sys);

    s_axi_lite_awaddr  <= addr;
    s_axi_lite_awvalid <= 1'b1;

    s_axi_lite_wdata   <= data;
    s_axi_lite_wvalid  <= 1'b1;

    wait(s_axi_lite_awready && s_axi_lite_wready);

    @(posedge clk_sys);

    s_axi_lite_awvalid <= 1'b0;
    s_axi_lite_wvalid  <= 1'b0;

    s_axi_lite_bready  <= 1'b1;
    wait(s_axi_lite_bvalid);

    @(posedge clk_sys);
    s_axi_lite_bready  <= 1'b0;

    $display("[%0t] DMA-REG WRITE Addr=%h Data=%h",
             $time, addr, data);
end
endtask

task automatic dma_axi_lite_read(
    input  [31:0] addr,
    output [31:0] data
);
begin
    @(posedge clk_sys);

    s_axi_lite_araddr  <= addr;
    s_axi_lite_arvalid <= 1'b1;

    wait(s_axi_lite_arready);

    @(posedge clk_sys);
    s_axi_lite_arvalid <= 1'b0;

    s_axi_lite_rready <= 1'b1;
    wait(s_axi_lite_rvalid);

    data = s_axi_lite_rdata;

    @(posedge clk_sys);
    s_axi_lite_rready <= 1'b0;

    $display("[%0t] DMA-REG READ Addr=%h Data=%h",
             $time, addr, data);
end
endtask

//   ---------------
// Main Test Sequence
//   ---------------
reg [31:0] status;
reg [31:0] rd_val;

initial begin

    wait(rst_sys_n);
    repeat(10) @(posedge clk_sys);

    $display("\n======================================");
    $display("     Starting DMA + Shared DRAM Test");
    $display("======================================");

    // -----------
    // Preload source words directly into shared DRAM
    // via the RISC-facing AXI-Lite port (word addrs 0..3)
    // -----------
    dram_axi_lite_write(32'h00, 32'h12345678);
    dram_axi_lite_write(32'h04, 32'h9ABCDEF0);
    dram_axi_lite_write(32'h08, 32'h11112222);
    dram_axi_lite_write(32'h0C, 32'h33334444);

    // -----------
    // Program DMA Registers
    // -----------

    // Source Address = word 0 (byte 0x00)
    dma_axi_lite_write(32'h08, 32'h00000000);

    // Destination Address = word 16 (byte 0x40)
    dma_axi_lite_write(32'h0C, 32'h00000040);

    // Transfer Length = 16 bytes (4 words)
    dma_axi_lite_write(32'h10, 32'h00000010);

    // -----------
    // Start DMA
    // -----------
    dma_axi_lite_write(32'h00, 32'h00000001);

    // -----------
    // Poll status until done
    // -----------
    repeat(1000) begin
        dma_axi_lite_read(32'h04, status);

        if (status[0] == 0)
            break;

        repeat(5) @(posedge clk_sys);
    end

    $display("\nDMA Finished.");
    $display("Status = %h", status);

    // -----------
    // Read back destination words via the DRAM AXI-Lite port
    // -----------
    $display("\nDestination Memory (via s_dram_axi_lite):");

    dram_axi_lite_read(32'h40, rd_val); $display("mem[word 16] = %h", rd_val);
    dram_axi_lite_read(32'h44, rd_val); $display("mem[word 17] = %h", rd_val);
    dram_axi_lite_read(32'h48, rd_val); $display("mem[word 18] = %h", rd_val);
    dram_axi_lite_read(32'h4C, rd_val); $display("mem[word 19] = %h", rd_val);

    $display("\nSimulation Finished.");
    #100;
    $finish;

end

endmodule


//`timescale 1ns / 1ps

//module tb_soc_top;

//parameter MATRIX_SIZE = 4;
//parameter DATA_WIDTH  = 4;
//parameter PSUM_WIDTH  = 10;

// 
//// Clocks & Reset
// 

//logic clk_sys;
//logic clk_accel;

//logic rst_sys_n;
//logic rst_accel_n;

//initial begin
//    clk_sys = 0;
//    forever #5 clk_sys = ~clk_sys;      //100MHz
//end

//initial begin
//    clk_accel = 0;
//    forever #10 clk_accel = ~clk_accel; //50MHz
//end

//initial begin
//    rst_sys_n   = 0;
//    rst_accel_n = 0;

//    #100;

//    rst_sys_n   = 1;
//    rst_accel_n = 1;
//end

// 
//// DMA AXI-Lite Interface
// 

//logic [31:0] s_axi_lite_awaddr;
//logic        s_axi_lite_awvalid;
//logic        s_axi_lite_awready;

//logic [31:0] s_axi_lite_wdata;
//logic        s_axi_lite_wvalid;
//logic        s_axi_lite_wready;

//logic [1:0]  s_axi_lite_bresp;
//logic        s_axi_lite_bvalid;
//logic        s_axi_lite_bready;

//logic [31:0] s_axi_lite_araddr;
//logic        s_axi_lite_arvalid;
//logic        s_axi_lite_arready;

//logic [31:0] s_axi_lite_rdata;
//logic [1:0]  s_axi_lite_rresp;
//logic        s_axi_lite_rvalid;
//logic        s_axi_lite_rready;

// 
//// AXI Master Interface (DMA -> Memory)
// 

//logic [31:0] m_axi_araddr;
//logic [7:0]  m_axi_arlen;
//logic [2:0]  m_axi_arsize;
//logic [1:0]  m_axi_arburst;
//logic        m_axi_arvalid;
//logic        m_axi_arready;

//logic [31:0] m_axi_rdata;
//logic [1:0]  m_axi_rresp;
//logic        m_axi_rlast;
//logic        m_axi_rvalid;
//logic        m_axi_rready;

//logic [31:0] m_axi_awaddr;
//logic [7:0]  m_axi_awlen;
//logic [2:0]  m_axi_awsize;
//logic [1:0]  m_axi_awburst;
//logic        m_axi_awvalid;
//logic        m_axi_awready;

//logic [31:0] m_axi_wdata;
//logic [3:0]  m_axi_wstrb;
//logic        m_axi_wvalid;
//logic        m_axi_wlast;
//logic        m_axi_wready;

//logic [1:0]  m_axi_bresp;
//logic        m_axi_bvalid;
//logic        m_axi_bready;

// 
//// DUT
// 

//soc_top #(
//    .MATRIX_SIZE(MATRIX_SIZE),
//    .DATA_WIDTH(DATA_WIDTH),
//    .PSUM_WIDTH(PSUM_WIDTH)
//) dut (

//    .clk_sys(clk_sys),
//    .rst_sys_n(rst_sys_n),

//    .clk_accel(clk_accel),
//    .rst_accel_n(rst_accel_n),

//    //  AXI-Lite  

//    .s_axi_lite_awaddr(s_axi_lite_awaddr),
//    .s_axi_lite_awvalid(s_axi_lite_awvalid),
//    .s_axi_lite_awready(s_axi_lite_awready),

//    .s_axi_lite_wdata(s_axi_lite_wdata),
//    .s_axi_lite_wvalid(s_axi_lite_wvalid),
//    .s_axi_lite_wready(s_axi_lite_wready),

//    .s_axi_lite_bresp(s_axi_lite_bresp),
//    .s_axi_lite_bvalid(s_axi_lite_bvalid),
//    .s_axi_lite_bready(s_axi_lite_bready),

//    .s_axi_lite_araddr(s_axi_lite_araddr),
//    .s_axi_lite_arvalid(s_axi_lite_arvalid),
//    .s_axi_lite_arready(s_axi_lite_arready),

//    .s_axi_lite_rdata(s_axi_lite_rdata),
//    .s_axi_lite_rresp(s_axi_lite_rresp),
//    .s_axi_lite_rvalid(s_axi_lite_rvalid),
//    .s_axi_lite_rready(s_axi_lite_rready),

//    //  AXI Master  

//    .m_axi_araddr(m_axi_araddr),
//    .m_axi_arlen(m_axi_arlen),
//    .m_axi_arsize(m_axi_arsize),
//    .m_axi_arburst(m_axi_arburst),
//    .m_axi_arvalid(m_axi_arvalid),
//    .m_axi_arready(m_axi_arready),

//    .m_axi_rdata(m_axi_rdata),
//    .m_axi_rresp(m_axi_rresp),
//    .m_axi_rlast(m_axi_rlast),
//    .m_axi_rvalid(m_axi_rvalid),
//    .m_axi_rready(m_axi_rready),

//    .m_axi_awaddr(m_axi_awaddr),
//    .m_axi_awlen(m_axi_awlen),
//    .m_axi_awsize(m_axi_awsize),
//    .m_axi_awburst(m_axi_awburst),
//    .m_axi_awvalid(m_axi_awvalid),
//    .m_axi_awready(m_axi_awready),

//    .m_axi_wdata(m_axi_wdata),
//    .m_axi_wstrb(m_axi_wstrb),
//    .m_axi_wvalid(m_axi_wvalid),
//    .m_axi_wlast(m_axi_wlast),
//    .m_axi_wready(m_axi_wready),

//    .m_axi_bresp(m_axi_bresp),
//    .m_axi_bvalid(m_axi_bvalid),
//    .m_axi_bready(m_axi_bready)

//);

// 
//// BRAM AXI-Lite Interface (used by TB to preload/read BRAM)
// 

//logic [31:0] bram_awaddr;
//logic        bram_awvalid;
//logic        bram_awready;

//logic [31:0] bram_wdata;
//logic [3:0]  bram_wstrb;
//logic        bram_wvalid;
//logic        bram_wready;

//logic [1:0]  bram_bresp;
//logic        bram_bvalid;
//logic        bram_bready;

//logic [31:0] bram_araddr;
//logic        bram_arvalid;
//logic        bram_arready;

//logic [31:0] bram_rdata;
//logic [1:0]  bram_rresp;
//logic        bram_rvalid;
//logic        bram_rready;


//// 
////// Shared BRAM Memory
//// 

////bram_axi_top #(
////    .AXI_ADDR_WIDTH(32),
////    .AXI_DATA_WIDTH(32),
////    .BRAM_DEPTH(48)
////) memory (

////    .clk(clk_sys),
////    .rst_n(rst_sys_n),

////    //   -----
////    // DMA AXI Master <-> BRAM AXI Slave
////    //   -----

////    .s_axi_awaddr (m_axi_awaddr),
////    .s_axi_awlen  (m_axi_awlen),
////    .s_axi_awsize (m_axi_awsize),
////    .s_axi_awburst(m_axi_awburst),
////    .s_axi_awvalid(m_axi_awvalid),
////    .s_axi_awready(m_axi_awready),

////    .s_axi_wdata (m_axi_wdata),
////    .s_axi_wstrb (m_axi_wstrb),
////    .s_axi_wlast (m_axi_wlast),
////    .s_axi_wvalid(m_axi_wvalid),
////    .s_axi_wready(m_axi_wready),

////    .s_axi_bresp (m_axi_bresp),
////    .s_axi_bvalid(m_axi_bvalid),
////    .s_axi_bready(m_axi_bready),

////    .s_axi_araddr (m_axi_araddr),
////    .s_axi_arlen  (m_axi_arlen),
////    .s_axi_arsize (m_axi_arsize),
////    .s_axi_arburst(m_axi_arburst),
////    .s_axi_arvalid(m_axi_arvalid),
////    .s_axi_arready(m_axi_arready),

////    .s_axi_rdata (m_axi_rdata),
////    .s_axi_rresp (m_axi_rresp),
////    .s_axi_rlast (m_axi_rlast),
////    .s_axi_rvalid(m_axi_rvalid),
////    .s_axi_rready(m_axi_rready),

////    //   -----
////    // AXI-Lite Port used by Testbench
////    //   -----

////    .s_axi_lite_awaddr (bram_awaddr),
////    .s_axi_lite_awvalid(bram_awvalid),
////    .s_axi_lite_awready(bram_awready),

////    .s_axi_lite_wdata (bram_wdata),
////    .s_axi_lite_wstrb (bram_wstrb),
////    .s_axi_lite_wvalid(bram_wvalid),
////    .s_axi_lite_wready(bram_wready),

////    .s_axi_lite_bresp (bram_bresp),
////    .s_axi_lite_bvalid(bram_bvalid),
////    .s_axi_lite_bready(bram_bready),

////    .s_axi_lite_araddr (bram_araddr),
////    .s_axi_lite_arvalid(bram_arvalid),
////    .s_axi_lite_arready(bram_arready),

////    .s_axi_lite_rdata (bram_rdata),
////    .s_axi_lite_rresp (bram_rresp),
////    .s_axi_lite_rvalid(bram_rvalid),
////    .s_axi_lite_rready(bram_rready)
////);


//// 
////// Default values
//// 

////initial begin

////    //  DMA AXI-Lite  

////    s_axi_lite_awaddr  = 0;
////    s_axi_lite_awvalid = 0;
////    s_axi_lite_wdata   = 0;
////    s_axi_lite_wvalid  = 0;
////    s_axi_lite_bready  = 1;

////    s_axi_lite_araddr  = 0;
////    s_axi_lite_arvalid = 0;
////    s_axi_lite_rready  = 1;

////    //  BRAM AXI-Lite  

////    bram_awaddr  = 0;
////    bram_awvalid = 0;

////    bram_wdata   = 0;
////    bram_wstrb   = 4'hF;
////    bram_wvalid  = 0;

////    bram_bready  = 1;

////    bram_araddr  = 0;
////    bram_arvalid = 0;

////    bram_rready  = 1;

////end

// =====
//// AXI4 Memory Model
// =====
////logic [31:0] mem [0:255];
////integer i;

////// Initialize memory
////initial begin
////    for(i=0;i<256;i=i+1)
////        mem[i] = i;

////    // Example matrix data
////    mem[0]  = 32'h12345678;
////    mem[1]  = 32'h9ABCDEF0;
////    mem[2]  = 32'h11223344;
////    mem[3]  = 32'h55667788;
////    mem[4]  = 32'h89ABCDEF;
////    mem[5]  = 32'h13572468;
////    mem[6]  = 32'h24681357;
////    mem[7]  = 32'hDEADBEEF;
////end

////   --------------
//// AXI Read Channel
////   --------------
////always @(posedge clk_sys) begin
////    if(!rst_sys_n) begin
////        m_axi_arready <= 0;
////        m_axi_rvalid  <= 0;
////        m_axi_rlast   <= 0;
////        m_axi_rresp   <= 0;
////    end
////    else begin
////        m_axi_arready <= 1;

////        if(m_axi_arvalid && m_axi_arready) begin
////            m_axi_rdata  <= mem[m_axi_araddr >> 2];
////            m_axi_rvalid <= 1;
////            m_axi_rlast  <= 1;
////            m_axi_rresp  <= 2'b00;
////        end
////        else if(m_axi_rvalid && m_axi_rready) begin
////            m_axi_rvalid <= 0;
////            m_axi_rlast  <= 0;
////        end
////    end
////end

//////   --------------
////// AXI Write Channel
//////   --------------
////always @(posedge clk_sys) begin
////    if(!rst_sys_n) begin
////        m_axi_awready <= 0;
////        m_axi_wready  <= 0;
////        m_axi_bvalid  <= 0;
////        m_axi_bresp   <= 0;
////    end
////    else begin
////        m_axi_awready <= 1;
////        m_axi_wready  <= 1;

////        if(m_axi_awvalid && m_axi_wvalid) begin
////            mem[m_axi_awaddr >> 2] <= m_axi_wdata;

////            m_axi_bvalid <= 1;
////            m_axi_bresp  <= 2'b00;

////            $display("[%0t] WRITE Addr=%h Data=%h",
////                     $time, m_axi_awaddr, m_axi_wdata);
////        end

////        if(m_axi_bvalid && m_axi_bready)
////            m_axi_bvalid <= 0;
////    end
////end

////   ---------------
//// Simple AXI Memory Model
////   ---------------
//logic [31:0] mem [0:255];

//// AXI Ready Signals
//assign m_axi_arready = 1'b1;
//assign m_axi_awready = 1'b1;
//assign m_axi_wready  = 1'b1;

////  Read Channel  
//always_ff @(posedge clk_sys) begin
//    if (!rst_sys_n) begin
//        m_axi_rvalid <= 0;
//        m_axi_rlast  <= 0;
//        m_axi_rresp  <= 2'b00;
//        m_axi_rdata  <= 32'd0;
//    end else begin
//        if (m_axi_arvalid && m_axi_arready) begin
//            m_axi_rvalid <= 1'b1;
//            m_axi_rlast  <= 1'b1;
//            m_axi_rresp  <= 2'b00;
//            m_axi_rdata  <= mem[m_axi_araddr >> 2];

//            $display("[%0t] AXI READ Addr=%h Data=%h",
//                      $time, m_axi_araddr, mem[m_axi_araddr >> 2]);
//        end
//        else if (m_axi_rvalid && m_axi_rready) begin
//            m_axi_rvalid <= 0;
//            m_axi_rlast  <= 0;
//        end
//    end
//end

////  Write Channel (single driver, burst-aware)  
//logic [31:0] wr_addr_cnt;
//logic [8:0]  wr_beats_remaining;   // covers awlen+1 up to 256
//logic        wr_active;

//always_ff @(posedge clk_sys) begin
//    if (!rst_sys_n) begin
//        m_axi_bvalid       <= 1'b0;
//        m_axi_bresp        <= 2'b00;
//        wr_active          <= 1'b0;
//        wr_addr_cnt        <= '0;
//        wr_beats_remaining <= '0;
//    end else begin
//        // Capture address phase, latch burst length, start burst
//        if (m_axi_awvalid && m_axi_awready && !wr_active) begin
//            wr_addr_cnt        <= m_axi_awaddr;
//            wr_beats_remaining <= m_axi_awlen + 1'b1;
//            wr_active          <= 1'b1;
//        end

//        // Consume one data beat per cycle while burst is active
//        if (wr_active && m_axi_wvalid && m_axi_wready) begin
//            mem[wr_addr_cnt >> 2] <= m_axi_wdata;

//            $display("[%0t] AXI WRITE Addr=%h Data=%h",
//                      $time, wr_addr_cnt, m_axi_wdata);

//            wr_addr_cnt        <= wr_addr_cnt + 4;
//            wr_beats_remaining <= wr_beats_remaining - 1'b1;

//            if (m_axi_wlast || (wr_beats_remaining == 9'd1)) begin
//                wr_active    <= 1'b0;
//                m_axi_bvalid <= 1'b1;
//                m_axi_bresp  <= 2'b00;
//            end
//        end

//        if (m_axi_bvalid && m_axi_bready) begin
//            m_axi_bvalid <= 1'b0;
//        end
//    end
//end

////   ---------------
//// Initialize Memory
////   ---------------
//integer i;

//initial begin
//    for (i = 0; i < 256; i = i + 1)
//        mem[i] = 32'h0;

//    mem[0] = 32'h12345678;
//    mem[1] = 32'h9ABCDEF0;
//    mem[2] = 32'h11112222;
//    mem[3] = 32'h33334444;
//end
////   ---------------
//// AXI-Lite Write Task
////   ---------------
//task automatic axi_lite_write(
//    input [31:0] addr,
//    input [31:0] data
//);
//begin
//    @(posedge clk_sys);

//    s_axi_lite_awaddr  <= addr;
//    s_axi_lite_awvalid <= 1'b1;

//    s_axi_lite_wdata   <= data;
//    s_axi_lite_wvalid  <= 1'b1;

//    wait(s_axi_lite_awready && s_axi_lite_wready);

//    @(posedge clk_sys);

//    s_axi_lite_awvalid <= 1'b0;
//    s_axi_lite_wvalid  <= 1'b0;

//    s_axi_lite_bready  <= 1'b1;
//    wait(s_axi_lite_bvalid);

//    @(posedge clk_sys);
//    s_axi_lite_bready  <= 1'b0;

//    $display("[%0t] AXI-Lite WRITE Addr=%h Data=%h",
//             $time, addr, data);
//end
//endtask


////   ---------------
//// AXI-Lite Read Task
////   ---------------
//task automatic axi_lite_read(
//    input  [31:0] addr,
//    output [31:0] data
//);
//begin
//    @(posedge clk_sys);

//    s_axi_lite_araddr  <= addr;
//    s_axi_lite_arvalid <= 1'b1;

//    wait(s_axi_lite_arready);

//    @(posedge clk_sys);
//    s_axi_lite_arvalid <= 1'b0;

//    s_axi_lite_rready <= 1'b1;
//    wait(s_axi_lite_rvalid);

//    data = s_axi_lite_rdata;

//    @(posedge clk_sys);
//    s_axi_lite_rready <= 1'b0;

//    $display("[%0t] AXI-Lite READ Addr=%h Data=%h",
//             $time, addr, data);
//end
//endtask

////   ---------------
//// Main Test Sequence
////   ---------------
//reg [31:0] status;

//initial begin

//    // -----------
//    // Initialize AXI-Lite signals
//    // -----------
//    s_axi_lite_awaddr  = 0;
//    s_axi_lite_awvalid = 0;
//    s_axi_lite_wdata   = 0;
//    s_axi_lite_wvalid  = 0;
//    s_axi_lite_bready  = 0;

//    s_axi_lite_araddr  = 0;
//    s_axi_lite_arvalid = 0;
//    s_axi_lite_rready  = 0;

//    // -----------
//    // Wait for reset
//    // -----------
//    wait(rst_sys_n);
//    repeat(10) @(posedge clk_sys);

//    $display("\n======================================");
//    $display("     Starting DMA Test");
//    $display("======================================");

//    // -----------
//    // Program DMA Registers
//    // -----------

//    // Source Address = mem[0]
//    axi_lite_write(32'h08,32'h00000000);

//    // Destination Address = mem[16]
//    axi_lite_write(32'h0C,32'h00000040);

//    // Transfer Length = 16 bytes (4 words)
//    axi_lite_write(32'h10,32'h00000010);

//    // -----------
//    // Start DMA
//    // -----------
//    axi_lite_write(32'h00,32'h00000001);

//    // -----------
//    // Wait until DMA finishes
//    // -----------
//    repeat(1000) begin
//        axi_lite_read(32'h04,status);

//        if(status[0]==0)
//            break;

//        repeat(5) @(posedge clk_sys);
//    end

//    $display("\nDMA Finished.");
//    $display("Status = %h",status);

//    // -----------
//    // Display Destination Memory
//    // -----------
//    $display("\nDestination Memory:");

//    $display("mem[16] = %h",mem[16]);
//    $display("mem[17] = %h",mem[17]);
//    $display("mem[18] = %h",mem[18]);
//    $display("mem[19] = %h",mem[19]);

//    $display("\nSimulation Finished.");
//    #100;
//    $finish;

//end

//endmodule
