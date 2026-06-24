#include "kernel_cpu.h"

// [TODO]: Implement the improved versions of all kernel functions below.

void conv_maxpooling(uint32_t input_C, uint32_t input_H, uint32_t input_W,
                     uint8_t* activation, uint32_t filter_N, uint32_t filter_C,
                     uint32_t filter_H, uint32_t filter_W, int8_t* filter,
                     int32_t* bias, uint32_t padding, uint8_t* output,
                     uint32_t scale, void* scratch) {
    /*! <<<========= Implement here =========>>> */
    #define FAST_RELU(x) ((x) & ~((x) >> 31))
    
    uint32_t padded_H = input_H + 2 * padding;
    uint32_t padded_W = input_W + 2 * padding;
    uint8_t* padded_in = (uint8_t*)scratch;

    // 1. 預先建立 Padded Input，消滅內層的邊界 if 判斷
    memset(padded_in, 128, input_C * padded_H * padded_W);
    uint8_t* in_base = activation;
    uint8_t* pad_base = padded_in + padding * padded_W + padding;
    for (uint32_t c = 0; c < input_C; c++) {
        for (uint32_t h = 0; h < input_H; h++) {
            memcpy(pad_base, in_base, input_W);
            in_base += input_W;
            pad_base += padded_W;
        }
        pad_base += 2 * padding * padded_W; // 跳過上下的 padding
    }

    uint32_t out_H = input_H + 2 * padding - filter_H + 1;
    uint32_t out_W = input_W + 2 * padding - filter_W + 1;
    uint32_t pooled_H = out_H / 2;
    uint32_t pooled_W = out_W / 2;

    uint8_t* out_ptr = output;

    // 2. Conv + ReLU + MaxPool 與暫存器推廣
    for (uint32_t n = 0; n < filter_N; n++) {
        int32_t b = bias[n];
        int8_t* wt_base = filter + n * filter_C * filter_H * filter_W;

        for (uint32_t ph = 0; ph < pooled_H; ph++) {
            for (uint32_t pw = 0; pw < pooled_W; pw++) {
                
                // 宣告區域變數，強迫編譯器使用暫存器
                int32_t acc00 = b, acc01 = b, acc10 = b, acc11 = b;
                uint32_t oh = 2 * ph;
                uint32_t ow = 2 * pw;

                int8_t* wt_ptr = wt_base;
                uint8_t* p_in_c = padded_in;

                // 3. 指標遞增取代複雜定址
                for (uint32_t c = 0; c < filter_C; c++) {
                    for (uint32_t r = 0; r < filter_H; r++) {
                        uint8_t* in00 = p_in_c + (oh + r) * padded_W + ow;
                        uint8_t* in10 = p_in_c + (oh + 1 + r) * padded_W + ow;
                        
                        for (uint32_t s = 0; s < filter_W; s++) {
                            int32_t w = *wt_ptr++;
                            // 暫存器平鋪：載入一個 weight 可給四個 pixel 使用
                            acc00 += ((int32_t)in00[s] - 128) * w;
                            acc01 += ((int32_t)in00[s + 1] - 128) * w;
                            acc10 += ((int32_t)in10[s] - 128) * w;
                            acc11 += ((int32_t)in10[s + 1] - 128) * w;
                        }
                    }
                    p_in_c += padded_H * padded_W;
                }

                // 無分支 ReLU 與量化
                uint8_t q00 = requant(FAST_RELU(acc00), scale);
                uint8_t q01 = requant(FAST_RELU(acc01), scale);
                uint8_t q10 = requant(FAST_RELU(acc10), scale);
                uint8_t q11 = requant(FAST_RELU(acc11), scale);

                // Inline MaxPool
                uint8_t max_val = q00;
                max_val = (q01 > max_val) ? q01 : max_val;
                max_val = (q10 > max_val) ? q10 : max_val;
                max_val = (q11 > max_val) ? q11 : max_val;

                *out_ptr++ = max_val;
            }
        }
    }
    #undef FAST_RELU

};

void conv(uint32_t input_C, uint32_t input_H, uint32_t input_W,
          uint8_t* activation, uint32_t filter_N, uint32_t filter_C,
          uint32_t filter_H, uint32_t filter_W, int8_t* filter, int32_t* bias,
          uint32_t padding, uint8_t* output, uint32_t scale, void* scratch) {
    /*! <<<========= Implement here =========>>> */
    #define FAST_RELU(x) ((x) & ~((x) >> 31))
    
    uint32_t padded_H = input_H + 2 * padding;
    uint32_t padded_W = input_W + 2 * padding;
    uint8_t* padded_in = (uint8_t*)scratch;

    memset(padded_in, 128, input_C * padded_H * padded_W);
    uint8_t* in_base = activation;
    uint8_t* pad_base = padded_in + padding * padded_W + padding;
    for (uint32_t c = 0; c < input_C; c++) {
        for (uint32_t h = 0; h < input_H; h++) {
            memcpy(pad_base, in_base, input_W);
            in_base += input_W;
            pad_base += padded_W;
        }
        pad_base += 2 * padding * padded_W;
    }

    uint32_t out_H = input_H + 2 * padding - filter_H + 1;
    uint32_t out_W = input_W + 2 * padding - filter_W + 1;
    uint8_t* out_ptr = output;

    for (uint32_t n = 0; n < filter_N; n++) {
        int32_t b = bias[n];
        int8_t* wt_base = filter + n * filter_C * filter_H * filter_W;

        for (uint32_t oh = 0; oh < out_H; oh++) {
            uint32_t ow = 0;
            // 水平展開 4 像素計算
            for (; ow + 3 < out_W; ow += 4) {
                int32_t acc0 = b, acc1 = b, acc2 = b, acc3 = b;
                int8_t* wt_ptr = wt_base;
                uint8_t* p_in_c = padded_in;

                for (uint32_t c = 0; c < filter_C; c++) {
                    for (uint32_t r = 0; r < filter_H; r++) {
                        uint8_t* in_row = p_in_c + (oh + r) * padded_W + ow;
                        for (uint32_t s = 0; s < filter_W; s++) {
                            int32_t w = *wt_ptr++;
                            acc0 += ((int32_t)in_row[s] - 128) * w;
                            acc1 += ((int32_t)in_row[s + 1] - 128) * w;
                            acc2 += ((int32_t)in_row[s + 2] - 128) * w;
                            acc3 += ((int32_t)in_row[s + 3] - 128) * w;
                        }
                    }
                    p_in_c += padded_H * padded_W;
                }
                *out_ptr++ = requant(FAST_RELU(acc0), scale);
                *out_ptr++ = requant(FAST_RELU(acc1), scale);
                *out_ptr++ = requant(FAST_RELU(acc2), scale);
                *out_ptr++ = requant(FAST_RELU(acc3), scale);
            }
            // 處理餘數邊界
            for (; ow < out_W; ow++) {
                int32_t acc = b;
                int8_t* wt_ptr = wt_base;
                uint8_t* p_in_c = padded_in;

                for (uint32_t c = 0; c < filter_C; c++) {
                    for (uint32_t r = 0; r < filter_H; r++) {
                        uint8_t* in_row = p_in_c + (oh + r) * padded_W + ow;
                        for (uint32_t s = 0; s < filter_W; s++) {
                            acc += ((int32_t)in_row[s] - 128) * (*wt_ptr++);
                        }
                    }
                    p_in_c += padded_H * padded_W;
                }
                *out_ptr++ = requant(FAST_RELU(acc), scale);
            }
        }
    }
    #undef FAST_RELU

};

void linear_relu(uint32_t input_size, uint32_t output_size, uint8_t* activation,
                 uint8_t* output, int8_t* filter, int32_t* bias, uint32_t scale,
                 void* scratch) {
    /*! <<<========= Implement here =========>>> */
    #define FAST_RELU(x) ((x) & ~((x) >> 31))
    
    int32_t* intermediate = (int32_t*)scratch;
    
    // 預先轉換型態並減去零點，減少疊代中的計算量
    uint32_t j = 0;
    for (; j + 7 < input_size; j += 8) {
        intermediate[j + 0] = (int32_t)activation[j + 0] - 128;
        intermediate[j + 1] = (int32_t)activation[j + 1] - 128;
        intermediate[j + 2] = (int32_t)activation[j + 2] - 128;
        intermediate[j + 3] = (int32_t)activation[j + 3] - 128;
        intermediate[j + 4] = (int32_t)activation[j + 4] - 128;
        intermediate[j + 5] = (int32_t)activation[j + 5] - 128;
        intermediate[j + 6] = (int32_t)activation[j + 6] - 128;
        intermediate[j + 7] = (int32_t)activation[j + 7] - 128;
    }
    for (; j < input_size; j++) {
        intermediate[j] = (int32_t)activation[j] - 128;
    }

    int8_t* wt_ptr = filter;
    uint8_t* out_ptr = output;

    for (uint32_t i = 0; i < output_size; i++) {
        int32_t acc = bias[i];
        uint32_t k = 0;
        
        // 16 路迴圈展開：打滿指令管線
        for (; k + 15 < input_size; k += 16) {
            acc += intermediate[k + 0] * (*wt_ptr++);
            acc += intermediate[k + 1] * (*wt_ptr++);
            acc += intermediate[k + 2] * (*wt_ptr++);
            acc += intermediate[k + 3] * (*wt_ptr++);
            acc += intermediate[k + 4] * (*wt_ptr++);
            acc += intermediate[k + 5] * (*wt_ptr++);
            acc += intermediate[k + 6] * (*wt_ptr++);
            acc += intermediate[k + 7] * (*wt_ptr++);
            acc += intermediate[k + 8] * (*wt_ptr++);
            acc += intermediate[k + 9] * (*wt_ptr++);
            acc += intermediate[k + 10] * (*wt_ptr++);
            acc += intermediate[k + 11] * (*wt_ptr++);
            acc += intermediate[k + 12] * (*wt_ptr++);
            acc += intermediate[k + 13] * (*wt_ptr++);
            acc += intermediate[k + 14] * (*wt_ptr++);
            acc += intermediate[k + 15] * (*wt_ptr++);
        }
        for (; k < input_size; k++) {
            acc += intermediate[k] * (*wt_ptr++);
        }
        
        *out_ptr++ = requant(FAST_RELU(acc), scale);
    }
    #undef FAST_RELU

};

void linear(uint32_t input_size, uint32_t output_size, uint8_t* activation,
            uint8_t* output, int8_t* filter, int32_t* bias, uint32_t scale,
            void* scratch) {
    /*! <<<========= Implement here =========>>> */
    int32_t* intermediate = (int32_t*)scratch;
    
    uint32_t j = 0;
    for (; j + 7 < input_size; j += 8) {
        intermediate[j + 0] = (int32_t)activation[j + 0] - 128;
        intermediate[j + 1] = (int32_t)activation[j + 1] - 128;
        intermediate[j + 2] = (int32_t)activation[j + 2] - 128;
        intermediate[j + 3] = (int32_t)activation[j + 3] - 128;
        intermediate[j + 4] = (int32_t)activation[j + 4] - 128;
        intermediate[j + 5] = (int32_t)activation[j + 5] - 128;
        intermediate[j + 6] = (int32_t)activation[j + 6] - 128;
        intermediate[j + 7] = (int32_t)activation[j + 7] - 128;
    }
    for (; j < input_size; j++) {
        intermediate[j] = (int32_t)activation[j] - 128;
    }

    int8_t* wt_ptr = filter;
    uint8_t* out_ptr = output;

    for (uint32_t i = 0; i < output_size; i++) {
        int32_t acc = bias[i];
        uint32_t k = 0;
        
        for (; k + 15 < input_size; k += 16) {
            acc += intermediate[k + 0] * (*wt_ptr++);
            acc += intermediate[k + 1] * (*wt_ptr++);
            acc += intermediate[k + 2] * (*wt_ptr++);
            acc += intermediate[k + 3] * (*wt_ptr++);
            acc += intermediate[k + 4] * (*wt_ptr++);
            acc += intermediate[k + 5] * (*wt_ptr++);
            acc += intermediate[k + 6] * (*wt_ptr++);
            acc += intermediate[k + 7] * (*wt_ptr++);
            acc += intermediate[k + 8] * (*wt_ptr++);
            acc += intermediate[k + 9] * (*wt_ptr++);
            acc += intermediate[k + 10] * (*wt_ptr++);
            acc += intermediate[k + 11] * (*wt_ptr++);
            acc += intermediate[k + 12] * (*wt_ptr++);
            acc += intermediate[k + 13] * (*wt_ptr++);
            acc += intermediate[k + 14] * (*wt_ptr++);
            acc += intermediate[k + 15] * (*wt_ptr++);
        }
        for (; k < input_size; k++) {
            acc += intermediate[k] * (*wt_ptr++);
        }
        
        // 這裡只需要 requant，不需要 ReLU
        *out_ptr++ = requant(acc, scale);
    }

};
