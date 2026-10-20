# ==============================================================================
# File: wave_CPU_system.tcl
# Description: Waveform layout for CPU_system_tb (DUT: CPU_system)
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
aw $g $tb/clk                       #FFFF00 bin
aw $g $tb/rst_n                     #FF0000 bin
aw $g $dut/u_cpu/Controller/pstate  #00FFFF default "cpu_state"

# ------------------------------------------------------------------------------
# GROUP 2: Program Flow (PC and current instruction)
# ------------------------------------------------------------------------------
set g [add_wave_group "Program Flow"]
aw $g $tb/bus_pc                        #7CFC00 hex "PC"
aw $g $dut/u_cpu/Datapath/d_out_IR      #6495ED hex "IR"
aw $g $dut/u_cpu/Controller/opcode      #C0C0C0 hex

# ------------------------------------------------------------------------------
# GROUP 3: CPU <-> Memory bus
# ------------------------------------------------------------------------------
set g [add_wave_group "Bus"]
aw $g $tb/bus_addr        #FF7F50 hex
aw $g $tb/bus_read_en     #FFA500 bin
aw $g $tb/bus_write_en    #FFA500 bin
aw $g $tb/bus_wdata       #FF00FF hex
aw $g $dut/cpu_rdata      #ADD8E6 hex
# bus_mem_ready is not connected in the TB, so take the internal signal
aw $g $dut/bus_mem_ready  #00FF00 bin "mem_ready"

# ------------------------------------------------------------------------------
# GROUP 4: Memory System (controller + SRAM)
# ------------------------------------------------------------------------------
set g [add_wave_group "Memory System"]
aw $g $dut/u_mem/ctr_unit/p_state  #FFFF00 default "mem_state"
aw $g $dut/u_mem/mem_unit/ena      #00FFFF bin
aw $g $dut/u_mem/mem_unit/wea      #FF7F50 bin
aw $g $dut/u_mem/mem_unit/addra    #FFA500 hex

# ------------------------------------------------------------------------------
# GROUP 5: Register File (full array, expandable)
# ------------------------------------------------------------------------------
set g [add_wave_group "Register File"]
aw $g $dut/u_cpu/Datapath/RF1/mem  #C0C0C0 hex "RF"

# ------------------------------------------------------------------------------
# GROUP 6: Verification & Status
# ------------------------------------------------------------------------------
set g [add_wave_group "Verification & Status"]
aw $g $tb/cycles  #00FFFF unsigned
aw $g $tb/done    #00FF00 bin

puts "CPU_system_tb waveforms loaded. Run 'run all'."