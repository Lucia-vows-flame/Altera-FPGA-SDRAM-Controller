module sdram_read
(
        input                                   i_sysclk                ,
        input                                   i_sysrst_n              ,
        input                                   i_init_done             ,
        input                   [23:0]          i_rd_addr               ,
        input                   [15:0]          i_rd_data               ,
        input                   [9:0]           i_rd_burst_len          ,
        input                                   i_read_start            ,

        output                                  o_rd_ack                ,
        output          reg     [3:0]           o_rd_cmd                ,
        output          reg     [1:0]           o_rd_ba                 ,
        output          reg     [12:0]          o_rd_addr               ,
        output                  [15:0]          o_rd_data               ,
        output                                  o_rd_done
);

//reg definitions
reg     [15:0]      r_rd_data       ;
/*
寄存从SDRAM中读出的数据，因为SDRAM属于sdram_clk=100MHz_shift时钟域，而SDRAM控制器属于i_sysclk=100MHz时钟域，
因此需要使用一个寄存器进行跨时钟域处理，将i_rd_data同步到i_sysclk时钟域。这里只是简单的同步，没有进行跨时钟域处理，
因为sdram_clk与i_sysclk仅仅只有相位不同，因此一个寄存器同步足矣
*/
reg     [3:0]           r_rd_state      ;//状态寄存器
reg     [9:0]           r_cnt_sysclk    ;//用来对读操作的等待时间进行计时，因为这些时间恰好是时钟的整数倍，因此直接对时钟进行计数即可
reg                     r_cnt_sysclk_rst;//r_cnt_sysclk的复位信号，高电平有效

//wire definitions
wire                    w_trcd_end              ;//t_{RCD}，激活等待结束信号
wire                    w_trp_end               ;//t_{RP}，预充电等待结束信号
wire                    w_tcl_end               ;//t_{CL}，潜伏期等待结束信号
wire                    w_trd_end               ;//t_{RD}，读数据等待结束信号
wire                    r_rd_bstop_flag         ;//突发停止的标志信号，当该信号为高电平时，在下一个时钟周期突发停止

//parameter definitions
//状态定义
//读操作初始状态
localparam      RD_IDLE         = 4'b0000;
//读操作激活状态
localparam      RD_ACTIVE       = 4'b0001;
//读操作激活等待状态
localparam      RD_TRCD         = 4'b0011;
//读操作读状态
localparam      READ            = 4'b0010;
//读操作潜伏期等待状态，潜伏期时长已经在初始化时设置为 3 个时钟周期
localparam      RD_CL           = 4'b0110;
//读操作读数据状态
localparam      RD_DATA         = 4'b0111;
//读操作预充电状态
localparam      RD_PCH          = 4'b0101;
//读操作预充电等待状态
localparam      RD_TRP          = 4'b0100;
//读操作完成状态
localparam      RD_DONE         = 4'b1000;
//定义等待时间相对于SDRAM时钟周期的倍数
//t_{RP}
localparam       TRP     =       'd2;
//t_{RCD}
localparam       TRCD    =       'd2;
//t_{CL}
localparam       TCL     =       'd3;
//指令编码，并且根据 {CS_N,RAS_N,CAS_N,WE_N} 这四个端口在对应指令下的高低电平进行编码
//NOP指令
localparam       NOP                     =       4'b0111;
//PRECHARGE指令
localparam       PRECHARGE               =       4'b0010;
//ACTIVE指令
localparam       ACTIVE                  =       4'b0011;
//WRITE指令
localparam       READ_CMD                =       4'b0101;
//BURST_TERMINATE指令
localparam       BURST_TERMINATE         =       4'b0110;

//数据同步
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                r_rd_data <= 16'd0;
        else
                r_rd_data <= i_rd_data;

//状态机-状态转移
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                r_rd_state <= RD_IDLE;
        else
                case(r_rd_state)
                        RD_IDLE:
                                r_rd_state <= ((i_init_done) && (i_read_start)) ? RD_ACTIVE : RD_IDLE;
                        RD_ACTIVE://根据时序图，激活状态只持续一个时钟周期
                                r_rd_state <= RD_TRCD;
                        RD_TRCD:
                                r_rd_state <= (w_trcd_end) ? READ : RD_TRCD; 
                        READ://写指令写入状态，同样只持续一个时钟周期
                                r_rd_state <= RD_CL;
                        RD_CL:
                                r_rd_state <= (w_tcl_end) ? RD_DATA : RD_CL;
                        RD_DATA:
                                r_rd_state <= (w_trd_end) ? RD_PCH  : RD_CL;
                        RD_PCH:
                                r_rd_state <= RD_TRP;
                        RD_TRP:
                                r_rd_state <= (w_trp_end) ? RD_DONE : RD_TRP;
                        RD_DONE:
                                r_rd_state <= RD_IDLE;
                        default:
                                r_rd_state <= RD_IDLE;
                endcase

//r_cnt_sysclk计数器
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                r_cnt_sysclk <= 10'd0;
        else if(r_cnt_sysclk_rst)//高电平有效的复位信号
                r_cnt_sysclk <= 10'd0;
        else
                r_cnt_sysclk <= r_cnt_sysclk + 1;

//r_cnt_sysclk_rst
always @(*)
        begin
                case(r_rd_state)
                        RD_IDLE:
                                r_cnt_sysclk_rst = 1'b1;
                        RD_TRCD:
                                r_cnt_sysclk_rst = (w_trcd_end) ? 1'b1 : 1'b0;
                        READ:
                                r_cnt_sysclk_rst = 1'b1;
                        RD_CL:
                                r_cnt_sysclk_rst = (w_tcl_end) ? 1'b1 : 1'b0;
                        RD_DATA:
                                r_cnt_sysclk_rst = (w_trd_end) ? 1'b1 : 1'b0;
                        RD_PCH:
                                r_cnt_sysclk_rst = (w_trp_end) ? 1'b1 : 1'b0;
                        RD_DONE:
                                r_cnt_sysclk_rst = 1'b1;
                        default:
                                r_cnt_sysclk_rst = 1'b0;
                endcase
        end

//等待时间逻辑
assign  w_trp_end  = ((r_rd_state == RD_TRP)  && (r_cnt_sysclk == TRP)) ? 1'b1 : 1'b0;                  //w_trp_end 只能在 RD_TRP 状态被拉高
assign  w_trcd_end = ((r_rd_state == RD_TRCD) && (r_cnt_sysclk == TRCD)) ? 1'b1 : 1'b0;                 //w_trcd_end 只能在 RD_TRCD 状态被拉高
assign  w_twr_end  = ((r_rd_state == RD_DATA) && (r_cnt_sysclk == i_rd_burst_len - 1 + TCL)) ? 1'b1 : 1'b0;   //w_twr_end 只能在 RD_DATA 状态被拉高，并且必须在读出 10 个数据后被拉高
assign  w_tcl_end  = ((r_rd_state == RD_CL)   && (r_cnt_sysclk == TCL - 1)) ? 1'b1 : 1'b0;                 //w_tcl_end 只能在 RD_CL 状态被拉高，并且必须在潜伏期结束后被拉高
//r_rd_bstop_flag
assign  r_rd_bstop_flag = ((r_rd_state == RD_DATA) && (r_cnt_sysclk == (i_rd_burst_len - 1 - TCL))) ? 1'b1 : 1'b0;                                        //r_rd_bstop_flag 只能在 RD_DATA 状态被拉高

//状态机-输出逻辑
//o_rd_ack
assign  o_rd_ack = ((r_rd_state == RD_DATA) && (r_cnt_sysclk >= 1) && (r_cnt_sysclk <= i_rd_burst_len)) ? 1'b1 : 1'b0;
//o_rd_done
assign  o_rd_done = (r_rd_state == RD_DONE) ? 1'b1 : 1'b0;
//o_rd_cmd, o_rd_ba, o_rd_addr
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                begin
                        o_rd_cmd  <= NOP;
                        o_rd_ba   <= 2'b11;
                        o_rd_addr <= 13'h1fff;
                end
        else
                case(r_rd_state)
                        RD_IDLE,RD_TRCD,RD_TRP:
                                begin
                                        o_rd_cmd  <= NOP;
                                        o_rd_ba   <= 2'b11;
                                        o_rd_addr <= 13'h1fff;
                                end
                        RD_ACTIVE:
                                begin
                                        o_rd_cmd  <= ACTIVE;
                                        o_rd_ba   <= i_rd_addr[23:22];//2位Bank地址
                                        o_rd_addr <= i_rd_addr[21:9];//13位行地址
                                end
                        READ:
                                begin
                                        o_rd_cmd  <= READ_CMD;
                                        o_rd_ba   <= i_rd_addr[23:22];//2位Bank地址
                                        o_rd_addr <= {4'b0000,i_rd_addr[8:0]};//列地址只有 9 位，因此需要在前面补 4 个 0，使得地址总长度为 13 位
                                end
                        RD_DATA:
                                if(w_twr_end)//读出 10 个数据后，需要发送终止指令。SDRAM没有突发长度为 10 的选择，因此使用页突发模式，然后在读出 10 个数据后发送突发终止指令，达到读出10个数据的目的
                                        o_rd_cmd  <= BURST_TERMINATE;
                                else//使用的是突出写入模式，因此只需要给首地址，后续地址会自动递增，换句话说，这里的 r_wr_ba和r_wr_addr 信号完全不用管，因此 r_wr_ba和r_wr_addr 均是全 1
                                        begin
                                                o_rd_cmd  <= NOP;
                                                o_rd_ba   <= 2'b11;
                                                o_rd_addr <= 13'h1fff;
                                        end
                        RD_PCH:
                                begin
                                        o_rd_cmd  <= PRECHARGE;
                                        o_rd_ba   <= i_rd_addr[23:22];
                                        o_rd_addr <= 13'h0400;//将 A10 位设置为 1，表示对所有的 Bank 预充电
                                end
                        RD_DONE:
                                begin
                                        o_rd_cmd  <= NOP;
                                        o_rd_ba   <= 2'b11;
                                        o_rd_addr <= 13'h1fff;
                                end
                        default://潜伏状态 RD_CL 包含在 default 中
                                begin
                                        o_rd_cmd  <= NOP;
                                        o_rd_ba   <= 2'b11;
                                        o_rd_addr <= 13'h1fff;
                                end
                endcase
//o_rd_data
assign  o_rd_data = (o_rd_ack) ? r_rd_data : 16'd0;

endmodule