# ==============================================================================
# File: wave_Memory.tcl
# Description: Waveform layout for Memory_tb (DUT: memory_system)
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
aw $g /Memory_tb/clk    #FFFF00 bin
aw $g /Memory_tb/rst_n  #FF0000 bin

# ------------------------------------------------------------------------------
# GROUP 2: Bus Request (DUT inputs)
# ------------------------------------------------------------------------------
set g [add_wave_group "Bus Request"]
aw $g /Memory_tb/addr      #FFA500 hex
aw $g /Memory_tb/data_in   #ADD8E6 hex
aw $g /Memory_tb/write_en  #FF7F50 bin
aw $g /Memory_tb/read_en   #00FFFF bin

# ------------------------------------------------------------------------------
# GROUP 3: Bus Response (DUT outputs)
# ------------------------------------------------------------------------------
set g [add_wave_group "Bus Response"]
aw $g /Memory_tb/mem_ready  #00FF00 bin
aw $g /Memory_tb/data_out   #6495ED hex
aw $g /Memory_tb/read_data  #FF00FF hex

# ------------------------------------------------------------------------------
# GROUP 4: Memory Controller FSM (WAIT / WRITE / READ_1 / READ_2)
# ------------------------------------------------------------------------------
set g [add_wave_group "Memory Controller"]
aw $g /Memory_tb/dut/ctr_unit/p_state    #FFFF00 default "p_state"
aw $g /Memory_tb/dut/ctr_unit/n_state    #C0C0C0 default "n_state"
aw $g /Memory_tb/dut/ctr_unit/mem_ready  #00FF00 bin

# ------------------------------------------------------------------------------
# GROUP 5: Internal SRAM (data_sram)
# ------------------------------------------------------------------------------
set g [add_wave_group "SRAM (data_sram)"]
aw $g /Memory_tb/dut/mem_unit/ena    #00FFFF bin
aw $g /Memory_tb/dut/mem_unit/wea    #FF7F50 bin
aw $g /Memory_tb/dut/mem_unit/addra  #FFA500 hex
aw $g /Memory_tb/dut/mem_unit/dina   #ADD8E6 hex
aw $g /Memory_tb/dut/mem_unit/douta  #6495ED hex

# ------------------------------------------------------------------------------
# GROUP 6: Reset injection handshake (random asynchronous reset)
# ------------------------------------------------------------------------------
set g [add_wave_group "Reset Injection"]
aw $g /Memory_tb/reset_en    #FFFFFF bin
aw $g /Memory_tb/reset_busy  #FF0000 bin
aw $g /Memory_tb/reset_hit   #FF7F50 bin
aw $g /Memory_tb/rst_hits    #C0C0C0 unsigned

# ------------------------------------------------------------------------------
# GROUP 7: Verification & Status
# ------------------------------------------------------------------------------
set g [add_wave_group "Verification & Status"]
aw $g /Memory_tb/num_errors  #FF0000 unsigned

puts "Memory_tb waveforms loaded. Run 'run all' (or 'run 100 us')."