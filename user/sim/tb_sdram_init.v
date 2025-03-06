`timescale 1ns/1ns
module tb_sdram_init();

//inports reg
reg     i_sysclk;
reg     i_sysrst_n;

// outports wire
wire [3:0]  	o_init_cmd;
wire [1:0]  	o_init_ba;
wire [12:0] 	o_init_addr;
wire        	o_init_done;

//wire definitions
wire    clk_50m         ;
wire    clk_100m        ;
wire    clk_100m_shift  ;
wire    locked          ;
wire    sysnrst_n       ;

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
assign  sysnrst_n = i_sysrst_n & locked;

//使用 PLL 产生所需的时钟信号
clk_gen	clk_gen_inst (
	.areset ( !i_sysrst_n ),//PLL的复位信号是高电平有效
	.inclk0 ( i_sysclk ),
	.c0 ( clk_50m ),
	.c1 ( clk_100m ),
	.c2 ( clk_100m_shift ),
	.locked ( locked )
	);

//实例化sdram_init
sdram_init u_sdram_init(
	.i_sysclk    	( clk_100m     ),
	.i_sysrst_n  	( sysrst_n     ),
	.o_init_cmd  	( o_init_cmd   ),
	.o_init_ba   	( o_init_ba    ),
	.o_init_addr 	( o_init_addr  ),
	.o_init_done 	( o_init_done  )
);

//使用sdr进行仿真，sdr是sdram的仿真模型
sdr u_sdr(
        .Dq     (),//没有数据线，不连接
        .Addr   (o_init_addr),
        .Ba     (o_init_ba),
        .Clk    (clk_100m_shift),//SDRAM的时钟需要相位偏移
        .Cke    (1'b1),//时钟使能
        .Cs_n   (o_init_cmd[3]),
        .Ras_n  (o_init_cmd[2]),
        .Cas_n  (o_init_cmd[1]),
        .We_n   (o_init_cmd[0]),
        .Dqm    (2'b00)//不使用数据掩码
);

//按照板子实际所用的SDRAM的型号，重新定义sdr中的参数，便于进行仿真
defparam        u_sdr.ADDR_BITS = 13;              //地址位宽
defparam        u_sdr.DQ_BITS   = 16;              //数据位宽
defparam        u_sdr.COL_BITS  = 9 ;              //列地址位宽
defparam        u_sdr.mem_sizes = 2*1024*1024;     //L-Bank容量

endmodule