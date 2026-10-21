# ==============================================================================
# File: wave_CPU_system.tcl
# Description: Waveform layout for CPU_system_tb (DUT: CPU_system) - Light Theme
# Usage (Vivado Tcl console, with the simulation running):
#   source wave_CPU_system.tcl
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

set tb  /CPU_system_tb
set dut /CPU_system_tb/dut

# ------------------------------------------------------------------------------
# GROUP 1: System & FSM
# ------------------------------------------------------------------------------
set g [add_wave_group "System & FSM"]
aw $g $tb/clk                       #008000 bin     ;# Dark Green
aw $g $tb/rst_n                     #B22222 bin     ;# Firebrick Red
aw $g $dut/u_cpu/Controller/pstate  #0000CC default "cpu_state" ;# Deep Blue

# ------------------------------------------------------------------------------
# GROUP 2: Program Flow (PC and current instruction)
# ------------------------------------------------------------------------------
set g [add_wave_group "Program Flow"]
aw $g $tb/bus_pc                      #008000 hex "PC"  ;# Dark Green
aw $g $dut/u_cpu/Datapath/d_out_IR    #000080 hex "IR"  ;# Navy Blue
aw $g $dut/u_cpu/Controller/opcode    #555555 hex       ;# Dark Gray

# ------------------------------------------------------------------------------
# GROUP 3: CPU <-> Memory bus
# ------------------------------------------------------------------------------
set g [add_wave_group "Bus"]
aw $g $tb/bus_addr        #8B4513 hex  ;# Saddle Brown
aw $g $tb/bus_read_en     #008080 bin  ;# Teal
aw $g $tb/bus_write_en    #D2691E bin  ;# Chocolate / Dark Orange
aw $g $tb/bus_wdata       #8B008B hex  ;# Dark Magenta
aw $g $dut/cpu_rdata      #0000FF hex  ;# Blue
# bus_mem_ready is not connected in the TB, so take the internal signal
aw $g $dut/bus_mem_ready  #008000 bin "mem_ready" ;# Dark Green

# ------------------------------------------------------------------------------
# GROUP 4: Memory System (controller + SRAM)
# ------------------------------------------------------------------------------
set g [add_wave_group "Memory System"]
aw $g $dut/u_mem/ctr_unit/p_state  #0000CC default "mem_state" ;# Deep Blue
aw $g $dut/u_mem/mem_unit/ena      #008080 bin                 ;# Teal
aw $g $dut/u_mem/mem_unit/wea      #D2691E bin                 ;# Chocolate / Dark Orange
aw $g $dut/u_mem/mem_unit/addra    #8B4513 hex                 ;# Saddle Brown

# ------------------------------------------------------------------------------
# GROUP 5: Register File (full array, expandable)
# ------------------------------------------------------------------------------
set g [add_wave_group "Register File"]
aw $g $dut/u_cpu/Datapath/RF1/mem  #555555 hex "RF"  ;# Dark Gray

# ------------------------------------------------------------------------------
# GROUP 6: Verification & Status
# ------------------------------------------------------------------------------
set g [add_wave_group "Verification & Status"]
aw $g $tb/cycles  #000080 unsigned  ;# Navy Blue
aw $g $tb/done    #008000 bin       ;# Dark Green

puts "CPU_system_tb light-theme waveforms loaded. Run 'run all'."