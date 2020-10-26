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
	set_global_assignment -name FAMILY "Cyclone III"
	set_global_assignment -name DEVICE EP3C16Q240C8
	set_location_assignment PIN_149 -to clk
	set_location_assignment PIN_145 -to rst
	set_location_assignment PIN_231 -to seg_1[7]
	set_location_assignment PIN_233 -to seg_1[6]
	set_location_assignment PIN_235 -to seg_1[5]
	set_location_assignment PIN_237 -to seg_1[4]
	set_location_assignment PIN_239 -to seg_1[3]
	set_location_assignment PIN_4 -to seg_1[2]
	set_location_assignment PIN_6 -to seg_1[1]
	set_location_assignment PIN_13 -to seg_1[0]
	set_location_assignment PIN_232 -to seg_2[7]
	set_location_assignment PIN_234 -to seg_2[6]
	set_location_assignment PIN_236 -to seg_2[5]
	set_location_assignment PIN_238 -to seg_2[4]
	set_location_assignment PIN_240 -to seg_2[3]
	set_location_assignment PIN_5 -to seg_2[2]
	set_location_assignment PIN_9 -to seg_2[1]
	set_location_assignment PIN_18 -to seg_2[0]
	set_location_assignment PIN_39 -to seg_s[7]
	set_location_assignment PIN_37 -to seg_s[6]
	set_location_assignment PIN_21 -to seg_s[5]
	set_location_assignment PIN_19 -to seg_s[4]
	set_location_assignment PIN_41 -to seg_s[3]
	set_location_assignment PIN_38 -to seg_s[2]
	set_location_assignment PIN_22 -to seg_s[1]
	set_location_assignment PIN_20 -to seg_s[0]
	set_location_assignment PIN_43 -to key_col[3]
	set_location_assignment PIN_45 -to key_col[2]
	set_location_assignment PIN_49 -to key_col[1]
	set_location_assignment PIN_51 -to key_col[0]
	set_location_assignment PIN_55 -to key_row[3]
	set_location_assignment PIN_57 -to key_row[2]
	set_location_assignment PIN_64 -to key_row[1]
	set_location_assignment PIN_68 -to key_row[0]
	set_location_assignment PIN_99 -to dot_g[7]
	set_location_assignment PIN_107 -to dot_g[6]
	set_location_assignment PIN_113 -to dot_g[5]
	set_location_assignment PIN_126 -to dot_g[4]
	set_location_assignment PIN_120 -to dot_g[3]
	set_location_assignment PIN_112 -to dot_g[2]
	set_location_assignment PIN_106 -to dot_g[1]
	set_location_assignment PIN_98 -to dot_g[0]
	set_location_assignment PIN_101 -to dot_r[7]
	set_location_assignment PIN_109 -to dot_r[6]
	set_location_assignment PIN_117 -to dot_r[5]
	set_location_assignment PIN_128 -to dot_r[4]
	set_location_assignment PIN_127 -to dot_r[3]
	set_location_assignment PIN_114 -to dot_r[2]
	set_location_assignment PIN_108 -to dot_r[1]
	set_location_assignment PIN_100 -to dot_r[0]
	set_location_assignment PIN_95 -to dot_s[7]
	set_location_assignment PIN_103 -to dot_s[6]
	set_location_assignment PIN_111 -to dot_s[5]
	set_location_assignment PIN_119 -to dot_s[4]
	set_location_assignment PIN_118 -to dot_s[3]
	set_location_assignment PIN_110 -to dot_s[2]
	set_location_assignment PIN_102 -to dot_s[1]
	set_location_assignment PIN_94 -to dot_s[0]
	set_location_assignment PIN_69 -to sw[7]
	set_location_assignment PIN_65 -to sw[6]
	set_location_assignment PIN_63 -to sw[5]
	set_location_assignment PIN_56 -to sw[4]
	set_location_assignment PIN_52 -to sw[3]
	set_location_assignment PIN_50 -to sw[2]
	set_location_assignment PIN_46 -to sw[1]
	set_location_assignment PIN_44 -to sw[0]
	set_location_assignment PIN_131 -to dht_data
	set_location_assignment PIN_144 -to tsl_scl
	set_location_assignment PIN_143 -to tsl_sda
	set_location_assignment PIN_147 -to tts_scl
	set_location_assignment PIN_146 -to tts_sda

	# Commit assignments
	export_assignments

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}
