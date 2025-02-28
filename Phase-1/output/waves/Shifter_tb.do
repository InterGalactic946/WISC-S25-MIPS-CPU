onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /Shifter_tb/iDUT/Mode
add wave -noupdate /Shifter_tb/iDUT/Shift_In
add wave -noupdate /Shifter_tb/iDUT/Shift_Val
add wave -noupdate /Shifter_tb/iDUT/Shift_SLL_step
add wave -noupdate /Shifter_tb/iDUT/Shift_SRA_step
add wave -noupdate /Shifter_tb/iDUT/Shift_ROR_step
add wave -noupdate /Shifter_tb/iDUT/Shift_SLL_Out
add wave -noupdate /Shifter_tb/iDUT/Shift_SRA_Out
add wave -noupdate /Shifter_tb/iDUT/Shift_ROR_Out
add wave -noupdate /Shifter_tb/iDUT/Shift_Out
add wave -noupdate /Shifter_tb/expected_result
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
