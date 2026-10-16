# ==============================================================================
# File: wave.do
# Description: Waveform layout script for RISC-V Multi-cycle CPU (Milestone 3)
# ==============================================================================
view wave
catch {delete wave *}

onerror {resume}
quietly WaveActivateNextPane {} 0

# Display settings
configure wave -namecolwidth  250
configure wave -valuecolwidth 130
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# ------------------------------------------------------------------------------
# GROUP 1: System Control (Clock, Reset & FSM)
# ------------------------------------------------------------------------------
add wave -noupdate -group {System Control} -color Yellow       -radix binary      /CPU_tb/clk
add wave -noupdate -group {System Control} -color Red          -radix binary      /CPU_tb/rst_n
add wave -noupdate -group {System Control} -color Cyan         -radix ascii       /CPU_tb/DUT/Controller/pstate
add wave -noupdate -group {System Control} -color {Dark Cyan}  -radix ascii       /CPU_tb/DUT/Controller/nstate

# ------------------------------------------------------------------------------
# GROUP 2: External Memory Interface & Protocol Handshake
# ------------------------------------------------------------------------------
add wave -noupdate -group {Memory Interface} -color Coral        -radix hexadecimal /CPU_tb/addr
add wave -noupdate -group {Memory Interface} -color Orange       -radix binary      /CPU_tb/read_en
add wave -noupdate -group {Memory Interface} -color Orange       -radix binary      /CPU_tb/write_en
add wave -noupdate -group {Memory Interface} -color Green        -radix binary      /CPU_tb/mem_ready
add wave -noupdate -group {Memory Interface} -color {Light Blue} -radix hexadecimal /CPU_tb/data_in
add wave -noupdate -group {Memory Interface} -color Magenta      -radix hexadecimal /CPU_tb/data_out

# ------------------------------------------------------------------------------
# GROUP 3: Program Counter & Jump/Branch Flow
# ------------------------------------------------------------------------------
add wave -noupdate -group {PC & Branch Flow} -color Lime        -radix hexadecimal /CPU_tb/DUT/Datapath/d_out_PC
add wave -noupdate -group {PC & Branch Flow}                    -radix binary      /CPU_tb/DUT/Controller/loadPC
add wave -noupdate -group {PC & Branch Flow}                    -radix binary      /CPU_tb/DUT/Controller/selINC_PC
add wave -noupdate -group {PC & Branch Flow}                    -radix binary      /CPU_tb/DUT/Controller/selImm_PC
add wave -noupdate -group {PC & Branch Flow}                    -radix binary      /CPU_tb/DUT/Controller/selIJump
add wave -noupdate -group {PC & Branch Flow}                    -radix binary      /CPU_tb/DUT/Controller/selZero_cond
add wave -noupdate -group {PC & Branch Flow} -color Yellow      -radix binary      /CPU_tb/DUT/Datapath/JC_out

# ------------------------------------------------------------------------------
# GROUP 4: Instruction Decoding & Format Types
# ------------------------------------------------------------------------------
add wave -noupdate -group {Instruction Decoding} -color {Cornflower Blue} -radix hexadecimal /CPU_tb/DUT/Controller/instr
add wave -noupdate -group {Instruction Decoding}                          -radix hexadecimal /CPU_tb/DUT/Controller/opcode
add wave -noupdate -group {Instruction Decoding}                          -radix binary      /CPU_tb/DUT/Controller/func3
add wave -noupdate -group {Instruction Decoding}                          -radix binary      /CPU_tb/DUT/Controller/func7
add wave -noupdate -group {Instruction Decoding}                          -radix binary      /CPU_tb/DUT/Controller/Type_R
add wave -noupdate -group {Instruction Decoding}                          -radix binary      /CPU_tb/DUT/Controller/Type_I
add wave -noupdate -group {Instruction Decoding}                          -radix binary      /CPU_tb/DUT/Controller/Type_S
add wave -noupdate -group {Instruction Decoding}                          -radix binary      /CPU_tb/DUT/Controller/Type_SB
add wave -noupdate -group {Instruction Decoding}                          -radix binary      /CPU_tb/DUT/Controller/Type_U
add wave -noupdate -group {Instruction Decoding}                          -radix binary      /CPU_tb/DUT/Controller/Type_UJ

# ------------------------------------------------------------------------------
# GROUP 5: Datapath Steering (Multiplexers)
# ------------------------------------------------------------------------------
add wave -noupdate -group {Datapath Steering} -radix binary /CPU_tb/DUT/Controller/selRS1
add wave -noupdate -group {Datapath Steering} -radix binary /CPU_tb/DUT/Controller/selRS2
add wave -noupdate -group {Datapath Steering} -radix binary /CPU_tb/DUT/Controller/selImm
add wave -noupdate -group {Datapath Steering} -radix binary /CPU_tb/DUT/Controller/selPC
add wave -noupdate -group {Datapath Steering} -radix binary /CPU_tb/DUT/Controller/selPC_addr
add wave -noupdate -group {Datapath Steering} -radix binary /CPU_tb/DUT/Controller/selALU_addr

# ------------------------------------------------------------------------------
# GROUP 6: ALU Subsystem (Operands, Operation & Flags)
# Nota: se l'istanza in Datapath si chiama 'ALU' invece di 'ALU1', adatta il prefisso
# ------------------------------------------------------------------------------
add wave -noupdate -group {ALU Core} -color Magenta     -radix ascii       /CPU_tb/DUT/Controller/ALU_op
add wave -noupdate -group {ALU Core} -color Blue        -radix hexadecimal /CPU_tb/DUT/Datapath/ALU1/in_a
add wave -noupdate -group {ALU Core} -color Blue        -radix hexadecimal /CPU_tb/DUT/Datapath/ALU1/in_b
add wave -noupdate -group {ALU Core} -color Yellow      -radix hexadecimal /CPU_tb/DUT/Datapath/ALU1/out
add wave -noupdate -group {ALU Core}                    -radix binary      /CPU_tb/DUT/Datapath/ALU1/flags.zero
add wave -noupdate -group {ALU Core}                    -radix binary      /CPU_tb/DUT/Datapath/ALU1/flags.negative
add wave -noupdate -group {ALU Core}                    -radix binary      /CPU_tb/DUT/Datapath/ALU1/flags.overflow

# ------------------------------------------------------------------------------
# GROUP 7: Memory Alignment & Data Formatting
# ------------------------------------------------------------------------------
add wave -noupdate -group {Data Formatting} -radix binary      /CPU_tb/DUT/Controller/ld_SB
add wave -noupdate -group {Data Formatting} -radix binary      /CPU_tb/DUT/Controller/ld_SH
add wave -noupdate -group {Data Formatting} -radix binary      /CPU_tb/DUT/Controller/ld_SW
add wave -noupdate -group {Data Formatting} -radix binary      /CPU_tb/DUT/Controller/SgnE_8
add wave -noupdate -group {Data Formatting} -radix binary      /CPU_tb/DUT/Controller/SgnE_16
add wave -noupdate -group {Data Formatting} -radix binary      /CPU_tb/DUT/Controller/PT
add wave -noupdate -group {Data Formatting} -radix binary      /CPU_tb/DUT/Controller/ZrE_8
add wave -noupdate -group {Data Formatting} -radix binary      /CPU_tb/DUT/Controller/ZrE_16
add wave -noupdate -group {Data Formatting} -radix hexadecimal /CPU_tb/DUT/Datapath/out_ext

# ------------------------------------------------------------------------------
# GROUP 8: Register File (Writeback & Selected Registers)
# ------------------------------------------------------------------------------
add wave -noupdate -group {Register File} -color Red          -radix binary      /CPU_tb/DUT/Controller/we_n
add wave -noupdate -group {Register File}                     -radix binary      /CPU_tb/DUT/Controller/ldALU
add wave -noupdate -group {Register File}                     -radix binary      /CPU_tb/DUT/Controller/ldMEM
add wave -noupdate -group {Register File}                     -radix binary      /CPU_tb/DUT/Controller/ldPC
add wave -noupdate -group {Register File} -color {Light Blue} -radix hexadecimal /CPU_tb/DUT/Datapath/data_in_RF
add wave -noupdate -group {Register File}                     -radix hexadecimal /CPU_tb/DUT/Datapath/RF1/mem(0)
add wave -noupdate -group {Register File}                     -radix hexadecimal /CPU_tb/DUT/Datapath/RF1/mem(1)
add wave -noupdate -group {Register File}                     -radix hexadecimal /CPU_tb/DUT/Datapath/RF1/mem(2)
add wave -noupdate -group {Register File}                     -radix hexadecimal /CPU_tb/DUT/Datapath/RF1/mem(3)
add wave -noupdate -group {Register File}                     -radix hexadecimal /CPU_tb/DUT/Datapath/RF1/mem(10)
add wave -noupdate -group {Register File}                     -radix hexadecimal /CPU_tb/DUT/Datapath/RF1/mem(11)
add wave -noupdate -group {Register File}                     -radix hexadecimal /CPU_tb/DUT/Datapath/RF1/mem(12)
add wave -noupdate -group {Register File}                     -radix hexadecimal /CPU_tb/DUT/Datapath/RF1/mem(15)
add wave -noupdate -group {Register File}                     -radix hexadecimal /CPU_tb/DUT/Datapath/RF1/mem(16)
add wave -noupdate -group {Register File}                     -radix hexadecimal /CPU_tb/DUT/Datapath/RF1/mem(17)

# Refresh view
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {1000 ns}