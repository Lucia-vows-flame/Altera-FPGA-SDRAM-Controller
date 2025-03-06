# 如果有上一次仿真，会退出上一次仿真
quit -sim

# 设置工作库
vlib work
vmap work work

# 创建Altera器件库
vlib altera_lib
vmap altera_lib altera_lib

# 编译Altera库文件
vlog -work altera_lib {C:/Quartus18.1/quartus/eda/sim_lib/altera_mf.v}
vlog -work altera_lib {C:/Quartus18.1/quartus/eda/sim_lib/220model.v}
vlog -work altera_lib {C:/Quartus18.1/quartus/eda/sim_lib/sgate.v}
vlog -work altera_lib {C:/Quartus18.1/quartus/eda/sim_lib/sdr.v}

# 编译PLL仿真模型
vlog -work work "C:/Altera_SDRAM_Controller/user/ip/clk_gen/clk_gen.v"  

# 编译设计文件
vlog -work work {C:/Altera_SDRAM_Controller/user/src/sdram_init.v}

# 编译测试平台文件
vlog -work work {C:/Altera_SDRAM_Controller/user/sim/tb_sdram_init.v}

# 加载仿真
vsim -t ps -L altera_lib -L work work.tb_sdram_init


add wave /tb_sdram_init/*

# 运行 1us
run 1us