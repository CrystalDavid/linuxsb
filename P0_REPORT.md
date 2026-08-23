# P0 Report

生成时间：2026-08-23（Asia/Shanghai）

## 总结

P0 与 P0-B 技术验证已经在真实 HarmonyOS API 26 设备完成。P0-1 至 P0-7 和 P0-B 均为 **PASS**；P0-8 真实写操作严格保持 **NOT RUN**。RCP 匿名请求、轻量协议解码、TaskPool、临时 ArkWeb 官方登录、Cookie 内存衔接、登录后 RCP 会话、进程级会话清理和登录后同页回复解码均获得设备证据。

P0-B 校正了旧证据口径：旧“登录后 Topic”按钮实际仍发匿名请求。真实登录后 `/topic/605` 同一 GET 响应包含 5 条回复；不需要额外分页、AJAX、POST 或 ArkWeb 数据桥。回复 ID 唯一、主楼未重复、楼层为 1～5，作者和正文最小字段完整。

本轮没有扩展完整首页、完整主题详情、个人中心或正式 UI；没有创建常驻或隐藏 ArkWeb；没有执行发帖、回复、编辑、删除或任何真实 POST。

## 真机环境

- 设备型号：SGT-AL10
- 系统版本：OpenHarmony 7.0.0.102；软件版本 `SGT-AL10 7.0.0.102(SP8C00E102R5P3)`
- API Version：26（满足 API 23+ 前置条件）
- 连接方式：HDC TCP / IP，无线连接；不是 USB
- 网络：Wi-Fi；HDC 与电脑位于同一局域网
- HDC：DevEco Studio 内置 `hdc` 3.2.0d
- Bundle Name：`com.example.shaobingcommunity`
- HAP：`entry/build/default/outputs/default/entry-default-signed.hap`，421184 bytes，SHA-256 `6ca53ca2bf0ad9d87a2b32c3835ba96945d0432f4747a29b20fc3c9147df1c28`
- HAP 签名：**PASS**；使用项目负责人自己的 DevEco 自动调试签名，未使用 ArkDO 的证书、Profile、密码或路径
- 安装：**PASS**；`install bundle successfully`
- 启动：**PASS**；`start ability successfully`
- 设备证据：`artifacts/p0-device/device-target.txt`、`artifacts/p0-device/device-api-version.txt`

说明：工程兼容下限仍是 API 23，但本轮真实设备是 API 26，因此“恰好 API 23 设备”的兼容性没有单独覆盖。

## 工程、SDK 与 Git

- 工程目录：`C:\Users\David\DevEcoStudioProjects\ShaobingCommunity`
- Git：P0 基线提交 `e4f2ba7`，标签 `p0-pass-api26-20260823`；P0-B 分支为 `p0b/reply-source`。
- 工程模型：ArkTS、Stage 模型、单 entry HAP，设备类型为 phone / tablet / 2in1。
- SDK：`compatibleSdkVersion` 为 HarmonyOS 6.1.0 API 23；`targetSdkVersion` 为 HarmonyOS 6.1.1 API 24；本机 DevEco SDK 为 HarmonyOS 6.1.1 API 24，版本 6.1.1.125。
- hvigor：6.24.4；仓库没有 Hvigor Wrapper，命令行直接使用 DevEco 自带 hvigor、JBR 21 和工程 SDK 环境，不修改系统级 PATH。
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
- P0 阶段观察到的“登录后 Topic 605 仍没有回复节点”已由 P0-B 证明确为匿名请求入口复用错误，不再作为未解决风险。
- P0-B 已确认登录后同一主题 GET 直接含 5 条回复；正式主题详情技术阶段门已解除，但本轮仍不扩展完整首页、主题详情、个人中心或正式 UI。
- 首页解析稳定中位数 46 ms，属于黄色区间。架构可用，但在正式 UI 前应继续减少 tokenizer 分配和重复实体解码。
- Cookie 名、登录重定向和 BBS1 HTML 都是站点契约；版本变化必须返回明确协议告警，不能静默展示错误数据。
- 继续保持写操作禁用；任何真实写测试仍需用户另行明确授权并提供专用测试主题。

当前决策：**P0 与 P0-B 均通过；可以在后续明确任务中进入正式主题详情纵向闭环，但真实写操作仍为 NOT RUN。**

---

## P0-B：回复数据来源与解码契约验证 — PASS

> 记录时间：2026-08-23。最终类型为 **PASS 类型 1：登录后同页解码**。

### P0 基线冻结 — PASS

- 已安全初始化并整理 Git；P0 API 26 真机通过基线提交为 `e4f2ba7`。
- 基线标签：`p0-pass-api26-20260823`。
- 当前调查分支：`p0b/reply-source`。
- 本机签名版 `build-profile.json5` 仍保留在本机并设置为 skip-worktree；可提交基线中不含 signingConfigs 敏感内容。
- `artifacts/`、`.p12`、`.cer`、`.p7b`、日志和截图均被 Git 忽略。
- 未打印、复制或提交签名密码、Cookie 值、证书路径或 Profile 路径。

### 旧证据口径校正 — PASS

P0 报告中“登录后再次请求 Topic 605”的观察，经 P0-B 代码审计确认仍调用匿名 `getTopic(topicId)`，没有向主题请求传入内存 Cookie Header。该次结果只能证明匿名响应仍为 0 条回复，不能证明登录态主题响应也为 0。

这不影响 P0-6 的 `/notify` 会话验证结论：`/notify` 确实通过带 Cookie 的 RCP GET 返回 `SERVER_RECOGNIZED_SESSION`。P0-B 已新增独立的 `getAuthenticatedTopic(topicId, cookieHeader)`，匿名和登录后主题入口不再混用。

### 当前匿名响应指纹与结构 — PASS

- 请求：匿名 `GET https://linux.sb/topic/605`，请求头与 App P0 RCP 探针一致。
- HTTP：200；最终 URL 未跳转；Content-Type 为 `text/html; charset=utf-8`。
- 保存的一次匿名正文：27811 bytes。
- SHA-256：`c9107b2b9da0615825d570b25b467dc5b681c67b0967df39d6213641db4e058f`。
- 检测版本：BBS1 v8.6.5。
- 当前静态 HTML：`post-entry = 1`、`data-floor = 0`、登录可见门禁标记 = 1。
- 页面明确声明 5 条评论，但匿名响应只包含主楼，并输出“登录后可见”的服务端占位结构。
- App UA、桌面浏览器 UA、搜索爬虫 UA 的匿名 GET 均得到同一结构：1 个主楼、0 个 `data-floor`、1 个登录门禁标记。字节数和 SHA 会因浏览数、运行耗时及侧栏实时内容变化，不将哈希变化误判为随机协议变化。
- 唯一匿名快照位于被忽略的 `artifacts/p0b/topic-605-anonymous.html`；没有保存登录后整页、请求头或 Cookie。

### BBS1 v8.6.5 源码契约 — PASS

- App 实际响应与 BBS1 官方发布页均检测到 v8.6.5；官方源码版本标识为 `25207df9ea6e`。
- 官方源码包 SHA-256：`f94e3421b52bdaa9df29a8c8e4f6a4948c6ba29d4a4da7b654adfdf265cde443`。
- 官方 `topic_page()` 直接查询 `app_replies`，并在同一主题页 GET 中循环调用 `topic_post_row()`。
- 回复容器契约为 `li.post-item.post-entry`，回复 ID 为 `id="post-{replyId}"`，楼层为 `data-floor` 和 `.post-floor`。
- 回复分页由真实主题路由的 `p` 参数生成；默认每页 50 条，Topic 605 的 5 条回复不需要第二页。
- 可影响回复的核心 Hook 包括 `topic.replies_data.load`、`topic.replies_data.loaded`、`topic.replies`、`reply.before_render` 和 `reply.after_render`。
- linux.sb 的合并插件样式明确包含 `replies_login_visible`；当前匿名门禁由服务器端输出。核心和站点 JavaScript中均未发现为主题页另行 GET 回复数据的逻辑。
- 官方来源：`https://bbs1.org/plugin_market_source`、`https://bbs1.org/topic/21`。

结论：当前证据选择 **分支 A（登录后同页解码）**。未构造或请求猜测的 `?page=`、`/replies`、AJAX 或私有接口。

### P0-B 实现与自动测试 — PASS

- 新增 `TopicStructureProbe`，在现有轻量 Token 流上只统计结构，不输出正文、用户名、Cookie 或完整 HTML。
- 结构统计包括 topic/user/reply 链接、楼层锚点、`post-`/`reply-` ID、`data-floor`、`replyid`、候选回复容器、分页链接和登录门禁标记。
- RCP 元数据新增 `Content-Encoding` 和响应体 SHA-256；主题请求设置 `no-cache` 与 `no-store`。
- 匿名 Topic GET 与登录后 Topic GET 使用两个独立方法；只有后者接收内存 Cookie Header。
- `TopicProbeDecoder` 增加回复作者和正文块的最小解码、主楼排除、回复 ID 去重、嵌套插件块保护及明确结构告警；诊断 UI 仍不显示作者或正文。
- 测试 fixture 使用虚构作者和虚构正文，没有提交真实社区整页或真实帖子内容。
- `hvigor test`：**PASS** — Tests run: 19, Failure: 0, Error: 0, Pass: 19, Ignore: 0。
- `hvigor onDeviceTest`：**PASS** — Tests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0。首次尝试因设备已锁屏而 FAIL；解锁后的最终重跑成功，不把首次失败误记为测试通过。
- `hvigor assembleHap`：**PASS** — `SignHap` 成功，最终 signed HAP 为 421184 bytes。

### P0-B 真机响应与会话复验 — PASS

- 设备：API 26；HDC TCP Connected；用于最终真机探针的同源码 signed HAP 为 421183 bytes，SHA-256 `23176ca64c612a6b582284c94fa35b720940a10b51fb923394dacabc3133b0e2`，安装和启动成功。验收后重新签名构建的最终归档 HAP 为 421184 bytes，其哈希记录在“真机环境”。
- 匿名 Topic 605：HTTP 200，27325 bytes，SHA-256 `9747a6bed588f35d084f1a8ab0de6e7eea682add7362cbec6122adb5a15147ff`，BBS1 v8.6.5，网络 240 ms。
- 匿名解码：TaskPool 26 ms，输出 1；声明回复 5、实际回复 0；`post-entry = 1`、候选回复容器 0、登录门禁标记 1。告警为 `REPLIES_NOT_PRESENT_IN_RESPONSE:5` 与 `REPLIES_LOGIN_GATED:5`，没有编造回复。
- Cookie 探针：`bbs_auth` 与 `bbs_csrf` 均为存在，Header 总长度 344；只显示布尔值和长度，不显示值。临时 ArkWeb 已关闭，普通探针页没有 Web。
- 登录后 `/notify`：HTTP 200，92 ms，不跳回登录页，`SERVER_RECOGNIZED_SESSION`。
- 登录后 Topic 605：HTTP 200，50622 bytes，SHA-256 `459123b3d9f01a3c7bf5cf950e2b530a3404ba519f366690d4fb79b0fdc5f87c`，BBS1 v8.6.5，网络 119 ms。
- 登录后解码：TaskPool 47 ms，输出 6；声明回复 5、实际回复 5；回复 ID 唯一、主楼未重复、楼层 1、2、3、4、5，作者/正文最小字段完整。
- 登录后结构：`post-entry = 6`、候选回复容器 5、登录门禁标记 0、分页链接 0。匿名/登录后字节数、SHA-256 和结构标记均明确不同。
- 结论：回复来自登录后的同一主题 HTML。没有第二次回复网络请求，没有猜测路由，没有 POST，没有 ArkWeb 数据桥。

### P0-B 真机验收 HAP 五次稳定性 — PASS

| 次数 | 网络耗时 | TaskPool 解析 | 字节数 | 声明 / 实际 | 结构结果 |
| --- | ---: | ---: | ---: | ---: | --- |
| 1 | 119 ms | 47 ms | 50622 | 5 / 5 | PASS，同页 5 条 |
| 2 | 233 ms | 54 ms | 50634 | 5 / 5 | PASS，同页 5 条 |
| 3 | 142 ms | 45 ms | 50634 | 5 / 5 | PASS，同页 5 条 |
| 4 | 99 ms | 47 ms | 50628 | 5 / 5 | PASS，同页 5 条 |
| 5 | 160 ms | 43 ms | 50639 | 5 / 5 | PASS，同页 5 条 |

- 网络中位数 / 最大值：142 / 233 ms。
- TaskPool 解析中位数 / 最大值：47 / 54 ms，处于项目绿色阈值（≤ 60 ms）。
- 5 次均为回复 ID 唯一、主楼未重复、楼层 1～5、最小字段完整、`post-entry = 6`、候选回复容器 5、登录门禁标记 0。
- 最终应用 PID 日志：190747 bytes；Cookie 值模式匹配 0，`UI_FALLBACK` 匹配 0，应用 Fatal 匹配 0。
- 全量 hilog 曾因 HDC 主机命令未按 PID 过滤而被立即停止并清空，不作为证据；最终只保留设备端 `hilog -P` 过滤结果。
- 脱敏截图：`artifacts/p0b-device/20260823-reconnected/p0b-final-authenticated-topic.jpeg`。截图只显示响应元数据、结构计数、Cookie 布尔值和 Header 长度，不含账号、正文或 Cookie 值。

### P0-B 最终验收矩阵

| 项目 | 状态 | 核心证据 |
| --- | --- | --- |
| Git 基线与敏感信息隔离 | **PASS** | 基线提交、标签、调查分支与忽略规则已建立 |
| 匿名响应指纹 | **PASS** | HTTP 200、v8.6.5、27811 bytes、SHA-256 已记录 |
| 匿名结构探针 | **PASS** | 主楼 1、候选回复 0、登录门禁标记 1 |
| 对应版本源码契约 | **PASS** | v8.6.5 同页回复循环、真实 `p` 分页和 Hook 已确认 |
| 分支 A 解码实现 | **PASS** | 同页 Reply 解码、去重、实体、插件嵌套与错配告警已覆盖 |
| 本地自动测试 | **PASS** | 19/19 通过 |
| signed HAP 构建 | **PASS** | `assembleHap` 与 `SignHap` 成功 |
| 真机安装 | **PASS** | API 26 设备 Connected，signed HAP 安装、启动成功 |
| 真机匿名/登录响应指纹比较 | **PASS** | 27325 / 50622 bytes，SHA-256 不同，结构标记 13 / 92 |
| 真机登录后 Topic 605 | **PASS** | declared 5 / actual 5，ID 唯一，楼层 1～5，最小字段完整 |
| 真机 TaskPool / UI_FALLBACK | **PASS** | 5 次解析中位数 47 ms、最大 54 ms，UI_FALLBACK 0 |
| 真机日志 Cookie 泄露扫描 | **PASS** | Cookie 值匹配 0，应用 Fatal 0 |
| `hvigor onDeviceTest` | **PASS** | 最终重跑 1/1 通过；首次锁屏尝试明确记录为 FAIL |
| P0-B 总结论 | **PASS** | 类型 1：登录后同页解码，不增加网络请求 |
| 写操作 | **NOT RUN** | 固定禁用；没有发送 POST |

当前决定：保持 RCP + 轻量解码 + TaskPool + 临时 ArkWeb 架构不变。P0-B 已解除正式主题详情的技术阶段门，但本轮没有开发正式页面；真实写操作继续固定禁用并保持 **NOT RUN**。
