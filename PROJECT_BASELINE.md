# 烧饼社区项目基线 v0.3

> 本文件合并产品定义、系统架构、UI 基线、工程目录、质量标准和技术决策。除非 P0 证据证明关键链路不可行，否则实现不得偏离本基线。

> 阶段状态（2026-08-23）：P0 与 P0-B 均已在 API 26 真机通过。RCP、轻量解码、TaskPool、临时 ArkWeb 官方登录、Cookie 内存桥接、登录后 RCP、会话清理，以及 Topic 605 登录后同页 5 条回复解码均已验证。正式主题详情的技术阶段门已解除，但本轮没有开始正式 UI；真实写操作仍为 NOT RUN。

## 1. 产品定义

### 1.1 身份

- 产品名：**烧饼社区**
- 定位：LinuxSB 的非官方第三方 HarmonyOS 客户端
- 平台基线：HarmonyOS 6.1，API 23
- 技术栈：ArkTS、Stage 模型、ArkUI、UI Design Kit、Remote Communication Kit、ArkWeb（仅登录）
- 服务端前提：不修改 linux.sb，不依赖站长安装插件，不建设中转代理服务器

应用内必须明确显示“非官方客户端”，不得让用户误以为由 linux.sb 站方发布。

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

真实写操作仍未授权和验证，继续保持功能开关关闭。P0-B 已通过，后续可以在新的明确任务中开始正式主题详情纵向闭环；本轮不扩展正式页面。

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

首版视觉与交互以 ArkDO 的成熟体验为对标对象，但采用 **clean-room 独立实现**：

- 不复制 ArkDO 源码、注释、资源、图标和品牌资产；
- 使用 ArkUI、HarmonyOS Symbol、UI Design Kit 与 HDS 组件重新实现；
- 页面结构、交互层级、内容密度、抽屉、回复浮层、图片预览、深色模式和双栏逻辑可对标；
- 使用“烧饼社区”自己的名称、图标、配色语义和文案。

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
- 正式主题详情的技术阶段门已解除，但必须由后续明确任务启动；本轮不实现正式 UI。

### 通过

P0 只读主链路与 P0-B 同页回复契约均已通过并冻结，可以在后续明确任务中进入正式主题详情纵向闭环。

### 条件通过

读取、登录和同页回复解码已经通过，真实写操作尚未验证：只读能力可以继续；编辑、回复和发帖必须保持关闭。

### 不通过

- RCP 被站点/WAF 阻断；
- 无法从官方登录页安全获得可用于 RCP 的会话；
- 登录后 RCP 始终不被服务器认可；
- 回复只能通过未经授权的 POST、执行远程 JavaScript或不稳定私有接口获得；
- 写操作协议无法在不绕过安全机制的前提下成立。

出现以上任一情况，Codex 必须停止扩展产品功能，生成证据报告。下一步是联系站长安装最小 API 插件，而不是偷偷切换为网页套壳或长期隐藏 ArkWeb 业务桥。
