module sdram_write
(
        input                                   i_sysclk                ,
        input                                   i_sysrst_n              ,
        input                                   i_init_done             ,
        input                   [23:0]          i_wr_addr               ,//24位的地址，包括2位的Bank地址、13位的行地址和9位的列地址
        input                   [15:0]          i_wr_data               ,
        input                   [9:0]           i_wr_burst_len          ,
        input                                   i_write_start           ,

        output          reg     [3:0]           o_wr_cmd                ,
        output          reg     [1:0]           o_wr_ba                 ,
        output          reg     [12:0]          o_wr_addr               ,
        output                  [15:0]          o_wr_data               ,
        output                                  o_wr_done               ,
        output                                  o_wr_ack                ,
        output          reg                     sdram_wr_dq_oe
);

//reg definitions
reg     [2:0]   r_wr_state              ;//状态寄存器
reg     [9:0]   r_cnt_sysclk            ;//用来对写操作的等待时间进行计时，因为这些时间恰好是时钟的整数倍，因此直接对时钟进行计数即可
reg             r_cnt_sysclk_rst        ;//r_cnt_sysclk的复位信号，高电平有效

//wire definitions
wire            w_trp_end               ;//t_{RP}等待结束信号
wire            w_trcd_end              ;//t_{RCD}等待结束信号
wire            w_twr_end               ;//t_{WR}等待结束信号，写入 10 个数据后拉高该信号

//parameter definitions
//状态定义
//写操作初始状态
localparam      WR_IDLE         = 3'b000;
//写操作预充电状态
localparam      WR_PCH          = 3'b111;
//写操作预充电等待状态
localparam      WR_TRP          = 3'b101;
//写操作激活状态
localparam      WR_ACTIVE       = 3'b001;
//写操作激活等待状态
localparam      WR_TRCD         = 3'b011;
//写操作写指令写入状态
localparam      WRITE           = 3'b010;
//写操作写等待状态：该状态等待数据写入SDRAM
localparam      WR_DATA         = 3'b110;
//写操作完成状态
localparam      WR_DONE         = 3'b100;
//定义等待时间相对于SDRAM时钟周期的倍数
//t_{RP}
localparam       TRP     =       'd2;
//t_{RCD}
localparam       TRCD    =       'd2;
//指令编码，并且根据 {CS_N,RAS_N,CAS_N,WE_N} 这四个端口在对应指令下的高低电平进行编码
//NOP指令
localparam       NOP                     =       4'b0111;
//PRECHARGE指令
localparam       PRECHARGE               =       4'b0010;
//ACTIVE指令
localparam       ACTIVE                  =       4'b0011;
//WRITE指令
localparam       WRITE_CMD               =       4'b0100;
//BURST_TERMINATE指令
localparam       BURST_TERMINATE         =       4'b0110;

//状态机-状态转移
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                r_wr_state <= WR_IDLE;
        else
                case(r_wr_state)
                        WR_IDLE:
                                if((i_init_done) && (i_write_start))
                                        r_wr_state <= WR_ACTIVE;
                                else
                                        r_wr_state <= WR_IDLE;
                        WR_ACTIVE://根据时序图，激活状态只持续一个时钟周期
                                r_wr_state <= WR_TRCD;
                        WR_TRCD:
                                if(w_trcd_end)
                                        r_wr_state <= WRITE;
                                else
                                        r_wr_state <= WR_TRCD;
                        WRITE://写指令写入状态，同样只持续一个时钟周期
                                r_wr_state <= WR_DATA;
                        WR_DATA:
                                if(w_twr_end)
                                        r_wr_state <= WR_PCH;
                                else
                                        r_wr_state <= WR_DATA;
                        WR_PCH:
                                r_wr_state <= WR_TRP;
                        WR_TRP:
                                if(w_trp_end)
                                        r_wr_state <= WR_DONE;
                                else
                                        r_wr_state <= WR_TRP;
                        WR_DONE:
                                r_wr_state <= WR_IDLE;
                        default:
                                r_wr_state <= WR_IDLE;
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
                case(r_wr_state)
                        WR_IDLE:
                                r_cnt_sysclk_rst = 1'b1;
                        WR_TRCD:
                                r_cnt_sysclk_rst = (w_trcd_end) ? 1'b1 : 1'b0;
                        WRITE:
                                r_cnt_sysclk_rst = 1'b1;
                        WR_DATA:
                                r_cnt_sysclk_rst = (w_twr_end) ? 1'b1 : 1'b0;
                        WR_PCH:
                                r_cnt_sysclk_rst = (w_trp_end) ? 1'b1 : 1'b0;
                        WR_DONE:
                                r_cnt_sysclk_rst = 1'b1;
                        default:
                                r_cnt_sysclk_rst = 1'b0;
                endcase
        end

//等待时间逻辑
assign  w_trp_end  = ((r_wr_state == WR_TRP) && (r_cnt_sysclk == TRP)) ? 1'b1 : 1'b0;                   //w_trp_end 只能在 WR_TRP 状态被拉高
assign  w_trcd_end = ((r_wr_state == WR_TRCD) && (r_cnt_sysclk == TRCD)) ? 1'b1 : 1'b0;                 //w_trcd_end 只能在 WR_TRCD 状态被拉高
assign  w_twr_end  = ((r_wr_state == WR_DATA) && (r_cnt_sysclk == i_wr_burst_len - 1)) ? 1'b1 : 1'b0;   //w_twr_end 只能在 WR_DATA 状态被拉高，并且必须在写入 10 个数据后被拉高

//状态机-输出逻辑
//r_wr_cmd,r_wr_ba,r_wr_addr
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                begin
                        o_wr_cmd  <= NOP;
                        o_wr_ba   <= 2'b11;
                        o_wr_addr <= 13'h1fff;
                end
        else
                case(r_wr_state)
                        WR_IDLE,WR_TRCD,WR_TRP:
                                begin
                                        o_wr_cmd  <= NOP;
                                        o_wr_ba   <= 2'b11;
                                        o_wr_addr <= 13'h1fff;
                                end
                        WR_ACTIVE:
                                begin
                                        o_wr_cmd  <= ACTIVE;
                                        o_wr_ba   <= i_wr_addr[23:22];//2位Bank地址
                                        o_wr_addr <= i_wr_addr[21:9];//13位行地址
                                end
                        WRITE:
                                begin
                                        o_wr_cmd  <= WRITE_CMD;
                                        o_wr_ba   <= i_wr_addr[23:22];//2位Bank地址
                                        o_wr_addr <= {4'b0000,i_wr_addr[8:0]};//列地址只有 9 位，因此需要在前面补 4 个 0，使得地址总长度为 13 位
                                end
                        WR_DATA:
                                if(w_twr_end)//写入 10 个数据后，需要发送终止指令。SDRAM没有突发长度为 10 的选择，因此使用页突发模式，然后在写入 10 个数据后发送突发终止指令，达到写入10个数据的目的
                                        o_wr_cmd  <= BURST_TERMINATE;
                                else//使用的是突出写入模式，因此只需要给首地址，后续地址会自动递增，则在这里的r_wr_ba和r_wr_addr均是全 1
                                        begin
                                                o_wr_cmd  <= NOP;
                                                o_wr_ba   <= 2'b11;
                                                o_wr_addr <= 13'h1fff;
                                        end
                        WR_PCH:
                                begin
                                        o_wr_cmd  <= PRECHARGE;
                                        o_wr_ba   <= i_wr_addr[23:22];
                                        o_wr_addr <= 13'h0400;//将 A10 位设置为 1，表示对所有的 Bank 预充电
                                end
                        WR_DONE:
                                begin
                                        o_wr_cmd  <= NOP;
                                        o_wr_ba   <= 2'b11;
                                        o_wr_addr <= 13'h1fff;
                                end
                        default:
                                begin
                                        o_wr_cmd  <= NOP;
                                        o_wr_ba   <= 2'b11;
                                        o_wr_addr <= 13'h1fff;
                                end
                endcase
//写响应信号
assign  o_wr_ack        = ((r_wr_state == WRITE) || ((r_wr_state == WR_DATA) && (r_cnt_sysclk <= i_wr_burst_len - 2))) ? 1'b1 : 1'b0;
//写完成信号
assign  o_wr_done       = (r_wr_state == WR_DONE) ? 1'b1 : 1'b0;
//sdram_wr_dq_oe，控制三态门的使能信号
///sdram_wr_dq_oe 恰好滞后 o_wr_ack 信号一个时钟周期，因此直接使用一个寄存器即可
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                sdram_wr_dq_oe <= 1'b0;
        else
                sdram_wr_dq_oe <= o_wr_ack;

//o_wr_data，由于要根据 sdram_wr_dq_oe 信号控制数据的输出，因此使用组合逻辑，这样才是同步的
assign  o_wr_data       = (sdram_wr_dq_oe) ? i_wr_data : 16'd0;

endmodule