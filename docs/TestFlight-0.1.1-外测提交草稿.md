# 0.1.1（7.1）外测提交准备与执行记录

目标构建：`ddcc9625-a6bc-4138-871f-cec1abd870c4`，App `6828962951`。当前 Apple 返回 VALID、未过期、内部 IN_BETA_TESTING、外部 READY_FOR_BETA_SUBMISSION，无成功审核记录。

用户截图显示外测“测试内容”向导已有文字，点击提交返回“处理你的请求时出错。请稍后再试。”未拿到这次网页请求的具体错误代码，不能用旧 5.1 的 HTTP 422 代替新构建响应。

## 拟更新的公开 Beta 描述

大学生课表工具的早期演示版本。无需登录，启动后展示独立演示课程，使用真实日期与时间。支持整页滑动切周、长按课程投放纸篓的非删除互动、课表联动黑白手绘人物，以及桌面和锁屏组件。演示编辑在本次会话生效，重启恢复样例，已有个人课程文件保持隔离。学校教务导入未提供；实时活动的后台自动结束及多节自动衔接仍在完善。

## 拟更新的审核备注

Native university timetable demo. No login, subscription, payment, or demo account is required. On first launch the app displays an isolated sample timetable using the real date and time. Swipe horizontally across the timetable to change weeks. Long-press a course and drop it in the contextual bin for a visual interaction; this does not delete the course. Edits are held for the current demo session and reset to sample data after relaunch; existing personal SwiftData files are not overwritten. Home Screen and Lock Screen widgets show the sample schedule. School-system login/import is not implemented. Background automatic Live Activity ending and multi-course handoff are not reliable yet. Notification permission is optional and requested only if the tester enables reminders.

## 拟执行操作与边界

沿用用户之前授权的审核联系人和反馈邮箱，不修改电话、账号、测试者或协议。更新描述与审核备注，确认 7.1 的测试说明非空，然后向 Apple 实际提交该构建一次。成功即记录审核编号；失败保存完整错误和非敏感请求追踪标识。不会批量重复请求，也不会使现有构建失效。

首次实际提审在自动审批时被拒绝：当时直接授权为内测安装排查，早前外测排查暂停，截图未被视为明确恢复外测提审授权。

用户随后明确答复“同意，更新说明并提交一次外测审核”。已更新上面的演示版描述和审核备注，保留现有联系人和反馈邮箱，实际提审一次。北京时间 2026-10-31 13:37:22 返回 HTTP 422 ENTITY_UNPROCESSABLE、Please try again later，无具体缺项。错误 ID `8ace89c8-5d1e-4aa4-89a8-30656aa0a7b2`，x-request-id `UNCHDTZWUV4XPH4S3GRDOHTJBI`。当前未进入审核，未继续循环重试。
