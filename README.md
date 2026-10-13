# 下班回血器 💰

> 把“今天又熬了多久”翻译成“我正在为自己积累多少选择权”。

下班回血器是一款面向打工人的实时工资与情绪陪伴工具，提供 Web、iPhone 和 macOS 三个平台版本。它不仅计算每秒收入，还会单独核算奖金、加班和休息，在下班时完成一次有边界感的“封账”。

![下班回血器 macOS 客户端](screenshots/macos-dashboard.png)

本仓库基于 [mereithhh/realtime-salary](https://github.com/mereithhh/realtime-salary) 二次开发，并保留原项目历史。

## 下载 macOS 客户端

[从 GitHub Releases 下载最新版](https://github.com/Ma-star/realtime-salary/releases/latest)

- 支持 macOS 14 及以上
- 通用二进制：Apple 芯片与 Intel Mac 均可运行
- 首次打开若被系统拦截，请在 Finder 中右键 App，选择“打开”
- 自用构建采用本地签名，未经过 Apple Developer ID 公证

## 功能

- 实时工资、每秒/每小时价值与下班倒计时
- 月薪、年薪、日薪、时薪等计算周期
- 固定奖金、月薪倍数、年薪比例、目标奖金 × 绩效系数
- 带薪/无薪休息与加班倍率单独核算
- 暂停、继续、重置与五步下班结算
- 心情记录、放下仪式、劳动结晶与脱敏战报
- 金额默认打码、“老板来了”一键隐藏
- 原生客户端使用 AES-GCM 加密文件和本机 Keychain 密钥
- 原生客户端不要求登录，不接入分析服务，不访问网络

## 平台

### Web

```bash
npm install
npm run dev
```

运行测试和生产构建：

```bash
npm test
npm run build
```

### macOS

macOS 客户端使用 SwiftUI。安装 Xcode Command Line Tools 后运行：

```bash
./macos/build.sh
```

成品会生成在 `macos/dist/下班回血器-macOS.zip`。实现说明见 [macos/README.md](macos/README.md)。

### iPhone

iOS 17 及以上，使用 Xcode 打开 `ios/RealtimeSalary.xcodeproj`，选择自己的 Apple Developer Team 后运行。详细说明见 [ios/README.md](ios/README.md)。

## 隐私设计

- 默认隐藏真实金额，查看金额需要本机身份验证
- 薪资、班次和结算记录加密后只保存在设备本地
- 密钥保存在 Keychain，不与加密数据放在一起
- 分享内容默认脱敏，不显示工资数字
- 用户可以随时清除全部本机数据

## 产品文档

- [产品方向](PRODUCT.md)
- [完整 PRD](docs/PRD.md)

欢迎提交 Issue 和 Pull Request。
