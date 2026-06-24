import torch
from torchvision import datasets, transforms
import numpy as np
import os
from PIL import Image

def generate_test_image():
    # 建立資料夾路徑
    dataset_dir = './dataset'
    os.makedirs(dataset_dir, exist_ok=True)

    # 定義轉換：轉成 Tensor 並將數值放縮回 0 ~ 255
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Lambda(lambda x: x * 255.0)
    ])

    print("[*] 正在載入 MNIST 測試資料集...")
    # 載入測試集
    test_dataset = datasets.MNIST(root=dataset_dir, train=False, download=True, transform=transform)

    # 抓取測試集的第一張圖片 (在 MNIST 測試集中，第一張圖片是數字 '7')
    # 可以更改 index 來測試不同的圖片，例如 test_dataset[1] 是 '2'
    index = 0
    image, label = test_dataset[index]

    # 將 1x28x28 的 Tensor 轉換為一維 784 bytes 的 uint8 陣列
    img_numpy = np.round(image.numpy()).clip(0, 255).astype(np.uint8)
    
    # 將陣列寫入二進位檔案 test_img.bin
    output_filename = "test_img.bin"
    with open(output_filename, "wb") as f:
        f.write(img_numpy.tobytes())

    img_2d = img_numpy.squeeze()
    pil_img = Image.fromarray(img_2d, mode='L')  # mode='L' 代表灰階
    output_png = "test_img.png"
    pil_img.save(output_png)

    print(f"[*] 成功產生 {output_filename}！")
    print(f"[*] 這張圖片的真實數字標籤為: {label}")

if __name__ == "__main__":
    generate_test_image()