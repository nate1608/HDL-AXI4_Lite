`timescale 1ns/1ps

`define DATA_WIDTH 32
`define ADDR_WIDTH 12

class write_packet;
	rand logic wr_en;
	rand logic [`DATA_WIDTH - 1: 0] w_data;
	rand logic [`ADDR_WIDTH - 1: 0] w_addr;
	rand logic [`DATA_WIDTH/8 - 1: 0] w_strb;
	logic [1:0] w_resp;

	static int wr_count =0;

	covergroup wr_coverage;
		write_data: coverpoint w_data{
			bins dividein4[4] = {[0:$]};
		}
		write_addr: coverpoint w_addr{
			bins dividein4[4] = {[1: {`ADDR_WIDTH{1'b1}} ]};
			bins start = {'0};
			bins finish = {'1};
		}
		write_strobe: coverpoint w_strb{
			bins feature1 = {4'b1111};
			bins feature2 = { 4'b0111, 4'b1011, 4'b1101, 4'b1110};
			bins feature3 = { 4'b0011, 4'b0110, 4'b1010, 4'b0101, 4'b1001, 4'b1100};
			bins feature4 = { 4'b0001, 4'b0010, 4'b0100, 4'b1000};
			bins feature5 = {4'b0000};
		}

		cross write_addr, write_strobe{ //only want to check the division with strobes all bins
			//bins addr_strobe = binsof(write_addr.dividein4) && binsof(write_strobe) ;
			ignore_bins ignore = binsof(write_addr.start) || binsof(write_addr.finish);
		}
	endgroup
	
	constraint wr_cons { (wr_en==0)-> (w_data == '0 && w_addr == '0 && w_strb == 4'b0000);	}

	constraint strobe_cons { w_strb dist { 4'b1111 :/ 70 , [0:14] :/30 }; }

	function new();

	wr_coverage = new;

	wr_count = wr_count+1;

	
        wr_en  = 0;
        
        w_data = 0;
        w_addr = 0;
        w_strb = 0;
        
        w_resp = 0;
    	endfunction

	function void display(string tag = "NO TAG!");
		$display("%0t: [%s] WID = %0d, wr_en = %b, w_addr = %0h, w_data = %0h, w_strobe = %b, w_resp = %b", $time,tag,wr_count, wr_en, w_addr, w_data, w_strb, w_resp);

	endfunction

	
endclass


class read_packet;
	
	rand logic rd_en;
	
	rand logic [`ADDR_WIDTH - 1: 0] r_addr;
	
	logic [1:0] r_resp;
	logic [`DATA_WIDTH - 1: 0] r_data;

	static int rd_count = 0;
	
	

	covergroup rd_coverage;
		coverpoint r_addr{
			bins dividein4[4] = {[1: {`ADDR_WIDTH{1'b1}} ]};
			bins start = {'0};
			bins finish = {'1};
		}

		coverpoint r_data{
			bins dividein4[4] = {[0:$]};
		}
	endgroup


	constraint rd_cons { (rd_en==0)-> (r_addr == '0); }

	function new();
	rd_coverage = new;

        rd_count = rd_count + 1;
        rd_en  = 0;
        r_addr = 0;
        r_resp = 0;
        r_data = 0;
    	endfunction

	function void display(string tag = "NO TAG!");
		$display("%0t: [%s] RID = %0d, rd_en = %b, r_addr = %0h, r_data = %0h, r_resp = %0b", $time,tag, rd_count, rd_en, r_addr, r_data, r_resp);

	endfunction
endclass



interface tb_if(input bit clk);
	logic rstn;

	logic wr_en;
	logic rd_en;
	logic [`DATA_WIDTH - 1: 0] w_data;
	logic [`ADDR_WIDTH - 1: 0] w_addr;
	logic [`DATA_WIDTH/8 - 1: 0] w_strb;
	logic [`ADDR_WIDTH - 1: 0] r_addr;
	logic [1:0] w_resp;
	logic [1:0] r_resp;
	logic [`DATA_WIDTH - 1: 0] r_data;
	
	int wr_count;
	int rd_count;

	clocking clb @(posedge clk);
		default input #1step output #0;
		output wr_en, rd_en, w_data, w_addr, r_addr, w_strb, wr_count, rd_count;
		input w_resp, r_data, r_resp;
	endclocking

endinterface


class driver;
	mailbox #(write_packet) wr_drv_mbx;
	mailbox #(read_packet) rd_drv_mbx;

	virtual tb_if vif;
	

	task run();
		@(vif.clb);
		$display("%0t, ----- [DRIVER] STARTING -----\n", $time);

		fork //FORKING READ AND WRITE TRANSACTIONS

		   forever begin
			write_packet wr_item;
			$display("%0t, --[DRIVER] WAITING FOR NEW WRITE PACKET--", $time);
			wr_drv_mbx.get(wr_item);
			wr_item.display("DRIVER");

			vif.clb.wr_count <= wr_item.wr_count;
			vif.clb.wr_en <= wr_item.wr_en;
			vif.clb.w_data <= wr_item.w_data;
			vif.clb.w_addr <= wr_item.w_addr;
			vif.clb.w_strb <= wr_item.w_strb;
			@(vif.clb); //dut sees above interface inputs at this edge
			
			vif.clb.wr_en <= 0;	
		   end

		   forever begin
			read_packet rd_item;
			$display("%0t, --[DRIVER] WAITING FOR NEW READ PACKET--", $time);
			rd_drv_mbx.get(rd_item);
			rd_item.display("DRIVER");
			
			vif.clb.rd_count <= rd_item.rd_count;
			vif.clb.rd_en <= rd_item.rd_en;
			vif.clb.r_addr <= rd_item.r_addr;

			@(vif.clb); //dut sees above interface inputs at this edge
			vif.clb.rd_en <= 0;			
		   end

		join
	endtask
endclass

class monitor;
	mailbox #(write_packet) wr_scb_mbx;
	mailbox #(read_packet) rd_scb_mbx;

	virtual tb_if vif;
	event wr_done;
	event rd_done;

	task run();
		write_packet wr_item;
		read_packet rd_item;
		$display("%0t, ----- [MONITOR] STARTING -----\n", $time);

		//since both read and write are parallel we need to fork i think
		fork 
			
			//need to wait to capture the write response and read response + data
			//but if i do this way i am completely seperating the write and reads (like even if rd and wr_en are simultaneour diff items will sent to scoreboard
			//solution: use seperate paramaterzed mailboxes for rd item and wr item sending

			forever begin 
			@(vif.clb); //wait so that stable pins

			if(vif.wr_en) begin
				wr_item = new();
				//capturing the inputs prvided by the driver (clk1) just before (clk2) (clocking block)
				wr_item.wr_en = vif.wr_en ;
				wr_item.w_data = vif.w_data ;
				wr_item.w_addr = vif.w_addr ;
				wr_item.w_strb = vif.w_strb;
			
				wr_item.wr_count = vif.wr_count;				
				
				//wait for the response
				while( vif.clb.w_resp == 2'b11 ) begin
					@(vif.clb);
				end
				wr_item.w_resp = vif.clb.w_resp;

				wr_scb_mbx.put(wr_item);

				->wr_done;
			end

			end


			forever begin

			@(vif.clb); //wait so that stable pins
			if(vif.rd_en) begin
				rd_item = new();
				rd_item.rd_en = vif.rd_en ;
				rd_item.r_addr = vif.r_addr ;
				rd_item.rd_count = vif.rd_count ;

				//wait for read data and response (indicator -> r_resp goes from 2'b11 since default value: 2'b11, any change indicates new response is there
				while( vif.clb.r_resp == 2'b11 ) begin
					@(vif.clb); //not sure about this delay, as the vif.clb.resp gets captured just before the #1step of posedge, and at that time even done gets triggered and seeing that generator generated new enable controls, the NS combinational logic in manager has to see this new enable and take appropriate stable value before the posedge edge comes

				end 

				rd_item.r_resp = vif.clb.r_resp;
				rd_item.r_data = vif.clb.r_data;
				
				rd_scb_mbx.put(rd_item);

				->rd_done; //read complete now other read request (rd_en) can start
			end

			end
				
		join
	endtask
	
endclass


class generator;
	event wr_done;
	event rd_done;
	
	write_packet w_item;
	read_packet r_item;

	mailbox #(write_packet) wr_drv_mbx;
	mailbox #(read_packet) rd_drv_mbx;

	logic [`ADDR_WIDTH - 1:0] written_addr[$];


	task gen_packets();

		

			fork
				repeat(250) begin
					w_item = new();

					assert(w_item.randomize() with { wr_en == 1; })
					else $fatal(1, "Randomization failed for WRITE Packet!");

					wr_drv_mbx.put(w_item);
					@(wr_done);
					written_addr.push_back(w_item.w_addr);

				end
				
				repeat(250) begin
					r_item = new();
					
					//50% of time read from written addresses
					if( written_addr.size() >1 && $urandom_range(0,1) ) begin
						int idx = $urandom_range(0, written_addr.size() - 1);
						assert (r_item.randomize() with { rd_en ==1; r_addr == written_addr[idx]; } )
						else $fatal(1, "Randomization failed for READ at written memory location!");
					end

					else begin
						assert (r_item.randomize() with {rd_en == 1; })
						else $fatal(1, "Randomization failed for READ Packet!");
					end
						
					rd_drv_mbx.put(r_item);
					@(rd_done);
				end
			join	
	endtask

	
endclass
	

class scoreboard;
	mailbox  #(read_packet) rd_scb_mbx;
	mailbox #(write_packet) wr_scb_mbx;

	logic rd_after_wr_once;

	covergroup rd_after_wr;
		coverpoint rd_after_wr_once;
	endgroup

	function new();
		rd_after_wr = new;
	endfunction

	//not making array of item packets of size 1024 for reference, just a simulating articficially memory inside slave

	reg [`DATA_WIDTH-1:0]  ref_MEM [ logic [`ADDR_WIDTH -1:0] ]; //32*1024 = 4KB

	task run();
		
		$display("%0t, ----- [SCOREBOARD] STARTING -----\n", $time);

		//SINCE CHANGEF THE REF MEM FROM FIXED 4GB TO DYNAMIC ASSOCIATIVE NO NEED TO INITIALLIZE TO ZERO
		/*for( int i = 0; i < 1024; i++) 
			ref_MEM[i] = '0;*/


		fork //again for seperating read and write scoreboarding

		   forever begin
			write_packet wr_item;
			$display("%0t, --[SCOREBOARD] WAITING FOR NEW WRITE PACKET-- \n", $time);
			wr_scb_mbx.get(wr_item);
			wr_item.display("SCOREBOARD / WRITE");

			//sample wr_item coverage
			wr_item.wr_coverage.sample();

			if(wr_item.wr_en == 1'b1) begin
				//if new queue element is there , then we need to first make and initialize that element to zero
				if(wr_item.w_resp == 2'b00) begin
					$display("%0t, [SCOREBOARD] WRITE COMPLETE! W_ADDR = %0h, W_DATA = %0h ", $time, wr_item.w_addr, wr_item.w_data);

					if( !ref_MEM.exists(wr_item.w_addr>>2) )  ref_MEM[wr_item.w_addr>>2] = '0;

                        		for(int i = 0; i < `DATA_WIDTH/8; i++) begin
                            			if(wr_item.w_strb[i]) 
                                			ref_MEM[wr_item.w_addr>>2][8*i +: 8] = wr_item.w_data[8*i +: 8];
                       			end

                    		end else $display("%0t, [SCOREBOARD] WRITE FIALED! W_ADDR = %0h, W_DATA = %0h", $time, wr_item.w_addr, wr_item.w_data);
			
			end 
		   end


		   forever begin
			read_packet rd_item;
			$display("%0t, --[SCOREBOARD] WAITING FOR NEW READ PACKET-- \n", $time);
			rd_scb_mbx.get(rd_item);
			rd_item.display("SCOREBOARD / READ");

			//sample rd_item coverage also read after write on same address coverage
			rd_item.rd_coverage.sample();
			

			if(rd_item.rd_en == 1'b1) begin
				if(rd_item.r_resp == 2'b00) begin
					if(ref_MEM.exists(rd_item.r_addr>>2) ) begin

					if(rd_item.r_data == ref_MEM[rd_item.r_addr>>2]) begin
						$display("%0t, [SCOREBOARD] READ COMPLETE (AFTER WRITE)! R_ADDR = %0h, R_DATA = %0h ", $time, rd_item.r_addr, rd_item.r_data);
						rd_after_wr_once  = 1;
					end else $display("%0t, [SCOREBOARD] READ AFTER WRITE FAILED (WRONG VALUE)! R_ADDR = %0h, R_DATA(wrong) = %0h, R_DATA(expected) = %0h", $time, rd_item.r_addr, rd_item.r_data, ref_MEM[rd_item.r_addr>>2]);
				
					end else begin
						rd_after_wr_once = 0;
						if(rd_item.r_data == '0) 
						$display("%0t, [SCOREBOARD] READ COMPLETE! R_ADDR = %0h, R_DATA = %0h ", $time, rd_item.r_addr, rd_item.r_data);
						else $display("%0t, [SCOREBOARD] READ FAILED (WRONG VALUE)! R_ADDR = %0h, R_DATA = %0h", $time, rd_item.r_addr, rd_item.r_data);
					end

				end else $display("%0t, [SCOREBOARD] READ FAILED (READ RESPONSE)! R_ADDR = %0h, R_DATA = %0h", $time, rd_item.r_addr, rd_item.r_data);
			end
			
			rd_after_wr.sample();
		   
		   end
		join

	endtask

endclass




class environment;
	mailbox #(write_packet) wr_scb_mbx;
	mailbox #(read_packet) rd_scb_mbx;

	virtual tb_if vif;
	event wr_done;
	event rd_done;

	driver d0;
	monitor m0;
	scoreboard s0;

	function new();
		d0 = new();
		m0 = new();
		s0 = new();

		wr_scb_mbx = new();
		rd_scb_mbx = new();
	endfunction


	task run();
		//connecting interface
		d0.vif = vif;
		m0.vif = vif;
		//connecting mailbox b/w scb and monitor
		m0.wr_scb_mbx  = wr_scb_mbx;
		s0.wr_scb_mbx = wr_scb_mbx;
		m0.rd_scb_mbx  = rd_scb_mbx;
		s0.rd_scb_mbx = rd_scb_mbx;
		//connceting events ( monitor)
		
		m0.wr_done = wr_done;
		m0.rd_done = rd_done;
		

		fork
			d0.run();
			m0.run();
			s0.run();
		join_any
		
	endtask
endclass


class test;
	mailbox #(read_packet) rd_drv_mbx;
	mailbox #(write_packet) wr_drv_mbx;

	generator g0;
	environment e0;
	event wr_done;
	event rd_done;


	function new();
		g0 = new();
		e0 = new();

		rd_drv_mbx = new();
		wr_drv_mbx = new();
	endfunction

	task start_testing();
		g0.rd_drv_mbx = rd_drv_mbx;
		e0.d0.rd_drv_mbx = rd_drv_mbx;
		
		g0.wr_drv_mbx = wr_drv_mbx;
		e0.d0.wr_drv_mbx = wr_drv_mbx;

		//events b/w gen and env
		g0.wr_done = wr_done;
		e0.wr_done = wr_done;
		g0.rd_done = rd_done;
		e0.rd_done = rd_done;

		fork
			g0.gen_packets();
			e0.run();
		join_any
	endtask
endclass


module top;
	//generating clk
	logic clk;
	always #5 clk = ~clk;

	//interfaces (one for testbench and one for axi interconnect)
	tb_if _tif(clk);
	axi_if _if(clk, _tif.rstn);

	//top module connected with testbench iterface for stimulus and output
	axi4_top	DUT(	._if(_if),
			.clk(_tif.clk), .wr_en(_tif.wr_en), .rd_en(_tif.rd_en),
    			.w_data(_tif.w_data),
    			.w_addr(_tif.w_addr), .r_addr(_tif.r_addr),
    			.w_strb(_tif.w_strb),
    			.r_data(_tif.r_data),
   			.w_resp(_tif.w_resp), .r_resp(_tif.r_resp)
		);

	//test class
	test t0;

	initial begin
		t0 = new();
		t0.e0.vif = _tif;

		clk = 1; //posedge comees at multiples of 10ns
		_tif.rstn = 0; //reset everyhting

		@(posedge clk); #1 _tif.rstn = 1;

		
		t0.start_testing();
		

		repeat(5) @(posedge clk);
		
		$display("========================================");
        $display("        FUNCTIONAL COVERAGE RESULTS     ");
        $display("========================================");
        $display("Total Global Coverage: %0.2f%%", $get_coverage());
        $display("Read After Write Hit : %0.2f%%", t0.e0.s0.rd_after_wr.get_inst_coverage());
        $display("========================================");
		$finish;
	end

endmodule














