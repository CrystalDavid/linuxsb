# Codex Instructions — 烧饼社区 P0

## 最高优先级

1. 先完整阅读 `PROJECT_BASELINE.md`，再修改代码。
2. 当前唯一任务是完成 **P0 技术验证探针**，不是开发完整社区 App。
3. 不复制 ArkDO 的任何源码、注释、资源、图标、截图或文件；UI 只使用 ArkUI/HDS 独立编写。
4. 正常业务测试使用 RCP；ArkWeb 只用于官方登录测试。
5. 不实现常驻隐藏 ArkWeb，不使用 DOMParser/querySelector，不解析 CSS，不做网页套壳。
6. 不执行真实发帖、回复、编辑或删除，除非用户随后明确开启写测试并提供测试主题。
7. 不更改或提交签名证书、Profile、私钥、密码和本机绝对路径。
8. Cookie/CSRF 只能报告“存在/不存在”和长度，禁止显示、保存或记录具体值。

## 先检查仓库

开始时输出并记录：

- 是否已是 HarmonyOS API 23、ArkTS、Stage 模型工程；
- SDK、hvigor、依赖和可用构建任务；
- 当前 Git 状态；
- 是否存在会造成许可证污染的 ArkDO 代码或资源；
- 是否已有签名配置。不得为了通过构建覆盖用户的签名配置。

若仓库为空，创建最小 API 23 Stage 工程骨架；若自动生成完整工程存在不确定性，则先创建源代码与配置草案，并在报告中明确指出需要用户在 DevEco Studio 完成的唯一手动步骤。不要凭空伪造“已构建成功”。

## 当前 P0 交付物

实现一个仅用于验证的 `P0ProbePage`，至少包含以下卡片或按钮：

1. **匿名首页请求**：RCP GET `https://linux.sb/`，显示状态码、响应字节数、Content-Type、耗时；
2. **匿名主题请求**：允许输入公开主题 ID，RCP GET 对应主题页；
3. **首页协议探针**：从响应中提取 BBS1 版本、主题 ID、标题和版块等最小字段；
4. **主题协议探针**：提取主题标题、主楼/回复数量、回复 ID/楼层等最小字段；
5. **解析性能**：在后台任务中运行解码并显示耗时、输入大小、输出数量；
6. **官方登录**：打开临时 ArkWeb 登录页，只允许 `linux.sb` 受信域；
7. **Cookie 探针**：登录后只显示 `bbs_auth`、`bbs_csrf` 是否存在及 Cookie Header 总长度；
8. **登录后 RCP 请求**：将必要 Cookie 仅在内存中交给 RCP，请求个人页或通知页并判断是否为登录状态；
9. **清理会话**：关闭页面/应用时正确关闭 RCP session；登录 Web 关闭后不得常驻。

P0 页面必须明确标注“技术验证，不是正式 UI”。

## 建议代码结构

```text
entry/src/main/ets/
├── services/
│   ├── transport/
│   │   ├── ForumTransport.ets
│   │   ├── RcpForumTransport.ets
│   │   └── CookieSessionBroker.ets
│   ├── auth/
│   │   ├── LoginProbePage.ets
│   │   └── SessionProbe.ets
│   └── protocol/
│       ├── ProbeModels.ets
│       ├── LightweightHtmlTokenizer.ets
│       ├── HomeProbeDecoder.ets
│       └── TopicProbeDecoder.ets
└── views/pages/P0ProbePage.ets
```

这只是 P0 最小结构，不要一次建立所有正式业务目录和空类。

## 实现约束

### RCP

- 复用一个明确生命周期的 session；
- 设置合理超时、`Accept-Language` 和可识别的普通客户端 User-Agent；
- 支持取消请求和关闭 session；
- 响应正文只在内存中处理；
- 不在日志中打印完整 HTML；
- 对 3xx、4xx、5xx、超时、证书和内容类型异常给出结构化错误。

### 协议探针

- 不使用正则表达式吞整页 HTML；
- 不建立 DOM；
- 使用小型 tokenizer/状态机，只实现 P0 所需字段；
- 解码接口与传输接口分离；
- 在 TaskPool/Worker 可用且适合时移出 UI 线程；如果受 Sendable/序列化限制，先保持清晰接口并记录限制，不要伪造并发；
- 为合成 fixture 编写单元测试，包括正常、字段缺失、实体转义、未知扩展和结构不匹配。

### 登录与 Cookie

- 登录页加载官方地址；
- 禁止应用自身收集用户名和密码；
- 通过 `WebCookieManager` 检查 Cookie；
- `CookieSessionBroker` 只返回请求所需的内存 Header，不写磁盘和 Preferences；
- 日志只允许布尔值和长度；
- 登录后 RCP 请求成功前，不宣称架构已经通过。

### 写操作

首轮 P0 只生成 `WriteContractProbe` 的接口和禁用状态，不实际 POST。界面显示：

```text
真实写测试：未启用（需要用户明确授权和测试主题）
```

不得通过自动创建帖子或回复来“验证”。

## 测试与构建

1. 先查看 `hvigorw --help` 和工程可用任务，不猜测任务名；
2. 运行所有可用的协议单元测试；
3. 执行能在当前环境完成的编译或 HAP 构建；
4. 若被签名、设备、SDK 或网络环境阻塞，保留完整错误摘要并继续完成不依赖该条件的测试；
5. 不把“代码看起来正确”写成“真机已验证”。

## 必须生成 `P0_REPORT.md`

报告应包含：

```text
# P0 Report
- 环境与分支/提交
- 已完成的代码
- 自动测试结果
- 构建结果
- 真机手动步骤
- P0-1 匿名 RCP：PASS / FAIL / NOT RUN + 证据
- P0-2 首页解码：PASS / FAIL / NOT RUN + 证据
- P0-3 主题解码：PASS / FAIL / NOT RUN + 证据
- P0-4 ArkWeb 登录：PASS / FAIL / NOT RUN + 证据
- P0-5 Cookie 衔接：PASS / FAIL / NOT RUN + 证据
- P0-6 登录后 RCP：PASS / FAIL / NOT RUN + 证据
- P0-7 解析性能：数据与设备，不先下结论
- P0-8 写操作：默认 NOT RUN
- 风险与下一步决策
```

不得泄露 Cookie、CSRF、账号、私密正文或完整登录页内容。

## 停止条件

出现下列情况之一，停止扩展功能，只修复探针或写报告：

- RCP 匿名请求被稳定阻断；
- ArkWeb 登录成功但无法安全获得会话；
- 携带会话后 RCP 仍不被服务器认可；
- 需要绕过验证码、WAF、权限或限流才能继续；
- 需要改为网页套壳或常驻隐藏 ArkWeb 才能通过；
- 协议结构无法可靠判断，存在把错误数据展示给用户的风险。

## 完成标准

本轮完成不是“App 已经能用”，而是：

- 最小探针代码可读、可测试、可构建到当前环境允许的程度；
- 自动测试与未验证事项严格区分；
- `P0_REPORT.md` 足以让项目负责人决定：继续采用 RCP 主架构，还是联系站长申请最小 API 插件。
