# Load Quartus II Tcl Project package
package require ::quartus::project

# Load Quartus II Tcl Flow package
package require ::quartus::flow

set need_to_close_project 0
set make_assignments 1

# Check that the right project is open
if {[is_project_open]} {
	if {[string compare $quartus(project) "libitc"]} {
		puts "Project libitc is not open"
		set make_assignments 0
	}
} else {
	# Only open if not already open
	if {[project_exists libitc]} {
		project_open -revision libitc libitc
	} else {
		project_new -revision libitc libitc
	}
	set need_to_close_project 1
}

# Make assignments
if {$make_assignments} {
	# Collect trash files
	set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files

	# Speed up compilation
	set_global_assignment -name PHYSICAL_SYNTHESIS_EFFORT FAST
	set_global_assignment -name FITTER_EFFORT FAST_FIT
	set_global_assignment -name SYNTHESIS_EFFORT FAST
	set_global_assignment -name SMART_RECOMPILE ON
	set_global_assignment -name TIMEQUEST_MULTICORNER_ANALYSIS OFF
	# set_global_assignment -name SYNTH_TIMING_DRIVEN_SYNTHESIS OFF
	# set_global_assignment -name OPTIMIZE_POWER_DURING_SYNTHESIS OFF
	# set_global_assignment -name OPTIMIZE_HOLD_TIMING OFF
	# set_global_assignment -name OPTIMIZE_MULTI_CORNER_TIMING OFF
	# set_global_assignment -name OPTIMIZE_POWER_DURING_FITTING OFF
	# set_global_assignment -name OPTIMIZE_TIMING OFF
	# set_global_assignment -name OPTIMIZE_IOC_REGISTER_PLACEMENT_FOR_TIMING OFF
	# set_global_assignment -name OPTIMIZE_FOR_METASTABILITY OFF
	# set_global_assignment -name IO_PLACEMENT_OPTIMIZATION OFF
	# set_global_assignment -name FINAL_PLACEMENT_OPTIMIZATION NEVER
	# set_global_assignment -name ROUTER_TIMING_OPTIMIZATION_LEVEL MINIMUM
	# set_global_assignment -name PLACEMENT_EFFORT_MULTIPLIER 0.000001
	# set_global_assignment -name ROUTER_EFFORT_MULTIPLIER 0.25

	# Disable unused pins
	set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED"

	# Source files
	set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
	set_global_assignment -name TOP_LEVEL_ENTITY underline

	## Unit tests
	# set_global_assignment -name VHDL_FILE tests/dht_test.vhd
	# set_global_assignment -name VHDL_FILE tests/dot_test.vhd
	# set_global_assignment -name VHDL_FILE tests/key_test.vhd
	# set_global_assignment -name VHDL_FILE tests/lcd_colors_test.vhd
	# set_global_assignment -name VHDL_FILE tests/lcd_image_test.vhd
	# set_global_assignment -name VHDL_FILE tests/lcd_image_test_bicolor.vhd
	# set_global_assignment -name VHDL_FILE tests/mot_test.vhd
	# set_global_assignment -name VHDL_FILE tests/rgb_test.vhd
	# set_global_assignment -name VHDL_FILE tests/seg_test.vhd
	# set_global_assignment -name VHDL_FILE tests/tsl_test.vhd
	# set_global_assignment -name VHDL_FILE tests/tts_test.vhd
	# set_global_assignment -name VHDL_FILE tests/uart_dino_test.vhd
	# set_global_assignment -name VHDL_FILE tests/uart_echo_test.vhd
	# set_global_assignment -name QIP_FILE tests/lcd/ip/image.qip
	# set_global_assignment -name MIF_FILE tests/lcd/ip/image.mif
	# set_global_assignment -name QIP_FILE tests/lcd/ip/image_bicolor.qip
	# set_global_assignment -name MIF_FILE tests/lcd/ip/image_bicolor.mif


	# set_global_assignment -name VHDL_FILE dist/itc108_1.pp.vhd
	# set_global_assignment -name QIP_FILE src/itc108_1/ip/icon.qip
	# set_global_assignment -name MIF_FILE src/itc108_1/ip/icon.mif

	# set_global_assignment -name VHDL_FILE dist/itc108_2.pp.vhd

	# set_global_assignment -name VHDL_FILE dist/itc108_2_1124.pp.vhd

	# set_global_assignment -name VHDL_FILE dist/itc109_2.pp.vhd

	# set_global_assignment -name VHDL_FILE dist/itc109_1.pp.vhd
	# set_global_assignment -name QIP_FILE src/itc109_1/ip/digit_0.qip
	# set_global_assignment -name MIF_FILE src/itc109_1/ip/digit_0.mif
	# set_global_assignment -name QIP_FILE src/itc109_1/ip/digit_1.qip
	# set_global_assignment -name MIF_FILE src/itc109_1/ip/digit_1.mif
	# set_global_assignment -name QIP_FILE src/itc109_1/ip/digit_2.qip
	# set_global_assignment -name MIF_FILE src/itc109_1/ip/digit_2.mif
	# set_global_assignment -name QIP_FILE src/itc109_1/ip/digit_3.qip
	# set_global_assignment -name MIF_FILE src/itc109_1/ip/digit_3.mif
	# set_global_assignment -name QIP_FILE src/itc109_1/ip/digit_4.qip
	# set_global_assignment -name MIF_FILE src/itc109_1/ip/digit_4.mif
	# set_global_assignment -name QIP_FILE src/itc109_1/ip/digit_5.qip
	# set_global_assignment -name MIF_FILE src/itc109_1/ip/digit_5.mif
	# set_global_assignment -name QIP_FILE src/itc109_1/ip/digit_6.qip
	# set_global_assignment -name MIF_FILE src/itc109_1/ip/digit_6.mif
	# set_global_assignment -name QIP_FILE src/itc109_1/ip/digit_7.qip
	# set_global_assignment -name MIF_FILE src/itc109_1/ip/digit_7.mif
	# set_global_assignment -name QIP_FILE src/itc109_1/ip/digit_8.qip
	# set_global_assignment -name MIF_FILE src/itc109_1/ip/digit_8.mif
	# set_global_assignment -name QIP_FILE src/itc109_1/ip/digit_9.qip
	# set_global_assignment -name MIF_FILE src/itc109_1/ip/digit_9.mif
	# set_global_assignment -name QIP_FILE src/itc109_1/ip/sensor_bg.qip
	# set_global_assignment -name MIF_FILE src/itc109_1/ip/sensor_bg.mif

	set_global_assignment -name VHDL_FILE tests/HW/buz_test/F1_underline.vhd
	set_global_assignment -name QIP_FILE tests/HW/buz_test/F1_underline.qip
	set_global_assignment -name MIF_FILE tests/HW/buz_test/F1_underline.mif
	set_global_assignment -name VHDL_FILE tests/HW/buz_test/underline.vhd

	# set_global_assignment -name VHDL_FILE tests/itc111_1/itc111_1.vhd
	# set_global_assignment -name VHDL_FILE tests/itc111_1/itc111_2.vhd
	

	## Components

	set_global_assignment -name VHDL_FILE lib/dht.vhd
	set_global_assignment -name VHDL_FILE lib/dot.vhd
	set_global_assignment -name VHDL_FILE lib/key.vhd
	set_global_assignment -name VHDL_FILE lib/lcd.vhd
	set_global_assignment -name VHDL_FILE lib/mot.vhd
	set_global_assignment -name VHDL_FILE lib/rgb.vhd
	set_global_assignment -name VHDL_FILE lib/seg.vhd
	set_global_assignment -name VHDL_FILE lib/sw.vhd
	set_global_assignment -name VHDL_FILE lib/tsl.vhd
	set_global_assignment -name VHDL_FILE lib/tts.vhd
	set_global_assignment -name VHDL_FILE lib/pkg/itc.pkg.vhd
	set_global_assignment -name VHDL_FILE lib/pkg/lcd.pkg.vhd
	set_global_assignment -name VHDL_FILE lib/util/clk.vhd
	set_global_assignment -name VHDL_FILE lib/util/debounce.vhd
	set_global_assignment -name VHDL_FILE lib/util/edge.vhd
	set_global_assignment -name VHDL_FILE lib/util/pwm.vhd
	set_global_assignment -name VHDL_FILE lib/util/i2c.vhd
	set_global_assignment -name VHDL_FILE lib/util/timer.vhd
	set_global_assignment -name VHDL_FILE lib/util/uart.vhd
	set_global_assignment -name VHDL_FILE lib/util/uart_txt.vhd
	set_global_assignment -name QIP_FILE lib/ip/framebuffer.qip

	# Commit assignments
	export_assignments

	# Compile
	execute_flow -compile

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}
