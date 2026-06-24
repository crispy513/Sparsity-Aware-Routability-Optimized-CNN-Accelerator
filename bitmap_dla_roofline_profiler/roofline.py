import csv
import os
import matplotlib.pyplot as plt
import numpy as np

# ==========================================
# 1. 硬體天花板
# ==========================================
peak_macs_per_cycle = 48.0  # 48 PEs
peak_bytes_per_cycle = 4.0  # 32-bit bus = 4 Bytes
ridge_point = peak_macs_per_cycle / peak_bytes_per_cycle

# ==========================================
# 2. 預先定義三個 Case 的形狀 (M, C, W, H, R, S)
# ==========================================
case_shapes = {
    0: {"M": 16,  "C": 3,  "W": 8,  "H": 8,  "R": 3, "S": 3},
    1: {"M": 64,  "C": 3,  "W": 32, "H": 32, "R": 3, "S": 3},
    2: {"M": 192, "C": 64, "W": 16, "H": 16, "R": 3, "S": 3}
}

# ==========================================
# 3. 讀取與分類 CSV 數據
# ==========================================
csv_file = "test/testbench/dla/roofline_data.csv"

if not os.path.exists(csv_file):
    print(f"Error: 找不到 {csv_file}！請確認 Makefile 已成功執行測試。")
    exit(1)

origin_oi, origin_perf = [], []
bitmap_oi, bitmap_perf = [], []

with open(csv_file, newline='') as f:
    reader = list(csv.DictReader(f))
    
    # 根據 Makefile 邏輯，前3筆是 Origin，後3筆是 Bitmap
    for i, row in enumerate(reader):
        c_idx = int(row['case'])
        pe_cycles = int(row['pe_cycles']) # 使用純 PE 週期
        mem_access = int(row['mem_reads']) + int(row['mem_writes'])
        
        shape = case_shapes[c_idx]
        total_macs = shape['M'] * shape['C'] * shape['W'] * shape['H'] * shape['R'] * shape['S']
        
        oi = total_macs / mem_access if mem_access > 0 else 0
        perf = total_macs / pe_cycles if pe_cycles > 0 else 0
        
        if i < 3:
            origin_oi.append(oi)
            origin_perf.append(perf)
        else:
            bitmap_oi.append(oi)
            bitmap_perf.append(perf)

# ==========================================
# 4. 建立繪圖函數
# ==========================================
def draw_roofline(test_oi, test_perf, title_text, output_filename):
    if not test_oi:
        return

    plt.figure(figsize=(10, 6))

    # 線性範圍的 OI 軸
    oi_axis = np.linspace(0, 150, 500) 
    perf_roof = np.minimum(peak_macs_per_cycle, oi_axis * peak_bytes_per_cycle)

    # 1. 畫出 Roofline 基線
    plt.plot(oi_axis, perf_roof, label='Hardware Peak', color='black', linewidth=3)

    # 2. 標示 Ridge Point
    plt.axvline(x=ridge_point, color='gray', linestyle='--', alpha=0.6)
    plt.scatter([ridge_point], [peak_macs_per_cycle], color='black', s=100, zorder=10)
    plt.text(ridge_point + 3, peak_macs_per_cycle * 0.9, 
             f'Ridge Point\n(OI={ridge_point:.1f})', 
             fontsize=10, fontweight='bold', color='black')

    colors = ['red', 'green', 'orange']

    # 3. 畫出真實數據點並在點上方標註
    for i in range(len(test_oi)):
        c_idx = i # 對應 case 0, 1, 2
        shape = case_shapes[c_idx]
        label_text = f"Case {c_idx} ({shape['M']}x{shape['C']}x{shape['W']}x{shape['H']})"
        
        plt.scatter(test_oi[i], test_perf[i], color=colors[i % len(colors)], s=120, 
                    edgecolors='black', label=label_text, zorder=10)
        
        # 直接在上方標註數值與單位
        plt.annotate(f'{test_perf[i]:.2f}\nMACs/cycle', 
                     xy=(test_oi[i], test_perf[i]), 
                     xytext=(0, 12),
                     textcoords='offset points', 
                     ha='center',
                     fontsize=9, 
                     fontweight='bold', 
                     color=colors[i % len(colors)])

    # 4. 樣式設定
    plt.title(title_text, fontsize=16, fontweight='bold')
    plt.xlabel('Operational Intensity (MACs / byte)', fontsize=12)
    plt.ylabel('Performance (MACs / PE Active Cycle)', fontsize=12)

    plt.xlim(0, 150)
    plt.ylim(0, 55)
    plt.grid(True, linestyle='--', alpha=0.5)
    plt.legend(loc='lower right', fontsize=10)
    plt.tight_layout()

    plt.savefig(output_filename, dpi=300)
    print(f"Successfully generated {output_filename}!")
    plt.close()

# ==========================================
# 5. 分別產生兩張圖表
# ==========================================
draw_roofline(origin_oi, origin_perf, 'Pure PE Roofline Analysis (Origin)', 'roofline_origin.png')

if bitmap_oi:
    draw_roofline(bitmap_oi, bitmap_perf, 'Pure PE Roofline Analysis (Bitmap)', 'roofline_bitmap.png')