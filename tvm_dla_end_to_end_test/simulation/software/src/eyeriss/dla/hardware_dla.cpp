/**
 * @file hardware_dla.cpp
 * @brief Provides an interface to configure and control a Deep Learning
 * Accelerator (DLA).
 *
 * This file implements functions to configure mapping parameters, shape
 * parameters, memory addresses, and enable various operations on the DLA. It
 * uses a Hardware Abstraction Layer (HAL) for memory-mapped I/O (MMIO)
 * interactions.
 */

#include "hardware_dla.h"

#include "hal.hpp"

/// @brief Global HAL instance for DLA interaction.
static HardwareAbstractionLayer hal(DLA_MMIO_BASE_ADDR,
                                    DLA_MMIO_SIZE);  // eyeriss device included

/* ========================= HAL Interface ========================= */
void wait_for_interrupt() { hal.wait_for_irq(); }
void hal_init() { hal.init(); }
void hal_final() { hal.final(); }

struct runtime_info get_runtime_info() { return hal.get_runtime_info(); }
void                reset_runtime_info() { hal.reset_runtime_info(); }

uint32_t mmu_map(void* host_ptr, size_t size) { return hal.mmu_map(host_ptr, size); }
void     mmu_unmap(uint32_t device_addr) { hal.mmu_unmap(device_addr); };

void reg_write(uint32_t offset, uint32_t value) { hal.memory_set(offset + DLA_MMIO_BASE_ADDR, value); }

uint32_t reg_read(uint32_t offset) {
  uint32_t value = 0;
  hal.memory_get(offset + DLA_MMIO_BASE_ADDR, value);
  return value;
}

static uint32_t sparse_index(uint32_t sel, uint32_t addr) {
  return ((sel & 0x3u) << DLA_SPARSE_INDEX_SEL_SHIFT) | (addr & DLA_SPARSE_BMAP_ADDR_MASK);
}

/* ========================= DLA Configuration ========================= */
void set_enable(uint32_t scale_factor, bool maxpool, bool relu, bool operation) {
  uint32_t value;
  //! hint>>
  value = (scale_factor & 0x3f) << 4;
  value |= operation << 3;
  value |= relu << 2;
  value |= maxpool << 1;
  value |= 0x1;
  //! hint<<
  reg_write(DLA_ENABLE_OFFSET, value);
}

void set_mapping_param(uint32_t m, uint32_t e, uint32_t p, uint32_t q, uint32_t r, uint32_t t) {
  uint32_t value;
  //! hint>>
  value = (m & 0x3ff) << 16;
  value |= (e & 0xf) << 12;
  value |= (p & 0x7) << 9;
  value |= (q & 0x7) << 6;
  value |= (r & 0x7) << 3;
  value |= (t & 0x7);
  //! hint<<
  reg_write(DLA_MAPPING_PARAM_OFFSET, value);
}

void set_shape_param1(uint32_t PAD, uint32_t U, uint32_t R, uint32_t S, uint32_t C, uint32_t M) {
  uint32_t value;
  //! hint>>
  value = (PAD & 0x7) << 26;
  value |= (U & 0x3) << 24;
  value |= (R & 0x3) << 22;
  value |= (S & 0x3) << 20;
  value |= (C & 0x3ff) << 10;
  value |= (M & 0x3ff);
  //! hint<<
  reg_write(DLA_SHAPE_PARAM1_OFFSET, value);
}

void set_shape_param2(uint32_t W, uint32_t H, uint32_t PAD) {
  uint32_t value;
  //! hint>>
  uint32_t padding = (PAD & 0x7);
  value            = ((W + 2 * padding) & 0xff) << 8;
  value |= ((H + 2 * padding) & 0xff);
  //! hint<<
  reg_write(DLA_SHAPE_PARAM2_OFFSET, value);
}

void set_ifmap_addr(uint8_t* addr) { reg_write(DLA_IFMAP_ADDR_OFFSET, (uint32_t)(uintptr_t)addr); }

void set_filter_addr(int8_t* addr) { reg_write(DLA_FILTER_ADDR_OFFSET, (uint32_t)(uintptr_t)addr); }

void set_bias_addr(int32_t* addr) { reg_write(DLA_BIAS_ADDR_OFFSET, (uint32_t)(uintptr_t)addr); }

void set_opsum_addr(uint8_t* addr) { reg_write(DLA_OPSUM_ADDR_OFFSET, (uint32_t)(uintptr_t)addr); }

void set_glb_filter_addr(uint32_t addr) { reg_write(DLA_GLB_FILTER_ADDR_OFFSET, addr); }

void set_glb_bias_addr(uint32_t addr) { reg_write(DLA_GLB_BIAS_ADDR_OFFSET, addr); }

void set_glb_ofmap_addr(uint32_t addr) { reg_write(DLA_GLB_OFMAP_ADDR_OFFSET, addr); }

void set_input_activation_len(uint32_t len) { reg_write(DLA_IFMAP_LEN_OFFSET, len); };

void set_output_activation_len(uint32_t len) { reg_write(DLA_OFMAP_LEN_OFFSET, len); };

void set_sparse_bitmap_index(uint32_t index) { reg_write(DLA_SPARSE_BITMAP_INDEX_OFFSET, index); }

void write_sparse_bitmap_data(uint32_t bitmap, uint32_t nz_count) {
  uint32_t value = (bitmap & 0xffu) | ((nz_count & 0x0fu) << 8);
  reg_write(DLA_SPARSE_BITMAP_WDATA_OFFSET, value);
}

uint32_t read_sparse_bitmap_data(void) { return reg_read(DLA_SPARSE_BITMAP_RDATA_OFFSET); }

void write_sparse_bitmap_entry(uint32_t sel, uint32_t addr, uint32_t bitmap, uint32_t nz_count) {
  set_sparse_bitmap_index(sparse_index(sel, addr));
  write_sparse_bitmap_data(bitmap, nz_count);
}

void set_sparse_len_index(uint32_t index) { reg_write(DLA_SPARSE_LEN_INDEX_OFFSET, index); }

void write_sparse_len_data(uint32_t value) { reg_write(DLA_SPARSE_LEN_WDATA_OFFSET, value); }

uint32_t read_sparse_len_data(void) { return reg_read(DLA_SPARSE_LEN_RDATA_OFFSET); }

void write_sparse_len_entry(uint32_t sel, uint32_t addr, uint32_t value) {
  set_sparse_len_index(sparse_index(sel, addr));
  write_sparse_len_data(value);
}

void set_sparse_control(bool ifmap_bitmap_enable) {
  uint32_t value = ((uint32_t)ifmap_bitmap_enable & 1u);
  reg_write(DLA_SPARSE_CTRL_OFFSET, value);
}
