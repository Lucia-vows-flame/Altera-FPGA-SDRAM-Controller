`timescale 1ns/1ns
module tb_sdram_auto_refresh();

//inports reg
reg     i_sysclk;
reg     i_sysrst_n;

// init outports wire
wire [3:0]  	o_init_cmd;
wire [1:0]  	o_init_ba;
wire [12:0] 	o_init_addr;
wire        	o_init_done;
// refresh outports wire
wire        	o_refresh_request;
wire [3:0]  	o_refresh_cmd;
wire [1:0]  	o_refresh_ba;
wire [12:0] 	o_refresh_addr;
wire        	o_refresh_done;

//wire definitions
wire    clk_50m         ;
wire    clk_100m        ;
wire    clk_100m_shift  ;
wire    locked          ;
wire    sysnrst_n       ;

//使用这三个信号进行简单的仲裁处理
wire    [3:0]   sdram_cmd       ;
wire    [1:0]   sdram_ba        ;
wire    [12:0]  sdram_addr      ;

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

//reg definitions
reg     i_refresh_start ;//生成自动刷新的 start 信号

//i_refresh_start
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                i_refresh_start <= 1'b0;
        else if((o_init_done) && (o_refresh_request))//初始化完成后并且发出请求信号后把i_refresh_start拉高，实际上的i_refresh_start信号由仲裁器拉高
                i_refresh_start <= 1'b1;
        else if(o_refresh_done)//根据时序图，自动刷新完成后把i_refresh_start拉低
                i_refresh_start <= 1'b0;
        else
                i_refresh_start <= i_refresh_start;

//实例化sdram_refresh
sdram_auto_refresh u_sdram_auto_refresh(
	.i_sysclk          	( clk_100m           ),
	.i_sysrst_n        	( sysrst_n           ),
	.i_init_done       	( o_init_done        ),
	.i_refresh_start   	( i_refresh_start    ),
	.o_refresh_request 	( o_refresh_request  ),
	.o_refresh_cmd     	( o_refresh_cmd      ),
	.o_refresh_ba      	( o_refresh_ba       ),
	.o_refresh_addr    	( o_refresh_addr     ),
	.o_refresh_done    	( o_refresh_done     )
);

//仲裁处理
assign  sdram_cmd       =       (o_init_done) ? o_refresh_cmd  : o_init_cmd ;//初始化完成，将自动刷新指令传给sdram，否则将初始化指令传给sdram
assign  sdram_ba        =       (o_init_done) ? o_refresh_ba   : o_init_ba  ;//初始化完成，将自动刷新指令传给sdram，否则将初始化指令传给sdram
assign  sdram_addr      =       (o_init_done) ? o_refresh_addr : o_init_addr;//初始化完成，将自动刷新指令传给sdram，否则将初始化指令传给sdram

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