vlib work

vmap work  work


vlog router.v router_packet.sv router_test_top.sv


vsim  work.router_test_top  -t 1ns -sv_seed random

add wave -position insertpoint  \
sim:/router_test_top/intf_io/clock \
sim:/router_test_top/intf_io/din \
sim:/router_test_top/intf_io/dout 



# sim:/router_test_top/intf_io/valido_n \
# sim:/router_test_top/intf_io/busy_n \
# sim:/router_test_top/intf_io/frameo_n \
# sim:/router_test_top/intf_io/reset_n \
# sim:/router_test_top/intf_io/frame_n \
# sim:/router_test_top/intf_io/valid_n \


run -all
