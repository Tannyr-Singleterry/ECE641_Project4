# (C) 2001-2025 Altera Corporation. All rights reserved.
# Your use of Altera Corporation's design tools, logic functions and other 
# software and tools, and its AMPP partner logic functions, and any output 
# files from any of the foregoing (including device programming or simulation 
# files), and any associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License Subscription 
# Agreement, Altera IP License Agreement, or other applicable 
# license agreement, including, without limitation, that your use is for the 
# sole purpose of programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the applicable 
# agreement for further details.


# (C) 2001-2024 Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions and other 
# software and tools, and its AMPP partner logic functions, and any output 
# files from any of the foregoing (including device programming or simulation 
# files), and any associated documentation or information are expressly subject 
# to the terms and conditions of the Intel Program License Subscription 
# Agreement, Intel FPGA IP License Agreement, or other applicable 
# license agreement, including, without limitation, that your use is for the 
# sole purpose of programming logic devices manufactured by Intel and sold by 
# Intel or its authorized distributors.  Please refer to the applicable 
# agreement for further details.


# $Revision: #1 
# $Date: 2017/07/31 
# $Author: zkumar 

#-------------------------------------------------------------------------------
# TimeQuest constraints to constrain the timing across asynchronous clock domain crossings.
# The idea is to minimize skew to between stp_status_bits_in_reg_acq (acq domain) and stp_status_bits_out_reg_tck (tck domain)
# 
# CDC takes place between these paths (in intel_stp_status_bits_cdc component)
#

# -----------------------------------------------------------------------------
# This procedure constrains the max_delay (not skew) between the status bit regs.
#
# The hierarchy path to the status_bits CDC instance is required as an 
# argument.
# -----------------------------------------------------------------------------
package require cmdline

proc constrain_signaltap_status_bits_max_delay { path } {

    ########################################## Original constraint ########################################## 
    post_message -type info "DEBUG: Top targeted path = $path"

    #set the to/from paths for stp_status_bits
    set path_from $path|stp_status_bits_in_reg_acq\[*\]
    set path_to $path|stp_status_bits_out_reg_tck\[*\]

    #check if the paths to be constrained exist or not
    set paths_from [get_registers -nowarn $path_from]
    set paths_to [get_registers -nowarn $path_to]
    set num_status_paths_from [get_collection_size $paths_from]
    set num_status_paths_to [get_collection_size $paths_to]
    post_message -type info "DEBUG: paths detected for *stp_status_bits_in_reg_acq* = $num_status_paths_from"
    post_message -type info "DEBUG: paths detected for *stp_status_bits_out_reg_tck* = $num_status_paths_to"

    #if either "to" or "from" paths donot exist, exit the .sdc gracefully
    if {$num_status_paths_to > 0} {
        
       set tck_clk [get_fanins $paths_to -clock -stop_at_clocks]
       set num_tck_clk [get_collection_size $tck_clk]
       post_message -type info "DEBUG: num_tck_clk = $num_tck_clk"
       
    } else {
    
       set num_tck_clk 0
       post_message -type info "DEBUG: num_tck_clk without get_fanin = $num_tck_clk"
       
    }
    
    post_message -type info "DEBUG: paths detected for *tck_clk* = $num_tck_clk"

    if {$num_status_paths_from == 0 || $num_status_paths_to == 0 || $num_tck_clk == 0 } {
    
        post_message -type info "Status exchange path between acquisition clock and communication clock in the Signal Tap instance, [get_current_instance] is synthesized out.  No constraint is added on this path."
        
    } else {
        
        post_message -type info "Constraints on the CDC paths between acquisition clock and communication clock are created in the Signal Tap instance, [get_current_instance]"
        #call to function to get the tck domain name and period
        # post_message -type warning "DEBUG: my path = $path|stp_status_bits_out_reg_tck*"
        set max_delay_prd [expr [get_tck_info $path_to $tck_clk]]
        # post_message -type warning "DEBUG: max delay is 1xtck_clk_prd = $max_delay_prd"

        #set the max delay as function of dst clk period (i.e. tck clk prd) so that -
        #1) to make the delay settings more relaxed (more than 1ns), between i/p and o/p status bits 
        #2) to ensure the max delay can be used when acq clk > tck clk and vice-versa
        #max delay is 1xtck clk period (because valid bit takes ~3 cycles to go from acq to tck domain)

        set_max_delay -from $paths_from  -to $paths_to  $max_delay_prd
        
        
        ########################################## New constraint ########################################## 
        # post_message -type info "DEBUG: Targeted path = $path"
        set new_path_from $path|stp_status_bits_in_reg_acq\[0]
        set new_path_to $path|stp_status_bits_out_reg_tck\[0]

        ## check if the paths to be constrained exist or not
        set new_paths_from [get_registers -nowarn $new_path_from]  
        set new_paths_to [get_registers -nowarn $new_path_to]   
        
        
        # set num_status_paths_to [get_collection_size $new_paths_to]
        # post_message -type info "DEBUG: paths detected for *stp_status_bits_out_reg_tck* = $num_status_paths_to"
        # foreach_in_collection path $new_paths_to {
        #   set name [get_register_info -name $path]
        #   post_message -type info "DEBUG: TCK path = $name"
        # } 

        ################################### Get the fanouts of the TCK clock domain ########################################################
        ## Find the clock source that connected to the known path
        set tck_clock_collection [get_clocks -of_objects $new_paths_to]
        # foreach_in_collection tck_clk $tck_clock_collection {
        #   set name [get_clock_info -name $tck_clk]
        #   post_message -type info "DEBUG: TCK clock name = $name"
        # }
        
        set num_tck_clk_collection [get_collection_size $tck_clock_collection]
        # post_message -type info "DEBUG: Number of *tck clk collection* = $num_tck_clk_collection"
        
        if {$num_tck_clk_collection == 1} {  
            
            ## Execute only if able to identify the clock source using get_clocks function
            set registers_in_tck_clock_domain [get_fanout_registers_in_clock_domain -clock_col $tck_clock_collection]
            
        } else {
        
            ## Find the clock node that connected to the known path (Target the undefined clock)
            # post_message -type info "DEBUG: tck path = $new_path_to"
            set tck_clock_object [get_fanins $new_paths_to -clock -stop_at_clocks]
            set num_tck_clock_object [get_collection_size $tck_clock_object]
            # post_message -type info "DEBUG: Number of *tck_clock_object* = $num_tck_clock_object"
            
            if {$num_tck_clock_object > 0} {
            
                ## Find the name of the clock node
                set tck_clock_collection [get_clk_name $tck_clock_object]
                # foreach_in_collection tck_clk $tck_clock_collection {
                #   set name [get_clock_info -name $tck_clk]
                #   post_message -type info "DEBUG: TCK clock name = $name"
                # }
                    
                set registers_in_tck_clock_domain [get_fanouts $tck_clock_collection]
            }
        }


        set special_path "auto_fab_0|alt_sld_fab_0|alt_sld_fab_0|sldfabric_1|jtag_hub_gen.real_sld_jtag_hub|irf_reg[*][*]"
        set special_registers [get_registers -nowarn -no_duplicate $special_path]
        set num_special_register [get_collection_size $special_registers]


        # post_message -type info "#################################################################################"
        # post_message -type info "#################################################################################"
        # set num_status_paths_from [get_collection_size $new_paths_from]
        # post_message -type info "DEBUG: paths detected for *stp_status_bits_in_reg_acq* = $num_status_paths_from"
        foreach_in_collection path $new_paths_from {

            set current_path_name [get_register_info -name $path]
            # post_message -type info "DEBUG: ACQ path = $current_path_name"
            set path_name [split $current_path_name |]
            set simplified_path_name [lreplace $path_name 4 10]
            set main_path [join $simplified_path_name |]
            # post_message -type info "DEBUG: ACQ main path = $main_path"


            # Get the STP registers     
            set stp_instance_path $main_path|sld_signaltap_inst|sld_signaltap_body|sld_signaltap_body|*
            set registers_in_stp_instance [get_registers -nowarn -no_duplicates $stp_instance_path|*]
            # set num_registers_in_stp_instance [get_collection_size $registers_in_stp_instance]
            # post_message -type info "DEBUG: paths detected in Signaltap* = $num_registers_in_stp_instance"    


            ################################### Get the fanouts of the ACQ clock domain ########################################################
            ## Find the clock source that connected to the known path
            set acq_clock_collection [get_clocks -of_objects $path]
            # foreach_in_collection acq_clk $acq_clock_collection {
            #   set name [get_clock_info -name $acq_clk]
            #   post_message -type info "DEBUG: ACQ clock name = $name"
            # } 

            set num_acq_clk_collection [get_collection_size $acq_clock_collection]
            # post_message -type info "DEBUG: Number of *acq clk collection* = $num_acq_clk_collection"

            if {$num_acq_clk_collection == 1} {

                ## Execute only if able to identify the clock source using get_clocks function
                set registers_in_acq_clock_domain [get_fanout_registers_in_clock_domain -clock_col $acq_clock_collection]
                
            } else {
                
                ## Find the clock node that connected to the known path (Target the undefined clock)
                # post_message -type info "DEBUG: acq path = $current_path_name"
                set acq_clock_object [ get_fanins $path -clock -stop_at_clocks ]
                set num_acq_object_collection [get_collection_size $acq_clock_object]
                # post_message -type info "DEBUG: Number of *acq object collection* = $num_acq_object_collection"
                
                if {$num_acq_object_collection > 0} {
                
                     # foreach_in_collection acq_object $acq_clock_object {
                     #   set name [get_register_info -name $acq_object]
                     #   post_message -type info "DEBUG: ACQ object name = $name"
                     # } 
                
                     set num_acq_clock_object [get_collection_size $acq_clock_object]
                     # post_message -type info "DEBUG: Number of *acq_clock_object* = $num_acq_clock_object"
                     set acq_clock_node_collection [get_clk_name $acq_clock_object]
                          
                     # Get the fanouts of the ACQ clock domain
                     set registers_in_acq_clock_domain [get_fanouts $acq_clock_node_collection]
                     
                } else {
                
                    break
                
                }
                
            }
            
            
            set num_tck_register [get_collection_size $registers_in_tck_clock_domain]
            # post_message -type info "DEBUG: Number of *registers_in_tck_clock_domain* = $num_tck_register"
            
            set num_acq_register [get_collection_size $registers_in_acq_clock_domain]
            # post_message -type info "DEBUG: Number of *registers_in_acq_clock_domain* = $num_acq_register"
            
            set num_stp_register [get_collection_size $registers_in_stp_instance]
            # post_message -type info "DEBUG: Number of *registers_in_stp_instance* = $num_stp_register"
            
            
            if {$num_tck_register > 0 && $num_acq_register > 0 && $num_stp_register > 0} {
              
                # Get the STP registers in TCK clock domain 
                set registers_outside_stp_in_tck_clock_domain [remove_from_collection $registers_in_tck_clock_domain $registers_in_stp_instance]    
                set registers_in_stp_in_tck_clock_domain [remove_from_collection $registers_in_tck_clock_domain $registers_outside_stp_in_tck_clock_domain] 
                set num_registers_in_stp_in_tck_clock_domain [get_collection_size $registers_in_stp_in_tck_clock_domain]
                # post_message -type info "DEBUG: Signaltap paths detected in TCK domain* = $num_registers_in_stp_in_tck_clock_domain"
                    
                # Get the STP registers in ACQ clock domain 
                set registers_outside_stp_in_acq_clock_domain [remove_from_collection $registers_in_acq_clock_domain $registers_in_stp_instance]
                set registers_in_stp_in_acq_clock_domain [remove_from_collection $registers_in_acq_clock_domain $registers_outside_stp_in_acq_clock_domain]
                set num_registers_in_stp_in_acq_clock_domain [get_collection_size $registers_in_stp_in_acq_clock_domain]
                # post_message -type info "DEBUG: Signaltap paths detected in ACQ domain* = $num_registers_in_stp_in_acq_clock_domain"

                set_false_path -from $registers_in_stp_in_acq_clock_domain -to $registers_in_stp_in_tck_clock_domain 
                set_false_path -from $registers_in_stp_in_tck_clock_domain -to $registers_in_stp_in_acq_clock_domain

                if {$num_special_register > 0} {
                    set_false_path -from $special_registers -to $registers_in_stp_in_acq_clock_domain
                }
            }
        }
    }
}

# -----------------------------------------------------------------------------
# This procedure is to find out the tck clk name and period
#
# The hierarchy path to the status_bits CDC instance is required as an 
# argument.
# -----------------------------------------------------------------------------
proc get_tck_info { filter tck_clk_col} {
    # post_message -type warning "DEBUG: Search for $filter"
    # post_message -type warning "DEBUG: my_tck_clk = $tck_clk_col"

    # A10 & S10 support max 33.3Mhz clock (default, in case tck clk prd is not defined)
    set default_tck_prd 30
    
    foreach_in_collection clk $tck_clk_col {
        set tck_clk_node_name [get_node_info -name $clk]
        # post_message -type warning "DEBUG: tck domain clk name: $tck_clk_node_name"
        set clks [get_clocks -nowarn -of_objects [get_registers $filter]]
        # post_message -type warning "DEBUG: $clks [llength $clks] get_clocks -of_objects \[get_registers $filter\]"

        ##check if tck clk period has been previously declared or not
        if {[get_collection_size $clks] == 0} {
                # post_message -type warning "DEBUG: tck clk period is not defined, setting max delay to 30ns (default 33MHz tck)"
                post_message -type info "The clock period of '$tck_clk_node_name' used in the Signal Tap instance, [get_current_instance] is not defined, setting max delay to 30ns (default 33MHz tck)"
                set tck_clk_prd $default_tck_prd
                # post_message -type warning "DEBUG: tck domain period (default): $tck_clk_prd"
        } else {
            # In the case of multiple clock definitions, arbitrarily use the first clock in the list
            foreach_in_collection clk $clks {
                set tck_clk_prd [get_clock_info $clk -period]
                # post_message -type warning "DEBUG: tck domain period: $tck_clk_prd"  
                break
            }
        }        

       
    }

    return $tck_clk_prd

}


proc get_clk_name { clk_col } {

    # post_message -type warning "DEBUG: Clock collection = $clk_col"

    foreach_in_collection clk $clk_col {
    
        set clk_node_name [get_node_info -name $clk]
         
        # post_message -type info "DEBUG: New proc clk name: $clk_node_name"    
    }

    return $clk_node_name

}


proc get_fanout_registers_in_clock_domain { args } {

    ## This procedure is to prevent the duplicated path when the ACQ clock has relationship with TCK clock 

    set options {
        { "clock_col.arg" "" "Clock(s) feeding known register name" }
    }
    array set opts [::cmdline::getoptions args $options]
    
    # Need to get back to the clock names in ascii
    set clock_names [query_collection -list -all $opts(clock_col)]
    
    # Need to know all clock and derived clocks from the initial collection
    set this_and_derived_clocks [get_clocks -include_generated_clocks $clock_names]
    
    set target_col [get_clock_info -targets $opts(clock_col)]
    set fanouts_from_clock_col [get_fanouts $target_col]
    set num_fanouts_from_clock_col [get_collection_size $fanouts_from_clock_col]
    # post_message -type info "DEBUG: Number of *num_fanouts_from_clock_col* = $num_fanouts_from_clock_col"
    
    # Now we need to prune stopped clock targets from the collection
    foreach_in_collection clock_object $this_and_derived_clocks {
    
        set test_name [get_clock_info -name $clock_object]
        puts "checking $test_name against $clock_names"
        if { $test_name in $clock_names } {
        
            # This is one of the starting clocks, it won't be in the fanout
            # collection, so we can skip it
            continue
            
        }
          
        set clock_object_targets [get_clock_info -targets $clock_object]
        set num_clock_object_targets [get_collection_size $clock_object_targets]
        # post_message -type info "DEBUG: Number of *clock_object_targets* = $num_clock_object_targets"


        set clock_object_collection [get_fanouts $clock_object_targets]
        set num_clock_object_collection [get_collection_size $clock_object_collection]
        # post_message -type info "DEBUG: Number of *num_clock_object_collection* = $num_clock_object_collection"

        if {$num_clock_object_collection > 0 && $num_fanouts_from_clock_col > 0} {
          
            set fanouts_from_clock_col [remove_from_collection $fanouts_from_clock_col $clock_object_collection]
                
        }
    }
    return $fanouts_from_clock_col
}

constrain_signaltap_status_bits_max_delay "[get_current_instance]|sld_signaltap_inst|sld_signaltap_body|sld_signaltap_body|jtag_acq_clk_xing|intel_stp_status_bits_cdc_u1"
