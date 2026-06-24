import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
import numpy as np
import os

# ==========================================
# 1. 定義契合 DLA 的 LeNet 模型
# ==========================================
class SimpleLeNet(nn.Module):
    def __init__(self):
        super(SimpleLeNet, self).__init__()
        # Input: 1x28x28
        # Conv1: 1 in_channel, 16 out_channels, 3x3 kernel, pad=1 -> 輸出 16x28x28
        # MaxPool: 2x2 -> 輸出 8x14x14
        self.conv1 = nn.Conv2d(1, 16, kernel_size=3, stride=1, padding=1)
        self.relu1 = nn.ReLU()
        self.pool1 = nn.MaxPool2d(kernel_size=2, stride=2)

        # Conv2: 8 in_channels, 32 out_channels, 3x3 kernel, pad=1 -> 輸出 32x14x14
        # MaxPool: 2x2 -> 輸出 32x7x7
        self.conv2 = nn.Conv2d(16, 32, kernel_size=3, stride=1, padding=1)
        self.relu2 = nn.ReLU()
        self.pool2 = nn.MaxPool2d(kernel_size=2, stride=2)

        # FC1: 32 * 7 * 7 = 1568 -> 10
        self.fc = nn.Linear(1568, 10)

    def forward(self, x):
        x = self.pool1(self.relu1(self.conv1(x)))
        x = self.pool2(self.relu2(self.conv2(x)))
        x = x.view(-1, 1568) 
        x = self.fc(x)
        return x

# ==========================================
# 2. 訓練模型 (使用 MNIST)
# ==========================================
def train_model():
    dataset_dir = './dataset'
    
    if not os.path.exists(dataset_dir):
        print(f"[*] 找不到 {dataset_dir} 資料夾，正在自動建立...")
        os.makedirs(dataset_dir, exist_ok=True)

    print("[*] 準備下載/載入 MNIST 資料集並開始訓練...")
    
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Lambda(lambda x: (x * 255.0) - 128.0) 
    ])
    
    train_dataset = datasets.MNIST(root=dataset_dir, train=True, download=True, transform=transform)
    train_loader = torch.utils.data.DataLoader(train_dataset, batch_size=64, shuffle=True)

    test_dataset = datasets.MNIST(root=dataset_dir, train=False, download=True, transform=transform)
    test_loader = torch.utils.data.DataLoader(test_dataset, batch_size=1000, shuffle=False)

    model = SimpleLeNet()
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001)

    epochs = 10
    for epoch in range(epochs):
        model.train()
        for batch_idx, (data, target) in enumerate(train_loader):
            optimizer.zero_grad()
            output = model(data)
            loss = criterion(output, target)
            loss.backward()
            optimizer.step()
            
            if batch_idx % 100 == 0:
                print(f"Train Epoch: {epoch} [{batch_idx * len(data)}/60000] Loss: {loss.item():.4f}")
        
        model.eval()
        test_loss = 0
        correct = 0
        
        with torch.no_grad():
            for data, target in test_loader:
                output = model(data)
                test_loss += criterion(output, target).item() * data.size(0)
                pred = output.argmax(dim=1, keepdim=True)
                correct += pred.eq(target.view_as(pred)).sum().item()

        test_loss /= len(test_loader.dataset)
        accuracy = 100.0 * correct / len(test_loader.dataset)
        
        print("----------------------------------------------------------------")
        print(f"Epoch {epoch} 驗證摘要 -> 測試集 Loss: {test_loss:.4f}, 整體正確率: {correct}/{len(test_loader.dataset)} ({accuracy:.2f}%)")
        print("----------------------------------------------------------------")
    
    print("[*] 訓練完成")
    return model

# ==========================================
# 3. Quantization 與匯出 C Header
# ==========================================
def export_to_c_header(model, filename="mnist_weights.h"):
    print(f"[*] 準備量化 (Scale=7) 並匯出為 {filename} ...")
    
    SCALE_FACTOR = 128.0 
    
    def quantize_weight(tensor):
        np_array = tensor.detach().numpy()
        q_array = np.round(np_array * SCALE_FACTOR).clip(-128, 127).astype(np.int8)
        return q_array

    def quantize_bias(tensor):
        np_array = tensor.detach().numpy()
        q_array = np.round(np_array * SCALE_FACTOR).astype(np.int32)
        return q_array

    with open(filename, "w") as f:
        f.write("#ifndef MNIST_WEIGHTS_H\n")
        f.write("#define MNIST_WEIGHTS_H\n\n")
        f.write("#include <stdint.h>\n\n")

        w_conv1 = quantize_weight(model.conv1.weight)
        b_conv1 = quantize_bias(model.conv1.bias)
        f.write(f"// Conv1 Weight Shape: {w_conv1.shape} -> NCHW\n")
        f.write("const int8_t conv1_wt[] = {" + ",".join(map(str, w_conv1.flatten())) + "};\n")
        f.write("const int32_t conv1_bias[] = {" + ",".join(map(str, b_conv1.flatten())) + "};\n\n")

        w_conv2 = quantize_weight(model.conv2.weight)
        b_conv2 = quantize_bias(model.conv2.bias)
        f.write(f"// Conv2 Weight Shape: {w_conv2.shape} -> NCHW\n")
        f.write("const int8_t conv2_wt[] = {" + ",".join(map(str, w_conv2.flatten())) + "};\n")
        f.write("const int32_t conv2_bias[] = {" + ",".join(map(str, b_conv2.flatten())) + "};\n\n")

        w_fc = quantize_weight(model.fc.weight)
        b_fc = quantize_bias(model.fc.bias)
        f.write(f"// FC Weight Shape: {w_fc.shape} -> [out_features, in_features]\n")
        f.write("const int8_t fc_wt[] = {" + ",".join(map(str, w_fc.flatten())) + "};\n")
        f.write("const int32_t fc_bias[] = {" + ",".join(map(str, b_fc.flatten())) + "};\n\n")

        f.write("#endif // MNIST_WEIGHTS_H\n")
        
    print("[*] 匯出成功！")

if __name__ == "__main__":
    trained_model = train_model()
    export_to_c_header(trained_model)