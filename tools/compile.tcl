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
	# collect trash files
	set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files

	# speed up compilation
	set_global_assignment -name PHYSICAL_SYNTHESIS_EFFORT FAST
	set_global_assignment -name FITTER_EFFORT FAST_FIT
	# set_global_assignment -name SYNTHESIS_EFFORT FAST
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

	# disable unused pins
	set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED"

	# source files
	set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
	set_global_assignment -name TOP_LEVEL_ENTITY itc108_2

	set_global_assignment -name VHDL_FILE tests/dht_test.vhd
	set_global_assignment -name VHDL_FILE tests/dot_test.vhd
	set_global_assignment -name VHDL_FILE tests/key_test.vhd
	set_global_assignment -name VHDL_FILE tests/lcd_colors_test.vhd
	set_global_assignment -name VHDL_FILE tests/lcd_image_test.vhd
	set_global_assignment -name VHDL_FILE tests/lcd_image_test_bicolor.vhd
	set_global_assignment -name VHDL_FILE tests/mot_test.vhd
	set_global_assignment -name VHDL_FILE tests/rgb_test.vhd
	set_global_assignment -name VHDL_FILE tests/seg_test.vhd
	set_global_assignment -name VHDL_FILE tests/tsl_test.vhd
	set_global_assignment -name VHDL_FILE tests/tts_test.vhd
	set_global_assignment -name VHDL_FILE tests/uart_dino_test.vhd
	set_global_assignment -name VHDL_FILE tests/uart_echo_test.vhd
	set_global_assignment -name QIP_FILE tests/res/image.qip
	set_global_assignment -name MIF_FILE tests/res/image.mif
	set_global_assignment -name QIP_FILE tests/res/image_bicolor.qip
	set_global_assignment -name MIF_FILE tests/res/image_bicolor.mif]

	# <start>108th section1 target files</start>
	set_global_assignment -name VHDL_FILE dist/itc108_1.pp.vhd
	set_global_assignment -name QIP_FILE tests/itc108_1/res/bg.qip
	set_global_assignment -name MIF_FILE tests/itc108_1/res/bg.mif
	set_global_assignment -name QIP_FILE tests/itc108_1/res/icon.qip
	set_global_assignment -name MIF_FILE tests/itc108_1/res/icon.mif
	# <end>108th section1 target files<end>

	# <start>109th section2 target files</start>
	set_global_assignment -name VHDL_FILE dist/itc108_2.pp.vhd

	# <start>109th section2 target files</start>

	set_global_assignment -name VHDL_FILE src/dht.vhd
	set_global_assignment -name VHDL_FILE src/dot.vhd
	set_global_assignment -name VHDL_FILE src/key.vhd
	set_global_assignment -name VHDL_FILE src/lcd.vhd
	set_global_assignment -name VHDL_FILE src/mot.vhd
	set_global_assignment -name VHDL_FILE src/rgb.vhd
	set_global_assignment -name VHDL_FILE src/seg.vhd
	set_global_assignment -name VHDL_FILE src/sw.vhd
	set_global_assignment -name VHDL_FILE src/tsl.vhd
	set_global_assignment -name VHDL_FILE src/tts.vhd
	set_global_assignment -name VHDL_FILE src/util/itc_pkg.vhd
	set_global_assignment -name VHDL_FILE dist/itc_lcd_pkg.pp.vhd
	set_global_assignment -name VHDL_FILE src/util/clk.vhd
	set_global_assignment -name VHDL_FILE src/util/debounce.vhd
	set_global_assignment -name VHDL_FILE src/util/edge.vhd
	set_global_assignment -name VHDL_FILE src/util/pwm.vhd
	set_global_assignment -name VHDL_FILE src/util/i2c.vhd
	set_global_assignment -name VHDL_FILE src/util/timer.vhd
	set_global_assignment -name VHDL_FILE src/util/uart.vhd
	set_global_assignment -name VHDL_FILE src/util/uart_txt.vhd
	set_global_assignment -name QIP_FILE src/util/framebuffer.qip

	# Commit assignments
	export_assignments

	# Compile
	execute_flow -compile

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}
