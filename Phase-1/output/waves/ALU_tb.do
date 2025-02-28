onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /ALU_tb/iDUT/ALU_In1
add wave -noupdate /ALU_tb/iDUT/ALU_In2
add wave -noupdate /ALU_tb/iDUT/Opcode
add wave -noupdate /ALU_tb/expected_result
add wave -noupdate /ALU_tb/result
add wave -noupdate /ALU_tb/expected_ZF
add wave -noupdate /ALU_tb/ZF
add wave -noupdate /ALU_tb/expected_VF
add wave -noupdate /ALU_tb/VF
add wave -noupdate /ALU_tb/expected_NF
add wave -noupdate /ALU_tb/NF
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
WaveRestoreZoom {5999055 ns} {6000055 ns}
