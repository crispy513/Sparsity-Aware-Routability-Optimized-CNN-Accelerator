// dla_hal.cpp — DlaHAL implementation

#include "dla_hal.hpp"

#include <cstdio>
#include <cstring>

#include "Vasic_wrapper___024root.h"

#ifndef DLA_IRQ_TIMEOUT_CYCLE
#define DLA_IRQ_TIMEOUT_CYCLE 100000000ULL
#endif

#ifdef USE_FST
void DlaHAL::fst_init() {
    Verilated::traceEverOn(true);
    FST_FP = new VerilatedFstC();
    device_->trace(FST_FP, DLA_TRACE_DEPTH);
    fprintf(stdout, "[DLA-HAL] FST trace enabled\n");
}

void DlaHAL::fst_final() {
    if (FST_FP) {
        delete FST_FP;
        FST_FP = nullptr;
    }
}
#endif

DlaHAL::DlaHAL(uint32_t baseaddr, uint32_t mmio_size)
    : info_{},
      baseaddr_(baseaddr),
      mmio_size_(mmio_size),
      device_(nullptr),
      vm_addr_h_(0) {
    vm_addr_h_ = (reinterpret_cast<uint64_t>(this) & 0xffffffff00000000ULL);
#ifdef DEBUG
    fprintf(stderr, "[DLA-HAL] vm_addr_h = 0x%lx\n", (unsigned long)vm_addr_h_);
#endif
#ifdef USE_FST
    fst_task_id_ = 0;
#endif
    device_ = new Vasic_wrapper("TOP");
}

DlaHAL::~DlaHAL() {
    if (device_) {
        delete device_;
        device_ = nullptr;
    }
#ifdef DEBUG
    fprintf(stderr, "[DLA-HAL] destroyed\n");
#endif
}

void DlaHAL::init() {
#ifdef USE_FST
    fst_init();
#endif
#ifdef DEBUG
    fprintf(stderr, "[DLA-HAL] init\n");
#endif
    reset_runtime_info();
    reset();
}

void DlaHAL::reset() {
    uint64_t start_c = info_.elapsed_cycle;

    device_->ARESETn = 0;
    for (uint32_t i = 0; i < DLA_RESET_CYCLE; i++) {
        clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    }
    device_->ARESETn = 1;
    device_->eval();

    info_.reset_cycles += (info_.elapsed_cycle - start_c);
}

void DlaHAL::final() {
#ifdef USE_FST
    fst_final();
#endif
}

struct runtime_info DlaHAL::get_runtime_info() const { return info_; }

void DlaHAL::reset_runtime_info() {
    info_.elapsed_cycle = 0;
    info_.elapsed_time = 0;
    info_.memory_read = 0;
    info_.memory_write = 0;

    info_.reset_cycles = 0;
    info_.mmio_setup_cycles = 0;
    info_.dma_read_cycles = 0;
    info_.dma_write_cycles = 0;
    info_.pe_active_cycles = 0;
}

/* MMIO write (AXI Slave Write) */
bool DlaHAL::memory_set(uint32_t addr, uint32_t data) {
    uint64_t start_c = info_.elapsed_cycle;

    if (!device_) {
        fprintf(stderr, "[DLA-HAL] device not initialised\n");
        return false;
    }

#ifdef DEBUG
    fprintf(stderr, "[DLA-HAL] memory_set(0x%08x) = 0x%08x\n", addr, data);
#endif
    if (addr < baseaddr_ || addr >= baseaddr_ + mmio_size_) {
#ifdef DEBUG
        fprintf(stderr, "[DLA-HAL] address 0x%08x out of MMIO range\n", addr);
#endif
        return false;
    }

    /* AW channel */
    // [TODO]: send write address
    /*! <<<========= Implement here =========>>> */
    const uint32_t local_addr = addr;
    device_->AWID_S = 0;
    device_->AWADDR_S = local_addr;
    device_->AWVALID_S = 1;
    device_->eval();
    for (uint32_t i = 0; i < DLA_MAX_CYCLE && !device_->AWREADY_S; i++) {
        clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    }
    // [TODO]: wait for ready (address)
    /*! <<<========= Implement here =========>>> */
    if (!device_->AWREADY_S) {
        fprintf(stderr, "[DLA-HAL] AXI-Lite write address timeout\n");
        device_->AWVALID_S = 0;
        return false;
    }
    clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    device_->AWVALID_S = 0;
    /* W channel */
    // [TODO]: send write data
    /*! <<<========= Implement here =========>>> */
    device_->WDATA_S = data;
    device_->WSTRB_S = AXI_STRB_WORD;
    device_->WLAST_S = 1;
    device_->WVALID_S = 1;
    device_->eval();
    for (uint32_t i = 0; i < DLA_MAX_CYCLE && !device_->WREADY_S; i++) {
        clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    }
    // [TODO]: wait for ready (data)
    /*! <<<========= Implement here =========>>> */
    if (!device_->WREADY_S) {
        fprintf(stderr, "[DLA-HAL] AXI-Lite write data timeout\n");
        device_->WVALID_S = 0;
        device_->WLAST_S = 0;
        return false;
    }
    clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    device_->WVALID_S = 0;
    device_->WLAST_S = 0;
    // [TODO]: wait for write response
    /*! <<<========= Implement here =========>>> */;
    device_->BREADY_S = 1;
    for (uint32_t i = 0; i < DLA_MAX_CYCLE && !device_->BVALID_S; i++) {
        clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    }
    if (!device_->BVALID_S) {
        fprintf(stderr, "[DLA-HAL] AXI-Lite write response timeout\n");
        device_->BREADY_S = 0;
        return false;
    }

    int resp = device_->BRESP_S;
    clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    device_->BREADY_S = 0;

    info_.mmio_setup_cycles += (info_.elapsed_cycle - start_c);
    return resp == AXI_RESP_OKAY;
}

/* MMIO read (AXI Slave Read) */
bool DlaHAL::memory_get(uint32_t addr, uint32_t& data) {
    if (!device_) {
        fprintf(stderr, "[DLA-HAL] device not initialised\n");
        return false;
    }

#ifdef DEBUG
    fprintf(stderr, "[DLA-HAL] memory_get(0x%08x)\n", addr);
#endif
    if (addr < baseaddr_ || addr >= baseaddr_ + mmio_size_) {
#ifdef DEBUG
        fprintf(stderr, "[DLA-HAL] address 0x%08x out of MMIO range\n", addr);
#endif
        return false;
    }

    /* AR channel */
    // [TODO]: send read address
    /*! <<<========= Implement here =========>>> */
    const uint32_t local_addr = addr;
    /* AR channel: send read address */
    device_->ARID_S = 0;
    device_->ARADDR_S = local_addr;
    device_->ARVALID_S = 1;
    device_->eval();
    for (uint32_t i = 0; i < DLA_MAX_CYCLE && !device_->ARREADY_S; i++) {
        clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    }
    if (!device_->ARREADY_S) {
        fprintf(stderr, "[DLA-HAL] AXI-Lite read address timeout\n");
        device_->ARVALID_S = 0;
        return false;
    }
    clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    device_->ARVALID_S = 0;
    /* R channel */
    // [TODO]: wait for valid (data)
    /*! <<<========= Implement here =========>>> */
    device_->RREADY_S = 1;
    device_->eval();
    for (uint32_t i = 0; i < DLA_MAX_CYCLE && !device_->RVALID_S; i++) {
        clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    }
    if (!device_->RVALID_S) {
        fprintf(stderr, "[DLA-HAL] AXI-Lite read data timeout\n");
        device_->RREADY_S = 0;
        return false;
    }

    data = device_->RDATA_S;
    int resp = device_->RRESP_S;
    clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    device_->RREADY_S = 0;
    return resp == AXI_RESP_OKAY;
}

/* Block until DLA interrupt */
void DlaHAL::wait_for_irq() {
    if (!device_) {
        fprintf(stderr, "[DLA-HAL] device not initialised\n");
        return;
    }

#ifdef DEBUG
    fprintf(stderr, "[DLA-HAL] wait_for_irq\n");
#endif

#ifdef USE_FST
#ifndef DLA_FST_DIR
#define DLA_FST_DIR ""
#endif
    char filename[256];
    snprintf(filename, sizeof(filename), "%sasic_%d.fst", DLA_FST_DIR,
             fst_task_id_);
    FST_FP->open(filename);
#endif

    const uint64_t start_cycle = info_.elapsed_cycle;
    while (!device_->ASIC_interrupt) {
        clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);

        uint8_t current_state = device_->rootp->asic_wrapper__DOT__asic_0__DOT__CONSERVATIVE_CONTROLLER__DOT__asic_controller_0__DOT__cs;
        if (current_state == 9 || current_state == 11 || current_state == 12) {
            info_.pe_active_cycles++;
        }

        if (device_->ARVALID_M) handle_dma_read();
        if (device_->AWVALID_M) handle_dma_write();

        if (info_.elapsed_cycle - start_cycle >= DLA_IRQ_TIMEOUT_CYCLE) {
            break;
        }
    }

#ifdef USE_FST
    FST_FP->close();
    fst_task_id_++;
#endif
}

/* DMA read — DLA requests data from host memory */
void DlaHAL::handle_dma_read() {
    uint64_t start_c = info_.elapsed_cycle;
    uint32_t* addr =
        reinterpret_cast<uint32_t*>(vm_addr_h_ | device_->ARADDR_M);
    uint32_t len = device_->ARLEN_M;

    device_->ARREADY_M = 1;
    clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    device_->ARREADY_M = 0;
    clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);

#ifdef DEBUG
    fprintf(stderr, "[DLA-HAL] DMA read addr=%p len=%u\n", addr, len + 1);
#endif

    device_->RID_M = 0;
    device_->RRESP_M = AXI_RESP_OKAY;

    // [TODO]: send read data (increase mode, burst_size 32bits)
    /*! <<<========= Implement here =========>>> */
    for (uint32_t beat = 0; beat <= len; beat++) {
        device_->RDATA_M = addr[beat];
        device_->RLAST_M = (beat == len);
        device_->RVALID_M = 1;
        device_->eval();

        while (!device_->RREADY_M) {
            clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
        }

        clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
        device_->RVALID_M = 0;
        device_->RLAST_M = 0;
        device_->eval();
        clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    }

    device_->RVALID_M = 0;
    device_->RLAST_M = 0;
    info_.memory_read += sizeof(uint32_t) * (len + 1);

    info_.dma_read_cycles += (info_.elapsed_cycle - start_c);
}

/* DMA write — DLA writes data to host memory */
void DlaHAL::handle_dma_write() {
    uint64_t start_c = info_.elapsed_cycle;
    uint32_t* addr =
        reinterpret_cast<uint32_t*>(vm_addr_h_ | device_->AWADDR_M);
    uint32_t len = device_->AWLEN_M;

    device_->AWREADY_M = 1;
    clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    device_->AWREADY_M = 0;
    clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);

#ifdef DEBUG
    fprintf(stderr, "[DLA-HAL] DMA write addr=%p len=%u\n", addr, len + 1);
#endif

    /* W channel */
    // [TODO]: recv write data (increase mode, burst_size 32bits)
    /*! <<<========= Implement here =========>>> */
    device_->WREADY_M = 1;
    for (uint32_t beat = 0; beat <= len; beat++) {
        for (uint32_t i = 0; i < DLA_MAX_CYCLE && !device_->WVALID_M; i++) {
            clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
        }
        if (!device_->WVALID_M) {
            fprintf(stderr, "[DLA-HAL] DMA write WVALID timeout\n");
            break;
        }

        addr[beat] = device_->WDATA_M;
        bool last = device_->WLAST_M;
        clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
        if (last) break;
    }
    device_->WREADY_M = 0;
    /* B channel */
    // [TODO]: recv write response
    /*! <<<========= Implement here =========>>> */
    device_->BRESP_M = AXI_RESP_OKAY;
    device_->BVALID_M = 1;
    for (uint32_t i = 0; i < DLA_MAX_CYCLE && !device_->BREADY_M; i++) {
        clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    }
    if (!device_->BREADY_M) {
        fprintf(stderr, "[DLA-HAL] DMA write BREADY timeout\n");
    }
    clock_step(device_, ACLK, info_.elapsed_cycle, info_.elapsed_time);
    device_->BVALID_M = 0;

    info_.memory_write += sizeof(uint32_t) * (len + 1);

    info_.dma_write_cycles += (info_.elapsed_cycle - start_c);
}
