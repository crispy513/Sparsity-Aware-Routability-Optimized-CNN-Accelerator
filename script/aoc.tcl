# JasperGold Superlint AOC (Arithmetic Overflow Check)
# Run from the script directory, for example:
#   jg -superlint -batch aoc.tcl

clear -all

# ----------------------------------------------------------------------
# Config rules
# Keep the same noisy-rule waivers used in the previous superlint.tcl,
# but leave the arithmetic-overflow Auto Formal checks enabled.
# ----------------------------------------------------------------------
config_rtlds -rule -enable -domain { LINT AUTO_FORMAL }

config_rtlds -rule -disable -tag { CAS_IS_DFRC SIG_IS_DLCK SIG_NO_TGFL SIG_NO_TGRS SIG_NO_TGST FSM_NO_MTRN FSM_NO_TRRN }
config_rtlds -rule -disable -category { NAMING AUTO_FORMAL_DEAD_CODE AUTO_FORMAL_SIGNALS AUTO_FORMAL_FSM AUTO_FORMAL_CASE AUTO_FORMAL_X_ASSIGNMENT AUTO_FORMAL_BUS AUTO_FORMAL_OUT_OF_BOUND_INDEXING AUTO_FORMAL_COMBO_LOOP }
config_rtlds -rule -disable -tag { IDN_NR_SVKY ARY_MS_DRNG IDN_NR_AMKY IDN_NR_CKYW IDN_NR_SVKW ARY_NR_LBND VAR_NR_INDL INS_NR_PTEX INP_NO_USED OTP_NR_ASYA FLP_NR_MXCS OTP_UC_INST OTP_NR_UDRV REG_NR_TRRC INS_NR_INPR MOD_NS_GLGC }
config_rtlds -rule -disable -tag { REG_NR_RWRC }
config_rtlds -rule -disable -tag { BUS_IS_FLOT ASG_IS_XRCH }

# AOC target rules.
config_rtlds -rule -enable -category { AUTO_FORMAL_ARITHMETIC_OVERFLOW }
config_rtlds -rule -enable -tag { ASG_AR_OVFL EXP_AR_OVFL }

# ----------------------------------------------------------------------
# Read RTL
# top.sv includes the GLB, sparse codec, and PE array hierarchy.
# The project uses `include "define.svh"` and `include "src/..."`,
# so ../ and ../src must both be in the include search path.
# ----------------------------------------------------------------------
analyze -sv \
    +incdir+.. \
    +incdir+../src \
    ../src/top.sv

elaborate -bbox true -top top_with_glb

# ----------------------------------------------------------------------
# Clock and reset
# ----------------------------------------------------------------------
clock clk
reset rst

# ----------------------------------------------------------------------
# Extract and prove AOC checks
# ----------------------------------------------------------------------
set_superlint_prove_parallel_tasks on
set_prove_no_traces true

check_superlint -extract
check_superlint -prove
