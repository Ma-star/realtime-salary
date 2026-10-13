# 下班回血器 iPhone 客户端

这是 `realtime-salary` 的原生 SwiftUI 客户端，目标平台为 iOS 17 及以上。

## 功能

- 实时工资、下班倒计时与跨重启班次恢复
- 带薪/无薪休息、加班确认与单独估算
- 固定奖金、月薪倍数、年薪比例、目标奖金 × 绩效系数
- 五步下班结算、心情记录、放下仪式与脱敏战报
- “劳动结晶”情绪价值里程碑与最近 90 次结算记录
- Face ID/设备密码解锁金额、老板模式、后台隐私遮挡
- AES-GCM 加密文件 + 本机 Keychain 密钥，不申请网络权限

## 打开与运行

1. 安装完整 Xcode 15 或更高版本。
2. 打开 `RealtimeSalary.xcodeproj`。
3. 在 Signing & Capabilities 中选择你的 Apple Developer Team。
4. 选择 iPhone 模拟器或已连接的 iPhone，点击 Run。

薪资、当前班次和历史记录会使用 AES-GCM 加密后写入受完整文件保护的数据文件，密钥保存在 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` 级别的 Keychain 中。旧版本 `UserDefaults` 明文会在首次启动时迁移并删除。
