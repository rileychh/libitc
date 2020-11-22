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
	set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"

	# OSC1, nRST
	set_location_assignment PIN_149 -to clk
	set_location_assignment PIN_195 -to rst_n

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

	# SEG{1,2}_{A..DOT}
	set_location_assignment PIN_232 -to seg_led[0]
	set_location_assignment PIN_236 -to seg_led[1]
	set_location_assignment PIN_240 -to seg_led[2]
	set_location_assignment PIN_9 -to seg_led[3]
	set_location_assignment PIN_18 -to seg_led[4]
	set_location_assignment PIN_22 -to seg_led[5]
	set_location_assignment PIN_37 -to seg_led[6]
	set_location_assignment PIN_63 -to seg_led[7]

	# SEG2_S{1..4}, SEG1_S{1..4}
	set_location_assignment PIN_43 -to seg_com[0]
	set_location_assignment PIN_45 -to seg_com[1]
	set_location_assignment PIN_49 -to seg_com[2]
	set_location_assignment PIN_51 -to seg_com[3]
	set_location_assignment PIN_69 -to seg_com[4]
	set_location_assignment PIN_68 -to seg_com[5]
	set_location_assignment PIN_57 -to seg_com[6]
	set_location_assignment PIN_55 -to seg_com[7]

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
	set_location_assignment PIN_224 -to sw[0]
	set_location_assignment PIN_221 -to sw[1]
	set_location_assignment PIN_218 -to sw[2]
	set_location_assignment PIN_216 -to sw[3]
	set_location_assignment PIN_207 -to sw[4]
	set_location_assignment PIN_202 -to sw[5]
	set_location_assignment PIN_200 -to sw[6]
	set_location_assignment PIN_196 -to sw[7]

	# SCL1, SDA1, MO{2..0}, RES
	set_location_assignment PIN_160 -to tts_scl
	set_location_assignment PIN_161 -to tts_sda
	set_location_assignment PIN_133 -to tts_mo[2]
	set_location_assignment PIN_132 -to tts_mo[1]
	set_location_assignment PIN_131 -to tts_mo[0]
	set_location_assignment PIN_162 -to tts_rst_n

	# SCL, SDA
	set_location_assignment PIN_164 -to tsl_scl
	set_location_assignment PIN_166 -to tsl_sda

	# LCD_{CLK,DAT,RES,DC,CS,BL}
	set_location_assignment PIN_159 -to lcd_sclk
	set_location_assignment PIN_146 -to lcd_mosi
	set_location_assignment PIN_145 -to lcd_rst_n
	set_location_assignment PIN_144 -to lcd_dc
	set_location_assignment PIN_143 -to lcd_ss_n
	set_location_assignment PIN_142 -to lcd_bl

	# DATA
	set_location_assignment PIN_38 -to dht_data

	# DOT_G{4,3,2,1,5,6,7,8} (G stands for red)
	set_location_assignment PIN_107 -to dot_red[0]
	set_location_assignment PIN_95 -to dot_red[1]
	set_location_assignment PIN_83 -to dot_red[2]
	set_location_assignment PIN_73 -to dot_red[3]
	set_location_assignment PIN_70 -to dot_red[4]
	set_location_assignment PIN_82 -to dot_red[5]
	set_location_assignment PIN_94 -to dot_red[6]
	set_location_assignment PIN_106 -to dot_red[7]

	# DOT_R{4,3,2,1,5,6,7,8} (R stands for green)
	set_location_assignment PIN_111  -to dot_green[0]
	set_location_assignment PIN_99 -to dot_green[1]
	set_location_assignment PIN_87 -to dot_green[2]
	set_location_assignment PIN_78 -to dot_green[3]
	set_location_assignment PIN_76 -to dot_green[4]
	set_location_assignment PIN_84 -to dot_green[5]
	set_location_assignment PIN_98 -to dot_green[6]
	set_location_assignment PIN_110  -to dot_green[7]

	# DOT_S{4,3,2,1,5,6,7,8} (S stands for common, thank me later)
	set_location_assignment PIN_113 -to dot_com[0]
	set_location_assignment PIN_103 -to dot_com[1]
	set_location_assignment PIN_93 -to dot_com[2]
	set_location_assignment PIN_81 -to dot_com[3]
	set_location_assignment PIN_80 -to dot_com[4]
	set_location_assignment PIN_88 -to dot_com[5]
	set_location_assignment PIN_100 -to dot_com[6]
	set_location_assignment PIN_112 -to dot_com[7]

	# PWM{1..2}, IN{1,2,3,4}
	set_location_assignment PIN_176 -to mot_ena[0]
	set_location_assignment PIN_171 -to mot_ena[1]
	set_location_assignment PIN_189 -to mot_ch[0]
	set_location_assignment PIN_187 -to mot_ch[1]
	set_location_assignment PIN_185 -to mot_ch[2]
	set_location_assignment PIN_183 -to mot_ch[3]

	# UART_{TX,RX} (green, white)
	set_location_assignment PIN_128 -to uart_rx
	set_location_assignment PIN_127 -to uart_tx

	# Commit assignments
	export_assignments

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}