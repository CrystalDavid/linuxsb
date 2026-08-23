# P0 Report

生成时间：2026-08-23（Asia/Shanghai）

## 总结

P0 技术验证已经在真实 HarmonyOS 设备完成。P0-1 至 P0-7 均为 **PASS**；P0-8 真实写操作严格保持 **NOT RUN**。RCP 匿名请求、轻量协议解码、TaskPool、临时 ArkWeb 官方登录、Cookie 内存衔接、登录后 RCP 会话和进程级会话清理均获得设备证据。

当前主架构可以继续，但存在一个明确的产品能力风险：Topic 605 在匿名和登录后响应中都声明有 5 条回复，却都没有携带回复节点。登录会话本身已通过，下一轮只能做“回复数据来源发现”，检查额外分页或 AJAX 路由；在数据来源确认前不开发正式主题详情页。

本轮没有扩展完整首页、完整主题详情、个人中心或正式 UI；没有创建常驻或隐藏 ArkWeb；没有执行发帖、回复、编辑、删除或任何真实 POST。

## 真机环境

- 设备型号：SGT-AL10
- 系统版本：OpenHarmony 7.0.0.102；软件版本 `SGT-AL10 7.0.0.102(SP8C00E102R5P3)`
- API Version：26（满足 API 23+ 前置条件）
- 连接方式：HDC TCP / IP，无线连接；不是 USB
- 网络：Wi-Fi；HDC 与电脑位于同一局域网
- HDC：DevEco Studio 内置 `hdc` 3.2.0d
- Bundle Name：`com.example.shaobingcommunity`
- HAP：`entry/build/default/outputs/default/entry-default-signed.hap`，358237 bytes
- HAP 签名：**PASS**；使用项目负责人自己的 DevEco 自动调试签名，未使用 ArkDO 的证书、Profile、密码或路径
- 安装：**PASS**；`install bundle successfully`
- 启动：**PASS**；`start ability successfully`
- 设备证据：`artifacts/p0-device/device-target.txt`、`artifacts/p0-device/device-api-version.txt`

说明：工程兼容下限仍是 API 23，但本轮真实设备是 API 26，因此“恰好 API 23 设备”的兼容性没有单独覆盖。

## 工程、SDK 与 Git

- 工程目录：`C:\Users\David\DevEcoStudioProjects\ShaobingCommunity`
- Git：当前目录不是 Git 仓库；没有初始化仓库、创建分支或提交。
- 工程模型：ArkTS、Stage 模型、单 entry HAP，设备类型为 phone / tablet / 2in1。
- SDK：`compatibleSdkVersion` 为 HarmonyOS 6.1.0 API 23；`targetSdkVersion` 为 HarmonyOS 6.1.1 API 24；本机 DevEco SDK 为 HarmonyOS 6.1.1 API 24，版本 6.1.1.125。
- hvigor：6.24.4；命令行使用 DevEco 自带 JBR 21 和 Hvigor Wrapper，没有修改系统 PATH。
- 自动签名已写入 `build-profile.json5` 并绑定 `default` 产品；签名值、密码和 Cookie 值均未写入本报告。
- 与 `C:\Code\ArkDO` 的 clean-room 检查只发现 DevEco 默认模板文件相同；没有复制 ArkDO 的业务源码、注释、图标、截图或签名材料。

## P0 实现边界

- RCP 只执行 GET：首页、公开主题和登录后 `/notify`。
- HTML 使用单遍轻量 tokenizer/状态机解码；不构建 DOM，不使用 CSS 选择器，不使用整页正则。
- 首页最小字段：BBS1 版本、主题 ID、标题、版块。
- 主题最小字段：主题 ID/标题、主楼 ID、浏览数、页面声明回复数、响应实际回复 ID/楼层。
- 页面声明回复数大于响应回复节点数时输出协议告警，不编造回复。
- 解码在 TaskPool 中执行，并记录解析耗时、输入字节数和输出数量；`UI_FALLBACK` 会直接导致失败。
- ArkWeb 只在用户显式打开官方登录页时创建；只允许 `https://linux.sb`，关闭后销毁。
- App 不提供用户名、密码、验证码输入框。
- Cookie broker 只检查 `bbs_auth`、`bbs_csrf`，只在内存中构造 Header；UI 仅显示布尔值和 Header 总长度。
- `WriteContractProbe` 固定禁用；源码中没有 RCP POST。

## 自动测试与构建

| 项目 | 状态 | 结果 |
| --- | --- | --- |
| `hvigor test` | **PASS** | Tests run: 7, Failure: 0, Error: 0, Pass: 7, Ignore: 0 |
| `hvigor onDeviceTest` | **PASS** | Tests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0 |
| `hvigor assembleHap` | **PASS** | `SignHap` 成功，生成 signed HAP |
| signed HAP 安装 | **PASS** | `install bundle successfully` |

7 个本地测试包括 6 个 P0 协议用例和 1 个 DevEco 模板基础断言。协议用例覆盖首页正常/字段缺失/结构不匹配，以及主题标题、主楼、回复 ID/楼层、回复节点缺失和主题 ID 不匹配。

## 真机 P0 结果

### P0-1：匿名首页 RCP — PASS

- HTTP：200
- Content-Type：`text/html; charset=utf-8`（响应头存在重复值，但类型可接受）
- 响应：126315 bytes
- 网络耗时：453 ms（首次冷请求）
- 正文非空；没有 TLS、WAF、登录页跳转、3xx、4xx 或 5xx 阻断。
- 证据：`artifacts/p0-device/20260823-100229/01-anonymous-home.png`

### P0-2：首页协议解码 — PASS

- BBS1：v8.6.5
- 主题数：30
- 首次输入：126315 bytes
- 首次 TaskPool 解析：54 ms
- 执行路径：TASKPOOL
- `UI_FALLBACK`：0
- 主题 ID、标题和版块均合理；没有致命结构不匹配。
- 证据：`artifacts/p0-device/20260823-100229/02-home-decoder.png`

### P0-3：公开主题 605 — PASS

- HTTP：200
- 匿名响应：27389 bytes，网络 110 ms，TaskPool 14 ms
- 标题：`问一下这是啥论坛项目`
- 主楼 ID：605
- 首次浏览数：168
- 页面声明回复：5
- 响应实际回复节点：0
- 协议告警：`REPLIES_NOT_PRESENT_IN_RESPONSE:5`
- 解码器没有编造回复或楼层，执行路径为 TASKPOOL，没有 `UI_FALLBACK`。
- 证据：`artifacts/p0-device/20260823-100229/03-anonymous-topic-605.png`

### P0-4：临时 ArkWeb 官方登录 — PASS

- 用户在手机上的 linux.sb 官方页面完成登录，并点击“完成并关闭”。
- App 不接收账号、密码或验证码；登录过程没有采集敏感截图。
- 登录页关闭后返回 P0 页面；普通页面 UI 树中没有 Web 节点。
- 会话清理后和进程重启后再次检查，均不存在常驻隐藏 ArkWeb。

### P0-5：Cookie 衔接 — PASS

- `bbs_auth`：存在
- `bbs_csrf`：存在
- Cookie Header 总长度：419
- UI、截图和最终应用日志均未显示 Cookie 值。
- 日志脱敏扫描：`bbs_auth=|bbs_csrf=|Cookie:` 匹配数为 0。
- Cookie Header 只保存在内存中；进程重启后 Cookie 探针恢复为 NOT RUN，没有自动恢复内存 Header。
- 证据：`artifacts/p0-device/20260823-100229/04-cookie-booleans-only.png`

### P0-6：登录后 RCP — PASS

- 请求：`GET /notify`
- HTTP：200
- 网络耗时：169 ms
- 跳回登录：否
- 服务器判断：`SERVER_RECOGNIZED_SESSION`
- 没有 401/403，没有 Cookie 值输出。
- 登录后再次请求 Topic 605：HTTP 200，27377 bytes，网络 111 ms，TaskPool 11 ms；页面仍声明 5 条回复、响应回复节点仍为 0。
- 结论：登录会话通过；回复数据来源仍未确认。
- 证据：`artifacts/p0-device/20260823-100229/05-authenticated-rcp.png`、`artifacts/p0-device/20260823-100229/06-authenticated-topic-605.png`

### P0-7：TaskPool 与解析性能 — PASS

首次冷数据与后续稳定数据分别记录如下：

| 页面 | 冷请求：网络 / 解析 | 稳定 5 次网络耗时 | 稳定 5 次解析耗时 | 解析中位数 / 最大值 | 输出一致性 |
| --- | --- | --- | --- | --- | --- |
| 首页 | 453 / 54 ms | 150、86、280、448、76 ms | 43、30、57、53、46 ms | 46 / 57 ms | 每次 30 个主题 |
| Topic 605 | 110 / 14 ms | 89、156、182、94、94 ms | 11、12、11、12、13 ms | 12 / 13 ms | 每次只输出主楼并给出相同告警 |

- 首页：黄色区间（30–100 ms），架构可用，后续优化。
- 主题：绿色区间（≤ 60 ms）。
- `UI_FALLBACK`：0；未发现崩溃、冻结、结果不一致或进程异常。

### P0-8：真实写操作 — NOT RUN

- 发帖/回复按钮保持禁用。
- 没有构造或发送 POST。
- 本轮没有真实发帖、回复、编辑或删除。

## 会话与 ArkWeb 清理

- 点击“清理 P0 内存会话”后：RCP session 关闭，内存 Cookie Header 清空，Cookie 与登录后 RCP 状态恢复为 NOT RUN。
- 清理后的普通 P0 页面没有 Web 节点。
- 进程级验证：旧 PID 41853 成功退出；重启后 PID 为 50435。
- 重启后首页、主题、Cookie 和登录后 RCP 均为 NOT RUN；写按钮仍禁用；没有从 Preferences 或普通文件恢复内存 Header。
- 证据：`artifacts/p0-device/20260823-100229/07-session-cleanup.png`、`artifacts/p0-device/20260823-100229/restart-session.png`。

## 日志证据与脱敏

- 最终保留日志：`artifacts/p0-device/20260823-100229/device-hilog-app-only.txt`。
- 最终日志只保留本 App 进程范围；Cookie 泄露模式匹配数为 0，`UI_FALLBACK` 匹配数为 0。
- 初次未过滤的全系统 hilog 因包含其他应用日志而被立即删除，未作为证据保留，且不可恢复。

## P0 验收矩阵

| 项目 | 状态 | 核心证据 |
| --- | --- | --- |
| P0-1 匿名 RCP | **PASS** | HTTP 200，126315 bytes，453 ms，正文非空，无稳定阻断 |
| P0-2 首页解码 | **PASS** | BBS1 v8.6.5，30 个主题，TaskPool 54 ms，无 UI_FALLBACK |
| P0-3 主题解码 | **PASS** | Topic 605，主楼 605，声明回复 5、响应回复 0，告警明确且不编造 |
| P0-4 ArkWeb 登录 | **PASS** | 官方页登录成功，临时可见 Web，关闭后和重启后均无 Web 节点 |
| P0-5 Cookie 衔接 | **PASS** | 两个 Cookie 均存在，Header 长度 419，值泄露匹配 0 |
| P0-6 登录后 RCP | **PASS** | `/notify` HTTP 200，不跳登录，`SERVER_RECOGNIZED_SESSION` |
| P0-7 解析性能 | **PASS** | 首页稳定中位数 46 ms、主题 12 ms，TaskPool 正常，结果一致 |
| P0-8 写操作 | **NOT RUN** | 固定禁用，无 POST，无真实发帖或回复 |

## 风险与下一步决策

- 主架构的 RCP、轻量解码、TaskPool、临时 ArkWeb 和 Cookie 内存桥接均已通过 P0，可继续下一轮窄范围技术验证。
- 登录后 Topic 605 仍没有回复节点。下一轮只允许做“回复数据来源发现”，检查 BBS1 的额外分页、AJAX 或其他只读路由。
- 在回复来源确认前，不开发正式主题详情页；也不扩展完整首页、个人中心或正式 UI。
- 首页解析稳定中位数 46 ms，属于黄色区间。架构可用，但在正式 UI 前应继续减少 tokenizer 分配和重复实体解码。
- Cookie 名、登录重定向和 BBS1 HTML 都是站点契约；版本变化必须返回明确协议告警，不能静默展示错误数据。
- 继续保持写操作禁用；任何真实写测试仍需用户另行明确授权并提供专用测试主题。

当前决策：**P0 通过，可进入下一轮只读“回复数据来源发现”；不得直接扩展正式 UI 或真实写操作。**
