onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /RegisterFile_tb/clk
add wave -noupdate /RegisterFile_tb/rst
add wave -noupdate /RegisterFile_tb/iDUT/SrcReg1
add wave -noupdate /RegisterFile_tb/iDUT/SrcReg2
add wave -noupdate /RegisterFile_tb/iDUT/DstReg
add wave -noupdate /RegisterFile_tb/iDUT/WriteReg
add wave -noupdate /RegisterFile_tb/iDUT/DstData
add wave -noupdate /RegisterFile_tb/regfile
add wave -noupdate /RegisterFile_tb/iDUT/SrcData1
add wave -noupdate /RegisterFile_tb/iDUT/SrcData2
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
WaveRestoreZoom {1999420 ns} {2000420 ns}
