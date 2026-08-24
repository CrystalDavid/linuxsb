# Codex Instructions — 烧饼社区 M3 原生社区壳与交互闭环

## 当前唯一任务

在不推翻 P0、P0-B 和 M1 已验证架构的前提下，完成简约、蓝色、纯 ArkUI 的社区主流程：

```text
首页 / 板块 / 发布 / 搜索 / 我的
  ↓
真实列表、真实头像、连续分页
  ↓
原生主题详情、楼中楼、图片和简约回复栏
```

当前分支为 `codex/m3-native-community-shell`。下方 M2 的阶段结论已转入 `PROJECT_BASELINE.md` 作为历史；如与本文冲突，以本 M3 指令为准。

## 必须保持的架构

- 正常业务：`RCP -> 版本化轻量解码 -> TaskPool -> 领域模型 -> PresentationMapper -> ArkUI`。
- Page / Component 不直接解析 HTML、读 Cookie 或绕过 Repository 请求网络。
- 不构建 DOM，不使用 CSS 选择器，不使用整页正则解码。
- ArkWeb 只允许出现在 `OfficialLoginPage`，只用于 linux.sb 官方登录；其他页面 Web 节点必须为 0。
- Cookie 只保留 `bbs_auth` / `bbs_csrf` 所需的内存 Header，不输出值，不写 Preferences 或文件。
- 全局复用正式 `RcpForumTransport` / Session，主题页保留缓存、在途去重和立即导航。

## UI 基线

- 底部为五位沉浸悬浮 Tab：`首页 / 板块 / + / 搜索 / 我的`。
- 语义主色为蓝色；禁止绿色品牌色泄漏。
- 主页不永久显示“非官方客户端”；身份说明保留在登录/关于等合适位置。
- 列表使用 linux.sb 真实头像；只在缺失或加载失败时显示首字母回退。
- 主楼、回复和楼中楼均为头像居左、作者/正文居右；使用克制的局部分隔，不还原网页容器和强分割线。
- 图片使用原生 `Image` 可视区懒加载，不阻塞文字首帧；失败时可重试且不让页面停留 Loading。
- 回复输入只使用简约线条和单一发送按钮。
- 用户已确认获得 ArkDO 作者授权；可在授权范围内参考、移植和改造固定上游提交 `7680996437b3b877aa5c69ac2f55529297a2ea52`，但保留烧饼社区自己的品牌、协议模型和网络架构。

## 数据与交互契约

- 首页根据服务端真实 `p` 链接连续加载，不得再有 30 条客户端上限；合并时按 topicId 去重。
- 板块页只展示服务端实际板块，选中后通过真实 `/forum/{id}` GET 筛选。
- 搜索使用真实 GET 契约，尊重服务端登录门控，不伪造结果。
- “我的”使用原生页面展示当前用户、主题和回复，不使用 ArkWeb 作业务容器。
- 新主题只允许 POST `/topic_edit`，回复只允许 POST `/reply_edit`；字段必须匹配 BBS1 v8.6.5 真实表单契约。
- 写请求必须同时拥有内存登录会话和 CSRF，且只能由用户在编辑页明确点击。自动测试只使用 fake transport，不得生成真实社区内容。
- P0 报告中 `P0-8` 的历史结论继续为 `NOT RUN`；M3 的真实发帖/回复远程验收也保持 `NOT RUN`，直到用户明确提供测试内容并确认发送。

## 安全与 Git

- 不打印、不提交、不覆盖 `build-profile.json5` 中的本机签名密码、证书路径或 Profile 路径。
- 不提交 `artifacts/`、日志、截图、HTML 快照、Cookie 或签名材料。
- 不修改 `P0_REPORT.md`历史结论。
- 工作树中已有的用户修改不得丢失；提交前执行 `git diff --check` 和敏感文件检查。

## 测试与阶段门

每次交付至少执行：

- `hvigor test`；
- `hvigor onDeviceTest`；
- `hvigor assembleHap`；
- `scripts/NoWebOutsideLogin.ps1`；
- 模拟器 signed HAP 覆盖安装、启动、`dumpLayout` 与进程日志检查；
- 里程碑最后再做 API 26 真机复验，不得把离线真机记为 PASS。

安全日志硬性检查：Cookie 值泄露 0、`UI_FALLBACK` 0、Fatal 0、自动化真实 POST 0。

## 当前状态（2026-08-25）

- M3 五栏原生社区壳、蓝色语义主题、首页真实分页、板块筛选、搜索、个人页、发帖编辑器和原生回复栏：`PASS`（实现与模拟器验收）。
- 主题详情原生排版、头像左/内容右、楼中楼层级、网页“展开全文”控件隔离和图片可视区懒加载：`PASS`。
- 临时登录关闭顺序：`PASS`；先移除 ArkWeb，下一帧再抓取内存 Cookie 并刷新。手工复验 600ms 后 Profile 节点 1、Web 节点 0；设备自动回归同样通过。
- 单元测试：`PASS`，86/86；模拟器设备测试：`PASS`，6/6。
- `NoWebOutsideLogin`、已采样普通页面的 `dumpLayout` Web 0、signed HAP 构建/覆盖安装/启动：`PASS`。
- 性能样本：点击到目的页约 9ms，Skeleton 约 26ms，含图主题首段文字约 968ms，TaskPool 解码约 14ms；首图受外部 CDN 影响约 5.06s，现已改为不阻塞正文的可视区懒加载。
- 真实社区 POST：`NOT RUN`；测试期间未发帖、未回复。
- API 26 真机本轮最终复验：`NOT RUN`；当前 HDC 真机目标为 Offline，不得宣称 M3 真机 PASS。

## 文档规则

- 只维护 `AGENTS.md`、`PROJECT_BASELINE.md` 和已冻结的 `P0_REPORT.md`，不新建成套阶段文档。
- 本轮只更新 `AGENTS.md` 和 `PROJECT_BASELINE.md`；`P0_REPORT.md` 保持不变。
- 所有验收结果严格使用 `PASS`、`FAIL` 或 `NOT RUN`，未执行真机或真实写入时不得补写 PASS。
