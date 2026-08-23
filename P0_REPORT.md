# P0 Report

生成时间：2026-08-23（Asia/Shanghai）

## 总结

本轮已完成 P0 技术验证探针的代码、纯协议自动测试和本机可执行的构建。当前环境没有已连接的 HarmonyOS 设备，工程也没有签名配置，因此所有依赖真实 API 23/24 设备、ArkWeb 登录和真实 RCP 网络栈的 P0 验收项严格标记为 **NOT RUN**。不能据此冻结生产架构，也不能宣称登录或 Cookie 衔接已通过。

没有实现完整首页、完整主题详情、个人中心或正式 UI；没有创建常驻或隐藏 ArkWeb；没有执行任何真实发帖、回复、编辑或删除。

## 环境与分支/提交

- 工程目录：`C:\Users\David\DevEcoStudioProjects\ShaobingCommunity`
- Git：当前目录不是 Git 仓库，因此分支和提交均不可用；没有初始化仓库或创建提交。
- 工程模型：ArkTS、Stage 模型、单 entry HAP，设备类型为 phone / tablet / 2in1。
- SDK 配置：
  - `targetSdkVersion`: HarmonyOS 6.1.1 (API 24)
  - `compatibleSdkVersion`: HarmonyOS 6.1.0 (API 23)
  - 本机 DevEco 内置 SDK：HarmonyOS 6.1.1，API 24，版本 6.1.1.125
  - 结论：工程可运行下限是 API 23，但当前编译/目标 SDK 不是 API 23，而是 API 24。真实 API 23 兼容性尚未在设备上验证。
- hvigor：6.24.4；命令行构建使用 DevEco 自带 JBR 21，仅对当前命令进程设置路径，没有修改系统环境或工程配置。
- 依赖：`@ohos/hypium` 1.0.25、`@ohos/hamock` 1.0.0；RCP、ArkWeb、TaskPool 均使用系统 Kit。
- 可用顶层任务已从 hvigor 任务信息确认：`test`、`onDeviceTest`、`assembleHap`、`assembleApp`、`buildInfo`、`clean`、`collectCoverage`。
- 设备：`hdc list targets -v` 返回 `[Empty]`。
- 签名：`signingConfigs` 为空，仓库内签名文件数量为 0。未生成、覆盖或复制证书、Profile、私钥、密码或本机签名路径。
- clean-room 检查：与 `C:\Code\ArkDO` 相同的 5 个非空文件均为 DevEco 默认模板文件（模块构建配置、混淆模板、备份 Ability 和基础资源配置）；未发现相同的业务源码或品牌资源。本轮没有复制 ArkDO 源码、注释、图标、截图或资源。

## 已完成的代码

- `P0ProbePage`：明确标注“非官方客户端”“技术验证，不是正式 UI”。
- `RcpForumTransport`：
  - 复用单一、可关闭的 RCP session；
  - 匿名 GET 首页和公开主题；
  - 仅用内存 Cookie Header GET `/notify`；
  - 设置连接、传输和空闲超时、普通 User-Agent、Accept-Language；
  - 支持取消和关闭；
  - 对 3xx、4xx、5xx、超时、TLS、取消、内容类型和 UTF-8 异常返回结构化错误；
  - 不打印或保存完整 HTML。
- 轻量协议层：
  - 单遍 tokenizer/状态机；
  - 不构建 DOM，不使用 CSS 选择器，不使用整页正则；
  - 提取 BBS1 版本、主题 ID/标题/版块；
  - 提取主题标题、浏览数、页面声明回复数、主楼 ID、响应中实际出现的回复 ID/楼层；
  - 页面声明回复数大于响应中的回复节点时明确告警，不编造回复或楼层；
  - 支持常用 HTML 实体和数字实体；未知扩展默认忽略，不使整页失败。
- 解析性能：首页/主题解码通过 TaskPool 执行并在任务内记录解析耗时、输入字节数和输出数量。TaskPool 失败时会明确显示 `UI_FALLBACK` 并将探针标记为 FAIL，不伪造后台执行。
- 临时 ArkWeb 登录：
  - 只在用户打开登录页时创建；关闭组件时停止并销毁；
  - 只允许 `https://linux.sb`，阻止其他域请求；
  - 应用不提供用户名/密码输入框，不接收凭据；
  - 不存在普通业务 ArkWeb 网桥或常驻隐藏 ArkWeb。
- Cookie 与登录态：
  - `WebCookieManager` 只检查 `bbs_auth`、`bbs_csrf`；
  - UI 只显示存在/不存在及 Cookie Header 总长度；
  - broker 只在内存中保留请求所需的两个 Cookie pair，不写 Preferences 或文件，不记录值；
  - 登录后 RCP 只判断服务器是否认可会话，不展示通知正文。
- 写操作：`WriteContractProbe` 固定禁用，UI 显示“真实写测试：未启用（需要用户明确授权和测试主题）”；代码中没有 RCP POST。
- 权限：仅新增 `ohos.permission.INTERNET` 和 `ohos.permission.GET_NETWORK_INFO`。

## 自动测试结果

### 协议单元测试：PASS

命令：

```text
hvigorw test --mode module -p product=default --no-daemon
```

最终结果：`Tests run: 7, Failure: 0, Error: 0, Pass: 7, Ignore: 0`。

其中 6 个 P0 协议用例覆盖：

- 首页正常结构、版本、主题、版块与实体转义；
- 首页字段缺失；
- 首页结构不匹配；
- 主题标题、主楼、回复 ID/楼层和实体转义；
- 页面声明回复存在但响应未携带回复节点；
- 未知扩展、标题缺失和主题 ID 不匹配。

另 1 个为 DevEco 模板自带基础断言。

## 构建结果

- `buildInfo`：**PASS**。
- ArkTS 全量编译：**PASS**。
- `assembleHap --mode module -p product=default`：**PASS**。
  - 输出：`entry/build/default/outputs/default/entry-default-unsigned.hap`
  - 大小：192472 bytes
- `assembleApp -p product=default`：**PASS**。
  - 输出：`build/outputs/default/ShaobingCommunity-default-unsigned.app`
  - 大小：143729 bytes
- HAP/APP 签名：**NOT RUN**。hvigor 因 `signingConfigs` 为空而明确跳过签名；未把无签名构建写成可安装验证。
- `onDeviceTest`：**NOT RUN**。前置检查确认没有连接设备，且无可安装签名包。

## 主机侧公开页面抽样（不等于 RCP 验证）

本机普通 HTTPS 客户端可读取 `https://linux.sb/` 和公开主题 `/topic/605` 的 HTML，这仅用于确认当前 BBS1 v8.6.5 标记与最小协议边界，不计入任何 RCP 验收项。

当前匿名主题响应可见主题标题、主楼和页面声明回复数，但抽样响应中没有实际回复节点。解码器因此分别输出“页面声明回复数”和“本响应含回复数”，并产生 `REPLIES_NOT_PRESENT_IN_RESPONSE` 告警。是否能在登录后通过 RCP 获得回复，必须由设备上的 P0-6 验证。

## 真机手动步骤

1. 在 DevEco Studio 的 Signing Configs 中配置项目负责人自己的调试签名；不要提交签名材料。
2. 连接 HarmonyOS 6.1.0 API 23 或更高设备，确认 `hdc list targets -v` 能看到目标。
3. 安装并打开 P0 页面，先运行匿名首页 RCP：记录状态码、字节数、Content-Type、网络耗时、TaskPool 解析耗时、输入大小、输出主题数和 BBS1 版本。
4. 输入一个确定公开的主题 ID，运行匿名主题 RCP：记录标题、主楼 ID、页面声明回复数、实际回复节点数、回复 ID/楼层和协议告警。
5. 打开官方登录页，确认只出现临时可见 ArkWeb，地址保持 `linux.sb`；完成官方登录后点击“完成并关闭”。
6. 只检查 Cookie 探针：截图中只能出现 `bbs_auth` / `bbs_csrf` 的布尔状态和 Header 总长度，不得包含值。
7. 关闭登录页后运行“用内存 Header 验证 RCP”，确认 `/notify` 没有跳回登录页且服务器认可会话。
8. 点击“清理 P0 内存会话”，确认 RCP session 关闭、内存 Header 清空；普通探针页不得残留 ArkWeb。
9. 退出应用后检查进程/内存，确认没有常驻隐藏 ArkWeb。
10. 不点击或构造任何真实写请求；本轮不执行发帖和回复。

## P0 验收矩阵

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| P0-1 匿名 RCP | **NOT RUN** | RCP 代码已全量编译；无连接设备，主机普通 HTTPS 抽样不能替代 HarmonyOS RCP。 |
| P0-2 首页解码 | **NOT RUN** | 合成 fixture 单测 PASS；真实 RCP 响应 + TaskPool 解码未在设备运行。 |
| P0-3 主题解码 | **NOT RUN** | 合成 fixture 单测 PASS；真实 RCP 响应 + TaskPool 解码未在设备运行。 |
| P0-4 ArkWeb 登录 | **NOT RUN** | 临时 ArkWeb 与受信域拦截代码已编译；未在设备输入账号或完成登录。 |
| P0-5 Cookie 衔接 | **NOT RUN** | broker 已编译且静态审计未发现值输出/持久化；没有真实登录 Cookie 证据。 |
| P0-6 登录后 RCP | **NOT RUN** | `/notify` 会话验证代码已编译；没有真实 Cookie 和设备 RCP 结果。 |
| P0-7 解析性能 | **NOT RUN** | 已实现 TaskPool 内计时、输入字节数和输出数记录；没有设备型号、系统版本或真实页面数据，不下性能结论。 |
| P0-8 写操作 | **NOT RUN** | 默认禁用；没有 POST，没有真实发帖或回复。 |

## 风险与下一步决策

- 当前只能确认“代码可测试、可编译、可打未签名包”，不能确认“RCP 主架构可用”。
- 工程兼容 API 23，但当前 target/compile SDK 为 API 24；必须补一台 API 23 设备的安装与运行证据。
- 当前匿名页面似乎不返回回复节点。若登录后 RCP 能返回回复，可继续；若登录后仍只返回占位内容，需要把游客/登录阅读能力重新纳入产品范围决策。
- TaskPool 对该解码函数的真实调度与序列化尚未在设备验证；如果 UI 显示 `UI_FALLBACK`，P0-2/P0-3/P0-7 不能通过。
- Cookie 名、登录重定向和 BBS1 HTML 都是站点契约，版本变化时必须返回明确协议告警，不能静默展示错误数据。
- 在 P0-1 至 P0-6 获得设备证据前，不进入完整首页、主题详情、个人中心或正式 UI。
- 若 RCP 被稳定阻断、ArkWeb 无法安全取得必要会话，或登录后 RCP 不被服务器认可，应停止扩展并联系站长申请最小 API；不得改为网页套壳或常驻隐藏 ArkWeb。

当前决策：**P0 验收未完成，生产架构暂不冻结；下一步仅执行上述真机探针。**
