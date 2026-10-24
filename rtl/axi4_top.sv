`timescale 1ns / 1ps

`define DATA_WIDTH 32 //bits
`define ADDR_WIDTH 12

module axi4_top(
    axi_if _if,
    input logic clk, wr_en, rd_en,
    input logic [`DATA_WIDTH-1:0] w_data,
    input logic [`ADDR_WIDTH-1:0] w_addr, r_addr,
    input logic [`DATA_WIDTH/8-1:0] w_strb,
    output logic [`DATA_WIDTH-1:0] r_data,
    output logic [1:0] w_resp, r_resp
);

    manager m0( .*);
    subordinate s0(.*);
    
    //initializing the memory in subordinate with zeros
    initial begin
	for(int i = 0; i < 1024; i++) 
		s0.MEM[i] = '0;
    end
endmodule

/*
// A 'sanity' check to ensure that the design is working before doing in depth system verilog verification
module test_mark1;
     logic clk, rstn, wr_en, rd_en;
     logic [`DATA_WIDTH-1:0] w_data;
     logic [`ADDR_WIDTH-1:0] w_addr, r_addr;
     logic [`DATA_WIDTH/8-1:0] w_strb;
     logic [`DATA_WIDTH-1:0] r_data;
     logic [1:0] w_resp, r_resp;
     
     wire [1:0] sub_PS = t0.s0.PS;
     wire [1:0] man_w_PS = t0.m0.PS;
     wire [1:0] man_r_PS = t0.m0.R_PS;
     
     axi_if _if(clk, rstn);
     axi4_top t0( .*);
     
     always #5 clk = ~clk;
     
     initial begin
        clk = 0;
        rstn = 0;
        wr_en = 0;
        rd_en = 0;
        w_strb = 4'b1111; // Write all 4 bytes
        w_data = 0;
        w_addr = 0;
        r_addr = 0;
        
        #7 rstn = 1;
        wr_en = 1; w_data = 32'ha; w_addr = 16'h4; w_strb = 4'b1111;
        #10
        wr_en = 0;
        #100 
        
        rd_en = 1; r_addr = 16'h4; 
        
        #100 $finish;
     end
    
    
endmodule
    
*/
