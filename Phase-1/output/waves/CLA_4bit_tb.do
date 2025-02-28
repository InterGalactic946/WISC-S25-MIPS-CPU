onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /CLA_4bit_tb/iDUT/A
add wave -noupdate /CLA_4bit_tb/iDUT/B
add wave -noupdate /CLA_4bit_tb/iDUT/sub
add wave -noupdate /CLA_4bit_tb/expected_sum
add wave -noupdate /CLA_4bit_tb/Sum
add wave -noupdate /CLA_4bit_tb/expected_pos_overflow
add wave -noupdate /CLA_4bit_tb/pos_overflow
add wave -noupdate /CLA_4bit_tb/expected_neg_overflow
add wave -noupdate /CLA_4bit_tb/neg_overflow
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {599055 ns} {600055 ns}
