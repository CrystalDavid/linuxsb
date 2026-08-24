# 烧饼社区项目基线 v0.4

> 本文件合并产品定义、系统架构、UI 基线、工程目录、质量标准和技术决策。除非 P0 证据证明关键链路不可行，否则实现不得偏离本基线。

> 阶段状态（2026-08-24）：P0、P0-B 与 M1“只读产品纵向闭环”均已在 API 26 真机通过。M2-R1 严格状态仍为 FAIL：模拟器冷正文目标仅 3/5 达标，认证高回复 Topic 15365 出现 `REPLY_STRUCTURE_MISMATCH`，DevEco ArkUI Inspector 为 NOT RUN。当前仅执行 M2-R1.1，对真实分页契约、原生正文边界、授权 ArkDO 抽屉/详情表现和主题打开性能进行修复；未完成全部验收前不得将 M2-R1 改为 PASS 或进入 M2-B。已验证架构继续冻结，真实写操作继续为 NOT RUN。

## 1. 产品定义

### 1.1 身份

- 产品名：**烧饼社区**
- 定位：LinuxSB 的非官方第三方 HarmonyOS 客户端
- 平台基线：HarmonyOS 6.1，API 23
- 技术栈：ArkTS、Stage 模型、ArkUI、UI Design Kit、Remote Communication Kit、ArkWeb（仅登录）
- 服务端前提：不修改 linux.sb，不依赖站长安装插件，不建设中转代理服务器

应用不得让用户误以为由 linux.sb 站方发布；非官方身份声明保留在关于、登录说明等合适位置，但正式首页不再永久展示“非官方客户端”副标题。

### 1.2 产品目标

为 HarmonyOS 手机和平板提供比浏览器更顺手的社区阅读与互动体验：原生列表、原生主题详情、原生导航、深浅色与大屏适配，同时继续使用 linux.sb 官方账号体系和权限规则。

### 1.3 第一版范围

首版目标功能：

- 游客浏览首页、版块、主题和回复；
- 新评论、新帖子、精华等基础筛选；
- 搜索；
- 官方网页登录与会话保持；
- 登录后的个人资料、我的主题、我的回复和通知；
- 新建主题、回复、编辑、删除（以服务端权限为准）；
- 本地草稿；
- 图片查看、分享、深浅色、手机单栏和平板双栏。

暂不进入首版主线：系统推送、实时在线状态、实时回复、私信、离线全文库、后台管理，以及所有 LinuxSB 插件的完整原生化。插件功能按独立扩展解码器逐项接入，不能污染普通主题链路。

## 2. 唯一主架构

### 2.1 结论

```text
ArkUI 页面
  ↓
ViewModel / Service
  ↓
Repository
  ↓
ForumTransport（正式实现只有 RcpForumTransport）
  ↓
RCP 原生 HTTP
  ↓
BBS1 版本化单遍协议解码
  ↓
Topic / Reply / User 等领域模型
  ↓
ArkUI 原生绘制
```

登录链路：

```text
ArkUI 点击登录
  ↓
临时 LoginWebPage（ArkWeb，加载 linux.sb 官方登录页）
  ↓
网站写入 bbs_auth / bbs_csrf Cookie
  ↓
CookieSessionBroker 仅在内存中读取所需 Cookie
  ↓
关闭登录页
  ↓
后续业务继续统一走 RCP
```

**这不是两套并行方案。** ArkWeb 不承担首页、主题详情或普通业务请求；它只是官方登录入口。正常业务阶段不得保留常驻隐藏 ArkWeb。

### 2.2 为什么选择它

- 相比全 ArkWeb 请求桥：冷启动、内存、请求调度和长期复杂度更低；
- 相比网页套壳：可见内容由 ArkUI 绘制，导航、列表、缓存和大屏体验可控；
- 相比 CSS/DOM 提取：解码器不建立 DOM、CSSOM，不执行网页脚本，也不进行网页布局和绘制；
- 相比自建代理：用户 Cookie 不离开设备，没有额外服务器、隐私责任和中转延迟。

### 2.3 P0 真机结论与冻结范围

API 26 真机已经验证：

1. RCP 匿名首页与公开主题 GET 成功；
2. 单遍轻量解码和 TaskPool 可稳定提取首页与主题核心字段；
3. 临时 ArkWeb 可以完成官方登录，关闭后和进程重启后没有隐藏 Web；
4. 应用只显示必要 Cookie 的存在性与 Header 长度，Cookie 值未泄露；
5. 内存 Cookie Header 交给 RCP 后，`/notify` 认可登录态；
6. 会话清理和进程重启后不会恢复内存 Header；
7. 首页解析处于可用但待优化区间，主题解析处于绿色区间；没有 `UI_FALLBACK`。
8. 匿名 Topic 605 由 `replies_login_visible` 服务端结构隐藏回复；登录后同一 `/topic/605` GET 稳定返回 5 个回复容器，无需额外 GET、AJAX、POST 或 ArkWeb 数据桥。

因此只读主架构正式冻结为：RCP GET → 版本化轻量解码 → TaskPool → ArkUI；登录继续只使用临时 ArkWeb → Cookie 内存桥接 → RCP。不得再讨论常驻隐藏 ArkWeb或网页套壳作为替代方案。

真实写操作仍未授权和验证，继续保持功能开关关闭。P0-B 与 M1 已通过；当前新增获准范围仅为 M2-R1 授权 UI 移植、首页真实字段扩展和只读主题打开性能优化，不扩展正式写入能力。

### 2.4 M1 状态与阶段门

当前 M1 验收状态：

- RootPage + Navigation + NavPathStack、正式 HomePage、正式 TopicDetailPage：PASS；
- Home/Topic Repository、ViewModel、领域模型和 ContentBlock v1：PASS；
- 临时官方登录覆盖层与登录后同 topicId 刷新链路：PASS（单元契约与 API 26 真机）；
- 原 19 个协议测试与新增 M1 测试：PASS（30/30）；
- signed HAP 构建、安装和启动：PASS；
- `hvigor onDeviceTest`：PASS（1/1）；
- API 26 真机默认首页、真实主题、匿名门控、登录回流和 5 条回复闭环：PASS；
- 普通页面 Web 节点 0、Cookie 值泄露匹配 0、`UI_FALLBACK` 0、Fatal 0、POST 0：PASS；
- M1 总状态：PASS；P0-8 真实写操作继续为 NOT RUN。

M1 阶段门已经通过；后续仍不得在没有新任务明确授权时扩展个人中心、搜索或任何写入能力。

### 2.5 M2-R1 授权移植范围

- 用户已确认获得 ArkDO 作者对源码学习、复用和改造的授权；授权证据由用户私下保存，不提交聊天隐私或授权材料。
- 允许直接读取、复制并改造 ArkDO UI 源码；唯一固定上游提交为 `7680996437b3b877aa5c69ac2f55529297a2ea52`，本机优先目录为 `C:\Code\ArkDO`。
- 保留烧饼社区自己的品牌、BBS1 数据协议、RCP 网络、TaskPool、临时 ArkWeb 登录和 Cookie 内存桥接。
- 上游 UI 对 Discourse 业务模型的依赖必须改为本项目的 Presentation Adapter 和 UI Model，不迁入 Discourse TopicService 或业务模型。
- 不迁入 ArkWebNetworkBridge、Challenge/Cloudflare、MessageBus、Presence、Push、DoH、Boost、Reaction、Poll、LDC Credit 或 LinuxDO 等级/品牌逻辑。
- 当前分支为 `m2/arkdo-authorized-ui-port`；授权边界 checkpoint、UI 移植、性能优化、Pura 90 模拟器回归和 API 26 真机核心闭环复验为 PASS。高回复主题兼容性为 FAIL，DevEco ArkUI Inspector 为 NOT RUN，因此完整里程碑严格记为 FAIL。

### 2.6 M2-R1 实现与验收状态

| 项目 | 状态 | 核心证据 |
| --- | --- | --- |
| 固定上游 | PASS | `C:\Code\ArkDO` HEAD 为 `7680996437b3b877aa5c69ac2f55529297a2ea52` |
| 授权 UI 基础设施与组件 | PASS | 主题、沉浸标题、浮动布局、头像、标签、抽屉、主题正文和禁用输入栏已适配到本项目模型 |
| 首页真实字段与 Adapter | PASS | tokenizer/状态机扩展作者、头像、回复、时间和状态；缺失字段不伪造；协议对象不直接进入 UI |
| 主题打开架构 | PASS | 立即 push、摘要首帧、骨架屏、单例 RCP Session、Product 缓存策略、20 条/2 分钟内存缓存、认证分区、在途去重、最多 3 条/并发 2 的受控预取 |
| 单元测试 | PASS | 44/44，Failure 0，Error 0 |
| Pura 90 设备测试 | PASS | API 24；onDeviceTest 5/5；signed HAP 构建、覆盖安装、启动和进程检查成功 |
| 首页/抽屉/匿名主题视觉 | PASS | 深浅色通过；首页首屏约 10 条；抽屉 288vp；匿名主题显示主楼与登录门控；普通 UI Web 节点 0 |
| 页面/骨架首帧 | PASS | 5 次冷开：中位 32 ms，最大 44 ms；目标不超过 100 ms |
| 热缓存正文 | PASS | 5 次：中位 35 ms，最大 51 ms；目标不超过 250 ms |
| 冷请求正文 | FAIL | 5 次中 3 次不超过 1500 ms；中位 1170 ms，最大 1871 ms；两次超标对应网络 1731/1827 ms，不是解码或 UI 阶段 |
| TaskPool 解码 | PASS | 冷开中位 13 ms，最大 16 ms；请求计数最大 1；first-byte 指标当前 RCP 接口不可获得 |
| 安全回归 | PASS | 模拟器与 API 26 真机均为 Cookie 泄露 0、`UI_FALLBACK` 0、Fatal 0、HTTP POST 0；真机最终进程日志 783 行；Web 构造器只在官方登录页 |
| DevEco ArkUI Inspector | NOT RUN | 桌面窗口焦点不稳定；已用 TestKit 与 `dumpLayout` 完成组件层级、抽屉边界、无效空白和普通页面 Web 节点检查 |
| API 26 真机 signed HAP | PASS | SGT-AL10、API 26；`entry-default-signed.hap` 为 978011 bytes，SHA-256 `78E7B48443BC7835A089DE9D4B3811D085C4F724940D7596DBD5EA019A471B44`；覆盖安装、启动和进程检查成功 |
| API 26 真机首页与匿名主题 | PASS | 深色首页首屏约 11 条真实主题；匿名主题主楼和登录门控可见；普通页面 Web 节点 0；匿名主题内容约 506 ms，其中网络约 443 ms、解码约 37 ms、请求数 1 |
| 临时官方登录与返回 | PASS | 登录期间只有一个可见临时 Web；关闭后返回原 Topic 15365 并发出认证 RCP GET；普通主题页面 Web 节点恢复为 0 |
| 登录后主题详情视觉 | PASS | 认证 Topic 15458 得到 `CONTENT`，约 419 ms、请求数 1；页面声明 35 条回复，滚动后的语义节点连续为楼层 1～4，登录门控 0、Web 节点 0 |
| 进程重启会话隔离 | PASS | 杀进程重启后正式首页恢复 20 个可定位主题项；再次进入主题显示匿名登录门控、回复节点 0、Web 节点 0，内存 RCP 会话未恢复 |
| 高回复主题兼容性 | FAIL | 登录返回的 Topic 15365 声明 75 条回复；认证 GET 完成后得到 `REPLY_STRUCTURE_MISMATCH`。本轮未猜分页路由、未补造回复、未执行 POST，留待独立协议契约调查 |
| M2-R1 完整里程碑 | FAIL | 授权 UI、立即导航、缓存、去重、模拟器和真机核心闭环已完成；冷正文目标与高回复主题兼容性未全部通过，ArkUI Inspector 仍为 NOT RUN |
| P0-8 写操作 | NOT RUN | FAB 与回复栏保持禁用；没有 POST 实现或请求 |

M2-R1 的授权 UI、主题打开优化和 API 26 真机核心闭环已经形成可复验候选版本，但完整里程碑严格记为 FAIL，不以局部 PASS 掩盖冷网络超标和高回复主题结构不兼容。后续如获新任务，应先对 Topic 15365 做独立、只读的版本化协议契约调查，再决定是否支持分页；不得猜测路由或执行 POST。DevEco ArkUI Inspector 仍需在桌面交互环境稳定时单独复验。P0、P0-B 与 M1 的历史结论不受本节影响。

### 2.7 M2-R1.1 修复范围与阶段门

- 当前分支：`m2/r1-1-native-topic-drawer-perf`，基线提交 `891231c`；不得创建 M2-R1 PASS 标签。
- 唯一目标：以 BBS1 v8.6.5 真实分页 href 修复 Topic 15365，分离正文与网页控制/扩展元数据，按 ArkDO 固定提交重做抽屉和主题详情，并继续缩短可感知打开时间。
- 普通 Home/Topic 必须保持纯 ArkUI；ArkWeb 只允许临时官方登录。新增 `NoWebOutsideLogin` 源码与 UI 结构自动检查。
- 分页仅允许 RCP GET；首屏只取第一页，接近底部再取下一页；按 replyId 去重并维持楼层顺序、重试幂等和返回后已加载页状态。
- P0-8 仍为 NOT RUN，禁止 POST、发帖、回复、编辑或删除。
- 当前实现：PASS。Topic 15365 已按真实 `?p=2` href 建模为分页回复页；第一页 50 条采用 BBS1 引用树顺序，`data-quote-threads-parent-floor` 已进入协议、领域和 UI 模型，不再把合法引用树误报为 `REPLY_STRUCTURE_MISMATCH`。网页“展开全文”、引用控制文字、编辑元信息和打赏扩展已与正文分离。
- 当前 Pura 90 自动回归：PASS。`hvigor test` 为 65/65，`onDeviceTest` 为 5/5，`NoWebOutsideLogin`、signed HAP 构建、覆盖安装和启动均通过；正式首页已移除“非官方客户端”副标题，dumpLayout 为 Home Web 0。
- 当前登录态第一页实测：PASS。Topic 15365 的实时总回复数会变化；本次结构探针得到第一页 50 条、总数 87、1/2 页、真实下一页链接存在，回复 ID 唯一且主楼未重复。
- 当前第二页 UI 懒加载复验：NOT RUN。最新版 HAP 覆盖安装后内存会话按设计清空，等待重新完成官方登录后验证 50 + 当前第二页余量的合并结果。
- DevEco ArkUI Inspector：NOT RUN。Windows 桌面仍处于锁定状态，不能以 dumpLayout 代替真实 Inspector 操作。
- 最终 API 26 真机复验：NOT RUN。M2-R1 总状态继续保持 FAIL，不创建 PASS 标签。

## 3. 协议适配原则

### 3.1 不是通用爬虫

烧饼社区针对明确的 BBS1 版本和 linux.sb 扩展结构开发协议适配器：

```text
ProtocolAdapter
├── Bbs1V865Adapter
│   ├── HomeDecoder
│   ├── TopicDecoder
│   ├── UserDecoder
│   ├── NotificationDecoder
│   └── FormContract
└── LinuxSbExtensions
    ├── FeaturedDecoder
    ├── LikeCoinDecoder
    ├── LotteryDecoder
    └── CardDecoder
```

核心解码器只识别语义边界、路由 ID、属性和表单字段，不关心颜色、字体、margin、CSS 计算结果或完整 DOM 树。

### 3.2 解码要求

- 单遍或有限回溯，时间复杂度目标为 O(n)；
- 解码任务放在 TaskPool/Worker，不阻塞 UI 线程；
- 未识别扩展生成 `UnsupportedExtension`，不得导致整个页面失败；
- 页面结构签名不匹配时，返回明确的 `PROTOCOL_MISMATCH`，不得静默输出错误数据；
- 协议层不得依赖 ArkUI；UI 层不得出现 HTML 选择器、Cookie 或表单字段。

### 3.3 缓存

- 首页优先显示上一次成功缓存，再后台刷新；
- 主题缓存按 ID 保存有限最近记录；
- Cookie 不写普通 Preferences，不写日志；
- 用户可以清缓存，但清缓存不得删除草稿或登录会话。

## 4. UI 基线

### 4.1 设计方向

首版视觉与交互允许在作者授权范围内直接移植和改造 ArkDO 固定提交的核心 UI：

- 移植来源必须固定到 `7680996437b3b877aa5c69ac2f55529297a2ea52`，不得混入未确认版本的工作树内容；
- 可以复用沉浸布局、主题列表、头像、标签、筛选抽屉、FAB、主题详情、富正文和禁用输入栏等 UI 实现；
- 必须改造 import、模型和回调，通过烧饼社区自己的 Presentation Adapter 消除 Discourse 业务依赖；
- 不复用 LINUX DO Logo、等级、站点品牌文案或被明确排除的网络/服务模块；
- 最终继续使用“烧饼社区”名称、非官方身份声明、BBS1 协议和现有只读网络架构；正式首页不固定展示“非官方客户端”副标题。

### 4.2 首版页面

```text
Root
├── 首页
│   ├── 主题列表
│   ├── 筛选/版块抽屉
│   └── 新建主题
├── 搜索
├── 主题详情
│   ├── 主楼
│   ├── 回复列表
│   ├── 图片预览
│   └── 回复/编辑浮层
├── 登录
├── 我的
│   ├── 个人资料
│   ├── 我的主题/回复
│   ├── 通知
│   └── 草稿
└── 设置
```

P0 阶段不实现完整页面，只实现技术探针页。

## 5. 工程目录

```text
entry/src/main/ets/
├── app/                         启动、全局环境、会话协调
├── common/
│   ├── constants/
│   ├── theme/
│   ├── ui/
│   └── utils/
├── models/                      Forum、Topic、Reply、User、ContentBlock
├── navigation/                  Navigation + NavPathStack 路由
├── services/
│   ├── transport/
│   │   ├── ForumTransport.ets
│   │   ├── RcpForumTransport.ets
│   │   ├── CookieSessionBroker.ets
│   │   └── ResponseCache.ets
│   ├── auth/
│   │   ├── AuthSession.ets
│   │   ├── LoginWebPage.ets
│   │   └── SessionProbe.ets
│   ├── protocol/
│   │   ├── ProtocolAdapter.ets
│   │   ├── ProtocolVersionDetector.ets
│   │   ├── HtmlTokenizer.ets
│   │   ├── HtmlEntityDecoder.ets
│   │   ├── bbs1/v8_6_5/
│   │   └── extensions/
│   ├── repository/
│   ├── draft/
│   └── logging/
└── views/
    ├── pages/
    └── components/

contracts/bbs1/v8.6.5/           路由、表单和结构契约
contracts/fixtures/              合成或脱敏测试页面，不提交真实 Cookie
entry/src/test/                  纯逻辑与协议单元测试
entry/src/ohosTest/              设备集成测试
```

第一阶段保持单 HAP、单 entry 模块；未出现真实模块边界前不得提前拆分多个 Feature Module。

## 6. 工程标准

### 6.1 依赖边界

- Page/Component 不直接发网络请求、不解析 HTML、不读 Cookie；
- Repository 不依赖 ArkUI；
- DTO/协议对象不得直接进入 UI；
- 所有站点请求只经过 `ForumTransport`；
- 当前正式业务实现只允许 `RcpForumTransport`；
- ArkWeb 只允许出现在 `services/auth` 与登录页面。

### 6.2 安全

- 不记录账号、密码、Cookie 值、CSRF 值、完整私密正文；
- 登录页只加载受信任的 `https://linux.sb/` 域名，外链转系统浏览器；
- Cookie 仅在必要时驻留内存；
- P0 默认禁止真实 POST；
- 不修改、提交或生成真实签名证书、Profile、私钥与密码；
- 不绕过验证码、人机验证、站点权限或限流。

### 6.3 质量目标

P0 先记录真实数据，正式阶段目标如下：

- 缓存首页首屏尽快可见，随后无感刷新；
- 正常浏览时 ArkWeb 实例为 0；
- 首页和主题解析不阻塞 UI；
- 同时网络请求不超过 4 个；
- 列表使用懒加载和精准更新；
- 每个页面具备 Loading、Empty、Error、Offline、Unauthorized 状态；
- 手机、平板、深浅色和系统大字体均纳入完成标准。

## 7. P0 决策规则

### 当前决策

- P0-1 至 P0-7：PASS；P0-8：NOT RUN。
- P0-B：PASS（类型 1，同页解码）。匿名响应声明 5、实际 0 并带登录门控；登录后同一 GET 声明 5、实际 5。
- 回复 ID 唯一、主楼未重复、楼层为 1～5，作者与正文最小字段完整；TaskPool、Cookie 脱敏和响应指纹均已通过真机复验。
- 不增加额外回复路由，不猜测分页接口，不使用 POST 或 ArkWeb 业务桥。
- 正式主题详情的技术阶段门已解除；M1 已完成只读首页 → 主题详情 → 登录回流纵向闭环；M2-R1 已获准直接移植固定 ArkDO 提交的核心 UI，并仅优化只读主题打开链路。

### 通过

P0 只读主链路、P0-B 同页回复契约与 M1 只读纵向闭环均已通过并冻结；M2-R1 可以在不改变该架构的前提下进行授权 UI 移植和只读性能优化，其他功能必须另行定义范围和验收门槛。

### 条件通过

读取、登录和同页回复解码已经通过，真实写操作尚未验证：只读能力可以继续；编辑、回复和发帖必须保持关闭。

### 不通过

- RCP 被站点/WAF 阻断；
- 无法从官方登录页安全获得可用于 RCP 的会话；
- 登录后 RCP 始终不被服务器认可；
- 回复只能通过未经授权的 POST、执行远程 JavaScript或不稳定私有接口获得；
- 写操作协议无法在不绕过安全机制的前提下成立。

出现以上任一情况，Codex 必须停止扩展产品功能，生成证据报告。下一步是联系站长安装最小 API 插件，而不是偷偷切换为网页套壳或长期隐藏 ArkWeb 业务桥。
