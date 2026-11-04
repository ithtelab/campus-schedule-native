# 课间册 1.0（90.1）发布记录

2026-11-04 上传 1.0 上线前构建，源码为 `80c8fa1`。此前的 89.1 因主 App 和组件共用签名配置未通过归档，未上传。

- [签名上传任务](https://github.com/ithtelab/campus-schedule-native/actions/runs/41785967280) 成功。383 项规则测试通过，归档检查确认真机包没有示例课表标记，内置隐私政策，主 App 拥有 iCloud 键值存储权限，组件使用独立共享组签名配置。
- [原生界面验收](https://github.com/ithtelab/campus-schedule-native/actions/runs/41785515348) 验证全新启动显示空课表、iCloud 开关可操作、关于页及离线隐私政策可打开。模拟器结果与截图在 `.tool-cache/release-ui-41785515348/`。实际跨设备 iCloud 同步仍待真机验证。
- Apple 构建 ID `2da92da6-8ce0-470a-a990-1bb1380d129e`，处理有效，已加入本人内测组。已提交 Beta 审核，苹果返回 `WAITING_FOR_REVIEW`。公开邀请继续使用 [现有 TestFlight 链接](https://testflight.apple.com/join/s1RtwCzq)。
- App Store Connect 的 1.0 草稿已从构建 15.1 切换至 90.1，仍为 `PREPARE_FOR_SUBMISSION`。草稿的 [公开隐私政策](https://github.com/ithtelab/campus-schedule-native/blob/master/PRIVACY.md) 已验证可读取。正式 App Store 审核尚未提交。
