module SP(
	// INPUT SIGNAL
	clk,
	rst_n,
	in_valid,
	inst,
	mem_dout,
	// OUTPUT SIGNAL
	out_valid,
	inst_addr,
	mem_wen,
	mem_addr,
	mem_din
);



//------------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION                         
//------------------------------------------------------------------------

input                    clk, rst_n, in_valid;
input             [31:0] inst;
input  signed     [31:0] mem_dout;
output reg               out_valid;
output reg        [31:0] inst_addr;
output reg               mem_wen;
output reg        [11:0] mem_addr;
output reg signed [31:0] mem_din;

//------------------------------------------------------------------------
//   DECLARATION
//------------------------------------------------------------------------

// REGISTER FILE, DO NOT EDIT THE NAME.
reg	        [31:0] r      [0:31]; 

localparam  S_IDLE=0;
localparam  S_IN=1;
localparam  S_EXE=2;
localparam  S_OUT=3;
integer i;


reg signed[31:0] rs_now, rt_now, rd_now;
reg [1:0] current_state, next_state;
reg [5:0] opcode;
reg [4:0] rs;
reg [4:0] rt;
reg [4:0] rd;
reg [4:0] shamt;
reg [5:0] funct;
reg [15:0] imm;
reg delay_valid_1,delay_valid_2,delay_valid_3,delay_valid_4;
reg signed [15:0] SEimm;
reg [15:0] ZEimm;
reg signed [31:0] ALU_output,ALU;
reg signed[31:0] rs_store,rt_store,rd_store;

//------------------------------------------------------------------------
//   DESIGN
//------------------------------------------------------------------------

always @(*) begin
	case(current_state)
		S_IDLE: 
			if(in_valid)	
				next_state=S_IN;
			else			
				next_state=S_IDLE;
		S_IN:
			if(in_valid)	
				next_state=S_IN;
			else		
			begin
				next_state=S_EXE;
				out_valid=in_valid;
			end		
		S_EXE:
			if(delay_valid_4)
				next_state=S_OUT;			
			else
				next_state=S_EXE;
		S_OUT:
		begin
			next_state=S_IDLE;	
			inst_addr=inst_addr+4;		
		end

		default:
			next_state=S_IDLE;	
	endcase			
end

always @(posedge clk)
begin
	if(next_state==S_IDLE)
	begin
		if(rst_n==0)
		begin
			out_valid=0;//1bit
			inst_addr=0;//32bit
			delay_valid_1=0;
			delay_valid_2=0;
			delay_valid_3=0;
			delay_valid_4=0;
			for(i=0;i<32;i=i+1)
			begin
				r[i]=0;
			end	
		end
	end
	else if(next_state==S_IN)
	begin
		opcode=inst[31:26];
		rs=inst[25:21];
		rt=inst[20:16];
		rd=inst[15:11];
		shamt=inst[10:6];
		funct=inst[5:0];
		imm=inst[15:0];
		ZEimm=inst[15:0];
		SEimm=inst[15:0];
		
		//clear
		for(i=0;i<32;i=i+1)
		begin
			if(rs==i)
				rs_now=r[i];
			else 
				r[i]=r[i];
		end
        //clear 
		for(i=0;i<32;i=i+1)
		begin
			if(rt==i)
				rt_now=r[i];
			else 
				r[i]=r[i];
		end
        //clear 
		for(i=0;i<32;i=i+1)
		begin
			if(rd==i)
				rd_now=r[i];
			else 
				r[i]=r[i];
		end
		case(opcode)
			6'b000000:
				begin
					case(funct)
						6'b000000:	//and
							ALU_output <= rs_now & rt_now; 
						6'b000001:	//or
							ALU_output <= rs_now | rt_now; 
						6'b000010:	//add
							ALU_output <= rs_now + rt_now; 
						6'b000011:	//sub
							ALU_output <= rs_now - rt_now; 
						6'b000100:	//slt
							ALU_output <= rs_now < rt_now; 
						6'b000101:	//sll
							ALU_output <= rs_now << shamt; 
					endcase
				end

			6'b000001:	//andi
				ALU_output <= rs_now & ZEimm; 
			6'b000010:	//ori
				ALU_output <= rs_now | ZEimm; 
			6'b000011:	//addi
				ALU_output <= rs_now + SEimm; 
			6'b000100:	//subi
				ALU_output <= rs_now - SEimm; 
			6'b000101:	//lw
				ALU_output <= rs_now + SEimm;	
			6'b000110:	//sw	
				ALU_output <= rs_now + SEimm; 
			6'b000111:	//beq   												
	            if(rs_now==rt_now)
                    ALU_output <= inst_addr+{14'b0,SEimm[15:0],2'b00};
            6'b001000:	//bne   
                if(rs_now!=rt_now)
                    ALU_output <= inst_addr+{14'b0,SEimm[15:0],2'b00};
			6'b001001:
				ALU_output <= {SEimm[15:0],16'b0};	
		endcase
	end

	else if(next_state==S_EXE)
	begin
		case(opcode)
			6'b000000:
				rd_store=ALU_output;
			6'b000001:
				rt_store=ALU_output;
			6'b000010:
				rt_store=ALU_output;
			6'b000011:
				rt_store=ALU_output;
			6'b000100:
				rt_store=ALU_output;
			6'b000101:
			begin
				mem_wen=1;
				mem_addr=ALU_output;
				rt_store=mem_dout;
			end
			6'b000110:
			begin
				mem_wen=0;
				mem_addr=ALU_output;
				mem_din=rt_now;
			end	
			6'b000111:
			begin
				if(rs_now==rt_now)
					inst_addr=ALU_output;
			end	
			6'b001000:
			begin
				if(rs_now!=rt_now)
					inst_addr=ALU_output;
			end	
			default: ALU = ALU_output;
			6'b001001:
				rt_store <= ALU_output;
		endcase
	end
	else if(next_state==S_OUT)
	begin
		case(opcode)
            6'b000000:	//R-type
			begin
                for(i=0;i<32;i=i+1) 
				begin
                    if(rd==i)
                        r[i]=rd_store;
                    else
                        r[i]=r[i];
                end
            end
            6'b000001:	//andi
			begin
                for(i=0;i<32;i=i+1) 
				begin
                    if(rt==i)
                        r[i]=rt_store;
                    else
                        r[i]=r[i];
                end
            end
        	6'b000010:	//ori
			begin
                for(i=0;i<32;i=i+1) 
				begin
                    if(rt==i)
                        r[i]=rt_store;
                    else
                        r[i]=r[i];
                end
            end
        	6'b000011:	//addi
			begin
                r[rt] = rt_store;
            end
        	6'b000100:	//subi
			begin
                for(i=0;i<32;i=i+1) 
				begin
                    if(rt==i)
                        r[i]=rt_store;
                end
            end
        	6'b000101:	//lw 
			begin
                r[rt]=rt_store;    
            end
			6'b001001:	//lw 
			begin 
				for(i=0;i<32;i=i+1)
				begin 
					if(rt == i)
						r[i] = rt_store;
					else 
						r[i]=r[i];
				end
			end	

        endcase	
	end
end

always @(posedge clk,negedge rst_n)
begin
    if(!rst_n)
    begin
        current_state <= S_IDLE;
        inst_addr=0;
        out_valid=0;
        delay_valid_1=0;
        delay_valid_2=0;
        delay_valid_3=0;
		delay_valid_4=0;
        for (i=0;i<32;i=i+1)
		begin
            r[i]=0;
        end
        mem_wen=1;
        mem_addr=0;
        mem_din=0;
    end
        
    else begin
        current_state <= next_state;
    end
        
end
always @(posedge clk)
begin
    delay_valid_1<=in_valid;
    delay_valid_2<=delay_valid_1;
    delay_valid_3<=delay_valid_2;
	delay_valid_4<=delay_valid_3;
    out_valid<=delay_valid_4;
    
end
endmodule