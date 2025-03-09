module sdram_arbiter
(
        //时钟、复位
        input                           i_sysclk                ,
        input                           i_sysrst_n              ,
        //sdram_init
        input                   [3:0]   i_init_cmd              ,
        input                   [1:0]   i_init_ba               ,
        input                   [12:0]  i_init_addr             ,
        input                           i_init_done             ,
        //sdram_auto_refresh
        input                           i_refresh_request       ,
        input                   [3:0]   i_refresh_cmd           ,
        input                   [1:0]   i_refresh_ba            ,
        input                   [12:0]  i_refresh_addr          ,
        input                           i_refresh_done          ,
        //sdram_write
        input                           i_wr_request            ,
        input                   [3:0]   i_wr_cmd                ,
        input                   [1:0]   i_wr_ba                 ,
        input                   [12:0]  i_wr_addr               ,
        input                   [15:0]  i_wr_data               ,
        input                           i_wr_done               ,
        input                           i_wr_sdram_dq_oe        ,
        //sdram_read
        input                           i_rd_request            ,
        input                   [3:0]   i_rd_cmd                ,
        input                   [1:0]   i_rd_ba                 ,
        input                   [12:0]  i_rd_addr               ,
        input                           i_rd_done               ,
        
        output          reg             o_refresh_start         ,
        output          reg             o_write_start           ,
        output          reg             o_read_start            ,
        
        output                          o_sdram_cke             ,
        output                          o_sdram_cs_n            ,
        output                          o_sdram_cas_n           ,
        output                          o_sdram_ras_n           ,
        output                          o_sdram_we_n            ,
        output          reg     [1:0]   o_sdram_ba              ,
        output          reg     [12:0]  o_sdram_addr            ,
        inout                   [15:0]  sdram_dq
);

//reg definitions
reg     [2:0]   r_arb_state              ;//状态寄存器
reg     [3:0]   sdram_cmd                ;//SDRAM指令

//parameter definitions
//状态定义
//初始化状态
localparam              IDLE        = 5'b00001;
//仲裁状态
localparam              ARBIT       = 5'b00010;
//自动刷新状态
localparam              AREF        = 5'b00100;
//写状态
localparam              WRITE       = 5'b01000;
//读状态
localparam              READ        = 5'b10000;
//空操作指令定义
localparam              NOP         = 4'b0111;

//状态机-状态转移
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                r_arb_state <= IDLE;
        else
                case (r_arb_state)
                        IDLE://初始化完成后，进入仲裁状态
                                r_arb_state <= (i_init_done) ? ARBIT : IDLE;
                        ARBIT://仲裁状态，仲裁器根据请求的优先级进行仲裁，优先级：自动刷新 > 写 > 读，由于 if-else if-else 语句具有优先级，因此直接使用 if-else if-else 语句进行仲裁
                                if(i_refresh_request)
                                        r_arb_state <= AREF;
                                else if(i_wr_request)
                                        r_arb_state <= WRITE;
                                else if(i_rd_request)
                                        r_arb_state <= READ;
                                else
                                        r_arb_state <= ARBIT;
                        AREF:
                                r_arb_state <= (i_refresh_done) ? ARBIT : AREF;
                        WRITE:
                                r_arb_state <= (i_wr_done) ? ARBIT : WRITE;
                        READ:
                                r_arb_state <= (i_rd_done) ? ARBIT : READ;
                        default:
                                r_arb_state <= IDLE;
                endcase

//状态机-输出
//sdram_cmd、o_sdram_ba、o_sdram_addr的赋值
always @(*)
        case(r_arb_state)
                IDLE:
                        begin
                                sdram_cmd       = i_init_cmd;
                                o_sdram_ba      = i_init_ba;
                                o_sdram_addr    = i_init_addr;
                        end
                AREF:
                        begin
                                sdram_cmd       = i_refresh_cmd;
                                o_sdram_ba      = i_refresh_ba;
                                o_sdram_addr    = i_refresh_addr;
                        end
                WRITE:
                        begin
                                sdram_cmd       = i_wr_cmd;
                                o_sdram_ba      = i_wr_ba;
                                o_sdram_addr    = i_wr_addr;
                        end
                READ:
                        begin
                                sdram_cmd       = i_rd_cmd;
                                o_sdram_ba      = i_rd_ba;
                                o_sdram_addr    = i_rd_addr;
                        end
                default://ARBIT状态包括在内
                        begin
                                sdram_cmd       = NOP;
                                o_sdram_ba      = 2'b11;
                                o_sdram_addr    = 13'h1fff;
                        end
        endcase
//o_refresh_start
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                o_refresh_start <= 1'b0;
        else if((r_arb_state == AREF) && (i_refresh_request))
                o_refresh_start <= 1'b1;
        else if(i_refresh_done)
                o_refresh_start <= 1'b0;
        else
                o_refresh_start <= o_refresh_start;
//o_write_start
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                o_write_start <= 1'b0;
        else if((r_arb_state == WRITE) && (!i_refresh_request) && (i_wr_request))
                o_write_start <= 1'b1;
        else if(i_wr_done)
                o_write_start <= 1'b0;
        else
                o_write_start <= o_write_start;
//o_read_start
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                o_read_start <= 1'b0;
        else if((r_arb_state == WRITE) && (!i_refresh_request) && (i_rd_request))
                o_read_start <= 1'b1;
        else if(i_rd_done)
                o_read_start <= 1'b0;
        else
                o_read_start <= o_read_start;
//sdram_cs_n、sdram_cas_n、sdram_ras_n、sdram_we_n的赋值
assign  {sdram_cs_n,sdram_ras_n,sdram_cas_n,sdram_we_n} = sdram_cmd;
//sdram_cke的赋值
assign  o_sdram_cke = 1'b1;
//sdram_dq的赋值，sdram_dq 为三态门，三态门必须根据控制信号进行输出，一般来说使用条件运算符进行控制
assign  sdram_dq = (i_wr_sdram_dq_oe) ? i_wr_data : 16'hzzzz;

endmodule