module sdram_auto_refresh
(
        input                           i_sysclk                ,
        input                           i_sysrst_n              ,
        input                           i_init_done             ,
        input                           i_refresh_start         ,
        
        output          reg             o_refresh_request       ,
        output          reg     [3:0]   o_refresh_cmd           ,
        output          reg     [1:0]   o_refresh_ba            ,
        output          reg     [12:0]  o_refresh_addr          ,
        output                          o_refresh_done
);

//reg definitions
reg     [9:0]   r_cnt_auto_ref          ;//SDRAM每隔一段时间就要自动刷新，使用这个计数器对这段时间进行计时
reg             r_auto_ref_ack          ;//i_refresh_start的应答信号，i_refresh_start拉高后，该信号产生一个周期的高电平脉冲，代表接收到开始自动刷新的信号并开始自动刷新
reg     [2:0]   r_auto_ref_state        ;//状态寄存器
reg     [2:0]   r_cnt_sysclk            ;//用来对预充电、自动刷新的等待时间进行计时，因为这些时间恰好是时钟的整数倍，因此直接对时钟进行计数即可
reg             r_cnt_sysclk_rst        ;//r_cnt_sysclk的复位信号，高电平有效
reg     [1:0]   r_cnt_ref_num           ;//对自动刷新次数进行计数

//wire definitions
wire            w_trp_end               ;
wire            w_trfc_end              ;
wire            w_auto_ref_ack          ;//i_refresh_start的应答信号，i_refresh_start拉高后，该信号产生一个周期的高电平脉冲，代表接收到开始自动刷新的信号并开始自动刷新

//parameter definitions
//r_cnt_auto_ref 的计数最大值
localparam      CNT_AUTO_REF_MAX = 10'd749;
//状态定义
//自动刷新初始状态
localparam      AUTO_REF_IDLE    = 3'b000;
//自动刷新预充电状态
localparam      AUTO_REF_PCH     = 3'b001;
//自动刷新预充电等待状态
localparam      AUTO_REF_TRP     = 3'b011;
//自动刷新状态
localparam      AUTO_REF         = 3'b010;
//自动刷新等待状态
localparam      AUTO_REF_TRFC    = 3'b110;
//自动刷新完成状态
localparam      AUTO_REF_DONE    = 3'b111;
//定义等待时间相对于SDRAM时钟周期的倍数
//t_{RP}
localparam       TRP     =       3'd2;
//t_{RFC}
localparam       TRFC    =       3'd7;
//指令编码，并且根据 {CS_N,RAS_N,CAS_N,WE_N} 这四个端口在对应指令下的高低电平进行编码
//NOP指令
localparam       NOP                     =       4'b0111;
//PRECHARGE指令
localparam       PRECHARGE               =       4'b0010;
//AUTO_REFRESH指令
localparam       AUTO_REFRESH            =       4'b0001;

//r_cnt_auto_ref 自动刷新周期
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                r_cnt_auto_ref <= 0;
        else if(r_cnt_auto_ref >= CNT_AUTO_REF_MAX)
                r_cnt_auto_ref <= 0;
        else if(i_init_done)
                r_cnt_auto_ref <= r_cnt_auto_ref + 1;
        else
                r_cnt_auto_ref <= r_cnt_auto_ref;

//o_refresh_request 赋值，每间隔一定时间，向仲裁器发送自动刷新请求
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                o_refresh_request <= 1'b0;
        else if(r_cnt_auto_ref == (CNT_AUTO_REF_MAX - 1))
                o_refresh_request <= 1'b1;
        else if(w_auto_ref_ack == 1'b1)
                o_refresh_request <= 1'b0;
        else
                o_refresh_request <= o_refresh_request;

//r_auto_ref_ack 赋值，
assign  w_auto_ref_ack = (r_auto_ref_state == AUTO_REF_PCH) ? 1'b1 : 1'b0;

//状态机-状态转换逻辑
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                r_auto_ref_state <= AUTO_REF_IDLE;
        else
                case(r_auto_ref_state)
                        AUTO_REF_IDLE:
                                if((i_init_done) && (i_refresh_start))
                                        r_auto_ref_state <= AUTO_REF_PCH;
                                else
                                        r_auto_ref_state <= r_auto_ref_state;
                        AUTO_REF_PCH :
                                r_auto_ref_state <= AUTO_REF_TRP;
                        AUTO_REF_TRP :
                                if(w_trp_end)
                                        r_auto_ref_state <= AUTO_REF;
                                else
                                        r_auto_ref_state <= r_auto_ref_state;
                        AUTO_REF     :
                                r_auto_ref_state <= AUTO_REF_TRFC;
                        AUTO_REF_TRFC:
                                if((w_trfc_end) && (r_cnt_ref_num == 2'd2))
                                        r_auto_ref_state <= AUTO_REF_DONE;
                                else if(w_trfc_end)
                                        r_auto_ref_state <= AUTO_REF;
                                else
                                        r_auto_ref_state <= r_auto_ref_state;
                        AUTO_REF_DONE:
                                r_auto_ref_state <= AUTO_REF_IDLE;
                        default      :
                                r_auto_ref_state <= AUTO_REF_IDLE;
                endcase

//r_cnt_sysclk计数器
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                r_cnt_sysclk <= 3'd0;
        else if(r_cnt_sysclk_rst)//高电平有效的复位信号
                r_cnt_sysclk <= 3'd0;
        else
                r_cnt_sysclk <= r_cnt_sysclk + 1;

//r_cnt_sysclk_rst
always @(*)
        begin
                case(r_auto_ref_state)
                        AUTO_REF_IDLE:
                                r_cnt_sysclk_rst = 1'b1;
                        AUTO_REF_TRP:
                                r_cnt_sysclk_rst = (w_trp_end) ? 1'b1 : 1'b0;
                        AUTO_REF_TRFC:
                                r_cnt_sysclk_rst = (w_trfc_end) ? 1'b1 : 1'b0;
                        AUTO_REF_DONE:
                                r_cnt_sysclk_rst = 1'b1;
                        default:
                                r_cnt_sysclk_rst = 1'b0;
                endcase
        end

//等待时间逻辑
assign  w_trp_end  = ((r_auto_ref_state == AUTO_REF_TRP) && (r_cnt_sysclk == TRP)) ? 1'b1 : 1'b0;       //w_trp_end 只能在 INIT_TRP 状态被拉高
assign  w_trfc_end = ((r_auto_ref_state == AUTO_REF_TRFC) && (r_cnt_sysclk == TRFC)) ? 1'b1 : 1'b0;     //w_trfc_end 只能在 INIT_TRFC 状态被拉高

//用于记录自动刷新次数的计数器r_cnt_auto_refresh
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                r_cnt_ref_num <= 2'd0;
        else if(r_auto_ref_state <= AUTO_REF_IDLE)
                r_cnt_ref_num <= 2'd0;
        else if(r_auto_ref_state <= AUTO_REF)
                r_cnt_ref_num <= r_cnt_ref_num + 1;
        else
                r_cnt_ref_num <= r_cnt_ref_num;

//状态机-输出逻辑
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                begin
                        o_refresh_cmd  <= NOP;
                        o_refresh_ba   <= 2'b11;
                        o_refresh_addr <= 13'h1fff;
                end
        else
                case (r_auto_ref_state)
                        AUTO_REF_IDLE,AUTO_REF_TRP,AUTO_REF_TRFC:
                                begin
                                        o_refresh_cmd  <= NOP;
                                        o_refresh_ba   <= 2'b11;
                                        o_refresh_addr <= 13'h1fff;
                                end
                        AUTO_REF_PCH:
                                begin
                                        o_refresh_cmd  <= PRECHARGE;
                                        o_refresh_ba   <= 2'b11;
                                        o_refresh_addr <= 13'h1fff;
                                end
                        AUTO_REF:
                                begin
                                        o_refresh_cmd  <= AUTO_REFRESH;
                                        o_refresh_ba   <= 2'b11;
                                        o_refresh_addr <= 13'h1fff;
                                end
                        AUTO_REF_DONE:
                                begin
                                        o_refresh_cmd  <= NOP;
                                        o_refresh_ba   <= 2'b11;
                                        o_refresh_addr <= 13'h1fff;
                                end
                        default:
                                begin
                                        o_refresh_cmd  <= NOP;
                                        o_refresh_ba   <= 2'b11;
                                        o_refresh_addr <= 13'h1fff;
                                end
                endcase

//o_refresh_done 赋值
assign  o_refresh_done = (r_auto_ref_state <= AUTO_REF_DONE) ? 1'b1 : 1'b0;

endmodule