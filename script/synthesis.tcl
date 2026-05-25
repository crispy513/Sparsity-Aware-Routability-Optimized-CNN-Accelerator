#   Read in RTL modules
set search_path "$search_path ../src ../src/GIN ../src/GON"
set rtl_files [list \
    ../src/GIN/GIN_MulticastController.v \
    ../src/GIN/GIN_Bus.v \
    ../src/GIN/GIN_local.v \
    ../src/GIN/GIN_cluster.sv \
    ../src/GON/GON_MulticastController.v \
    ../src/GON/GON_Bus.v \
    ../src/GON/GON_local.v \
    ../src/GON/GON_cluster.sv \
    ../src/GON/GON.v \
    ../src/PE.sv \
    ../src/PE_cluster.sv \
    ../src/rv_pipe_reg.sv \
    ../src/PE_array.sv \
]
analyze -format sverilog $rtl_files

#   SET top module
elaborate PE_array
current_design PE_array
link

#   Set Design Environment
set_host_options -max_core 8
source ../script/DC.sdc
check_design

#   Distinguish multiple duplicate module
uniquify

set_fix_multiple_port_nets -all -buffer_constants [get_designs *]

#   Minimize area
set_max_area 0

#   Synthesize circuit
compile
compile -inc -only_hold_time

#   Create Report
#   timing report(setup time)
report_timing -path full -delay max -nworst 1 -max_paths 1 -significant_digits 4 -sort_by group > ../syn/top_timing_max_rpt.txt
#   timing report(hold time)
report_timing -path full -delay min -nworst 1 -max_paths 1 -significant_digits 4 -sort_by group > ../syn/top_timing_min_rpt.txt
#   area report
report_area -nosplit > ../syn/top_area_rpt.txt
#   report power
report_power -analysis_effort low > ../syn/top_power_rpt.txt

#   Save syntheized file
write -hierarchy -format verilog -output {../syn/top_syn.v}
write_sdf -version 3.0 -context verilog {../syn/top_syn.sdf}

