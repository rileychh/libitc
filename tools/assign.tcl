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
	set_global_assignment -name DEVICE EP3C40Q240C8

	# OSC1, nRST
	set_location_assignment PIN_149 -to clk
	set_location_assignment PIN_195 -to rst_n

	# SEG1_{A...DOT}
	set_location_assignment PIN_232 -to seg_1[0]
	set_location_assignment PIN_236 -to seg_1[1]
	set_location_assignment PIN_240 -to seg_1[2]
	set_location_assignment PIN_9 -to seg_1[3]
	set_location_assignment PIN_18 -to seg_1[4]
	set_location_assignment PIN_22 -to seg_1[5]
	set_location_assignment PIN_56 -to seg_1[6]
	set_location_assignment PIN_63 -to seg_1[7]

	# SEG2_{A...DOT}
	set_location_assignment PIN_231 -to seg_2[0]
	set_location_assignment PIN_235 -to seg_2[1]
	set_location_assignment PIN_239 -to seg_2[2]  
	set_location_assignment PIN_6 -to seg_2[3]
	set_location_assignment PIN_21 -to seg_2[4]
	set_location_assignment PIN_13 -to seg_2[5]
	set_location_assignment PIN_37 -to seg_2[6]
	set_location_assignment PIN_39 -to seg_2[7]

	# # SEG2_S{1..4}, SEG1_S{1..4}
	set_location_assignment PIN_43 -to seg_s[0]
	set_location_assignment PIN_45 -to seg_s[1]
	set_location_assignment PIN_49 -to seg_s[2]
	set_location_assignment PIN_51 -to seg_s[3]
	set_location_assignment PIN_69 -to seg_s[4]
	set_location_assignment PIN_68 -to seg_s[5]
	set_location_assignment PIN_57 -to seg_s[6]
	set_location_assignment PIN_55 -to seg_s[7]

	# KEY_COL{1..4}
	set_location_assignment PIN_214 -to key_row[0]
	set_location_assignment PIN_203 -to key_row[1]
	set_location_assignment PIN_201 -to key_row[2]
	set_location_assignment PIN_197 -to key_row[3]

	# KEY_ROW{1..4}
	set_location_assignment PIN_226 -to key_col[0]
	set_location_assignment PIN_223 -to key_col[1]
	set_location_assignment PIN_219 -to key_col[2]
	set_location_assignment PIN_217 -to key_col[3]

	# SW_{1..8}
	set_location_assignment PIN_224 -to sw[7]
	set_location_assignment PIN_221 -to sw[6]
	set_location_assignment PIN_218 -to sw[5]
	set_location_assignment PIN_216 -to sw[4]
	set_location_assignment PIN_207 -to sw[3]
	set_location_assignment PIN_202 -to sw[2]
	set_location_assignment PIN_200 -to sw[1]
	set_location_assignment PIN_196 -to sw[0]

	# BUZZER
	set_location_assignment PIN_169 -to buz

	# LED_{R,G,Y}
	set_location_assignment PIN_173 -to led_r
	set_location_assignment PIN_177 -to led_g
	set_location_assignment PIN_184 -to led_y

	# RGB_{R,G,B}
	set_location_assignment PIN_186 -to rgb[0]
	set_location_assignment PIN_188 -to rgb[1]
	set_location_assignment PIN_194 -to rgb[2]

	# IN{1,2,3,4}, PWM{1..2}
	set_location_assignment PIN_189 -to mot_out[0]
	set_location_assignment PIN_187 -to mot_out[1]
	set_location_assignment PIN_185 -to mot_out[2]
	set_location_assignment PIN_183 -to mot_out[3]
	set_location_assignment PIN_176 -to mot_ena[0]
	set_location_assignment PIN_171 -to mot_ena[1]

	# DOT_G{4,3,2,1,5,6,7,8} (G stands for red)
	set_location_assignment PIN_107 -to dot_r[0]
	set_location_assignment PIN_95 -to dot_r[1]
	set_location_assignment PIN_83 -to dot_r[2]
	set_location_assignment PIN_73 -to dot_r[3]
	set_location_assignment PIN_70 -to dot_r[4]
	set_location_assignment PIN_82 -to dot_r[5]
	set_location_assignment PIN_94 -to dot_r[6]
	set_location_assignment PIN_106 -to dot_r[7]

	# DOT_R{4,3,2,1,5,6,7,8} (R stands for green)
	set_location_assignment PIN_111 -to dot_g[0]
	set_location_assignment PIN_99 -to dot_g[1]
	set_location_assignment PIN_87 -to dot_g[2]
	set_location_assignment PIN_78 -to dot_g[3]
	set_location_assignment PIN_76 -to dot_g[4]
	set_location_assignment PIN_84 -to dot_g[5]
	set_location_assignment PIN_98 -to dot_g[6]
	set_location_assignment PIN_110 -to dot_g[7]

	# DOT_S{4,3,2,1,5,6,7,8} (S stands for common, thank me later)
	set_location_assignment PIN_113 -to dot_s[0]
	set_location_assignment PIN_103 -to dot_s[1]
	set_location_assignment PIN_93 -to dot_s[2]
	set_location_assignment PIN_81 -to dot_s[3]
	set_location_assignment PIN_80 -to dot_s[4]
	set_location_assignment PIN_88 -to dot_s[5]
	set_location_assignment PIN_100 -to dot_s[6]
	set_location_assignment PIN_112 -to dot_s[7]

	# LCD_{CLK,DAT,CS,DC,BL,RES}
	set_location_assignment PIN_159 -to lcd_sclk
	set_location_assignment PIN_146 -to lcd_mosi
	set_location_assignment PIN_145 -to lcd_ss_n
	set_location_assignment PIN_144 -to lcd_dc
	set_location_assignment PIN_143 -to lcd_bl
	set_location_assignment PIN_142 -to lcd_rst

	# DATA
	set_location_assignment PIN_38 -to dht_data

	# SCL, SDA
	set_location_assignment PIN_164 -to tsl_scl
	set_location_assignment PIN_166 -to tsl_sda

	# SCL1, SDA1
	set_location_assignment PIN_160 -to tts_scl
	set_location_assignment PIN_161 -to tts_sda

	# # Debug ports
	# set_location_assignment PIN_187 -to dbg_a[0]
	# set_location_assignment PIN_185 -to dbg_a[1]
	# set_location_assignment PIN_183 -to dbg_a[2]
	# set_location_assignment PIN_181 -to dbg_a[3]
	# set_location_assignment PIN_176 -to dbg_a[4]
	# set_location_assignment PIN_174 -to dbg_a[5]
	# set_location_assignment PIN_171 -to dbg_a[6]
	# set_location_assignment PIN_168 -to dbg_a[7]
	# set_location_assignment PIN_188 -to dbg_b[0]
	# set_location_assignment PIN_186 -to dbg_b[1]
	# set_location_assignment PIN_184 -to dbg_b[2]
	# set_location_assignment PIN_182 -to dbg_b[3]
	# set_location_assignment PIN_177 -to dbg_b[4]
	# set_location_assignment PIN_175 -to dbg_b[5]
	# set_location_assignment PIN_173 -to dbg_b[6]
	# set_location_assignment PIN_169 -to dbg_b[7]

	# Commit assignments
	export_assignments

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}
