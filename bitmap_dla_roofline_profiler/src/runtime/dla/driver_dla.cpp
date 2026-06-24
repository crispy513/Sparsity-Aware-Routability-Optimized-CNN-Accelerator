// driver_dla.cpp — DLA register-level driver.
//
// The DlaHAL instance is owned by tb.cpp. tb.cpp calls set_dla_hal(&hal) once
// after construction so that all register-level helpers below can reach the
// same HAL object.

#include "driver_dla.h"

#include <assert.h>
#include <stdio.h>

#include "dla_hal.hpp"

static DlaHAL* g_hal = nullptr;

void set_dla_hal(DlaHAL* hal) { g_hal = hal; }
DlaHAL* get_dla_hal() { return g_hal; }

void reg_write(uint32_t offset, uint32_t value) {
    assert(g_hal != nullptr);
    g_hal->memory_set(offset + DLA_MMIO_BASE_ADDR, value);
}

uint32_t reg_read(uint32_t offset) {
    uint32_t value = 0;
    assert(g_hal != nullptr);
    g_hal->memory_get(offset + DLA_MMIO_BASE_ADDR, value);
    return value;
}

static uint32_t sparse_index(uint32_t sel, uint32_t addr) {
    return ((sel & 0x3u) << DLA_SPARSE_INDEX_SEL_SHIFT) |
           (addr & DLA_SPARSE_BMAP_ADDR_MASK);
}

/* DLA configuration */
void set_enable(uint32_t scale_factor, bool maxpool, bool relu,
                bool operation) {
    uint32_t value = 0;

    // [TODO]: Pack the enable register with scale factor, operation mode,
    //         and activation function flags into the appropriate bitfields.
    /*! <<<========= Implement here =========>>> */
    value |= 1u;                              // bit 0: en
    value |= ((uint32_t)maxpool & 1u) << 1;   // bit 1: maxpool
    value |= ((uint32_t)relu & 1u) << 2;      // bit 2: relu
    value |= ((uint32_t)operation & 1u) << 3; // bit 3: operation
    value |= (scale_factor & 0x3Fu) << 4;     // bit 9:4 scale

    reg_write(DLA_ENABLE_OFFSET, value);
}

void set_mapping_param(uint32_t m, uint32_t e, uint32_t p, uint32_t q,
                       uint32_t r, uint32_t t) {
    uint32_t value = 0;
    // [TODO]: Pack the mapping parameters (m, e, p, q, r, t) into their
    //         respective bitfield positions in the mapping config register.
    /*! <<<========= Implement here =========>>> */
    value |= (m & 0x3FFu) << 16;
    value |= (e & 0x0Fu)  << 12;
    value |= (p & 0x07u)  << 9;
    value |= (q & 0x07u)  << 6;
    value |= (r & 0x07u)  << 3;
    value |= (t & 0x07u);

    reg_write(DLA_MAPPING_PARAM_OFFSET, value);
}

void set_shape_param1(uint32_t PAD, uint32_t U, uint32_t R, uint32_t S,
                      uint32_t C, uint32_t M) {
    uint32_t value = 0;
    // [TODO]: Pack the shape parameters (PAD, U, R, S, C, M) into their
    //         respective bitfield positions in the shape config register.
    /*! <<<========= Implement here =========>>> */
    value |= (PAD & 0x07u) << 26;
    value |= (U   & 0x03u) << 24;
    value |= (R   & 0x03u) << 22;
    value |= (S   & 0x03u) << 20;
    value |= (C   & 0x3FFu) << 10;
    value |= (M   & 0x3FFu);

    reg_write(DLA_SHAPE_PARAM1_OFFSET, value);
}

void set_shape_param2(uint32_t W, uint32_t H, uint32_t PAD) {
    // [TODO]: Calculate and pack the padded width and padded height into
    //         the shape config register bitfields.
    /*! <<<========= Implement here =========>>> */
    uint32_t padded_W = W + (PAD << 1);
    uint32_t padded_H = H + (PAD << 1);

    uint32_t value = ((padded_W & 0xFFu) << 8) |
                     ((padded_H & 0xFFu) << 0);

    reg_write(DLA_SHAPE_PARAM2_OFFSET, value);
}

void set_ifmap_addr(uint8_t* addr) {
    reg_write(DLA_IFMAP_ADDR_OFFSET, (uint32_t)(uintptr_t)addr);
}

void set_filter_addr(int8_t* addr) {
    reg_write(DLA_FILTER_ADDR_OFFSET, (uint32_t)(uintptr_t)addr);
}

void set_bias_addr(int32_t* addr) {
    reg_write(DLA_BIAS_ADDR_OFFSET, (uint32_t)(uintptr_t)addr);
}

void set_opsum_addr(uint8_t* addr) {
    reg_write(DLA_OPSUM_ADDR_OFFSET, (uint32_t)(uintptr_t)addr);
}

void set_glb_filter_addr(uint32_t addr) {
    reg_write(DLA_GLB_FILTER_ADDR_OFFSET, addr);
}

void set_glb_bias_addr(uint32_t addr) {
    reg_write(DLA_GLB_BIAS_ADDR_OFFSET, addr);
}

void set_glb_ofmap_addr(uint32_t addr) {
    reg_write(DLA_GLB_OFMAP_ADDR_OFFSET, addr);
}

void set_input_activation_len(uint32_t len) {
    reg_write(DLA_IFMAP_LEN_OFFSET, len);
};

void set_output_activation_len(uint32_t len) {
    reg_write(DLA_OFMAP_LEN_OFFSET, len);
};

void set_sparse_bitmap_index(uint32_t index) {
    reg_write(DLA_SPARSE_BITMAP_INDEX_OFFSET, index);
}

void write_sparse_bitmap_data(uint32_t bitmap, uint32_t nz_count) {
    uint32_t value = (bitmap & 0xffu) | ((nz_count & 0x0fu) << 8);
    reg_write(DLA_SPARSE_BITMAP_WDATA_OFFSET, value);
}

uint32_t read_sparse_bitmap_data(void) {
    return reg_read(DLA_SPARSE_BITMAP_RDATA_OFFSET);
}

void write_sparse_bitmap_entry(uint32_t sel, uint32_t addr, uint32_t bitmap,
                               uint32_t nz_count) {
    set_sparse_bitmap_index(sparse_index(sel, addr));
    write_sparse_bitmap_data(bitmap, nz_count);
}

void set_sparse_len_index(uint32_t index) {
    reg_write(DLA_SPARSE_LEN_INDEX_OFFSET, index);
}

void write_sparse_len_data(uint32_t value) {
    reg_write(DLA_SPARSE_LEN_WDATA_OFFSET, value);
}

uint32_t read_sparse_len_data(void) {
    return reg_read(DLA_SPARSE_LEN_RDATA_OFFSET);
}

void write_sparse_len_entry(uint32_t sel, uint32_t addr, uint32_t value) {
    set_sparse_len_index(sparse_index(sel, addr));
    write_sparse_len_data(value);
}

void set_sparse_control(bool ifmap_bitmap_enable) {
    uint32_t value = 0;
    value |= ((uint32_t)ifmap_bitmap_enable & 1u);
    reg_write(DLA_SPARSE_CTRL_OFFSET, value);
}
