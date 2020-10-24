// source: https://blog.csdn.net/shen_you/article/details/78628839

module I2C_Master(
	//I2C
	clk_in,
	rst_in,
	scl_out,
	sda_inout,
	//control_sig
	start_in,   //一次读/写操作开始信号
	done_out,    //一次读/写操作结束信号
	read_write_in, //读写控制信号，写为1，读为0
	slave_addr_in,//从机地址
	command_data_in,//读写控制字16位 command_data_in[15:8]->reg_addr,command_data_in[7:0]->W_data,读状态则可默认为7'b0
	data_out,    //读到的数据，当O_Done拉高时数据有效
	err_out	  //检测传输错误信号，当出现从机未响应，从机不能接收数据等情况时，拉高电平		
 );
 
//I/O
input		clk_in;
input		rst_in;
output		scl_out;
inout		sda_inout;
 
input		start_in;
output		done_out;
input  [6:0] 	slave_addr_in;
input		read_write_in;
input  [15:0]	command_data_in;
output [7:0] 	data_out;
output      	err_out;
/******时钟定位模块（测试时时钟为50MHz）,定位SCL的高电平中心，与SCL的低电平中心，产生100kHz的SCL*******/
parameter   Start_Delay=9'd60;//开始时SDA拉低电平持续的时间，共用计数器下应小于SCL_HIGH2LOW-1
parameter   Stop_Delay=9'd150;//一次读/写结束后SDA拉高电平的时间，共用计数器下应小于SCL_HIGH2LOW-1
parameter   SCL_Period=9'd499;//测试板时钟为50MHz,100KHz为500个Clk
parameter   SCL_LOW_Dest=9'd374;//时钟判定高电平在前，低电平在后,低电平中央为3/4个周期，375个Clk
parameter   SCL_HIGH2LOW=9'd249;//电平翻转位置，1/2个SCL周期，250个Clk
parameter   ACK_Dect=9'd124;     //SCL高电平中间位置，用于检测ACK信号
reg [8:0]	scl_timer;
reg        	scl_ena;
 
assign    	scl_out=(scl_timer<=SCL_HIGH2LOW)?1'b1:1'b0;//SCL 时钟输出
 
always @ (posedge clk_in or negedge rst_in) begin
	if (~rst_in) begin
		scl_timer<=9'b0;
	end else begin
		if (scl_ena)
			if (scl_timer==SCL_Period)
				scl_timer<=9'b0;
			else
				scl_timer<=scl_timer+9'b1;
		else
		   scl_timer<=9'b0;
	end
end
 
/******SDA读写控制模块******/
reg [5:0]    state;
reg          write_enable;//SDA双向选择I/O口 1为输出，0为输入
reg          sda_out;      //SDA的输出端口
reg          done_out;       //结束信号
reg [7:0]    data_out;       //读到的数据
reg          err_out;		//传输错误指示信号
 
/****状态定义*****/
parameter    Start=6'd0;  //一次读写开始的状态
parameter    ReStart=6'd34; //读操作入口状态
parameter    Stop=6'd56;    //发送停止位状态
 
always @ (posedge clk_in or negedge rst_in) begin
	if (~rst_in) begin
		scl_ena<=1'b0;     //计数时钟停止
		state<=6'd0;
		write_enable<=1'b1;//默认设置为输出管脚
		sda_out<=1'b1;      //SDA输出默认拉高
		data_out<=8'b0;
		done_out<=1'b0;
		err_out<=1'b0;
	end else begin
		if (start_in) begin //当开始信号置高时表示I2C通信开始
			case(state)
			Start: begin //启动位
				scl_ena<=1'b1;
				err_out<=1'b0;//每次重新下一次传输时，清除错误标志位
				if (scl_timer==Start_Delay) begin
					sda_out<=1'b0; //SCL高电平时拉低
					state<=state+6'd1;
				end else begin
					sda_out<=1'b1;
					state<=state;
				end
			end

			6'd1,6'd2,6'd3,6'd4,6'd5,6'd6,6'd7: begin //写入7位从机地址
				if (scl_timer==SCL_LOW_Dest) begin
						sda_out<=slave_addr_in[6'd7-state];//从MSB-LSB写入输入端从机地址
						state<=state+6'd1;
				end else
						state<=state;		
				end

			6'd8: begin //写入写标志（0）
				if (scl_timer==SCL_LOW_Dest) begin
					sda_out<=1'b0;
					state<=state+6'd1;
				end else
					state<=state;							 
				end

			6'd9: begin //ACK状态 
				if (scl_timer==SCL_HIGH2LOW) begin //在第8个时钟的下降沿释放SDA
					write_enable<=1'b0;
					state<=state+6'd1;
				end else
					state<=state;
				end

			6'd10: begin //在第9个时钟高电平中心检测ACK信号是否为0，如果为1，则表示从机未应答，进入结束位
				if (scl_timer==ACK_Dect) begin
					err_out<=sda_inout;  //检测从机是否响应
					state<=state+6'd1;
				end else
					state<=state; 
				end

			6'd11: begin
				if (scl_timer==SCL_HIGH2LOW) begin //在第9个时钟的下降沿重新占用SDA，准备发送从机子寄存器地址
					write_enable<=1'b1;
					state<=(err_out)?Stop:(state+6'd1);
					sda_out<=1'b0;
				end else
					state<=state;					  
			end

			6'd12,6'd13,6'd14,6'd15,6'd16,6'd17,6'd18,6'd19: begin //写入8位寄存器地址
				if (scl_timer==SCL_LOW_Dest) begin
					sda_out<=command_data_in[6'd27-state];//从MSB-LSB写入寄存器地址 command_data_in[15:8]
					state<=state+6'd1;
				end else
					state<=state;							 
			end			 

			6'd20: begin //ACK状态  
				if (scl_timer==SCL_HIGH2LOW) begin//在第8个时钟的下降沿释放SDA
					write_enable<=1'b0;
					state<=state+6'd1;
				end else
					state<=state;
			end

			6'd21: begin //检测ACK
				if (scl_timer==ACK_Dect) begin
					err_out<=sda_inout;//检测从机是否响应
					state<=state+6'd1;
				end else
					state<=state; 
			end

			6'd22: begin
				if (scl_timer==SCL_HIGH2LOW) begin //在第9个时钟的下降沿重新占用SDA，区分接下来该发送数据还是读数据
					write_enable<=1'b1;
					state<=(err_out)?Stop:((read_write_in)?(state+6'd1):ReStart); //从机状态
					sda_out<=(err_out|read_write_in)?1'b0:1'b1; //此处拉高SDA信号是为读状态重启开始信号做准备
				end else
					state<=state;							
			end

			6'd23,6'd24,6'd25,6'd26,6'd27,6'd28,6'd29,6'd30: begin //写入8位数据地址 
				if (scl_timer==SCL_LOW_Dest) begin
					sda_out<=command_data_in[6'd30-state];//从MSB-LSB写入8位数据地址
					state<=state+6'd1;
				end else
					state<=state;
			end

			6'd31: begin //ACK状态
				if (scl_timer==SCL_HIGH2LOW) begin //在第8个时钟的下降沿释放SDA
					write_enable<=1'b0;
					state<=state+6'd1;
				end else
					state<=state;					
			end

			6'd32: begin //检测ACK
				if (scl_timer==ACK_Dect) begin
						err_out<=sda_inout;//检测从机是否响应
						state<=state+6'd1;
				end else
						state<=state; 
			end				 

			6'd33: begin
				if (scl_timer==SCL_HIGH2LOW) begin //在第9个时钟的下降沿重新占用SDA，准备发送停止位
					write_enable<=1'b1;
					sda_out<=1'b0;//先拉低SDA信号
					state<=Stop;//跳转到结束位发送状态
				end else
					state<=state;							 
			end

			ReStart: begin //主机读状态入口 初始时需要重启开始状态
				if (scl_timer==Start_Delay) begin
					sda_out<=1'b0; //SCL高电平时拉低
					state<=state+6'd1;
				end else begin
					sda_out<=1'b1;
						state<=state;
				end					  
			end			

			6'd35,6'd36,6'd37,6'd38,6'd39,6'd40,6'd41: begin//发送从机7位地址		
				if (scl_timer==SCL_LOW_Dest) begin
					sda_out<=slave_addr_in[6'd41-state];//从MSB-LSB写入输入端从机地址
					state<=state+6'd1;
				end else
					state<=state;						
			end

			6'd42: begin //写入读标志(1)
				if (scl_timer==SCL_LOW_Dest) begin
					sda_out<=1'b1;//写入读地址标志
					state<=state+6'd1;
				end else
					state<=state;							  
			end

			6'd43: begin //ACK状态
				if (scl_timer==SCL_HIGH2LOW) begin //在第8个时钟的下降沿释放SDA
					write_enable<=1'b0;
					state<=state+6'd1;
				end else
					state<=state;
			end
					
			6'd44: begin//ACK检测
				if (scl_timer==ACK_Dect) begin
					err_out<=sda_inout;
					state<=state+6'd1;
				end else
					state<=state;
			end	

			6'd45: begin //之后需要一直读取数据，所以SDA总线这里需要保持输入状态
				if (scl_timer==SCL_HIGH2LOW) begin //在第9个时钟下降沿保持SDA总线的释放状态
					write_enable<=(err_out)?1'b1:1'b0;//若前次ACK检测通过，则保持SDA总线释放状态，不                                                                                通过则占用SDA总线用来发送停止位
					state<=(err_out)?Stop:(state+6'd1);
					sda_out<=1'b0; 
				end else
					state<=state;
			end

			6'd46,6'd47,6'd48,6'd49,6'd50,6'd51,6'd52,6'd53: begin//8个时钟信号高电平中间依次从SDA上读取数据
				if (scl_timer==ACK_Dect) begin
					data_out<={data_out[6:0],sda_inout};//从MSB开始读入数据
					state<=state+6'd1;
				end else
					state<=state;
			end

			6'd54: begin //读入8位数据后,主机需要向外发送一个NACK信号
				if (scl_timer==SCL_HIGH2LOW) begin
					write_enable<=1'b1;//主机重新占用SDA
					sda_out<=1'b1;
					state<=state+6'd1;
				end else
					state<=state;
			end

			6'd55: begin //在第9个时钟下降沿持续占用总线，拉低SDA，开始发送结束位
				if (scl_timer==SCL_HIGH2LOW) begin
					sda_out<=1'b0;
					state<=state+6'd1;
				end else
					state<=state;
				end

			Stop: begin //发送停止位
				if (scl_timer==Stop_Delay) begin
					sda_out<=1'b1;
					state<=state+6'd1;
				end else
					state<=state;
			end

			6'd57: begin //停止时钟，同时输出Done信号，表示一次读写操作完成
				scl_ena<=1'b0;
				done_out<=1'b1;//拉高Done信号
				state<=state+6'd1;
			end

			6'd58: begin
				done_out<=1'b0;//拉低Done信号
				state<=Start;
			end

			default: begin
					scl_ena<=1'b0;//计数时钟停止
					state<=6'd0;
					write_enable<=1'b1;//默认设置为输出管脚
					sda_out<=1'b1;//SDA输出默认拉高
					done_out<=1'b0;			 					
			end
			endcase			  
		end else begin //开始信号无效时，回到初始设置
			scl_ena<=1'b0;     //计数时钟停止
			state<=6'd0;
			write_enable<=1'b1;//默认设置为输出管脚
			sda_out<=1'b1;      //SDA输出默认拉高
			done_out<=1'b0;
		end		 
	end
end
 
/*******配置三态门信号******/
assign  sda_inout=(write_enable)?sda_out:1'bz;
 
endmodule