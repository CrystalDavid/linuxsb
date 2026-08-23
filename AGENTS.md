# Codex Instructions — 烧饼社区 M2-R1.1 分页回复、原生详情、抽屉与性能修复

## 当前唯一任务

在不改变已验证业务架构的前提下，修复 M2-R1 遗留的分页、原生主题详情、ArkDO 抽屉高保真和主题打开性能问题：

```text
登录后主题 GET
→ BBS1 v8.6.5 真实分页 href
→ TopicReplyPage + TaskPool
→ 原生 TopicDetailPage + 懒加载回复
→ ArkDO 固定提交的授权抽屉/详情 UI
→ 立即导航 + 骨架屏 + 缓存/去重/受控预取
```

所有结果严格使用 PASS、FAIL 或 NOT RUN。M2-R1 在本轮全部验收通过前继续保持 FAIL；M2-R1.1 完成后停止，不自行进入 M2-B、搜索、个人中心、通知或任何写操作。

## 开始工作前

1. 完整阅读 `PROJECT_BASELINE.md` 和冻结的 `P0_REPORT.md`。
2. 检查工作树、分支、标签、签名隔离和忽略规则。
3. 不打印、暂存、提交或覆盖本机签名密码、证书路径、Profile 路径、Cookie 值、账号、通知或私密正文。
4. `P0_REPORT.md` 是冻结技术报告，不修改历史结论。
5. 授权证据只由用户私下保存，不把聊天隐私或授权材料提交到 Git。

## 已冻结事实

- P0、P0-B 与 M1 已在 API 26 真机通过。
- M1 通过标签为 `m1-pass-api26-20260823`。
- 只读主架构固定为：RCP GET → 版本化轻量解码 → TaskPool → ArkUI。
- 登录固定为：临时 ArkWeb 官方登录 → Cookie 内存桥接 → RCP。
- 登录后同一 `/topic/605` GET 稳定返回 5 条回复；不需要额外 GET、AJAX、POST 或 ArkWeb 数据桥。
- P0-8 写操作为 NOT RUN；发帖、回复、编辑和删除继续固定禁用。

## Git 与敏感信息边界

- 当前开发分支：`m2/r1-1-native-topic-drawer-perf`，从 M2-R1 失败基线提交 `891231c` 创建。
- 分支基线：annotated tag `m1-pass-api26-20260823` 指向的 M1 稳定提交。
- `main` 上已通过的 P0/P0-B/M1 历史和标签不得重写。
- `build-profile.json5` 的本机签名版保持 `skip-worktree`，不得读取、暂存或提交。
- `artifacts/`、日志、截图、Cookie、网页快照和签名材料不得进入公开提交。
- UI 大改前必须保留仅含授权边界和基线修订的安全 checkpoint。
- 不在 UI 提交中混入 RCP、协议解码、登录或 Cookie 架构重写。

## ArkDO 授权移植边界

- 用户已确认获得 ArkDO 作者对源码学习、复用和改造的授权。
- 允许直接读取、复制并改造 ArkDO UI 源码。
- 唯一固定上游提交：`7680996437b3b877aa5c69ac2f55529297a2ea52`。
- 本机上游目录优先使用 `C:\Code\ArkDO`；读取必须按固定提交对象完成，不依赖未提交工作树内容。
- 允许移植主题、沉浸布局、浮动布局、列表项、头像、标签、筛选抽屉、详情阅读和禁用输入栏等表现层实现。
- 保留“烧饼社区”自己的品牌、字段语义、BBS1 协议、RCP 网络、登录与 Cookie 架构。
- 不迁入 ArkWebNetworkBridge、Challenge/Cloudflare、Discourse TopicService、MessageBus、Presence、Push、DoH、Boost、Reaction、Poll、LDC Credit 或 LinuxDO 等级/品牌逻辑。
- 上游组件依赖 Discourse 模型时，必须通过 `TopicPresentationMapper` 和本项目自己的 `TopicUiModel`、`ReplyUiModel`、`UserUiModel`、`CategoryUiModel` 适配，不迁入 Discourse 业务模型。

## M2-R1 页面范围

### 首页

- 删除巨大 Hero、“linux.sb · 只读浏览”、永久搜索框、巨大筛选胶囊、版块汉字头像、主题 ID 主信息和开发占位文案。
- 使用紧凑顶部导航：菜单、烧饼社区、搜索图标、用户头像/未登录图标。
- TopicListItem 优先显示真实头像；缺失时才使用作者首字母，不使用版块首字。
- 标题最多两行，分类/状态标签与时间进入紧凑元信息层。
- 保留 ArkDO 风格 FAB；点击只提示“写操作尚未开放”，不得发送 POST。
- CategoryDrawer 只显示 linux.sb 真实支持的筛选和版块，不展示无数据支撑的假功能。

### 主题详情

- 移植并适配 TopicDetailHeader、TopicPostItem、PostRichContent、登录门控、回复项和 CommentInputBar 外观。
- 匿名显示主楼和“登录后查看 N 条回复”；登录只打开临时官方 ArkWeb。
- 登录完成后返回原主题并刷新；普通主题详情 Web 节点必须为 0。
- CommentInputBar 固定禁用，不发送 POST。
- 头像、正文图片和标签图标异步加载，失败不得阻塞正文或保持 Loading。

## 数据与依赖边界

- 在轻量 tokenizer/状态机内仅扩展真实且稳定的首页字段，不构建 DOM、不使用 CSS 计算或整页正则。
- Page/Component 不直接发网络请求、不解析 HTML、不读取 Cookie。
- Repository 不依赖 ArkUI；协议对象不得直接进入 UI。
- 所有站点请求只经过 `ForumTransport`，正式实现只允许 `RcpForumTransport`。
- ArkWeb 只允许出现在登录模块。
- 数据不存在或无法稳定识别时隐藏字段，不伪造作者、头像、时间、回复数或状态。

## 主题打开性能边界

- Debug-only `TopicOpenTrace` 只记录时间点与阶段耗时，不记录 Cookie、HTML、私密正文或签名信息。
- 点击列表后立即 push TopicDetailPage，不等待网络。
- 首帧使用 TopicSummary 的已有字段和 ArkDO 风格正文骨架，不显示长期全屏旋转 Loading。
- 全 App 复用一个正式 RcpForumTransport/Session；页面退出不得关闭全局 Session。
- P0 探针可继续 no-cache/no-store，正式 TopicRepository 请求不得固定 no-store。
- `TopicMemoryCache`：最近 20 个主题、TTL 2 分钟、命中立即显示并后台刷新；登录态变化时清理权限相关匿名缓存。
- 同一 topicId + 同一认证状态只允许一个在途请求。
- 不得每次打开主题都请求 `/notify`。
- 首页稳定后最多并发 2 个、低优先级预取可见区域前 3 个公开主题；不得阻塞首页或预取权限未知页面。

## Pura 90 验收

- 默认目标为显式指定的 `127.0.0.1:55xx` Pura 90 模拟器，API 不低于 23。
- 同时有多个设备时，每个 HDC 命令必须带 `-t`；目标不明确时停止。
- 运行 `hvigor test`、`hvigor onDeviceTest`、`assembleHap`、signed HAP 覆盖安装和启动。
- 检查进程日志、dumpLayout、浅色/深色截图和 ArkUI Inspector。
- 目标：tap→页面首帧 ≤100 ms；缓存内容 ≤250 ms；冷请求正文 ≤1500 ms；同主题重复点击网络请求最多 1 个；TaskPool 解码约 ≤60 ms。
- 网络超时必须与解码时间分开报告，且仍要保证立即导航和骨架首帧。

## 禁止事项

- 不发送 POST，不发帖、回复、编辑或删除；
- 不新增常驻或隐藏 ArkWeb；
- 不使用 ArkWeb 作为普通业务网络桥；
- 不迁入被排除的 ArkDO 网络、服务和品牌模块；
- 不绕过验证码、WAF、权限或限流；
- 不缓存 Cookie、完整私密 HTML或登录后页面；
- 不修改 `P0_REPORT.md`；
- 不新建大量 M2-R1 文档。

## 当前状态（2026-08-24）

- M1 稳定基线与新分支：PASS。
- ArkDO 固定提交及指定 UI 文件可读取：PASS。
- 签名配置与 `artifacts/` 隔离：PASS。
- M2-R1 授权边界文档 checkpoint：PASS。
- M2-R1 授权 UI 移植、真实首页字段、Presentation Adapter、共享 Session、主题缓存、在途去重和受控预取：PASS。
- Pura 90（API 24）功能、深浅色、语义 UI、signed HAP 安装启动与安全回归：PASS。
- Pura 90 主题打开：页面/骨架首帧最大 44 ms、热缓存正文最大 51 ms、TaskPool 解码最大 16 ms：PASS；冷正文 1500 ms 目标为 3/5，另外两次由 1731/1827 ms 网络阶段导致：FAIL（已与解码耗时分开记录）。
- M2-R1 API 26 真机 signed HAP 安装、启动、正式首页、匿名主题和临时官方登录：PASS；首页与普通主题页 Web 节点均为 0。
- M2-R1 登录返回与认证会话桥接：PASS；临时 ArkWeb 关闭后返回原主题并发出认证 RCP GET，没有使用 ArkWeb 数据桥。
- M2-R1 登录后回复视觉：PASS（Topic 15458）；页面声明 35 条回复，滚动视口语义节点连续显示楼层 1～4，登录门控 0、普通页面 Web 节点 0。
- 真机进程重启会话隔离：PASS；重启后正式首页恢复，进入主题重新显示匿名登录门控，内存 RCP 会话没有持久化恢复。
- 高回复主题兼容性：FAIL（Topic 15365）；认证 GET 成功返回后解码结果为 `REPLY_STRUCTURE_MISMATCH`。本轮不猜分页路由、不执行 POST，也不把协议修订混入 UI 里程碑。
- 真机最终进程日志：PASS；783 行中 Fatal 0、`UI_FALLBACK` 0、Cookie 泄露匹配 0、HTTP POST 0。
- DevEco ArkUI Inspector 交互检查：NOT RUN（本轮桌面窗口焦点不稳定）；已用 TestKit 与 `dumpLayout` 完成组件层级、空白、抽屉边界和普通页面 Web 节点检查。
- M2-R1 历史状态：FAIL；冷正文目标、高回复主题兼容性未全部通过，ArkUI Inspector 为 NOT RUN。
- M2-R1.1 分支与安全 checkpoint：PASS；实现、测试、Inspector 和最终 API 26 复验均为 NOT RUN。
- P0-8 真实写操作：NOT RUN；继续禁止 POST、发帖、回复、编辑和删除。
