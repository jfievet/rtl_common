add wave -noupdate -divider {=====================}
add wave -noupdate -divider {         TB          }
add wave -noupdate -divider {=====================}

add wave -noupdate -divider {axi_lite_interconnect_tb}
add wave -position insertpoint sim:/axi_lite_interconnect_tb/*

add wave -noupdate -divider {=====================}
add wave -noupdate -divider {         DUT         }
add wave -noupdate -divider {=====================}

add wave -noupdate -divider {dut}
add wave -position insertpoint sim:/axi_lite_interconnect_tb/dut/*