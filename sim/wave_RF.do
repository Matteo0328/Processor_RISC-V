# ==============================================================================
# File: wave_RF.do
# Description: Waveform layout script for Register File Testbench (RF_tb / DUT1)
# Parameters: BW = 8, DEPTH = 8
# ==============================================================================
view wave
catch {delete wave *}

onerror {resume}
quietly WaveActivateNextPane {} 0

# Interface display settings
configure wave -namecolwidth  230
configure wave -valuecolwidth 110
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# ------------------------------------------------------------------------------
# GROUP 1: System & Control
# ------------------------------------------------------------------------------
add wave -noupdate -group {System Control}        -color Yellow       -radix binary      /RF_tb/clk
add wave -noupdate -group {System Control}        -color Red          -radix binary      /RF_tb/rst_n
add wave -noupdate -group {System Control}        -color Cyan         -radix binary      /RF_tb/chip_en

# ------------------------------------------------------------------------------
# GROUP 2: Synchronous Write Port
# ------------------------------------------------------------------------------
add wave -noupdate -group {Write Port}            -color Orange       -radix binary      /RF_tb/write_en_n
add wave -noupdate -group {Write Port}            -color Coral        -radix unsigned    /RF_tb/write_addr
add wave -noupdate -group {Write Port}            -color {Light Blue} -radix hexadecimal /RF_tb/data_in

# ------------------------------------------------------------------------------
# GROUP 3: Asynchronous Read Port 1
# ------------------------------------------------------------------------------
add wave -noupdate -group {Read Port 1}           -color {Cornflower Blue} -radix unsigned    /RF_tb/read_addr_1
add wave -noupdate -group {Read Port 1}           -color Lime              -radix hexadecimal /RF_tb/data_out_1

# ------------------------------------------------------------------------------
# GROUP 4: Asynchronous Read Port 2
# ------------------------------------------------------------------------------
add wave -noupdate -group {Read Port 2}           -color Magenta           -radix unsigned    /RF_tb/read_addr_2
add wave -noupdate -group {Read Port 2}           -color Yellow            -radix hexadecimal /RF_tb/data_out_2

# ------------------------------------------------------------------------------
# GROUP 5: Verification & Status
# ------------------------------------------------------------------------------
add wave -noupdate -group {Verification & Status} -color Cyan         -radix decimal     /RF_tb/test_count
add wave -noupdate -group {Verification & Status} -color Red          -radix decimal     /RF_tb/error_count
add wave -noupdate -group {Verification & Status} -color White        -radix hexadecimal /RF_tb/expected_mem

# ------------------------------------------------------------------------------
# GROUP 6: DUT Internal Storage (mem[0] to mem[7])
# ------------------------------------------------------------------------------
# Entire memory array (expandable in the wave window)
add wave -noupdate -group {DUT Registers}         -color Gray70       -radix hexadecimal /RF_tb/DUT1/mem

# Individual registers: mem(0) highlighted in Red to verify x0 immutability
add wave -noupdate -group {DUT Registers}         -color Red          -radix hexadecimal /RF_tb/DUT1/mem(0)
add wave -noupdate -group {DUT Registers}                             -radix hexadecimal /RF_tb/DUT1/mem(1)
add wave -noupdate -group {DUT Registers}                             -radix hexadecimal /RF_tb/DUT1/mem(2)
add wave -noupdate -group {DUT Registers}                             -radix hexadecimal /RF_tb/DUT1/mem(3)
add wave -noupdate -group {DUT Registers}                             -radix hexadecimal /RF_tb/DUT1/mem(4)
add wave -noupdate -group {DUT Registers}                             -radix hexadecimal /RF_tb/DUT1/mem(5)
add wave -noupdate -group {DUT Registers}                             -radix hexadecimal /RF_tb/DUT1/mem(6)
add wave -noupdate -group {DUT Registers}                             -radix hexadecimal /RF_tb/DUT1/mem(7)

# ------------------------------------------------------------------------------
# Tree Update & Wave Window Setup
# ------------------------------------------------------------------------------
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {350 ns}