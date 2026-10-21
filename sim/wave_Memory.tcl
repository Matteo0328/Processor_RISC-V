# ==============================================================================
# File: wave_Memory.tcl
# Description: Waveform layout for Memory_tb (DUT: memory_system) - Light Theme
# Usage (Vivado Tcl console, with the simulation running):
#   source wave_Memory.tcl
#   restart
#   run all
# ==============================================================================

# Remove existing waveforms
catch {remove_wave [get_waves *]}

# Helper: add a signal and keep going if the path does not exist
proc aw {grp path color radix {name ""}} {
    set cmd [list add_wave -into $grp -color $color -radix $radix]
    if {$name ne ""} { lappend cmd -name $name }
    lappend cmd $path
    if {[catch {eval $cmd} err]} {
        puts "WARNING: cannot add $path ($err)"
    }
}

# ------------------------------------------------------------------------------
# GROUP 1: System & Control
# ------------------------------------------------------------------------------
set g [add_wave_group "System Control"]
aw $g /Memory_tb/clk    #008000 bin  ;# Dark Green
aw $g /Memory_tb/rst_n  #B22222 bin  ;# Firebrick Red

# ------------------------------------------------------------------------------
# GROUP 2: Bus Request (DUT inputs)
# ------------------------------------------------------------------------------
set g [add_wave_group "Bus Request"]
aw $g /Memory_tb/addr      #8B4513 hex  ;# Saddle Brown
aw $g /Memory_tb/data_in   #0000FF hex  ;# Blue
aw $g /Memory_tb/write_en  #D2691E bin  ;# Chocolate / Dark Orange
aw $g /Memory_tb/read_en   #008080 bin  ;# Teal

# ------------------------------------------------------------------------------
# GROUP 3: Bus Response (DUT outputs)
# ------------------------------------------------------------------------------
set g [add_wave_group "Bus Response"]
aw $g /Memory_tb/mem_ready #008000 bin  ;# Dark Green
aw $g /Memory_tb/data_out  #000080 hex  ;# Navy Blue
aw $g /Memory_tb/read_data #8B008B hex  ;# Dark Magenta

# ------------------------------------------------------------------------------
# GROUP 4: Memory Controller FSM (WAIT / WRITE / READ_1 / READ_2)
# ------------------------------------------------------------------------------
set g [add_wave_group "Memory Controller"]
aw $g /Memory_tb/dut/ctr_unit/p_state   #0000CC default "p_state" ;# Deep Blue
aw $g /Memory_tb/dut/ctr_unit/n_state   #800000 default "n_state" ;# Maroon
aw $g /Memory_tb/dut/ctr_unit/mem_ready #008000 bin               ;# Dark Green

# ------------------------------------------------------------------------------
# GROUP 5: Internal SRAM (data_sram)
# ------------------------------------------------------------------------------
set g [add_wave_group "SRAM (data_sram)"]
aw $g /Memory_tb/dut/mem_unit/ena   #008080 bin  ;# Teal
aw $g /Memory_tb/dut/mem_unit/wea   #D2691E bin  ;# Chocolate / Dark Orange
aw $g /Memory_tb/dut/mem_unit/addra #8B4513 hex  ;# Saddle Brown
aw $g /Memory_tb/dut/mem_unit/dina  #0000FF hex  ;# Blue
aw $g /Memory_tb/dut/mem_unit/douta #000080 hex  ;# Navy Blue

# ------------------------------------------------------------------------------
# GROUP 6: Reset injection handshake (random asynchronous reset)
# ------------------------------------------------------------------------------
set g [add_wave_group "Reset Injection"]
aw $g /Memory_tb/reset_en   #000000 bin       ;# Black (was White)
aw $g /Memory_tb/reset_busy #B22222 bin       ;# Firebrick Red
aw $g /Memory_tb/reset_hit  #D2691E bin       ;# Chocolate / Dark Orange
aw $g /Memory_tb/rst_hits   #555555 unsigned  ;# Dark Gray (was Light Gray)

# ------------------------------------------------------------------------------
# GROUP 7: Verification & Status
# ------------------------------------------------------------------------------
set g [add_wave_group "Verification & Status"]
aw $g /Memory_tb/num_errors #B22222 unsigned  ;# Firebrick Red

puts "Memory_tb light-theme waveforms loaded. Run 'run all' (or 'run 100 us')."