module sdram_init
(
        input           i_sysclk        ,//SDRAM时钟，100MHz
        input           i_sysrst_n      ,//复位

        output  [3:0]   o_init_cmd      ,//输出指令序列
        output  [1:0]   o_init_ba       ,//输出bank地址
        output  [12:0]  o_init_addr     ,//输出行、列地址
        output          o_init_done      //握手信号，标志初始化完成
);

//wire definitions
wire            w_wait_200us_end        ;//等待200us结束信号
wire            w_trp_end               ;//预充电等待状态结束的标志信号t_{RP}
wire            w_trfc_end              ;//自动刷新等地啊状态结束的标志信号t_{RFC}
wire            w_tmrd_end              ;//模式寄存器配置等待状态结束的标志信号t_{MRD}

//reg definitions
reg     [2:0]   r_init_state            ;//状态寄存器
reg     [14:0]  r_cnt_200us             ;//定时200us的寄存器
reg     [2:0]   r_cnt_sysclk            ;//用来对预充电、自动刷新、模式寄存器配置的等待时间进行计时，因为这些时间恰好是时钟的整数倍，因此直接对时钟进行计数即可
reg             r_cnt_sysclk_rst        ;//r_cnt_sysclk的复位信号，高电平有效
reg             r_cnt_auto_refresh      ;//记录自动刷新的次数
reg             r_init_cmd              ;//输出指令序列
reg             r_init_ba               ;//输出bank地址
reg             r_init_addr             ;//输出行、列地址

//parameter definitions
//使用 grey 码进行状态编码
//初始状态
parameter       INIT_IDLE               =       3'b000,
                INIT_PRE_CHARGE         =       3'b001,//预充电状态
                INIT_TRP                =       3'b011,//预充电等待状态
                INIT_AUTO_REFRESH       =       3'b010,//自动刷新状态
                INIT_TRFC               =       3'b110,//自动刷新等待状态
                INIT_LOAD_MODE_REGISTER =       3'b111,//模式寄存器配置状态
                INIT_TMRD               =       3'b101,//模式寄存器配置等待状态
                INIT_DONE               =       3'b100;//初始化完成状态
//r_cnt_200us的计数最大值
parameter       WAIT_200US_MAX  =       20_000;
//定义等待时间相对于SDRAM时钟周期的倍数
//t_{RP}
parameter       TRP     =       3'd2;
//t_{RFC}
parameter       TRFC    =       3'd7;
//t_{MRD}
parameter       TMRD    =       3'd3;
//指令编码，并且根据 {CS_N,RAS_N,CAS_N,WE_N} 这四个端口在对应指令下的高低电平进行编码
//NOP指令
parameter       NOP                     =       4'b0111;
//PRECHARGE指令
parameter       PRECHARGE               =       4'b0010;
//AUTO_REFRESH指令
parameter       AUTO_REFRESH            =       4'b0001;
//LOAD_MODE_REGISTER指令
parameter       LOAD_MODE_REGISTER      =       4'b0000;

//状态机-状态转移
always @(posedge i_sysclk or negedge i_sysrst_n)
        begin
                if(!i_sysrst_n)
                        begin
                                r_init_state <= INIT_IDLE;
                        end
                else
                        begin
                                case (r_init_state)
                                        INIT_IDLE:
                                                begin
                                                        if(w_wait_200us_end)
                                                                begin
                                                                        r_init_state <= INIT_IDLE;
                                                                end
                                                        else
                                                                begin
                                                                        r_init_state <= INIT_PRE_CHARGE;
                                                                end
                                                end
                                        INIT_PRE_CHARGE:
                                                begin
                                                        r_init_state <= INIT_TRP;
                                                end
                                        INIT_TRP:
                                                begin
                                                        if(w_trp_end)
                                                                begin
                                                                        r_init_state <= INIT_AUTO_REFRESH;
                                                                end
                                                        else
                                                                begin
                                                                        r_init_state <= r_init_state;
                                                                end
                                                end
                                        INIT_AUTO_REFRESH:
                                                begin
                                                        r_init_state <= INIT_TRFC;
                                                end
                                        INIT_TRFC:
                                                begin
                                                        if((w_trfc_end == 1'b1) && (r_cnt_auto_refresh == 4'd8))
                                                                begin
                                                                        r_init_state <= INIT_LOAD_MODE_REGISTER;
                                                                end
                                                        else if(w_trfc_end == 1'b1)
                                                                begin
                                                                        r_init_state <= INIT_AUTO_REFRESH;
                                                                end
                                                        else
                                                                begin
                                                                        r_init_state <= r_init_state;
                                                                end
                                                end
                                        INIT_LOAD_MODE_REGISTER:
                                                begin
                                                        r_init_state <= INIT_TMRD;
                                                end
                                        INIT_TMRD:
                                                begin
                                                        if(w_tmrd_end)
                                                                begin
                                                                        r_init_state <= INIT_DONE;
                                                                end
                                                        else
                                                                begin
                                                                        r_init_state <= r_init_state;
                                                                end
                                                end
                                        INIT_DONE:
                                                begin
                                                        r_init_state <= INIT_DONE;
                                                end
                                        default:
                                                begin
                                                        r_init_state <= INIT_IDLE;
                                                end
                                endcase
                        end
        end

//计时200us计数器
always @(posedge i_sysclk or negedge i_sysrst_n)
        begin
                if(!i_sysrst_n)
                        begin
                                r_cnt_200us <= 15'd0;
                        end
                else if(r_cnt_200us == WAIT_200US_MAX)
                        begin
                                r_cnt_200us <= WAIT_200US_MAX;
                        end
                else
                        begin
                                r_cnt_200us <= r_cnt_200us + 1;
                        end
        end

//等待200us结束信号
assign  w_wait_200us_end = (r_cnt_200us == (WAIT_200US_MAX - 1)) ? 1'b1 : 1'b0;

//r_cnt_sysclk计数器
always @(posedge i_sysclk or negedge i_sysrst_n)
        begin
                if(!i_sysrst_n)
                        begin
                                r_cnt_sysclk <= 3'd0;
                        end
                else if(r_cnt_sysclk_rst)
                        begin
                                r_cnt_sysclk <= 3'd0;
                        end
                else
                        begin
                                r_cnt_sysclk <= r_cnt_sysclk + 1;
                        end
        end

//r_cnt_sysclk_rst
always @(*)
        begin
                case(r_init_state)
                        INIT_IDLE:
                                begin
                                        r_cnt_sysclk_rst = 1'b1;
                                end
                        INIT_TRP:
                                begin
                                        r_cnt_sysclk_rst = (w_trp_end) ? 1'b1 : 1'b0;
                                end
                        INIT_TRFC:
                                begin
                                        r_cnt_sysclk_rst = (w_trfc_end) ? 1'b1 : 1'b0;
                                end
                        INIT_TMRD:
                                begin
                                        r_cnt_sysclk_rst = (w_tmrd_end) ? 1'b1 : 1'b0;
                                end
                        INIT_DONE:
                                begin
                                        r_cnt_sysclk_rst = 1'b1;
                                end
                        default:
                                begin
                                        r_cnt_sysclk_rst = 1'b0;
                                end
                endcase
        end

//等待时间逻辑
assign  w_trp_end  = (r_cnt_sysclk == TRP) ? 1'b1 : 1'b0;
assign  w_trfc_end = (r_cnt_sysclk == TRFC) ? 1'b1 : 1'b0;
assign  w_tmrd_end = (r_cnt_sysclk == TMRD) ? 1'b1 : 1'b0;

//用于记录自动刷新次数的计数器r_cnt_auto_refresh
always @(posedge i_sysclk or negedge i_sysrst_n)
        begin
                if(!i_sysrst_n)
                        begin
                                r_cnt_auto_refresh <= 4'd0;
                        end
                else if(r_init_state == INIT_IDLE)
                        begin
                                r_cnt_auto_refresh <= 4'd0;
                        end
                else if(r_init_state == INIT_AUTO_REFRESH)
                        begin
                                r_cnt_auto_refresh <= r_cnt_auto_refresh + 1;
                        end
                else
                        begin
                                r_cnt_auto_refresh <= r_cnt_auto_refresh;
                        end
        end

//状态机-输出
always @(posedge i_sysclk or negedge i_sysrst_n)
        begin
                if(!i_sysrst_n)
                        begin
                                r_init_cmd  <= NOP;
                                r_init_ba   <= 2'b11;
                                r_init_addr <= 13'h1fff;
                        end
                else
                        begin
                                case (r_init_state)
                                        INIT_IDLE,INIT_TRP,INIT_TRFC,INIT_TMRD,INIT_DONE:
                                                begin
                                                        r_init_cmd  <= NOP;
                                                        r_init_ba   <= 2'b11;
                                                        r_init_addr <= 13'h1fff;
                                                end
                                        INIT_PRE_CHARGE:
                                                begin
                                                        r_init_cmd  <= PRECHARGE;
                                                        r_init_ba   <= 2'b11;
                                                        r_init_addr <= 13'h1fff;
                                                end
                                        INIT_AUTO_REFRESH:
                                                begin
                                                        r_init_cmd  <= AUTO_REFRESH;
                                                        r_init_ba   <= 2'b11;
                                                        r_init_addr <= 13'h1fff;
                                                end
                                        INIT_LOAD_MODE_REGISTER:
                                                begin
                                                        r_init_cmd  <= LOAD_MODE_REGISTER;
                                                        r_init_ba   <= 2'b00;
                                                        r_init_addr <= {3'b0,1'b0,2'b0,3'b011,1'b0,3'b111};
                                                end
                                        default:
                                                begin
                                                        r_init_cmd  <= NOP;
                                                        r_init_ba   <= 2'b11;
                                                        r_init_addr <= 13'h1fff;
                                                end
                                endcase
                        end
        end

//将输出端口与寄存器连接
assign        o_init_cmd      =       r_init_cmd        ;
assign        o_init_ba       =       r_init_ba         ;
assign        o_init_addr     =       r_init_addr       ;

//o_init_done
assign  o_init_done     =       (r_init_state == INIT_DONE) ? 1'b1 : 1'b0;

endmodule