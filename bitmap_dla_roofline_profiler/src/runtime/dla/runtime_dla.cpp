#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef DLA_BITMAP_BACKEND
#include <vector>
#endif

#include "driver_dla.h"
#include "runtime.h"

/*  //////////      NOTICE      //////////
    all parameter used to set DLA are send in by function argument
*/
#ifndef DLA_GLB_SIZE
#define DLA_GLB_SIZE (64u * 1024u)
#endif

#define ALIGN4(x) (((x) + 3u) & ~3u)

#ifdef DLA_BITMAP_BACKEND
namespace {

#define DLA_BITMAP_FILTER_DMA_WORD_CAP (1u << 20)
#define DLA_BITMAP_IFMAP_DMA_WORD_CAP  (1u << 20)

static uint32_t g_bitmap_filter_dma_buffer[DLA_BITMAP_FILTER_DMA_WORD_CAP];
static uint32_t g_bitmap_ifmap_dma_buffer[DLA_BITMAP_IFMAP_DMA_WORD_CAP];

struct SparseBitmapBuilder {
    std::vector<uint8_t> bitmap;
    std::vector<uint8_t> nz_count;
    uint32_t word_count = 0;
    uint32_t nonzero_count = 0;
    uint32_t current_bitmap = 0;
    uint32_t current_nz = 0;
    uint32_t bit_index = 0;

    void append(bool nonzero) {
        if (nonzero) {
            current_bitmap |= (1u << bit_index);
            current_nz++;
            nonzero_count++;
        }

        word_count++;
        bit_index++;
        if (bit_index == DLA_SPARSE_BLOCK_SIZE) flush();
    }

    void flush() {
        bitmap.push_back((uint8_t)(current_bitmap & 0xffu));
        nz_count.push_back((uint8_t)(current_nz & 0x0fu));
        current_bitmap = 0;
        current_nz = 0;
        bit_index = 0;
    }

    void finish() {
        if (bit_index != 0) flush();
    }
};

struct BitmapPayload {
    std::vector<uint32_t> compressed_filter;
    std::vector<uint32_t> compressed_ifmap;
    SparseBitmapBuilder filter_bitmap;
    SparseBitmapBuilder ifmap_bitmap;
    std::vector<uint32_t> filter_len;
    std::vector<uint32_t> ifmap_len;
};

static uint32_t min_u32(uint32_t a, uint32_t b) {
    return (a < b) ? a : b;
}

static uint32_t pack_filter_word(const int8_t* filter, uint32_t out_ch,
                                 uint32_t c_base, uint32_t k, uint32_t C) {
    const uint32_t padded_C = (C < 4u) ? 4u : C;
    const uint32_t out_stride = padded_C * 9u;
    uint32_t word = 0;

    for (uint32_t lane = 0; lane < 4u; lane++) {
        uint32_t c = c_base + lane;
        uint8_t byte = 0;
        if (c < C) {
            uint32_t index = out_ch * out_stride + c * 9u + k;
            byte = (uint8_t)filter[index];
        }
        word |= ((uint32_t)byte) << (lane * 8u);
    }

    return word;
}

static void append_filter_chunk(BitmapPayload& payload, const int8_t* filter,
                                uint32_t out_ch, uint32_t c_base, uint32_t C) {
    uint32_t chunk_nonzero = 0;

    for (uint32_t k = 0; k < 9u; k++) {
        uint32_t word = pack_filter_word(filter, out_ch, c_base, k, C);
        bool nonzero = (word != 0u);
        payload.filter_bitmap.append(nonzero);
        if (nonzero) {
            payload.compressed_filter.push_back(word);
            chunk_nonzero++;
        }
    }

    payload.filter_len.push_back(chunk_nonzero);
}

static uint32_t pack_ifmap_word(const uint8_t* input, uint32_t c_base,
                                uint32_t row, uint32_t col, uint32_t C,
                                uint32_t W, uint32_t H) {
    uint32_t word = 0;
    const uint32_t plane_stride = W * H;

    for (uint32_t lane = 0; lane < 4u; lane++) {
        uint32_t c = c_base + lane;
        uint8_t byte = 0;
        if (c < C && row < H && col < W) {
            byte = input[c * plane_stride + row * W + col];
        }
        word |= ((uint32_t)byte) << (lane * 8u);
    }

    return word;
}

static void append_ifmap_chunk(BitmapPayload& payload, const uint8_t* input,
                               uint32_t c_base, uint32_t count_H,
                               uint32_t valid_e, uint32_t C, uint32_t W,
                               uint32_t H, uint32_t padded_W,
                               uint32_t padded_H) {
    const uint32_t F = padded_H - 2u;
    const uint32_t h_max = valid_e + 2u;
    const bool top_padding = (count_H == 0u);
    const bool bottom_padding = (count_H + h_max + 1u >= padded_H);
    uint32_t chunk_nonzero = 0;

    for (uint32_t count_W = 1u; count_W + 1u < padded_W; count_W++) {
        for (uint32_t count_h = 0u; count_h < h_max; count_h++) {
            if ((top_padding && count_h == 0u) ||
                (bottom_padding && count_h + 1u == h_max)) {
                continue;
            }

            uint32_t row = count_H + count_h - (top_padding ? 1u : 0u);
            uint32_t col = count_W - 1u;
            if (col >= F) continue;

            uint32_t word = pack_ifmap_word(input, c_base, row, col, C, W, H);
            bool nonzero = (word != 0u);
            payload.ifmap_bitmap.append(nonzero);
            if (nonzero) {
                payload.compressed_ifmap.push_back(word);
                chunk_nonzero++;
            }
        }
    }

    payload.ifmap_len.push_back(chunk_nonzero);
}

static BitmapPayload build_bitmap_payload(const uint8_t* input,
                                          const int8_t* filter, uint32_t m,
                                          uint32_t p, uint32_t q, uint32_t r,
                                          uint32_t t, uint32_t C, uint32_t M,
                                          uint32_t W, uint32_t H,
                                          uint32_t padded_W,
                                          uint32_t padded_H) {
    BitmapPayload payload;
    const uint32_t PP_filt = p * t;
    const uint32_t PP_ch = (C < 4u) ? C : (q * r);
    const uint32_t E = padded_W - 2u;
    const uint32_t F = padded_H - 2u;

    if (PP_filt == 0u || PP_ch == 0u || E == 0u || F == 0u) {
        return payload;
    }

    for (uint32_t count_M = 0; count_M < M; count_M += m) {
        uint32_t count_E = 0;
        uint32_t count_H = 0;
        for (uint32_t guard = 0; guard < 1024u; guard++) {
            uint32_t valid_e = min_u32(8u, E - count_E);
            uint32_t h_max = valid_e + 2u;
            for (uint32_t count_C = 0; count_C < C; count_C += PP_ch) {
#ifdef DLA_BITMAP_IFMAP
                append_ifmap_chunk(payload, input, count_C, count_H, valid_e,
                                   C, W, H, padded_W, padded_H);
#endif
                for (uint32_t count_m = 0; count_m < m; count_m += PP_filt) {
                    for (uint32_t pp = 0; pp < PP_filt; pp++) {
                        uint32_t out_ch = count_M + count_m + pp;
                        if (out_ch < M) {
                            append_filter_chunk(payload, filter, out_ch,
                                                count_C, C);
                        }
                    }

                }
            }

            bool count_E_reset = (count_E + valid_e == E);
            bool count_H_reset = (count_H + h_max + 1u >= H);
            if (count_E_reset && count_H_reset) break;

            count_E = count_E_reset ? 0u : (count_E + valid_e);
            if (count_H_reset) {
                count_H = 0u;
            } else if (count_H == 0u) {
                count_H += valid_e - 1u;
            } else {
                count_H += valid_e;
            }
        }
    }

    payload.filter_bitmap.finish();
    if (payload.compressed_filter.empty()) {
        payload.compressed_filter.push_back(0u);
    }
    payload.ifmap_bitmap.finish();
    if (payload.compressed_ifmap.empty()) {
        payload.compressed_ifmap.push_back(0u);
    }
    return payload;
}

static void write_len_table(uint32_t sel, const std::vector<uint32_t>& lens) {
    uint32_t limit =
        min_u32((uint32_t)lens.size(), DLA_SPARSE_BMAP_ADDR_MASK + 1u);
    for (uint32_t i = 0; i < limit; i++) {
        write_sparse_len_entry(sel, i, lens[i]);
    }
}

static void program_bitmap_metadata(const BitmapPayload& payload) {
#ifdef DLA_BITMAP_IFMAP
    uint32_t ifmap_bitmap_limit =
        min_u32((uint32_t)payload.ifmap_bitmap.bitmap.size(),
                DLA_SPARSE_BMAP_ADDR_MASK + 1u);
    for (uint32_t i = 0; i < ifmap_bitmap_limit; i++) {
        write_sparse_bitmap_entry(DLA_SPARSE_SEL_IFMAP, i,
                                  payload.ifmap_bitmap.bitmap[i],
                                  payload.ifmap_bitmap.nz_count[i]);
    }

    write_len_table(DLA_SPARSE_SEL_IFMAP, payload.ifmap_len);
#endif

    uint32_t bitmap_limit =
        min_u32((uint32_t)payload.filter_bitmap.bitmap.size(),
                DLA_SPARSE_BMAP_ADDR_MASK + 1u);
    for (uint32_t i = 0; i < bitmap_limit; i++) {
        write_sparse_bitmap_entry(DLA_SPARSE_SEL_FILTER, i,
                                  payload.filter_bitmap.bitmap[i],
                                  payload.filter_bitmap.nz_count[i]);
    }

    write_len_table(DLA_SPARSE_SEL_FILTER, payload.filter_len);

#ifdef DEBUG
    fprintf(stderr,
            "[DLA-BITMAP] original_filter_words=%u compressed_words=%u "
            "filter_blocks=%u nonzero_words=%u filter_len_entries=%u\n",
            payload.filter_bitmap.word_count,
            (uint32_t)payload.compressed_filter.size(),
            (uint32_t)payload.filter_bitmap.bitmap.size(),
            payload.filter_bitmap.nonzero_count,
            (uint32_t)payload.filter_len.size());
#ifdef DLA_BITMAP_IFMAP
    fprintf(stderr,
            "[DLA-BITMAP] original_ifmap_words=%u compressed_words=%u "
            "ifmap_blocks=%u nonzero_words=%u ifmap_len_entries=%u\n",
            payload.ifmap_bitmap.word_count,
            (uint32_t)payload.compressed_ifmap.size(),
            (uint32_t)payload.ifmap_bitmap.bitmap.size(),
            payload.ifmap_bitmap.nonzero_count,
            (uint32_t)payload.ifmap_len.size());
#endif
#endif
}

static int8_t* stage_filter_dma_buffer(const BitmapPayload& payload) {
    if (payload.compressed_filter.size() > DLA_BITMAP_FILTER_DMA_WORD_CAP) {
        fprintf(stderr,
                "DLA bitmap filter buffer overflow: need %u words, cap %u words.\n",
                (uint32_t)payload.compressed_filter.size(),
                (uint32_t)DLA_BITMAP_FILTER_DMA_WORD_CAP);
        return nullptr;
    }

    memcpy(g_bitmap_filter_dma_buffer, payload.compressed_filter.data(),
           payload.compressed_filter.size() * sizeof(uint32_t));

#ifdef DEBUG
    fprintf(stderr, "[DLA-BITMAP] staged_filter_dma=%p words=%u\n",
            (void*)g_bitmap_filter_dma_buffer,
            (uint32_t)payload.compressed_filter.size());
#endif

    return (int8_t*)g_bitmap_filter_dma_buffer;
}

static uint8_t* stage_ifmap_dma_buffer(const BitmapPayload& payload) {
    if (payload.compressed_ifmap.size() > DLA_BITMAP_IFMAP_DMA_WORD_CAP) {
        fprintf(stderr,
                "DLA bitmap ifmap buffer overflow: need %u words, cap %u words.\n",
                (uint32_t)payload.compressed_ifmap.size(),
                (uint32_t)DLA_BITMAP_IFMAP_DMA_WORD_CAP);
        return nullptr;
    }

    memcpy(g_bitmap_ifmap_dma_buffer, payload.compressed_ifmap.data(),
           payload.compressed_ifmap.size() * sizeof(uint32_t));

#ifdef DEBUG
    fprintf(stderr, "[DLA-BITMAP] staged_ifmap_dma=%p words=%u\n",
            (void*)g_bitmap_ifmap_dma_buffer,
            (uint32_t)payload.compressed_ifmap.size());
#endif

    return (uint8_t*)g_bitmap_ifmap_dma_buffer;
}

}  // namespace
#endif

void dla_stop() {
    // set disable
    reg_write(DLA_ENABLE_OFFSET, 0);
}

void create_dla_info_to_csv(const char* filename) {
    fprintf(stdout, "Creating dla info file: %s\n", filename);
    FILE* file = fopen(filename, "w");
    if (!file) {
        fprintf(stderr, "Create DLA info file failed.\n");
        return;
    }
    fprintf(file,
            "Operation,Cycles,Time(ns),Memory read,Memory "
            "write,m,e,p,q,r,t,PAD,U,R,S,C,M,W,H\n");
    fclose(file);
}

void dump_dla_info_to_csv(const char* filename, const char* operation_name,
                          // mapping parameter
                          uint32_t m, uint32_t e, uint32_t p, uint32_t q,
                          uint32_t r, uint32_t t,
                          // shape parameter
                          uint32_t PAD, uint32_t U, uint32_t R, uint32_t S,
                          uint32_t C, uint32_t M, uint32_t W, uint32_t H) {
    FILE* file = fopen(filename, "a");
    struct runtime_info info = get_dla_hal()->get_runtime_info();
    fprintf(file, "%s,", operation_name);  // Operation
    fprintf(file, "%10llu,", (unsigned long long)info.elapsed_cycle);  // Cycles
    fprintf(file, "%10llu,", (unsigned long long)info.elapsed_time);   // Time (ns)
    fprintf(file, "%10d,", info.memory_read);        // Memory read
    fprintf(file, "%10d,", info.memory_write);       // Memory write
    fprintf(file, "%d,%d,%d,%d,%d,%d,", m, e, p, q, r, t);
    fprintf(file, "%d,%d,%d,%d,%d,%d,%d,%d\n", PAD, U, R, S, C, M, W, H);
    fclose(file);
}

int qconv2d_relu_maxpool(
    uint8_t* input_in_DRAM, int8_t* filter_in_DRAM, uint8_t* opsum_in_DRAM,
    int32_t* bias, uint32_t ofmap_len, uint32_t ifmap_len, uint32_t filter_len,
    // mapping parameter
    uint32_t m, uint32_t e, uint32_t p, uint32_t q, uint32_t r, uint32_t t,
    // shape parameter
    uint32_t PAD, uint32_t U, uint32_t R, uint32_t S, uint32_t C, uint32_t M,
    uint32_t W, uint32_t H,
    uint32_t scale) {  // int32_t scale_factor: merge ifmap and weight and ofmap
    // scale bit-shift

#ifdef DLA_INFO
    dla_reset_runtime_info();
#endif
    // [TODO]: Calculate the sizes and base addresses of each data region
    //         (ifmap, filter, bias, ofmap) in the GLB (Global Buffer).
    //         Adjust the tiling parameter `m` to fit within the remaining GLB
    //         space.
    /*! <<<========= Implement here =========>>> */
    if (M == 0u) {
        fprintf(stderr, "DLA runtime error: M must not be 0.\n");
        return -1;
    }

    if (m == 0u) m = 1u;
    if (m > M) m = M;

    uint32_t PP_filt = p * t;
    uint32_t tile_e = e;
    if (PP_filt == 0u) return -1;
    if (tile_e == 0u || tile_e > W) tile_e = W;
    if (tile_e > 8u) tile_e = 8u;

    uint32_t GLB_ifmap_len = ALIGN4(4u * W * (U * (tile_e - 1u) + R));
    uint32_t GLB_filter_len = ALIGN4(4u * R * S * PP_filt);
    uint32_t GLB_ofmap_len = 0;
    uint32_t GLB_bias_len = 0;
    uint32_t GLB_total_len = 0;
    uint32_t selected_m = 0;

    uint32_t cand_m = 1u;
    while ((cand_m << 1) <= m && (cand_m << 1) <= M) cand_m <<= 1;
    for (; cand_m > 0u; cand_m >>= 1) {
        if ((cand_m % PP_filt) != 0u) continue;
        if ((M % cand_m) != 0u) continue;

        GLB_bias_len = ALIGN4(4u * cand_m);
        GLB_ofmap_len = ALIGN4((uint32_t)(4u * cand_m * tile_e * H));
        GLB_total_len =
            GLB_ifmap_len + GLB_bias_len + GLB_filter_len + GLB_ofmap_len;

        if (GLB_total_len <= DLA_GLB_SIZE) {
            selected_m = cand_m;
            break;
        }
    }

    if (selected_m == 0u) {
        fprintf(stderr,
                "DLA GLB overflow in qconv2d_relu_maxpool: GLB only %u bytes.\n",
                (uint32_t)DLA_GLB_SIZE);
        return -1;
    }
    m = selected_m;

#ifdef DLA_BITMAP_BACKEND
    uint32_t padded_W = W + (PAD << 1);
    uint32_t padded_H = H + (PAD << 1);
    BitmapPayload bitmap_payload =
        build_bitmap_payload(input_in_DRAM, filter_in_DRAM, m, p, q, r, t, C,
                             M, W, H, padded_W, padded_H);
    int8_t* bitmap_filter_dma = stage_filter_dma_buffer(bitmap_payload);
    if (bitmap_filter_dma == nullptr) return -1;
#ifdef DLA_BITMAP_IFMAP
    uint8_t* bitmap_ifmap_dma = stage_ifmap_dma_buffer(bitmap_payload);
    if (bitmap_ifmap_dma == nullptr) return -1;
#endif
#endif

    //  get GLB ADDR
    uint32_t GLB_bias_adress = GLB_ifmap_len;
    uint32_t GLB_filter_adress = GLB_bias_adress + GLB_bias_len;
    uint32_t GLB_ofmap_address = GLB_filter_adress + GLB_filter_len;

    // [TODO]: Configure all DLA hardware registers with the tiling/shape
    //         parameters, DRAM pointers, GLB addresses, activation lengths,
    //         and enable the DLA with the appropriate operation flags
    //         (relu + maxpool enabled).
    // Note: Using lower setting APIs in `driver_dla` here
    /*! <<<========= Implement here =========>>> */
#ifdef DLA_BITMAP_BACKEND
#ifdef DLA_BITMAP_IFMAP
    set_ifmap_addr(bitmap_ifmap_dma);
#else
    set_ifmap_addr(input_in_DRAM);
#endif
    set_filter_addr(bitmap_filter_dma);
#else
    set_ifmap_addr(input_in_DRAM);
    set_filter_addr(filter_in_DRAM);
#endif
    set_bias_addr(bias);
    set_opsum_addr(opsum_in_DRAM);

    set_glb_bias_addr(GLB_bias_adress);
    set_glb_filter_addr(GLB_filter_adress);
    set_glb_ofmap_addr(GLB_ofmap_address);

    set_input_activation_len(ifmap_len);
    set_output_activation_len(ofmap_len);

    set_mapping_param(m, e, p, q, r, t);
    set_shape_param1(PAD, U, R, S, C, M);
    set_shape_param2(W, H, PAD);

#ifdef DLA_BITMAP_BACKEND
#ifdef DLA_BITMAP_IFMAP
    set_sparse_control(true);
#else
    set_sparse_control(false);
#endif
    program_bitmap_metadata(bitmap_payload);
#endif

    // set_enable(scale_factor, maxpool, relu, operation)
    set_enable(scale, true, true, false);
    get_dla_hal()->wait_for_irq();
    dla_stop();
#ifdef DLA_INFO
    dump_dla_info_to_csv(DLA_INFO_CSV, "qconv2d_relu_maxpool", m, e, p, q, r, t,
                         PAD, U, R, S, C, M, W, H);
#endif
    return 0;
};

int qconv2d_relu(uint8_t* input_in_DRAM, int8_t* filter_in_DRAM,
                 uint8_t* opsum_in_DRAM, int32_t* bias, uint32_t ofmap_len,
                 uint32_t ifmap_len, uint32_t filter_len,
                 // mapping parameter
                 uint32_t m, uint32_t e, uint32_t p, uint32_t q, uint32_t r,
                 uint32_t t,
                 // shape parameter
                 uint32_t PAD, uint32_t U, uint32_t R, uint32_t S, uint32_t C,
                 uint32_t M, uint32_t W, uint32_t H,
                 uint32_t scale) {  // int32_t scale_factor: merge ifmap and
                                    // ofmap scale bit-shift
#ifdef DLA_INFO
    dla_reset_runtime_info();
#endif
    // [TODO]: Calculate the sizes and base addresses of each data region
    //         (ifmap, filter, bias, ofmap) in the GLB (Global Buffer).
    //         Adjust the tiling parameter `m` to fit within the remaining GLB
    //         space.
    /*! <<<========= Implement here =========>>> */
    if (M == 0u) {
        fprintf(stderr, "DLA runtime error: M must not be 0.\n");
        return -1;
    }

    if (m == 0u) m = 1u;
    if (m > M) m = M;
    //  get GLB ADDR
    uint32_t PP_filt = p * t;
    uint32_t tile_e = e;
    if (PP_filt == 0u) return -1;
    if (tile_e == 0u || tile_e > W) tile_e = W;
    if (tile_e > 8u) tile_e = 8u;

    uint32_t GLB_ifmap_len = ALIGN4(4u * W * (U * (tile_e - 1u) + R));
    uint32_t GLB_filter_len = ALIGN4(4u * R * S * PP_filt);
    uint32_t GLB_ofmap_len = 0;
    uint32_t GLB_bias_len = 0;
    uint32_t GLB_total_len = 0;
    uint32_t GLB_bias_adress;
    uint32_t GLB_filter_adress;
    uint32_t GLB_ofmap_address;

    uint32_t selected_m = 0;
    uint32_t cand_m = 1u;
    while ((cand_m << 1) <= m && (cand_m << 1) <= M) cand_m <<= 1;
    for (; cand_m > 0u; cand_m >>= 1) {
        if ((cand_m % PP_filt) != 0u) continue;
        if ((M % cand_m) != 0u) continue;

        GLB_bias_len = ALIGN4(4u * cand_m);
        GLB_ofmap_len = ALIGN4((uint32_t)(4u * cand_m * tile_e * H));
        GLB_total_len =
            GLB_ifmap_len + GLB_bias_len + GLB_filter_len + GLB_ofmap_len;

        if (GLB_total_len <= DLA_GLB_SIZE) {
            selected_m = cand_m;
            break;
        }
    }

    if (selected_m == 0u) {
        fprintf(stderr,
                "DLA GLB overflow in qconv2d_relu: GLB only %u bytes.\n",
                (uint32_t)DLA_GLB_SIZE);
        return -1;
    }
    m = selected_m;

#ifdef DLA_BITMAP_BACKEND
    uint32_t padded_W = W + (PAD << 1);
    uint32_t padded_H = H + (PAD << 1);
    BitmapPayload bitmap_payload =
        build_bitmap_payload(input_in_DRAM, filter_in_DRAM, m, p, q, r, t, C,
                             M, W, H, padded_W, padded_H);
    int8_t* bitmap_filter_dma = stage_filter_dma_buffer(bitmap_payload);
    if (bitmap_filter_dma == nullptr) return -1;
#ifdef DLA_BITMAP_IFMAP
    uint8_t* bitmap_ifmap_dma = stage_ifmap_dma_buffer(bitmap_payload);
    if (bitmap_ifmap_dma == nullptr) return -1;
#endif
#endif

    //  get GLB ADDR
    GLB_bias_adress = GLB_ifmap_len;
    GLB_filter_adress = GLB_bias_adress + GLB_bias_len;
    GLB_ofmap_address = GLB_filter_adress + GLB_filter_len;

    // [TODO]: Configure all DLA hardware registers with the tiling/shape
    //         parameters, DRAM pointers, GLB addresses, activation lengths,
    //         and enable the DLA with the appropriate operation flags
    //         (relu enabled, maxpool disabled).
    // Note: Using lower setting APIs in `driver_dla` here
    /*! <<<========= Implement here =========>>> */
#ifdef DLA_BITMAP_BACKEND
#ifdef DLA_BITMAP_IFMAP
    set_ifmap_addr(bitmap_ifmap_dma);
#else
    set_ifmap_addr(input_in_DRAM);
#endif
    set_filter_addr(bitmap_filter_dma);
#else
    set_ifmap_addr(input_in_DRAM);
    set_filter_addr(filter_in_DRAM);
#endif
    set_bias_addr(bias);
    set_opsum_addr(opsum_in_DRAM);

    set_glb_bias_addr(GLB_bias_adress);
    set_glb_filter_addr(GLB_filter_adress);
    set_glb_ofmap_addr(GLB_ofmap_address);

    set_input_activation_len(ifmap_len);
    set_output_activation_len(ofmap_len);

    set_mapping_param(m, e, p, q, r, t);
    set_shape_param1(PAD, U, R, S, C, M);
    set_shape_param2(W, H, PAD);

#ifdef DLA_BITMAP_BACKEND
#ifdef DLA_BITMAP_IFMAP
    set_sparse_control(true);
#else
    set_sparse_control(false);
#endif
    program_bitmap_metadata(bitmap_payload);
#endif

    // set_enable(scale_factor, maxpool, relu, operation)
    set_enable(scale, false, true, false);

    get_dla_hal()->wait_for_irq();
    dla_stop();
#ifdef DLA_INFO
    dump_dla_info_to_csv(DLA_INFO_CSV, "qconv2d_relu", m, e, p, q, r, t, PAD, U,
                         R, S, C, M, W, H);
#endif
    return 0;
};
