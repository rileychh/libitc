// source: https://blog.csdn.net/Ninquelote/article/details/105824323

// dht11
// made by 00
//time 2020.4.28
module dht11(
    input               clk,   
    input               rst_n,                                   
    inout               dht11,   
    output  reg  [31:0] data_valid     
); 
/**************parameter********************/              
parameter  POWER_ON_NUM     = 1000_000;              
parameter  S_POWER_ON      = 0;       
parameter  S_LOW_20MS      = 1;     
parameter  S_HIGH_13US     = 2;    
parameter  S_LOW_83US      = 3;      
parameter  S_HIGH_87US     = 4;      
parameter  S_SEND_DATA     = 5;      
parameter  S_DEALY         = 6; 
//reg define
reg[2:0]   cur_state;        
reg[2:0]   next_state;        
reg[20:0]  count_1us;       
reg[5:0]   data_count;                                       
reg[39:0]  data_temp;        
reg[4:0]   clk_cnt;

reg        clk_1M;       
reg        us_clear;        
reg        state;        
reg        dht_buffer;        
reg        dht_d0;        
reg        dht_d1;        
               
wire       dht_podge;        //data posedge
wire       dht_nedge;        //data negedge
/*********************main codes*********************/
assign dht11     = dht_buffer;
assign dht_podge   = ~dht_d1 & dht_d0; // catch posedge
assign dht_nedge   = dht_d1  & (~dht_d0); // catch negedge

/*********************counters*****************************/
//clock with 1MHz
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_cnt <= 0;
        clk_1M  <= 0;
    end 
    else if (clk_cnt < 24) 
        clk_cnt <= clk_cnt + 1;       
    else begin
        clk_cnt <= 0;
        clk_1M  <= ~ clk_1M;
    end 
end
//counter 1 us
always @ (posedge clk_1M or negedge rst_n) begin
    if (!rst_n)
        count_1us <= 0;
    else if (us_clear)
        count_1us <= 0;
    else 
        count_1us <= count_1us + 1;
end 
//change state
always @ (posedge clk_1M or negedge rst_n) begin
    if (!rst_n)
        cur_state <= S_POWER_ON;
    else 
        cur_state <= next_state;
end 
// state machine
always @ (posedge clk_1M or negedge rst_n) begin
    if(!rst_n) begin
        next_state <= S_POWER_ON;
        dht_buffer <= z;   
        state      <= 0; 
        us_clear   <= 0;
		data_temp  <= 0;
        data_count <= 0; 
    end 
    else begin
        case (cur_state)     
        S_POWER_ON : begin                
            if(count_1us < POWER_ON_NUM) begin
                dht_buffer <= z; 
                us_clear   <= 0;
            end
            else begin            
                next_state <= S_LOW_20MS;
                us_clear   <= 1;
			end
        end
                
        S_LOW_20MS: begin
            if(count_1us < 20000) begin
                dht_buffer <= 0; 
                us_clear   <= 0;
            end
            else begin
                next_state   <= S_HIGH_13US;
                dht_buffer <= z; 
                us_clear   <= 1;
            end    
        end 
               
        S_HIGH_13US: begin                      
            if (count_1us < 20) begin
                us_clear    <= 0;
                if(dht_nedge) begin   
                    next_state <= S_LOW_83US;
                    us_clear   <= 1; 
                end
            end
            else                      
                next_state <= S_DELAY;
        end 
                
        S_LOW_83US: begin                  
            if(dht_podge)                   
               next_state <= S_HIGH_87US;  
        end 
                
        S_HIGH_87US: begin              // ready to receive data signal
            if(dht_nedge) begin          
                next_state <= S_SEND_DATA; 
                us_clear    <= 1;
            end
            else begin                
               data_count <= 0;
               data_temp  <= 0;
               state      <= 0;
            end
        end 
                  
        S_SEND_DATA: begin   // have 40 bit
            case(state)
                0: begin               
                    if(dht_podge) begin 
                        state    <= 1;
                        us_clear <= 1;
                    end            
                    else               
                        us_clear  <= 0;
                    end
						 
                1: begin               
                    if(dht_nedge) begin 
                        data_count <= data_count + 1;
                        state    <= 0;
                        us_clear <= 1;              
						if(count_1us < 60)
							data_temp <= {data_temp[38:0],0}; //0
						else                
							data_temp <= {data_temp[38:0],1}; //1
                    end 
                    else                                            //wait for high end
                       us_clear <= 0;
                end
            endcase
                
            if(data_cnt == 40) begin                                //check data bit
                next_state <= S_DELAY;
                if(data_temp[7:0] == data_temp[39:32] + data_temp[31:24] + data_temp[23:16] + data_temp[15:8])
                    data_valid <= data_temp[39:8];  
            end
        end 
                
        S_DELAY: begin                                // after data received delay 2s
            if(count_1us < 2000_000)
                us_cnt_clr <= 0;
            else begin                 
                next_state <= S_LOW_20MS;              // send signal again
                us_cnt_clr <= 1;
            end
        end

        default :
            cur_state <= cur_state;
        endcase
    end 
end

//edge
always @ (posedge clk_1M or negedge rst_n) begin
    if (!rst_n) begin
        dht_d0 <= 1;
        dht_d1 <= 1;
    end 
    else begin
        dht_d0 <= dht11;
        dht_d1 <= dht_d0;
    end 
end 
endmodule