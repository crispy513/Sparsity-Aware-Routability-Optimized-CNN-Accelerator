import os
import pandas as pd
import matplotlib.pyplot as plt

def main():
    csv_path = os.path.join("test", "testbench", "dla", "sparsity_sweep_data.csv")
            
    if not os.path.exists(csv_path):
        print("[-] 錯誤：找不到數據檔案 sparsity_sweep_data.csv。")
        return
        
    print(f"[*] 成功載入實驗數據：{csv_path}")
    df = pd.read_csv(csv_path)
    
    # 將 Read 轉為 KB
    df['mem_reads_kb'] = df['mem_reads'] / 1024.0
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
    
    # ---- 圖一：稀疏度 vs 執行週期數 ----
    ax1.plot(df['sparsity'], df['cycles'], marker='o', linewidth=2.5, color='#1f77b4')
    ax1.set_title('Weight Sparsity vs. Hardware Execution Cycles', fontsize=12, fontweight='bold', pad=12)
    ax1.set_xlabel('Weight Sparsity (%)', fontsize=10)
    ax1.set_ylabel('Clock Cycles', fontsize=10)
    ax1.ticklabel_format(useOffset=False, style='plain', axis='y')
    ax1.grid(True, linestyle='--', alpha=0.5)
    
    for i, txt in enumerate(df['cycles']):
        y_offset = 20 if i % 2 == 0 else -25
        ax1.annotate(f"{txt:,}", (df['sparsity'].iloc[i], df['cycles'].iloc[i]), 
                     textcoords="offset points", xytext=(0, y_offset), 
                     ha='center', fontsize=8, fontweight='bold', color='#1f77b4')
        
    # ---- 圖二：稀疏度 vs DRAM 讀取量 (只顯示 Memory Reads) ----
    ax2.plot(df['sparsity'], df['mem_reads_kb'], marker='s', linewidth=2.5, color='#2ca02c')
    ax2.set_title('Weight Sparsity vs. DRAM Memory Traffic', fontsize=12, fontweight='bold', pad=12)
    ax2.set_xlabel('Weight Sparsity (%)', fontsize=10)
    ax2.set_ylabel('DRAM Reads (KB)', fontsize=10)
    ax2.grid(True, linestyle='--', alpha=0.5)
    
    # 標籤標示讀取量
    for i in range(len(df)):
        ax2.annotate(f"{df['mem_reads_kb'].iloc[i]:.1f}", 
                     (df['sparsity'].iloc[i], df['mem_reads_kb'].iloc[i]), 
                     textcoords="offset points", xytext=(15, 8), 
                     ha='center', fontsize=8, fontweight='bold', color='#2ca02c')
        
    plt.tight_layout()
    
    output_image = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sparsity_sweep_analysis.png")
    plt.savefig(output_image, dpi=300)
    print(f"\n分析圖表繪製完成，已儲存至: {output_image}")

if __name__ == "__main__":
    main()