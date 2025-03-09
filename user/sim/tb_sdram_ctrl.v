`timescale 1ns/1ps
module tb_sdram_ctrl();

//inports reg
reg     i_sysclk;
reg     i_sysrst_n;

//wire definitions
wire    clk_50m         ;
wire    clk_100m        ;
wire    clk_100m_shift  ;
wire    locked          ;
wire    sysnrst_n       ;

//使用 PLL 产生所需的时钟信号
clk_gen	clk_gen_inst (
	.areset ( !i_sysrst_n ),//PLL的复位信号是高电平有效
	.inclk0 ( i_sysclk ),
	.c0 ( clk_50m ),
	.c1 ( clk_100m ),
	.c2 ( clk_100m_shift ),
	.locked ( locked )
	);

//初始化时钟和复位
initial begin
        i_sysclk = 1'b1;
        i_sysrst_n <= 1'b0;
        #30;
        i_sysrst_n <= 1'b1;
end

//产生时钟
always #10 i_sysclk = ~i_sysclk;

//生成复位信号，这个复位信号在时钟稳定后撤掉
assign  sysrst_n = i_sysrst_n & locked;

//实例化sdram_ctrl
// sdram_ctrl outports wire
wire        	o_init_done;
wire        	o_wr_ack;
wire [15:0] 	o_rd_data;
wire        	o_rd_ack;
wire        	o_sdram_cke;
wire        	o_sdram_cs_n;
wire        	o_sdram_cas_n;
wire        	o_sdram_ras_n;
wire        	o_sdram_we_n;
wire [1:0]  	o_sdram_ba;
wire [12:0] 	o_sdram_addr;

sdram_ctrl u_sdram_ctrl(
	.i_sysclk       	( clk_100m        ),
	.i_sysrst_n     	( sysrst_n        ),
	.o_init_done    	( o_init_done     ),
	.i_wr_req       	( i_wr_req        ),
	.i_wr_addr      	( i_wr_addr       ),
	.i_wr_burst_len 	( i_wr_burst_len  ),
	.i_wr_data      	( i_wr_data       ),
	.o_wr_ack       	( o_wr_ack        ),
	.i_rd_req       	( i_rd_req        ),
	.i_rd_addr      	( i_rd_addr       ),
	.i_rd_burst_len 	( i_rd_burst_len  ),
	.o_rd_data      	( o_rd_data       ),
	.o_rd_ack       	( o_rd_ack        ),
	.o_sdram_cke    	( o_sdram_cke     ),
	.o_sdram_cs_n   	( o_sdram_cs_n    ),
	.o_sdram_cas_n  	( o_sdram_cas_n   ),
	.o_sdram_ras_n  	( o_sdram_ras_n   ),
	.o_sdram_we_n   	( o_sdram_we_n    ),
	.o_sdram_ba     	( o_sdram_ba      ),
	.o_sdram_addr   	( o_sdram_addr    ),
	.sdram_dq       	( sdram_dq        )
);

//使用sdram_model_plus进行仿真，sdram_model_plus是sdram的仿真模型
sdram_model_plus u_sdram_model_plus(
        .Dq     (),//没有数据线，不连接
        .Addr   (o_init_addr),
        .Ba     (o_init_ba),
        .Clk    (clk_100m_shift),//SDRAM的时钟需要相位偏移
        .Cke    (1'b1),//时钟使能
        .Cs_n   (o_init_cmd[3]),
        .Ras_n  (o_init_cmd[2]),
        .Cas_n  (o_init_cmd[1]),
        .We_n   (o_init_cmd[0]),
        .Dqm    (2'b00),//不使用数据掩码
        .Debug  (1'b1)//不使用调试接口
);

//按照板子实际所用的SDRAM的型号，重新定义sdr中的参数，便于进行仿真
defparam        u_sdram_model_plus.addr_bits = 13;              //地址位宽
defparam        u_sdram_model_plus.dq_bits   = 16;              //数据位宽
defparam        u_sdram_model_plus.col_bits  = 9 ;              //列地址位宽
defparam        u_sdram_model_plus.mem_sizes = 2*1024*1024;     //L-Bank容量

endmodule