`timescale 1ns/1ps

`define  DATA_WIDTH 32 //bits
`define ADDR_WIDTH 12


module subordinate(axi_if.subordinate_mp _if);
  
  reg [`DATA_WIDTH-1:0]  MEM [1024]; //32*1024 = 4KB
  reg [`ADDR_WIDTH-1:0] w_addr, r_addr;
  reg [`DATA_WIDTH-1:0] w_data;
  reg [`DATA_WIDTH/8 - 1: 0] w_strb;
  
  typedef enum {IDLE , ADDR, DATA, RESP} states;
  states PS, NS;

  always_ff @(posedge _if.clk) begin
    if(_if.rstn==0) begin
        PS <= IDLE;
    end else begin
        PS <= NS;
    end
  end
  
  //NEXT STATE LOGIC DEPEDING ON HANDSHAKE SIGNALS
  always_comb begin
    NS = PS;
    case(PS)
        IDLE: begin
                if(_if.AW_VALID && _if.AW_READY && _if.W_VALID && _if.W_READY) begin
                  NS = RESP;
                end else if(_if.W_VALID && _if.W_READY) begin
                  NS = ADDR;
                end else if(_if.AW_VALID && _if.AW_READY ) begin
                  NS = DATA;
                end else NS = IDLE;
              end
           
        DATA: begin
                if(_if.W_VALID && _if.W_READY) begin
                  NS = RESP;
                end else NS = DATA;
              end
              
        ADDR: begin
                 if(_if.AW_VALID && _if.AW_READY) begin
                    NS = RESP;
                 end
              end
       
        RESP: begin
                if(_if.B_VALID && _if.B_READY) begin
                    NS = IDLE;
                end else NS = RESP;
              end
    endcase
  end
  
  //HANDSHAKE SIGNALS FROM SLAVE 
  always_comb begin
    _if.AW_READY = 0; _if.W_READY = 0; _if.B_VALID = 0; _if.B_RESP = 2'b11;
        case(PS) 
            IDLE: begin 
                    _if.AW_READY = 1; _if.W_READY = 1;
                  end
            DATA: begin
                    _if.AW_READY = 0; _if.W_READY = 1;
                  end
            ADDR: begin
                    _if.AW_READY = 1; _if.W_READY = 0;
                  end
            RESP: begin
                    _if.B_VALID = 1;
                    _if.B_RESP = 2'b00;
                  end
        endcase
  end
  
  //DATA CAPTURING BASED ON STATE AND SIGNALS
  always_ff @(posedge _if.clk) begin
    
    case(PS)
            IDLE: begin 
                    if(_if.AW_VALID && _if.AW_READY && _if.W_VALID && _if.W_READY) begin
                        w_addr <= _if.AW_ADDR;
                        w_data <= _if.W_DATA;
                        w_strb <= _if.W_STRB;
                        
                    end else if(_if.W_VALID && _if.W_READY) begin
                        w_data <= _if.W_DATA;
                        w_strb <=   _if.W_STRB;
                        
                    end else if(_if.AW_VALID && _if.AW_READY) begin
                        w_addr <= _if.AW_ADDR;
                    end
                  end
                  
            DATA: begin
                    if(_if.W_VALID && _if.W_READY) begin
                        w_data <= _if.W_DATA;
                        w_strb <=   _if.W_STRB;
                    end
                  end
                  
            ADDR: begin
                    if(_if.AW_VALID && _if.AW_READY)
                        w_addr <= _if.AW_ADDR;
                  end
            RESP: begin
                   
                        //MEM[w_addr] <= w_data; 
                        for(int i = 0; i < `DATA_WIDTH/8; i++) begin
                            if(w_strb[i]) 
                                MEM[w_addr>>2][8*i +: 8] <= w_data[8*i +: 8];
                        end
                    
                  end
    endcase
    
  end
  
  
  
  //READ LOGIC WITHOUT STASTES ANOTHER WAY (AS ONLY TWO STATES)
  always_ff @(posedge _if.clk) begin
  
    if(!_if.rstn) begin
        _if.AR_READY <= 1'b1;
        _if.R_VALID <= 1'b0;
    end else begin
        if(_if.AR_VALID && _if.AR_READY) begin
          _if.R_DATA <= MEM[_if.AR_ADDR>>2];
          _if.R_VALID <= 1;
          
          _if.AR_READY <= 0;
          
          _if.R_RESP <= 2'b00;
          
          
        end
        
        if(_if.R_VALID && _if.R_READY) begin
           _if.R_VALID <= 1'b0;
           _if.AR_READY <= 1'b1;
        end
    end
  end
   

endmodule
