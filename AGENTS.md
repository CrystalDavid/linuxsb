# Codex Instructions — 烧饼社区 M1 只读产品纵向闭环

## 当前唯一任务

实现并验证 M1：

```text
启动 App
→ 正式首页与真实主题列表
→ 正式主题详情
→ 匿名主楼与登录门控
→ 临时 ArkWeb 官方登录
→ 返回同一主题并刷新
→ 登录后显示回复
```

M1 完成前不得宣称完整首页或完整主题详情已完成；所有结果严格使用 PASS、FAIL 或 NOT RUN。

## 开始工作前

1. 完整阅读 `PROJECT_BASELINE.md` 和 `P0_REPORT.md`。
2. 检查工作树、分支、标签、签名隔离和忽略规则。
3. 不打印、暂存、提交或覆盖本机签名密码、证书路径、Profile 路径、Cookie 值、账号、通知或私密正文。
4. `P0_REPORT.md` 是已冻结技术报告，M1 不重写其历史结论。

## 已冻结事实

- P0 与 P0-B 已在 API 26 真机通过。
- P0-B 通过提交为 `bd3b3af`，通过标签为 `p0b-pass-api26-20260823`。
- 只读主架构固定为：RCP GET → 版本化轻量解码 → TaskPool → ArkUI。
- 登录固定为：临时 ArkWeb 官方登录 → Cookie 内存桥接 → RCP。
- 匿名 Topic 605 声明 5 条回复但由服务端隐藏；登录后同一 `/topic/605` GET 稳定返回 5 条回复。
- 不需要额外 GET、AJAX、POST 或 ArkWeb 数据桥。
- P0-8 写操作为 NOT RUN；发帖、回复、编辑和删除继续固定禁用。

## Git 与敏感信息边界

- 当前开发分支：`m1/read-only-vertical-slice`。
- `main` 上 P0/P0-B 通过基线和已有标签不得重写。
- `build-profile.json5` 的提交版本保持脱敏；本机签名版保持 `skip-worktree`，不得暂存或提交。
- `artifacts/`、日志、截图、匿名网页快照和签名文件不得进入公开提交。
- 不复制 ArkDO 源码、注释、资源、图标、截图、签名或品牌资产；UI 只能 clean-room 独立实现。

## M1 实现边界

- 默认入口必须是 `RootPage` / 正式 `HomePage`，不得默认进入 `P0ProbePage`。
- 使用 `Navigation` + `NavPathStack`；P0 探针只作为 Debug 诊断入口，Release 不得默认进入或向普通用户展示。
- 首页和主题详情必须通过 ViewModel → Repository → ForumTransport 获取领域模型。
- Page/Component 不直接发网络请求、不解析 HTML、不读取 Cookie。
- Repository 不依赖 ArkUI；协议对象不得直接进入 UI。
- 正式业务 Transport 只有 `RcpForumTransport`。
- ArkWeb 只允许出现在登录模块；普通首页和主题详情 UI 树中不得存在 Web。
- 不构建 DOM，不使用 DOMParser、CSS 选择器或整页正则。
- 未识别正文结构转换为 `UnsupportedExtension`，不得显示原始 HTML 或导致页面崩溃。
- 本轮不实现任何写操作按钮或 POST 请求。

## 页面最低要求

### 首页

- 显示“烧饼社区”和“非官方客户端”；
- 使用真实 `TopicSummary`、`HomeRepository`、`HomeViewModel`；
- 使用 `List` / `LazyForEach`；
- 支持 Loading、Content、Empty、Error、Offline、Retry 和下拉刷新；
- 手机单栏，保留明确的平板双栏断点；
- 支持浅色和深色 Token。

### 主题详情

- 使用正式 `TopicDetail`、`Reply`、`Author`、`ContentBlock` 模型；
- 匿名有声明回复但实际回复被隐藏时显示“登录后查看 N 条回复”，不得显示“暂无回复”；
- 登录关闭后捕获内存会话，自动刷新原 topicId；
- 登录后回复 ID 唯一、主楼不重复、楼层合理；
- 正文 v1 支持 Paragraph、LineBreak、Link、Quote、InlineCode、CodeBlock、Image 和 UnsupportedExtension 降级。

## 禁止事项

- 不发送 POST，不发帖、回复、编辑或删除；
- 不新增常驻或隐藏 ArkWeb；
- 不使用 ArkWeb 作为普通业务网络桥；
- 不绕过验证码、WAF、权限或限流；
- 不缓存 Cookie、完整私密 HTML 或登录后页面；
- 不新建成套 M1 文档；
- 不修改 `P0_REPORT.md`。

## 测试与真机验收

1. 保留原 19 个协议测试，并覆盖 Repository 映射、登录门控、5 条回复、去重、登录后同主题刷新、正文降级和 ViewModel 状态流。
2. 运行 `hvigor test`、`hvigor onDeviceTest` 和 `hvigor assembleHap`。
3. 构建并安装 signed HAP。
4. 最终必须在 API 26 真机验证默认正式首页、真实主题、Topic 605 匿名门控、官方登录回流、登录后同页 5 条回复。
5. 验收必须确认普通页面 Web 节点 0、Cookie 值泄露匹配 0、`UI_FALLBACK = 0`、Fatal 0、POST 0。

## 文档边界

- `AGENTS.md`：只记录当前 M1 任务和约束；
- `PROJECT_BASELINE.md`：只追加简洁 M1 状态与验收结论；
- `P0_REPORT.md`：冻结，不修改；
- 不创建新的成套报告。

## 当前状态（2026-08-23）

- Git 基线与分支：PASS。
- 主机侧 ArkTS 编译、signed HAP 构建、原 19 个测试及新增 M1 测试：PASS（30/30）。
- `hvigor onDeviceTest`：PASS（1/1）。
- signed HAP 安装与启动：PASS。
- API 26 真机 M1 手工闭环：PASS；默认正式首页、真实主题列表、Topic 605 匿名登录门控、临时官方登录回流及登录后同页 5 条回复均已验证。
- 普通页面 Web 节点 0、Cookie 值泄露匹配 0、`UI_FALLBACK` 0、Fatal 0、POST 实现与执行 0：PASS。
- M1 总状态：PASS。
- P0-8 真实写操作：NOT RUN；继续禁止 POST、发帖、回复、编辑和删除，后续范围须由新任务明确授权。
