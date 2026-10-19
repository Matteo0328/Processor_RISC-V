# ==============================================================================
# File: wave_ALU.do
# Description: Waveform layout script for ALU Testbench (ALU_tb / DUT)
# Parameters: BW = 32
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
# GROUP 1: Inputs
# ------------------------------------------------------------------------------
add wave -noupdate -group {Inputs}                -color Yellow            -radix hexadecimal /ALU_tb/in_a
add wave -noupdate -group {Inputs}                -color Orange            -radix hexadecimal /ALU_tb/in_b
add wave -noupdate -group {Inputs}                -color Cyan                                 /ALU_tb/ALU_op

# ------------------------------------------------------------------------------
# GROUP 2: Outputs
# ------------------------------------------------------------------------------
add wave -noupdate -group {Outputs}               -color Lime              -radix hexadecimal /ALU_tb/out
# Flags struct (expandable in the wave window: zero / negative / overflow)
add wave -noupdate -group {Outputs}               -color Magenta           -radix binary      /ALU_tb/flags

# ------------------------------------------------------------------------------
# GROUP 3: Verification & Status
# ------------------------------------------------------------------------------
add wave -noupdate -group {Verification & Status} -color Cyan              -radix decimal     /ALU_tb/test_count
add wave -noupdate -group {Verification & Status} -color Red               -radix decimal     /ALU_tb/error_count

# ------------------------------------------------------------------------------
# GROUP 4: DUT Internal
# ------------------------------------------------------------------------------
add wave -noupdate -group {DUT Internal}          -color {Light Blue}      -radix unsigned    /ALU_tb/DUT/shamt

# ------------------------------------------------------------------------------
# Tree Update & Wave Window Setup
# ------------------------------------------------------------------------------
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -timeline 0
configure wave -timelineunits ns
update
# one check every 1 ns: zoom on the first part of the run
WaveRestoreZoom {0 ps} {100 ns}