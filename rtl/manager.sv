`timescale 1ns/1ps

`define  DATA_WIDTH 32 //bits
`define ADDR_WIDTH 12


module manager(	axi_if.manager_mp _if, 
		input logic wr_en, 
		input logic rd_en, 
		input logic [`DATA_WIDTH/8 -1:0] w_strb, 
		input logic [`DATA_WIDTH-1:0] w_data, 
		input logic [`ADDR_WIDTH - 1:0] w_addr, 
		input logic [`ADDR_WIDTH - 1:0] r_addr,
		output logic [`DATA_WIDTH-1:0] r_data, 
		output logic [1:0] w_resp, 
		output logic [1:0] r_resp
		);
  
  typedef enum {IDLE ,DRIVE, RESP} states;
  states PS, NS; //WRITE TRANSACTIONS
  states R_NS, R_PS; //READ TRANSACTIONS

  reg AW_done, W_done;
  
  //variables needed to capture from the input signals (soo that buses can be driven by these stabel registers)
  logic [`DATA_WIDTH/8 -1:0] reg_w_strb;
  logic [`DATA_WIDTH-1:0] reg_w_data;
  logic [`ADDR_WIDTH - 1:0] reg_w_addr;
  logic [`ADDR_WIDTH - 1:0] reg_r_addr;
 
  
  
  
  //PS state flipflop
  always_ff @(posedge _if.clk) begin
    if(_if.rstn==0) begin
        PS <= IDLE;
        R_PS <= IDLE;
    end else begin
        PS <= NS;
        R_PS <= R_NS;
    end
  end
  
  //done flags of drive stage indicating if W or AW handshake is done previously
  always_ff @(posedge _if.clk) begin
    if(_if.rstn==0) begin
        AW_done <= 0;
        W_done <= 0;
    end else begin
        if(PS != DRIVE) begin
            AW_done <= 0;
            W_done <= 0;
        end else begin
            if(_if.AW_VALID && _if.AW_READY) AW_done <= 1;
            if(_if.W_VALID && _if.W_READY) W_done <= 1;
        end
    end
  end
  
  
  //NS logic
  always_comb begin
    NS = PS;
    case(PS)
        IDLE: if(wr_en) NS = DRIVE;
        
        DRIVE: begin
                if(AW_done && _if.W_VALID && _if.W_READY ) NS = RESP;
                else if(W_done && _if.AW_VALID && _if.AW_READY) NS = RESP;
                else if(_if.W_VALID && _if.W_READY && _if.AW_VALID && _if.AW_READY) NS = RESP;
               end
             
        RESP: if(_if.B_VALID && _if.B_READY) NS = IDLE;
               
    endcase
  end
  
  //valid and corresponding data, also ready flags  from manager to subordinate logic
  always_comb begin
    _if.AW_VALID = 0; _if.W_VALID = 0; _if.B_READY = 0;
    _if.W_DATA = 0;  _if.W_STRB = 'h0;  _if.AW_ADDR = 0;
    
    case(PS) 
        IDLE: begin
                _if.AW_VALID = 0; _if.W_VALID = 0; _if.B_READY = 0;
              end
              
        DRIVE: begin
                _if.AW_VALID = 1; _if.W_VALID = 1; _if.B_READY = 1;
                _if.W_DATA = reg_w_data;
                _if.AW_ADDR = reg_w_addr;
                _if.W_STRB = reg_w_strb;
                
                if(AW_done) begin 
                    _if.AW_VALID = 0;
                    _if.AW_ADDR = 0;
                end
                
                if(W_done) begin
                    _if.W_VALID = 0;
                    _if.W_DATA = 0;
                    _if.W_STRB = 0;
                end
                
               end
               
        RESP: begin
                _if.B_READY = 1;
              end
              
    endcase
  end
  
  //data driving and response capturing based on stages logic
  always_ff @(posedge _if.clk) begin
    if(_if.rstn==0) begin
        reg_w_data <= 0;
        reg_w_strb <= 'h0;
        reg_w_addr <= 0;
        w_resp <= 2'b11;
        
    end else begin
        if( PS == IDLE && wr_en) begin
            reg_w_data <= w_data;
            reg_w_addr <= w_addr;
            reg_w_strb <= w_strb;
        end 
        
        if( PS == RESP && _if.B_VALID && _if.B_READY) begin
            w_resp <= _if.B_RESP;
        end else w_resp <= 2'b11;
        
    end
  end
  
  
  //---READ LOGIC--- (using same states fsm as WRITE LOGIC)
  //R_NS logic
  always_comb begin
    R_NS = R_PS;
    case(R_PS)
    
        IDLE: if(rd_en) R_NS = DRIVE;
        DRIVE: if(_if.AR_READY && _if.AR_VALID) R_NS = RESP;
        RESP: if(_if.R_READY && _if.R_VALID) R_NS = IDLE;
        
    endcase
  end
  
  //Read valid ready logic
  always_comb begin
        _if.AR_VALID = 0; _if.R_READY = 0; 
        _if.AR_ADDR = 0;
        
        case(R_PS) 
            IDLE: begin
                    _if.AR_VALID = 0; _if.R_READY = 0; 
                     _if.AR_ADDR = 0;
                  end
               
            DRIVE: begin
                    _if.AR_VALID = 1; _if.AR_ADDR = reg_r_addr; _if.R_READY = 1; 
                    
                  end
                  
            RESP: begin
                    _if.AR_VALID = 0; _if.AR_ADDR = 0; _if.R_READY = 1;
                  end            
        endcase
        
  end
    
  //read data and resp capture
  always_ff @(posedge _if.clk) begin
        if(_if.rstn==0) begin
            reg_r_addr <= 0;
            r_resp <= 2'b11;
            r_data <= 0;
            
        end else begin
            if(R_PS == IDLE && rd_en) reg_r_addr <= r_addr;
            
            if(R_PS == RESP && _if.R_READY && _if.R_VALID) begin
                r_resp <= _if.R_RESP;
                r_data <= _if.R_DATA;
            end else r_resp <= 2'b11;
        end
  end
  
endmodule

