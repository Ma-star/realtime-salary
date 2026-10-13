# 下班回血器 macOS 客户端

原生 SwiftUI macOS 应用，最低支持 macOS 14。发布包是 Universal Binary，同时支持 Apple 芯片和 Intel Mac。

## 一键构建

```bash
./macos/build.sh
```

脚本会编译 arm64 与 x86_64 两个版本，合并为通用 App，执行本地签名并生成：

```text
macos/dist/下班回血器-macOS.zip
```

## 隐私

应用不申请网络权限。薪资、当前班次和结算记录使用 AES-GCM 加密文件保存，密钥存放在仅本机可用的 Keychain 中。

双击应用即可运行。如果 macOS 因本地签名提示无法验证，可在 Finder 中右键应用并选择“打开”，再确认一次。
