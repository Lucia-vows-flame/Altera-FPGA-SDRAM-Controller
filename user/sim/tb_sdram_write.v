`timescale 1ns/1ns
module tb_sdram_write();

//inports reg
reg             i_sysclk;
reg             i_sysrst_n;
reg     [15:0]  i_wr_data;
reg             i_write_start;

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

// sdram_init outports wire
wire [3:0]  	o_init_cmd;
wire [1:0]  	o_init_ba;
wire [12:0] 	o_init_addr;
wire        	o_init_done;

// sdram_write outports wire
wire [3:0]  	o_wr_cmd;
wire [1:0]  	o_wr_ba;
wire [12:0] 	o_wr_addr;
wire [15:0] 	o_wr_data;
wire        	o_wr_done;
wire        	o_wr_ack;
wire        	sdram_wr_dq_oe;

//定义SDRAM的数据端口，该端口是三态的
wire    [15:0]  sdram_data;

//sdram_data
assign  sdram_data = (sdram_wr_dq_oe) ? o_wr_data : 16'dz;

//产生i_wr_data
always @(posedge clk_100m or negedge sysrst_n)
        if(!sysrst_n)
                i_wr_data <= 16'd0;
        else if(i_wr_data == 16'd10)
                i_wr_data <= 16'd0;
        else if(o_wr_ack)
                i_wr_data <= i_wr_data + 1;
        else
                i_wr_data <= i_wr_data;

//产生i_write_start
always @(posedge clk_100m or negedge sysrst_n)
        if(!sysrst_n)
                i_write_start <= 1'b0;
        else if(o_wr_done)
                i_write_start <= 1'b0;
        else if(o_init_done)
                i_write_start <= 1'b1;
        else
                i_write_start <= i_write_start;

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

//实例化sdram_write
sdram_write u_sdram_write(
	.i_sysclk     	        ( clk_100m        ),
	.i_sysrst_n             ( sysrst_n        ),
	.i_init_done    	( o_init_done     ),
	.i_wr_addr      	( 24'h000_000     ),
	.i_wr_data      	( i_wr_data       ),
	.i_wr_burst_len 	( 10              ),
	.i_write_start  	( i_write_start   ),
	.o_wr_cmd       	( o_wr_cmd        ),
	.o_wr_ba        	( o_wr_ba         ),
	.o_wr_addr      	( o_wr_addr       ),
	.o_wr_data      	( o_wr_data       ),
	.o_wr_done      	( o_wr_done       ),
	.o_wr_ack       	( o_wr_ack        ),
	.sdram_wr_dq_oe 	( sdram_wr_dq_oe  )
);

//仲裁处理
assign  sdram_cmd       =       (o_init_done) ? o_wr_cmd  : o_init_cmd ;//初始化完成，将读指令传给sdram，否则将初始化指令传给sdram
assign  sdram_ba        =       (o_init_done) ? o_wr_ba   : o_init_ba  ;//初始化完成，将读指令传给sdram，否则将初始化指令传给sdram
assign  sdram_addr      =       (o_init_done) ? o_wr_addr : o_init_addr;//初始化完成，将读指令传给sdram，否则将初始化指令传给sdram

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