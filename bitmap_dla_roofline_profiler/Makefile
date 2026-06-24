LAB4_ROOT := $(abspath .)

CC ?= gcc

RESET  := \033[0m
GREY   := \033[0;37m
WHITE  := \033[1;37m
GREEN  := \033[0;32m
RED    := \033[0;31m
CYAN   := \033[0;36m
YELLOW := \033[0;33m

define msg_grey
	@printf "$(GREY)$(1)$(RESET)\n"
endef
define msg_green
	@printf "$(GREEN)$(1)$(RESET)\n\n"
endef
define msg_red
	@printf "$(RED)$(1)$(RESET)\n"
endef
define msg_white
	@printf "$(WHITE)$(1)$(RESET)\n"
endef
define msg_cyan
	@printf "$(CYAN)$(1)$(RESET)\n"
endef
define msg_yellow
	@printf "$(YELLOW)$(1)$(RESET)\n"
endef

.PHONY: all hardware hardware_cpu hardware_dla cpu dla \
        run_cpu run_cpu_original run_cpu_improve run_dla run_all clean help \
        run_cpu_case0 run_cpu_case1 run_cpu_case2 \
        run_cpu_fallback_linear run_cpu_fallback_linear_relu \
        run_dla_case0 run_dla_case1 run_dla_case2 \
        clean_hw clean_hw_cpu clean_hw_dla \
        clean_runtime clean_runtime_cpu clean_runtime_dla

help:
	@echo "Usage: make [target] [OPTIONS]"
	@echo ""
	@echo "Options:"
	@echo "  CPU targets"
	@echo "     IMPROVE=1   Select 'improve' runtime mode (default: original)"
	@echo "     DIAG=1      Print first 16 element-wise mismatches on failure"
	@echo "  DLA targets"
	@echo "     INFO=1      Dump DLA statistics to build/dla_info_caseN.csv"
	@echo "     DEBUG=1     Print DLA HAL verbose log (MMIO R/W, DMA R/W addr+data, IRQ)"
	@echo "     DLA_HW=bitmap or USE_BITMAP_WRAPPER=1"
	@echo "                  Build/run the bitmap wrapper backend (default: origin)"
	@echo "     IFMAP_BITMAP=1"
	@echo "                  Enable bitmap-compressed IFMAP on bitmap DLA backend"
	@echo ""
	@echo "Run targets — individual cases:"
	@echo "  run_cpu_caseN                  - Run CPU case N (N = 0..2)"
	@echo "  run_cpu_fallback_linear        - Run LINEAR fallback"
	@echo "  run_cpu_fallback_linear_relu   - Run LINEAR_RELU fallback"
	@echo "  run_dla_caseN                  - Run DLA case N (N = 0..2)"
	@echo ""
	@echo "Run targets — batch:"
	@echo "  run_cpu                        - Run all CPU cases (original & improve)"
	@echo "  run_cpu_original               - Run all CPU cases (original only)"
	@echo "  run_cpu_improve                - Run all CPU cases (improve only)"
	@echo "  run_dla                        - Run all DLA cases"
	@echo "  run_all                        - Run everything (DLA & CPU improve)"
	@echo ""
	@echo "Clean targets:"
	@echo "  clean                          - Clean all build artifacts"
	@echo "  clean_hw                       - Clean both hardware Verilated libs"
	@echo "  clean_hw_cpu                   - Clean CPU (NutShell) Verilated lib"
	@echo "  clean_hw_dla                   - Clean DLA Verilated lib"
	@echo "  clean_runtime                  - Clean all runtime ELFs + testbench artifacts"
	@echo "  clean_runtime_cpu              - Clean CPU runtime ELFs + CPU testbench"
	@echo "  clean_runtime_dla              - Clean DLA testbench artifacts"
	@echo ""

# ============================================================
# hardware - build Verilated libraries for CPU and DLA
# ============================================================

hardware_cpu:
	$(call msg_grey,[ROOT] Building NutShell Verilated library...)
	$(MAKE) -C src/hardware/cpu

hardware_dla:
	$(call msg_grey,[ROOT] Building DLA $(_DLA_HW) Verilated library...)
	$(MAKE) -C src/hardware/dla_$(_DLA_HW) EXTRA_DEFS='$(_DLA_EXTRA_DEFS)'

hardware: hardware_cpu hardware_dla

# ============================================================
# cpu — build RV64 ELFs + CPU testbench executable
# ============================================================

cpu: hardware_cpu
	$(call msg_grey,[ROOT] Building RV64 ELFs...)
	$(MAKE) -C src/runtime/cpu
	$(call msg_grey,[ROOT] Building CPU testbench...)
	$(MAKE) -C test/testbench/cpu tb

# ============================================================
# dla — build DLA testbench
# ============================================================

dla: hardware_dla
	$(call msg_grey,[ROOT] Building DLA testbench...)
	$(MAKE) -C test/testbench/dla all DLA_HW='$(_DLA_HW)' EXTRA_DEFS='$(_DLA_EXTRA_DEFS)'

# ============================================================
# all - build hardware + runtimes + testbenches
# ============================================================

all: cpu dla

# ============================================================
# run targets — individual case shortcuts
# ============================================================

_CPU_VARIANT    := $(if $(filter 1,$(IMPROVE)),improve,original)
_CPU_TB_FLAGS   := $(if $(filter 1,$(DIAG)),--diag) $(if $(filter 1,$(TRACE)),--trace)
_DLA_EXTRA_DEFS := $(if $(filter 1,$(INFO)),-DDLA_INFO) $(if $(filter 1,$(TRACE)),-DUSE_FST) $(if $(filter 1,$(DEBUG)),-DDEBUG) $(if $(filter 1,$(IFMAP_BITMAP)),-DDLA_BITMAP_IFMAP)
_DLA_HW         := $(if $(filter 1,$(USE_BITMAP_WRAPPER)),bitmap,$(if $(DLA_HW),$(DLA_HW),origin))
BUILD_DIR       := $(LAB4_ROOT)/build

run_cpu_case0:
	$(call msg_grey,[ROOT] Building case0 ELF ($(_CPU_VARIANT))...)
	$(MAKE) -B -C src/runtime/cpu case0_$(_CPU_VARIANT)
	$(call msg_cyan,[ROOT] Running CPU case0 $(_CPU_VARIANT)...)
	$(MAKE) -C test/testbench/cpu run_case0_$(_CPU_VARIANT) TB_ARGS='$(_CPU_TB_FLAGS)'

run_cpu_case1:
	$(call msg_grey,[ROOT] Building case1 ELF ($(_CPU_VARIANT))...)
	$(MAKE) -B -C src/runtime/cpu case1_$(_CPU_VARIANT)
	$(call msg_cyan,[ROOT] Running CPU case1 $(_CPU_VARIANT)...)
	$(MAKE) -C test/testbench/cpu run_case1_$(_CPU_VARIANT) TB_ARGS='$(_CPU_TB_FLAGS)'

run_cpu_case2:
	$(call msg_grey,[ROOT] Building case2 ELF ($(_CPU_VARIANT))...)
	$(MAKE) -B -C src/runtime/cpu case2_$(_CPU_VARIANT)
	$(call msg_cyan,[ROOT] Running CPU case2 $(_CPU_VARIANT)...)
	$(MAKE) -C test/testbench/cpu run_case2_$(_CPU_VARIANT) TB_ARGS='$(_CPU_TB_FLAGS)'

run_cpu_fallback_linear:
	$(call msg_grey,[ROOT] Building case_cpu_fallback_linear ELF ($(_CPU_VARIANT))...)
	$(MAKE) -B -C src/runtime/cpu case_cpu_fallback_linear_$(_CPU_VARIANT)
	$(call msg_cyan,[ROOT] Running CPU case_cpu_fallback_linear $(_CPU_VARIANT)...)
	$(MAKE) -C test/testbench/cpu run_case_cpu_fallback_linear_$(_CPU_VARIANT) TB_ARGS='$(_CPU_TB_FLAGS)'

run_cpu_fallback_linear_relu:
	$(call msg_grey,[ROOT] Building case_cpu_fallback_linear_relu ELF ($(_CPU_VARIANT))...)
	$(MAKE) -B -C src/runtime/cpu case_cpu_fallback_linear_relu_$(_CPU_VARIANT)
	$(call msg_cyan,[ROOT] Running CPU case_cpu_fallback_linear_relu $(_CPU_VARIANT)...)
	$(MAKE) -C test/testbench/cpu run_case_cpu_fallback_linear_relu_$(_CPU_VARIANT) TB_ARGS='$(_CPU_TB_FLAGS)'

run_dla_case0:
	$(call msg_grey,[ROOT] Building DLA case0 testbench...)
	$(MAKE) -B -C test/testbench/dla case0 EXTRA_DEFS='$(_DLA_EXTRA_DEFS)' DLA_HW='$(_DLA_HW)'
	$(call msg_cyan,[ROOT] Running DLA case0...)
	$(MAKE) -C test/testbench/dla run0 EXTRA_DEFS='$(_DLA_EXTRA_DEFS)' DLA_HW='$(_DLA_HW)'

run_dla_case1:
	$(call msg_grey,[ROOT] Building DLA case1 testbench...)
	$(MAKE) -B -C test/testbench/dla case1 EXTRA_DEFS='$(_DLA_EXTRA_DEFS)' DLA_HW='$(_DLA_HW)'
	$(call msg_cyan,[ROOT] Running DLA case1...)
	$(MAKE) -C test/testbench/dla run1 EXTRA_DEFS='$(_DLA_EXTRA_DEFS)' DLA_HW='$(_DLA_HW)'

run_dla_case2:
	$(call msg_grey,[ROOT] Building DLA case2 testbench...)
	$(MAKE) -B -C test/testbench/dla case2 EXTRA_DEFS='$(_DLA_EXTRA_DEFS)' DLA_HW='$(_DLA_HW)'
	$(call msg_cyan,[ROOT] Running DLA case2...)
	$(MAKE) -C test/testbench/dla run2 EXTRA_DEFS='$(_DLA_EXTRA_DEFS)' DLA_HW='$(_DLA_HW)'

run_cpu_original:
	$(call msg_grey,[ROOT] Building case ELFs (original)...)
	$(MAKE) -B -C src/runtime/cpu case0_original case1_original case2_original \
	    case_cpu_fallback_linear_original case_cpu_fallback_linear_relu_original
	$(call msg_cyan,[ROOT] Running CPU cases (original)...)
	@pass_count=0; total_count=5; \
	for c in 0 1 2; do \
	    $(MAKE) -C test/testbench/cpu run_case$$c\_original TB_ARGS='$(_CPU_TB_FLAGS)' && pass_count=$$((pass_count+1)) || true; \
	done; \
	for n in case_cpu_fallback_linear case_cpu_fallback_linear_relu; do \
	    $(MAKE) -C test/testbench/cpu run_$${n}_original TB_ARGS='$(_CPU_TB_FLAGS)' && pass_count=$$((pass_count+1)) || true; \
	done; \
	printf "\n"; \
	if [ $$pass_count -eq $$total_count ]; then \
	    printf "\033[0;32m[TB/CPU original] ALL TESTS PASSED ($$pass_count/$$total_count)\033[0m\n\n"; \
	else \
	    printf "\033[0;31m[TB/CPU original] FAILED ($$pass_count/$$total_count passed)\033[0m\n\n"; \
	    exit 1; \
	fi

run_cpu_improve:
	$(call msg_grey,[ROOT] Building case ELFs (improve)...)
	$(MAKE) -B -C src/runtime/cpu case0_improve case1_improve case2_improve \
	    case_cpu_fallback_linear_improve case_cpu_fallback_linear_relu_improve
	$(call msg_cyan,[ROOT] Running CPU cases (improve)...)
	@pass_count=0; total_count=5; \
	for c in 0 1 2; do \
	    $(MAKE) -C test/testbench/cpu run_case$$c\_improve TB_ARGS='$(_CPU_TB_FLAGS)' && pass_count=$$((pass_count+1)) || true; \
	done; \
	for n in case_cpu_fallback_linear case_cpu_fallback_linear_relu; do \
	    $(MAKE) -C test/testbench/cpu run_$${n}_improve TB_ARGS='$(_CPU_TB_FLAGS)' && pass_count=$$((pass_count+1)) || true; \
	done; \
	printf "\n"; \
	if [ $$pass_count -eq $$total_count ]; then \
	    printf "\033[0;32m[TB/CPU improve] ALL TESTS PASSED ($$pass_count/$$total_count)\033[0m\n\n"; \
	else \
	    printf "\033[0;31m[TB/CPU improve] FAILED ($$pass_count/$$total_count passed)\033[0m\n\n"; \
	    exit 1; \
	fi

run_cpu: run_cpu_original run_cpu_improve

run_dla:
	$(call msg_grey,[ROOT] Running DLA all cases...)
	@pass_count=0; total_count=3; \
	for c in 0 1 2; do \
	    $(MAKE) -B -C test/testbench/dla case$$c EXTRA_DEFS='$(_DLA_EXTRA_DEFS)' DLA_HW='$(_DLA_HW)' && \
	    $(MAKE) -C test/testbench/dla run$$c EXTRA_DEFS='$(_DLA_EXTRA_DEFS)' DLA_HW='$(_DLA_HW)' && pass_count=$$((pass_count+1)) || true; \
	done; \
	printf "\n"; \
	if [ $$pass_count -eq $$total_count ]; then \
	    printf "\033[0;32m[TB/DLA] ALL TESTS PASSED ($$pass_count/$$total_count)\033[0m\n\n"; \
	else \
	    printf "\033[0;31m[TB/DLA] FAILED ($$pass_count/$$total_count passed)\033[0m\n\n"; \
	    exit 1; \
	fi

run_all: run_cpu_improve run_dla

# ============================================================
# clean targets
# ============================================================

clean_hw_cpu:
	$(call msg_grey,[ROOT] Cleaning hardware/cpu...)
	$(MAKE) -C src/hardware/cpu clean

clean_hw_dla:
	$(call msg_grey,[ROOT] Cleaning DLA hardware variants...)
	$(MAKE) -C src/hardware/dla_origin clean
	$(MAKE) -C src/hardware/dla_bitmap clean

clean_hw: clean_hw_cpu clean_hw_dla

clean_runtime_cpu:
	$(call msg_grey,[ROOT] Cleaning runtime/cpu ELFs...)
	$(MAKE) -C src/runtime/cpu clean
	$(MAKE) -C test/testbench/cpu clean

clean_runtime_dla:
	$(call msg_grey,[ROOT] Cleaning runtime/dla + DLA testbench...)
	$(MAKE) -C test/testbench/dla clean

clean_runtime: clean_runtime_cpu clean_runtime_dla

clean: clean_hw clean_runtime
	@rm -rf $(BUILD_DIR)
	$(call msg_green,[ROOT] Done.)

.PHONY: run_all_analysis sparsity_sweep roofline

# 定義稀疏度測試的級距 (0 到 90)
SWEEP_LEVELS := 0 10 20 30 40 50 60 70 80 90

run_all_analysis:
	@printf "\033[0;36m[AUTO] 階段 1: 開始執行標準測試 cases (case0 ~ case2)...\033[0m\n"
	@$(MAKE) run_dla
	@printf "\n"
	@printf "\033[0;36m[AUTO] 階段 2: 標準測試完成，正在初始化稀疏度資料表...\033[0m\n"
	@echo "sparsity,cycles,mem_reads,mem_writes" > test/testbench/dla/sparsity_sweep_data.csv
	@printf "\n"
	@printf "\033[0;36m[AUTO] 階段 3: 開始執行 0 到 90 稀疏度掃描實驗...\033[0m\n"
	@$(MAKE) sparsity_sweep
	@printf "\n"
	@printf "\033[0;36m[AUTO] 階段 4: 所有數據收集完畢，呼叫 Python 繪製稀疏度趨勢圖...\033[0m\n"
	@python3 plot_sweep.py || echo "\033[0;31m[ERR] 繪圖失敗，請確認是否安裝 pandas 與 matplotlib\033[0m"
	@printf "\033[0;32m[AUTO] 所有 case 測試、Roofline 與 Sparsity 分析皆完成\033[0m\n"

# 內部隱藏目標：走進 dla 資料夾，並透過迴圈連續注入巨集進行硬體模擬
sparsity_sweep:
	@for s in $(SWEEP_LEVELS); do \
	    printf "\033[0;33m[Sparsity Sweep] === 正在測試 權重稀疏度: $${s} ===\033[0m\n"; \
	    rm -f test/testbench/dla/build/tb_dla_case2; \
	    $(MAKE) -C test/testbench/dla run2 \
	        EXTRA_DEFS='$(_DLA_EXTRA_DEFS) -DSPARSITY_PERCENT='"$${s}" \
	        DLA_HW='$(_DLA_HW)'; \
	done

roofline:
	@rm -f test/testbench/dla/roofline_data.csv
	@printf "\n\033[0;36m[AUTO] 階段 1: 使用 Origin 版本執行全部 case...\033[0m\n"
	@$(MAKE) run_dla DLA_HW=origin
	@printf "\n\033[0;36m[AUTO] 階段 2: 使用 Bitmap 版本執行全部 case...\033[0m\n"
	@$(MAKE) run_dla DLA_HW=bitmap
	@printf "\n\033[0;36m[AUTO] 階段 3: 讀取所有數據，繪製純 PE 效能對比圖...\033[0m\n"
	@python3 roofline.py
	@printf "\033[0;32m[AUTO] Roofline 測試完成！\033[0m\n"

.PHONY: DEMO

DEMO:
	@$(call msg_green,[ROOT] 啟動 MNIST DEMO (未使用 bitmap)...)
	@$(MAKE) -s -C test/testbench/dla run_demo USE_BITMAP_WRAPPER=0 DLA_HW=origin
	@$(call msg_green,[ROOT] 啟動 MNIST DEMO (使用 bitmap 進行加速)...)
	@$(MAKE) -s -C test/testbench/dla run_demo USE_BITMAP_WRAPPER=1 DLA_HW=bitmap

generate:
	@echo "[*] 正在生成測試圖片..."
	@cd test/testbench/dla && python3 generate_test_img.py	