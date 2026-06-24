#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fstream>

#include "dla_hal.hpp"
#include "driver_dla.h"
#include "hal.hpp"
#include "runtime.h"

#include "mnist_weights.h"

#define COL_RESET "\033[0m"
#define COL_GREEN "\033[0;32m"
#define COL_CYAN  "\033[0;36m"
#define COL_RED   "\033[0;31m"

// ====================================================================
// 全域 Buffer 宣告
// 說明：加上 __attribute__((aligned(64))) 是為了滿足硬體 DMA 
// Burst Transfer (突發傳輸) 的記憶體對齊要求，避免匯流排錯誤。
// ====================================================================
static __attribute__((aligned(64))) uint8_t mnist_input[8192];
static __attribute__((aligned(64))) uint8_t buffer_A[8192];
static __attribute__((aligned(64))) uint8_t buffer_B[8192];

// 全連接層輸出 Buffer：使用 int32_t 儲存原始分數 (Logits)
// 說明：因為硬體量化不包含 Softmax，且運算中會出現負數，若強制轉為 uint8_t 會導致負數歸零。
static __attribute__((aligned(64))) int32_t buffer_C_logits[10];

static __attribute__((aligned(64))) int8_t  aligned_conv1_wt[144];
static __attribute__((aligned(64))) int32_t aligned_conv1_bias[16];
static __attribute__((aligned(64))) int8_t  aligned_conv2_wt[4608];
static __attribute__((aligned(64))) int32_t aligned_conv2_bias[32];

// ====================================================================
// 防止硬體邊界死鎖專用 Buffer (W=32, H=32, C=8) 與 MRSC 權重排列
// ====================================================================
static __attribute__((aligned(64))) uint8_t padded_mnist_input[8192]; 
static __attribute__((aligned(64))) int8_t  padded_conv1_wt[1152];     
static __attribute__((aligned(64))) int8_t  permuted_conv2_wt[4608]; 

// ====================================================================
// CPU Fully-Connected 層 (全連接層運算)
// 說明：承接 DLA 加速器算完的卷積特徵圖，進行最後的矩陣內積以輸出 10 個類別的分數。
// ====================================================================
void fc_layer_cpu(const uint8_t* input, const int8_t* weight, const int32_t* bias, int32_t* output,
                  int out_features, int in_features, int scale) {
    for (int i = 0; i < out_features; i++) {
        int32_t sum = bias[i];
        for (int j = 0; j < in_features; j++) {
            // 量化零點校正 (Zero-point Correction)：
            // DLA 硬體內建 MSB 翻轉，將 uint8_t 的 0 視為有號數的 -128。
            // 這裡由 CPU 手動扣除 128，將 uint8_t 特徵圖還原為真實的 int32_t 有號數。
            int32_t true_val = (int32_t)input[j] - 128;
            sum += true_val * (int32_t)weight[i * in_features + j];
        }
        // 直接輸出縮放後的原始分數 (允許負數)
        output[i] = sum >> scale;
    }
}

// ====================================================================
// 算 sparsity 的工具
// 說明：計算送入硬體 PE 陣列前，特徵圖中數值為 0（背景或經 ReLU 歸零）的比例
// ====================================================================
float calculate_act_sparsity(const uint8_t* array, int total_elements) {
    int zero_count = 0;
    for (int i = 0; i < total_elements; i++) {
        if (array[i] == 0) {
            zero_count++;
        }
    }
    return ((float)zero_count / total_elements) * 100.0f;
}

int main() {
    printf(COL_CYAN "\n[DEMO] 1. 初始化 DLA 加速器" COL_RESET "\n");
    static DlaHAL hal(DLA_MMIO_BASE_ADDR, DLA_MMIO_SIZE);
    set_dla_hal(&hal);
    hal.init();

    // 將唯讀資料複製到對齊的記憶體區段
    memcpy(aligned_conv1_wt, conv1_wt, sizeof(conv1_wt));
    memcpy(aligned_conv1_bias, conv1_bias, sizeof(conv1_bias));
    memcpy(aligned_conv2_wt, conv2_wt, sizeof(conv2_wt));
    memcpy(aligned_conv2_bias, conv2_bias, sizeof(conv2_bias));

    std::ifstream f_img("test_img.bin", std::ios::binary);
    if (!f_img.is_open()) {
        printf(COL_RED "[ERR] 找不到 test_img.bin！" COL_RESET "\n");
        hal.final(); 
        return 1;
    }
    
    f_img.read(reinterpret_cast<char*>(mnist_input), 784);
    if (f_img.gcount() != 784) {
        printf(COL_RED "[ERR] 讀取 test_img.bin 失敗或檔案大小不正確！" COL_RESET "\n");
        f_img.close();
        hal.final();
        return 1;
    }
    f_img.close();

    // ====================================================================
    // 1. 輸入影像 Padding 與 HWC 轉換
    // ====================================================================

    // 1. 解決 Partial Tile 死鎖問題：將 28x28 擴充為硬體偏好的 8的倍數 (32x32)
    // 2. 背景填 0：硬體讀取 0 會自動轉換為 -128，完美契合模型訓練時的背景數值。
    memset(padded_mnist_input, 0, sizeof(padded_mnist_input)); 
    for (int h = 0; h < 28; h++) {
        for (int w = 0; w < 28; w++) { 
            // 轉換為 HWC (Height, Width, Channel) 記憶體交錯排列以符合硬體 MAC 單元取資料的順序
            // 索引公式: h * (W * C) + w * C + c (此處 W=32, C=8, 將影像放在 c=0)
            padded_mnist_input[h * (32 * 8) + w * 8 + 0] = mnist_input[h * 28 + w];
        }
    }

    // ====================================================================
    // 2. 卷積權重記憶體排列轉換 (MCRS 轉 MRSC)
    // ====================================================================

    // Layer 1 權重翻轉 (同時將 C=1 擴充為硬體最低要求 C=8)
    // 無效通道 (c=1~7) 保持為 0，避免運算時產生負能量干擾正確的卷積結果
    memset(padded_conv1_wt, 0, sizeof(padded_conv1_wt)); // 保持 0，杜絕無效通道干擾
    for(int m = 0; m < 16; m++) {
        for(int r = 0; r < 3; r++) {
            for(int s = 0; s < 3; s++) {
                // 硬體要求順序 (MRSC): m * (R*S*C) + r * (S*C) + s * C + c
                int target_idx = m * (3*3*8) + r * (3*8) + s * 8 + 0; 
                // PyTorch 預設順序 (MCRS): m * (C*R*S) + c * (R*S) + r * S + s
                int src_idx = m * (1*3*3) + r * 3 + s;
                padded_conv1_wt[target_idx] = aligned_conv1_wt[src_idx];
            }
        }
    }

    // Layer 2 權重翻轉 (單純 MCRS 轉 MRSC)
    for(int m = 0; m < 32; m++) {
        for(int c = 0; c < 16; c++) {
            for(int r = 0; r < 3; r++) {
                for(int s = 0; s < 3; s++) {
                    int target_idx = m * (3*3*16) + r * (3*16) + s * 16 + c;
                    int src_idx = m * (16*3*3) + c * (3*3) + r * 3 + s;
                    permuted_conv2_wt[target_idx] = aligned_conv2_wt[src_idx];
                }
            }
        }
    }

    // ====================================================================
    // 3. DLA 硬體加速執行 (Layer 1 & Layer 2)
    // ====================================================================
    float sparsity_l1 = calculate_act_sparsity(padded_mnist_input, 8192); // 32 * 32 * 8 = 8192
    printf("Layer 1 輸入特徵稀疏度: %.2f%%\n", sparsity_l1);

    printf(COL_CYAN "[DEMO] 2. 執行 Layer 1" COL_RESET "\n");
    qconv2d_relu_maxpool(
        padded_mnist_input, padded_conv1_wt, buffer_A, aligned_conv1_bias, 
        4096, 8192, 1152,           
        16,                         
        DEFAULT_e, DEFAULT_p, DEFAULT_q, DEFAULT_r, DEFAULT_t, 
        1, 1, 3, 3, 8, 16, 32, 32, 7  
    );

    float sparsity_l2 = calculate_act_sparsity(buffer_A, 4096); // 16 * 16 * 16 = 4096
    printf("Layer 2 輸入特徵稀疏度: %.2f%%\n", sparsity_l2);

    printf(COL_CYAN "[DEMO] 3. 執行 Layer 2" COL_RESET "\n");
    qconv2d_relu_maxpool(
        buffer_A, permuted_conv2_wt, buffer_B, aligned_conv2_bias,    
        2048, 4096, 4608,          
        32,                        
        DEFAULT_e, DEFAULT_p, DEFAULT_q, DEFAULT_r, DEFAULT_t, 
        1, 1, 3, 3, 16, 32, 16, 16, 7 
    );

    // ====================================================================
    // 4. 有效區域裁剪與 HWC 轉 CHW
    // ====================================================================
    printf(COL_CYAN "[DEMO] 4. 正在抽取有效 7x7 區域 (HWC to CHW)..." COL_RESET "\n");
    static uint8_t buffer_B_cropped[32 * 7 * 7];
    for (int c = 0; c < 32; c++) {
        for (int h = 0; h < 7; h++) {
            for (int w = 0; w < 7; w++) {
                // 剔除 Layer 1 墊零所產生的無效邊界，只抽取左上角有效的 7x7 區域
                int src_idx = h * (8 * 32) + w * 32 + c; // DLA 輸出的 HWC 排列
                int dst_idx = c * 49 + h * 7 + w;        // 還原為 CPU FC 層需要的 CHW 排列        
                buffer_B_cropped[dst_idx] = buffer_B[src_idx];
            }
        }
    }

    // ====================================================================
    // 5. 輸出預測結果
    // ====================================================================
    printf(COL_CYAN "[DEMO] 5. 執行 Layer 3: Fully-Connected (CPU)..." COL_RESET "\n");
    fc_layer_cpu(buffer_B_cropped, (int8_t*)fc_wt, (int32_t*)fc_bias, buffer_C_logits, 10, 1568, 7);

    int predicted_digit = 0;
    int32_t max_prob = INT32_MIN; 
    
    printf("\n[*] 最終 10 個類別的輸出機率值 (原始分數 Logits): \n");
    for (int i = 0; i < 10; i++) {
        printf("  [%d]: %6d \n", i, buffer_C_logits[i]);
        if (buffer_C_logits[i] > max_prob) {
            max_prob = buffer_C_logits[i];
            predicted_digit = i;
        }
    }
    printf("\n");
    
    printf(COL_GREEN "========================================" COL_RESET "\n");
    printf(COL_GREEN "       MNIST 最終預測數字: %d " COL_RESET "\n", predicted_digit);
    printf(COL_GREEN "========================================" COL_RESET "\n\n");

    struct runtime_info ri = hal.get_runtime_info();
    unsigned long long current_cycles = (unsigned long long)ri.elapsed_cycle;
    uint32_t current_mem_read = ri.memory_read;
    uint32_t current_mem_write = ri.memory_write;

    printf("[DEMO] DLA 硬體效能報告:\n");
    printf("  - 執行週期 (Cycles)   : %llu\n", current_cycles);
    printf("  - 記憶體讀取 (Bytes)  : %u\n", current_mem_read);
    printf("  - 記憶體寫入 (Bytes)  : %u\n", current_mem_write);

    std::ifstream f_in("dla_metrics.tmp");
    if (!f_in.is_open()) {
        std::ofstream f_out("dla_metrics.tmp");
        if (f_out.is_open()) {
            f_out << current_cycles << " " << current_mem_read << "\n";
            f_out.close();
        }
    } 
    else {
        unsigned long long base_cycles = 0;
        uint32_t base_mem_read = 0;
        
        f_in >> base_cycles >> base_mem_read;
        f_in.close();
        
        remove("dla_metrics.tmp");

        // 避免分母為 0 的嚴謹寫法
        double c_saving = (double)(base_cycles - current_cycles) / (double)base_cycles * 100.0;
        double m_saving = (double)(base_mem_read - current_mem_read) / (double)base_mem_read * 100.0;

        printf("\n" COL_GREEN "========================================" COL_RESET "\n");
        printf(COL_GREEN "         分析報告" COL_RESET);
        printf("\n" COL_GREEN "========================================" COL_RESET "\n");
        printf(" Layer 1 特徵圖稀疏度 (MNIST背景+邊界填零): %.2f%%\n", sparsity_l1);
        printf(" Layer 2 特徵圖稀疏度 (經 ReLU 函數激活後)  : %.2f%%\n", sparsity_l2);
        printf(COL_GREEN "------------------------------------------------------------" COL_RESET "\n");
        printf(" [指標 1] 執行週期 (Execution Cycles):\n");
        printf("   - Baseline (無 Bitmap) : %llu\n", base_cycles);
        printf("   - Optimized(有 Bitmap) : %llu\n", current_cycles);
        printf(COL_CYAN "   => 縮短比例 : %.2f%%\n" COL_RESET, c_saving);
        printf(COL_GREEN "------------------------------------------------------------" COL_RESET "\n");
        printf(" [指標 2] 記憶體讀取量 (Memory Read Bandwidth):\n");
        printf("   - Baseline (無 Bitmap) : %u Bytes\n", base_mem_read);
        printf("   - Optimized(有 Bitmap) : %u Bytes\n", current_mem_read);
        printf(COL_CYAN "   => 節省頻寬 : %.2f%%\n" COL_RESET, m_saving);
        printf(COL_GREEN "============================================================" COL_RESET "\n\n");
    }

    hal.final();
    return 0;
}