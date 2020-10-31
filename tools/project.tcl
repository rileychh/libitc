# Load Quartus II Tcl Project package
package require ::quartus::project

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
	# may be faster, may be slower
	# set_global_assignment -name SYNTHESIS_EFFORT FAST
	set_global_assignment -name SYNTHESIS_EFFORT AUTO
	set_global_assignment -name SMART_RECOMPILE ON

	# source files
	set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
	set_global_assignment -name SEARCH_PATH src\\util
	set_global_assignment -name SEARCH_PATH src
	set_global_assignment -name TOP_LEVEL_ENTITY rgb_test
	set_global_assignment -name VHDL_FILE tests/key_seg_test.vhd
	set_global_assignment -name VHDL_FILE tests/dot_test.vhd
	set_global_assignment -name VHDL_FILE tests/bcd_seg_test.vhd
	set_global_assignment -name VHDL_FILE tests/dht_seg_test.vhd
	set_global_assignment -name VHDL_FILE tests/tsl_seg_test.vhd
	set_global_assignment -name VHDL_FILE tests/tts_test.vhd
	set_global_assignment -name VHDL_FILE tests/rgb_test.vhd
	set_global_assignment -name VHDL_FILE src/seg.vhd
	set_global_assignment -name VHDL_FILE src/key.vhd
	set_global_assignment -name VHDL_FILE src/dht.vhd
	set_global_assignment -name VHDL_FILE src/dot.vhd
	set_global_assignment -name VHDL_FILE src/tsl.vhd
	set_global_assignment -name VHDL_FILE src/tts.vhd
	set_global_assignment -name VHDL_FILE src/rgb.vhd
	set_global_assignment -name VHDL_FILE src/util/clk.vhd
	set_global_assignment -name VHDL_FILE src/util/pwm.vhd
	set_global_assignment -name VHDL_FILE src/util/i2c.vhd

	# Commit assignments
	export_assignments

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}
