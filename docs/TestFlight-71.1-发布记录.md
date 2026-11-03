# 课间册 0.1.0（71.1）发布记录

用户于 2026-11-03 要求暂停新增功能，发布当前修复版并提供公开链接。

- App：课间册；Apple ID：`6829142615`。
- 源码：`161a5997655e167bed8c3159566ab68b0135d595`。
- [签名上传任务 41622627147](https://github.com/ithtelab/campus-schedule-native/actions/runs/41622627147)：成功；2026-11-03 18:53:57（北京时间）取得上传回执，版本和 App ID 与目标一致。
- Apple 处理状态 VALID、未过期；新构建 ID `692bcfc4-e7e2-4572-ba01-cf3ab7c7756d`，内测状态 IN_BETA_TESTING，已关联本人内测组，设备实际更新仍待用户验证。
- [公开邀请地址](https://testflight.apple.com/join/s1RtwCzq)：沿用当前 App 的公开组，启用且限 100 人，新构建已加入该组。**公开下载须等待本构建 Beta 审核通过**，不能将链接存在当作已可下载。
- 2026-11-03 19:01:03（北京时间）实际提交一次 Beta 审核成功。已单独读回审核资源，`betaReviewState = WAITING_FOR_REVIEW`，`externalBuildState = WAITING_FOR_BETA_REVIEW`。提交后的组列表查询曾返回 Apple 500，独立读回确认提交已成功，不重复提交。
- 审核联系人沿用已授权资料，中英文测试说明和 App 描述更新成功。仅发布 TestFlight，未提交 App Store 正式分发。

## 发布前证据

[原生验证任务 41619548576](https://github.com/ithtelab/campus-schedule-native/actions/runs/41619548576) 的产物保存在本地忽略目录 `.tool-cache/native-proof-41619548576/`。

- 312 项测试、25 个套件通过，主 App 与扩展原生编译成功。
- `data-reliability-smoke.txt`：PASS，覆盖实际内存 Store 导入、稳定 ID、周次、目标学期、作息提交和读取保护。
- 人物资源与动作检查、本地持久化检查通过；考试编辑页、设置页和组件内容预览已检查截图。
- 工作流整体触及 20 分钟时限，在后段演示与实时活动检查被取消，不能视为整套验证通过。共享容器检查为 UNAVAILABLE；组件预览也不是实际桌面宿主交互验收。

## 本版范围

教务网页 HTTP 兼容和解析修复，学校入口数量文案更正；考试首次编辑白屏、外观切换、设置页校园卡片；小组件人物放大与按课表状态响应；作息、重复导入、备份、读取保护和组件跳转修复。

仍使用独立演示数据，导入和编辑仅在本次会话生效，重启恢复样例，个人 SwiftData 文件保持隔离。未加入教师模式、纪念日和倒数日。实时活动后台完整自动结束仍未解决，不宣称修复。审核说明使用 `TestFlight-修复版发布说明.json`，保留原有已授权联系资料。
