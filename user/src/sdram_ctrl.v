module sdram_ctrl
(
        //时钟、复位、初始化结束信号
        input                                   i_sysclk                ,
        input                                   i_sysrst_n              ,
        output                                  o_init_done             ,
        //SDRAM写端口
        input                                   i_wr_req                ,
        input                   [23:0]          i_wr_addr               ,
        input                   [9:0]           i_wr_burst_len          ,
        input                   [15:0]          i_wr_data               ,
        output                                  o_wr_ack                ,
        //SDRAM读端口
        input                                   i_rd_req                ,
        input                   [23:0]          i_rd_addr               ,
        input                   [9:0]           i_rd_burst_len          ,
        output                  [15:0]          o_rd_data               ,
        output                                  o_rd_ack                ,
        //SDRAM硬件接口
        output                                  o_sdram_cke             ,
        output                                  o_sdram_cs_n            ,
        output                                  o_sdram_cas_n           ,
        output                                  o_sdram_ras_n           ,
        output                                  o_sdram_we_n            ,
        output                  [1:0]           o_sdram_ba              ,
        output                  [12:0]          o_sdram_addr            ,
        inout                   [15:0]          sdram_dq
);

// sdram_init outports wire
wire [3:0]  	o_init_cmd;
wire [1:0]  	o_init_ba;
wire [12:0] 	o_init_addr;
// sdram_arbiter outports wire
wire        	o_refresh_start;
wire        	o_write_start;
wire        	o_read_start;
wire        	o_sdram_cke;
wire        	o_sdram_cs_n;
wire        	o_sdram_cas_n;
wire        	o_sdram_ras_n;
wire        	o_sdram_we_n;
wire [1:0]  	o_sdram_ba;
wire [12:0] 	o_sdram_addr;
// sdram_auto_refresh outports wire
wire        	o_refresh_request;
wire [3:0]  	o_refresh_cmd;
wire [1:0]  	o_refresh_ba;
wire [12:0] 	o_refresh_addr;
wire        	o_refresh_done;
// sdram_write outports wire
wire [3:0]  	o_wr_cmd;
wire [1:0]  	o_wr_ba;
wire [12:0] 	o_wr_addr;
wire [15:0] 	o_wr_data;
wire        	o_wr_done;
wire        	sdram_wr_dq_oe;
// sdram_read outports wire
wire        	o_rd_ack;
wire [3:0]  	o_rd_cmd;
wire [1:0]  	o_rd_ba;
wire [12:0] 	o_rd_addr;
wire        	o_rd_done;

//初始化模块实例化
sdram_init u_sdram_init(
	.i_sysclk    	( i_sysclk     ),
	.i_sysrst_n  	( i_sysrst_n   ),
	.o_init_cmd  	( o_init_cmd   ),
	.o_init_ba   	( o_init_ba    ),
	.o_init_addr 	( o_init_addr  ),
	.o_init_done 	( o_init_done  )
);

//仲裁模块实例化
sdram_arbiter u_sdram_arbiter(
	.i_sysclk          	( i_sysclk           ),
	.i_sysrst_n        	( i_sysrst_n         ),
	.i_init_cmd        	( o_init_cmd         ),
	.i_init_ba         	( o_init_ba          ),
	.i_init_addr       	( o_init_addr        ),
	.i_init_done       	( o_init_done        ),
	.i_refresh_request 	( o_refresh_request  ),
	.i_refresh_cmd     	( o_refresh_cmd      ),
	.i_refresh_ba      	( o_refresh_ba       ),
	.i_refresh_addr    	( o_refresh_addr     ),
	.i_refresh_done    	( o_refresh_done     ),
	.i_wr_request      	( i_wr_req           ),
	.i_wr_cmd          	( o_wr_cmd           ),
	.i_wr_ba           	( o_wr_ba            ),
	.i_wr_addr         	( o_wr_addr          ),
	.i_wr_data         	( o_wr_data          ),
	.i_wr_done         	( o_wr_done          ),
	.i_wr_sdram_dq_oe  	( wr_sdram_dq_oe   ),
	.i_rd_request      	( i_rd_req           ),
	.i_rd_cmd          	( o_rd_cmd           ),
	.i_rd_ba           	( o_rd_ba            ),
	.i_rd_addr         	( o_rd_addr          ),
	.i_rd_done         	( o_rd_done          ),
	.o_refresh_start   	( o_refresh_start    ),
	.o_write_start     	( o_write_start      ),
	.o_read_start      	( o_read_start       ),
	.o_sdram_cke       	( o_sdram_cke        ),
	.o_sdram_cs_n      	( o_sdram_cs_n       ),
	.o_sdram_cas_n     	( o_sdram_cas_n      ),
	.o_sdram_ras_n     	( o_sdram_ras_n      ),
	.o_sdram_we_n      	( o_sdram_we_n       ),
	.o_sdram_ba        	( o_sdram_ba         ),
	.o_sdram_addr      	( o_sdram_addr       ),
	.sdram_dq          	( sdram_dq           )
);

//自动刷新模块实例化
sdram_auto_refresh u_sdram_auto_refresh(
	.i_sysclk          	( i_sysclk           ),
	.i_sysrst_n        	( i_sysrst_n         ),
	.i_init_done       	( o_init_done        ),
	.i_refresh_start   	( o_refresh_start    ),
	.o_refresh_request 	( o_refresh_request  ),
	.o_refresh_cmd     	( o_refresh_cmd      ),
	.o_refresh_ba      	( o_refresh_ba       ),
	.o_refresh_addr    	( o_refresh_addr     ),
	.o_refresh_done    	( o_refresh_done     )
);

//写模块实例化
sdram_write u_sdram_write(
	.i_sysclk       	( i_sysclk        ),
	.i_sysrst_n     	( i_sysrst_n      ),
	.i_init_done    	( o_init_done     ),
	.i_wr_addr      	( i_wr_addr       ),
	.i_wr_data      	( i_wr_data       ),
	.i_wr_burst_len 	( i_wr_burst_len  ),
	.i_write_start  	( o_write_start   ),
	.o_wr_cmd       	( o_wr_cmd        ),
	.o_wr_ba        	( o_wr_ba         ),
	.o_wr_addr      	( o_wr_addr       ),
	.o_wr_data      	( o_wr_data       ),
	.o_wr_done      	( o_wr_done       ),
	.o_wr_ack       	( o_wr_ack        ),
	.sdram_wr_dq_oe 	( sdram_wr_dq_oe  )
);

//读模块实例化
sdram_read u_sdram_read(
	.i_sysclk       	( i_sysclk        ),
	.i_sysrst_n     	( i_sysrst_n      ),
	.i_init_done    	( o_init_done     ),
	.i_rd_addr      	( i_rd_addr       ),
	.i_rd_data      	( sdram_dq        ),
	.i_rd_burst_len 	( i_rd_burst_len  ),
	.i_read_start   	( o_read_start    ),
	.o_rd_ack       	( o_rd_ack        ),
	.o_rd_cmd       	( o_rd_cmd        ),
	.o_rd_ba        	( o_rd_ba         ),
	.o_rd_addr      	( o_rd_addr       ),
	.o_rd_data      	( o_rd_data       ),
	.o_rd_done      	( o_rd_done       )
);

endmodule