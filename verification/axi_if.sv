`timescale 1ns/1ps

`define DATA_WIDTH 32
`define ADDR_WIDTH 8


interface axi_if(input bit clk , input bit rstn);
  //commented out Channdels/signals are for future incorporation of burst and out-of-order transfers
  
  //logic AW_ID;
  logic AW_READY;
  logic AW_VALID;
  logic [`ADDR_WIDTH-1:0] AW_ADDR;
  //logic [1:0] AW_BURST; 
  //logic [2:0] AW_SIZE;
  //logic [3:0] AW_LEN;
  
  //logic AR_ID;
  logic AR_READY;
  logic AR_VALID;
  logic [`ADDR_WIDTH-1:0] AR_ADDR;
  //logic [1:0] AR_BURST; 
  //logic [2:0] AR_SIZE;
  //logic [3:0] AR_LEN;
  
  //logic B_ID;
  logic B_VALID;
  logic B_READY;
  logic [1:0] B_RESP;
  
  
  logic W_READY;
  logic W_VALID;
  logic [`DATA_WIDTH - 1: 0] W_DATA;
  logic [`DATA_WIDTH/8 - 1: 0] W_STRB;
  //logic W_LAST;
  
  //logic R_ID;
  logic R_READY;
  logic R_VALID;
  logic [`DATA_WIDTH - 1: 0] R_DATA;
  logic [1:0] R_RESP;
  //logic R_LAST;
  
  modport subordinate_mp ( 
    input clk, AW_VALID, AW_ADDR, W_VALID, W_DATA,W_STRB, B_READY,
           AR_VALID, AR_ADDR, R_READY, rstn,
    output AW_READY, W_READY, B_VALID, B_RESP,
           AR_READY, R_VALID, R_DATA, R_RESP
  ); 

    modport manager_mp (
        input clk, AW_READY, W_READY, B_RESP, B_VALID, AR_READY,
                R_DATA, R_VALID, R_RESP, rstn,
        output AW_VALID, AW_ADDR, W_VALID, W_DATA, W_STRB, B_READY,
                AR_VALID, AR_ADDR,  R_READY
    );


	//ASSERTIONS 
	//ASSERTION TYPE1: VALID SHOULD REMAIN ASSERTED UNTIL HANDSGAKE ONCE ASSERTED
	property AW_VAL;
		@(posedge clk) disable iff(!rstn)
		AW_VALID && !AW_READY |=> AW_VALID;
	endproperty

	property W_VAL;
		@(posedge clk) disable iff(!rstn)
		W_VALID && !W_READY |=> W_VALID;
	endproperty

	property B_VAL;
		@(posedge clk) disable iff(!rstn)
		B_VALID && !B_READY |=> B_VALID;
	endproperty

	property AR_VAL;
        	@(posedge clk) disable iff(!rstn)
        	AR_VALID && !AR_READY |=> AR_VALID;
    	endproperty

	property R_VAL;
		@(posedge clk) disable iff(!rstn)
		R_VALID && !R_READY |=> R_VALID;
	endproperty

	assert property(AW_VAL);
	assert property(W_VAL);
	assert property(B_VAL);
	assert property(AR_VAL);
	assert property(R_VAL);

	//payload should also be stable during the constant valid
	property p_aw_addr_stable;
        	@(posedge clk) disable iff(!rstn)
      	  	AW_VALID && !AW_READY |=> $stable(AW_ADDR); 
    	endproperty

    	property p_w_data_stable;
        	@(posedge clk) disable iff(!rstn)
        	W_VALID && !W_READY |=> $stable(W_DATA) && $stable(W_STRB);
    	endproperty

    	property p_ar_addr_stable;
        	@(posedge clk) disable iff(!rstn)
        	AR_VALID && !AR_READY |=> $stable(AR_ADDR);
    	endproperty

    	assert property(p_aw_addr_stable);
    	assert property(p_w_data_stable);
    	assert property(p_ar_addr_stable);

	//ASSERTION TYPE2: B_VALID CAN ONLY OCCUR AFTER AW AND W HANDSHAKES
	property W_dependency;
		@(posedge clk) disable iff(!rstn)
		AW_VALID || W_VALID |-> !B_VALID; //DIDNT WRITE READY COZ VALID DOWN INDICATES HANDSHAKE COMPLETE (EXCEPT RESET CASE)
	endproperty
	
	assert property (W_dependency);

	//ASSERTION TYPE3: R_VALID ONLY AFTER AR HANDSHAKE;
	property R_dependency;
		@(posedge clk) disable iff(!rstn)
		AR_VALID |-> !R_VALID;
	endproperty

	assert property (R_dependency);

 
endinterface
