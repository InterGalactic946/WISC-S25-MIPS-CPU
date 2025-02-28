onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /PSA_16bit_tb/iDUT/A
add wave -noupdate /PSA_16bit_tb/iDUT/B
add wave -noupdate /PSA_16bit_tb/Sum
add wave -noupdate /PSA_16bit_tb/expected_PSA_sum
add wave -noupdate /PSA_16bit_tb/expected_sum
add wave -noupdate /PSA_16bit_tb/iDUT/pos_Ovfl
add wave -noupdate /PSA_16bit_tb/iDUT/neg_Ovfl
add wave -noupdate /PSA_16bit_tb/iDUT/Error
add wave -noupdate /PSA_16bit_tb/expected_PSA_error
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
