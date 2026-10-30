# Expo 云端模拟器预览

目标：在 Windows 浏览器查看现有 SwiftUI APP；不申请苹果分发证书、不上传 TestFlight。

## 当前状态

最新 UI 第二版验证：构建 [d9d1219e-9c5a-43c5-9fbc-2f654a9b87bf](https://expo.dev/accounts/ithte/projects/campus-schedule-native/builds/d9d1219e-9c5a-43c5-9fbc-2f654a9b87bf) 状态 FINISHED，已导出十二张截图到 `screenshots/`。验证环境为 Xcode 27.0、iOS 27.0 / iPhone 17。已检查五天、七天、深浅色、大字体和两个新表单的页面渲染，修复日期截断、节次轴错位和大字体时间拆行。尚未执行真实触控、表单保存或真机验收。

用户已付款购买 Apple Developer Program，当前仍在处理会员资格，尚不能开始签名。会员激活后可准备 TestFlight；未上传或发布任何真机版本。以下保留最初配置和第一版构建记录：

- 已安装并检查 EAS CLI 27.2.0，确认支持 `simulator:start` 与浏览器预览。
- 已配置 `simulator` 构建 profile，使用 `macos-tahoe-26.6-xcode-27.0`，最低 iOS 27.0。
- 已生成 `ios/CampusSchedule.xcodeproj` 和共享 Scheme；源文件仍位于根目录 `CampusSchedule/`。
- 已通过原生工程解析器与本地配置检查，首个模拟器构建已编译成功。
- 已登录 Expo 账号 `ithte`，关联项目 ID `7ff78bf0-9088-4084-a76c-0615b1903ed3`。
- 首个模拟器构建 `52a5f62c-37ea-4893-8ca4-a0cb868bfd7a` 状态 FINISHED，已生成 `.app` 模拟器归档；并非真机安装包。
- 启动云端交互模拟器时，Expo 明确返回账号 `ithte` 尚未开放 EAS Simulator，需要加入 [等候名单](https://expo.dev/services/simulators)。没有成功启动会话，也没有预览链接。
- 已增加构建机模拟器截图配置 `ui-screenshots` 作为备用验证方式。首次自定义流程误触发 Expo prebuild，已改为直接运行 Xcode，不添加 Expo SDK。
- 修正后的截图构建 ID `c935de0f-8754-495d-9249-0abf634ec3b6` 状态 FINISHED。已在 Xcode 27.0、iOS 27.0 / iPhone 17 模拟器安装并启动 APP，成功导出今日、周课表、设置的浅色与深色六张截图。
- 截图已下载到根目录 `screenshots/`，其中 `simulator.json` 和 `xcode.txt` 记录实际运行环境。该目录不提交 Git、不上传到后续构建。
- [成功的截图构建](https://expo.dev/accounts/ithte/projects/campus-schedule-native/builds/c935de0f-8754-495d-9249-0abf634ec3b6)。已确认页面可渲染；尚未验证真实交互、课程详情弹窗、最大字体、真机通知和性能。
- [Expo 项目](https://expo.dev/accounts/ithte/projects/campus-schedule-native) · [首个构建日志](https://expo.dev/accounts/ithte/projects/campus-schedule-native/builds/52a5f62c-37ea-4893-8ca4-a0cb868bfd7a)
- 本地使用 Git 管理原型代码、工程与文档，尚未推送远端；截图与工具缓存不纳入版本库。

## 首次登录与关联

在 VS Code 打开项目根目录，打开终端运行：

```powershell
npx.cmd eas-cli@27.2.0 login
```

按官方提示在浏览器登录。浏览器网页已登录不代表命令行已登录。不要把密码、验证码、访问令牌提交到项目或发送到聊天。

登录完成后检查账号并关联项目：

```powershell
npx.cmd eas-cli@27.2.0 whoami
npm.cmd run eas:init
```

选择自己的个人账号或已有团队；已有项目优先关联，避免重复创建。成功后 `app.json` 应出现 `extra.eas.projectId`。显示名称 CampusSchedule 只是工程名称，不代表正式产品名称。

## 构建

```powershell
npm.cmd run preview:build
```

该命令重新扫描 Swift 文件、生成工程、检查配置，再上传并构建模拟器版本。`package.json` 仅用于工具命令，不引入 React、React Native、Expo SDK 或 JavaScript 页面。空 Podfile 适配 EAS 默认 `pod install` 阶段，不安装业务依赖。

只使用 `simulator` profile；不需要付费 Apple 开发者账号。如果流程要求苹果分发证书或真机注册，应检查是否选错 profile。Expo 构建与模拟器仍受账号额度、功能权限和计费规则约束；遇到付费要求先停止，不自动升级套餐。

等待构建状态为 FINISHED，记录该次 BUILD_ID。失败时先查看云端日志，不能把“已上传”视为“已编译成功”。

## 在浏览器打开

**当前账号尚无 EAS Simulator 权限，以下命令配置完备但不可用。需账号获准后才能执行成功；不要因此购买苹果开发者会员，苹果会员不能解锁 Expo 的权限。**

将下面占位内容换成实际构建 UUID，不保留尖括号：

```powershell
npm.cmd run preview:start -- <BUILD_ID>
```

此命令只接收合法构建 ID，创建名为 `CampusSchedule-UI-preview` 的浏览器预览会话。会话最长 15 分钟、空闲 5 分钟停止；若账号计划限制更短，按实际限制调整。默认不开放匿名分享。

打开命令输出的浏览器预览链接，用所属 Expo 账号登录。不同 CLI / 控制台版本可能同时显示会话管理页与预览链接，以实际输出为准。

看完可主动结束：

```powershell
npm.cmd run preview:stop
```

连接信息保存在被忽略的 `.env.eas-simulator` 文件；不要提交该文件或随意分享带令牌的预览链接。

## 无交互模拟器权限时导出截图

```powershell
npm.cmd run prepare:ios
npx.cmd eas-cli@27.2.0 build --platform ios --profile ui-screenshots
```

该 profile 在构建机启动模拟器，安装真实 APP，分别打开今日、周课表、设置、添加课程、学期与作息五个页面并拍摄浅色与深色截图，另外拍摄七天周课表及辅助功能大字体列表。通过启动环境变量选择页面，正常启动不受影响。

成功后从构建页面下载附加截图产物，包含十二张 PNG、实际模拟器信息和 Xcode 版本。截图只能用于查看和验证页面，不提供交互，也不代表真机验证完成。失败时保留日志，不将编译成功视为截图成功。

## 重要限制

- 云端模拟器功能目前标为实验性，以实际账号权限、系统运行时与服务状态为准。
- Xcode 27 构建环境已在官方列表中确认；预览会话是否提供 iOS 27 运行时仍需启动后核实。如果只有较旧系统，当前 iOS 27.0 APP 无法启动，应调整运行环境，不能声称已预览 iOS 27。
- 网页显示的是远程模拟器，不是安装到自己的 iPhone。真机通知、性能、材质与触控仍需后续真机验证。
- 新增 Swift 文件后必须重新生成工程；云端每次构建要包含新的原生工程与所有源文件。
- 应用图标、生产签名、发布账号和实际 Bundle ID 仍未设置，本配置不用于商店发布。

## 官方参考

- [原生 Swift 工程使用 EAS](https://github.com/expo/skills/blob/main/plugins/expo/skills/eas-app-stores/references/native-ios.md)
- [EAS 构建环境](https://docs.expo.dev/build-reference/infrastructure/)
- [模拟器构建](https://docs.expo.dev/build-reference/simulators/)
- [云端模拟器分享与预览](https://expo.dev/articles/cloud-simulators/share-a-simulator-link)
