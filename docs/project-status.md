# 烧饼社区项目基线 v0.5

> 本文件合并产品定义、系统架构、UI 基线、工程目录、质量标准和技术决策。除非 P0 证据证明关键链路不可行，否则实现不得偏离本基线。

> 阶段状态（2026-08-26）：P0、P0-B 与 M1 历史验收继续为 PASS，M2-R1 历史状态保持 FAIL。M3 已在 Pura 90 API 24 模拟器完成四栏原生社区壳与首页独立 FAB、连续首页分页、板块筛选、搜索/个人页、原生发帖/回复 UI、主题重排版、楼中楼、图片懒加载、登录返回假死修复、全局单层轮廓保留玻璃、三档主题切换，以及单一鸿蒙原生底栏图标；删除测试源码前的 91/91 单元测试和 13/13 设备测试为历史 PASS。当前仓库按维护者要求已移除自动测试源码，因此后续变化的活动自动回归状态为 NOT RUN。M3 真实社区 POST 与本轮 API 26 真机复验同样为 NOT RUN，因此只能称为“模拟器验收候选”，不宣称整个 M3 真机 PASS。

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

截至 M2-R1.1，真实写操作仍未授权且功能固定禁用。M3 任务已由用户明确扩展为原生发帖与回复；实现只能使用 BBS1 v8.6.5 已核对的 `/topic_edit` 和 `/reply_edit` 表单契约，必须有内存登录态、CSRF 与用户明确点击。自动化不得代替用户发送真实社区内容。

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

M1 阶段门已经通过。当时对个人中心、搜索和写入能力的禁止是历史范围边界；已被用户后续的 M3 明确任务覆盖，但安全、权限和真实内容发送的阶段门依然有效。

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
- 当前 Pura 90 自动回归：PASS。`hvigor test` 为 71/71，`onDeviceTest` 为 5/5，`NoWebOutsideLogin`、signed HAP 构建、覆盖安装和启动均通过；正式首页已移除“非官方客户端”副标题，dumpLayout 为 Home/Drawer Web 0。
- 当前登录态第一页实测：PASS。Topic 15365 的实时总回复数会变化；本次结构探针得到第一页 50 条、总数 87、1/2 页、真实下一页链接存在，回复 ID 唯一且主楼未重复。
- 当前 UI 修复：PASS。抽屉使用蓝色语义主色，删除“筛选”“版块”“最新”，只保留“新评论 / 新帖子”；网页“展开全文”控件与正文分离，懒加载/链接包裹图片由原生 Image 异步呈现，楼中楼保留引用树顺序并显示父楼层。
- 当前性能修复：PASS（自动契约）。不同主题冷开不再短暂显示上一个主题；同主题刷新保留现有内容；可见窗口预取去重并在返回首页后恢复，TopicMemoryCache、InFlight 去重、十条批量挂载和图片非阻塞保持启用。历史冷网络阶段超过 1500 ms 的样本继续单独标记，不误报为解码慢。
- 当前模拟器安全回归：PASS。最终 5 秒应用日志 7117 行中 Fatal 0、`UI_FALLBACK` 0、Cookie 泄露 0、POST 证据 0；生产源码 POST 命中 0。
- 当前第二页 UI 懒加载复验：NOT RUN。最新版 HAP 覆盖安装后内存会话按设计清空，等待重新完成官方登录后验证 50 + 当前第二页余量的合并结果。
- DevEco ArkUI Inspector：PASS。已真实连接应用进程，展开 `RootPage -> RootTabPage -> Navigation`，普通页面以 `Web` 搜索后无匹配组件；该证据不以 dumpLayout 替代。
- 最终 API 26 真机复验：NOT RUN。M2-R1 总状态继续保持 FAIL，不创建 PASS 标签。

### 2.8 M3 原生社区壳与交互闭环

M3 不改变已冻结的 RCP / 轻量解码 / TaskPool / ArkUI 架构，仅扩展正式产品导航、真实 GET 数据范围和经用户授权的原生写入 UI/表单契约。

| 项目 | 状态 | 核心证据 |
| --- | --- | --- |
| 四栏原生导航与首页 FAB | PASS | 根壳使用 `HdsNavigation / HdsNavDestination / HdsTabs`；可见底栏只有 `首页 / 板块 / 搜索 / 我的`，发布入口位于首页可拖动 FAB。底栏固定为 56vp 鸿蒙高亮托盘和 64×50vp 连续移动指示器，按 72vp Tab 槽位精确居中，不再保留紧凑或 iOS 玻璃分支；Tab 默认状态层关闭，避免黑闪和双层轮廓。底栏图标只保留一套原生实现：板块、搜索、我的使用系统填充 `SymbolGlyph`，首页使用 ArkUI `Path` 按参考轮廓绘制并以 `vp2px` 适配密度；无图片与 SVG 图标资源。四枚图标位于相同 28×26vp 光学盒，保留各自原有轮廓、比例、字重和位移补偿，从自身中心统一乘以 0.92 的最终显示缩放，再统一下移 0.7vp；首页只将门洞下沿横梁由 1.55 继续加粗为 1.85 路径单位。模拟器 1320×2856 截图中四枚图标整体下移约 2px，与标签的可见间距缩短 2–3px，尺寸与水平位置不变；首页中心封口由 5px 增至 7px，屋顶、外墙与门洞圆弧边界不变。当前 `ImmersiveBottomTabBar.ets` 以 SHA-256 `D50D21A0E9E9863CB4F5123EC453717C23C15072DB4979FD96614E06AE67EE65` 冻结并由脚本校验（2026-08-28 经用户授权将托盘采样升级为 24vp 主玻璃后重新冻结）。首页 FAB 继续使用 23vp 系统加号，只将字重从 Bold 提高为 900；1320×2856 同区域像素测量中横/竖笔画由 8/9px 增至 11/11px，尺寸与位置不变 |
| 沉浸光感材质 | PASS（构建与脚本；设备截图复验待做） | 标题栏使用 HDS `GRADIENT_BLUR` 与能力探测后的系统材质；FAB、详情返回、分段控件、搜索/回复/发帖输入统一为一个 6vp `backgroundEffect` 采样层，默认 1.08 饱和度、1.12 亮度、约 1.25vp 高光边缘和单圈中性阴影。2026-08-28 经用户授权，悬浮底栏升级为独立的“主玻璃”：24vp 采样半径、1.15 饱和度、1.35 亮度和专用 `bottom_tab_bar_frost` tint（浅色 `#33FFFFFF`），滚动内容在托盘下融化成柔和色场，接近参考的灵动透亮观感；按钮、连续移动指示器与图标保持冻结线不变。深色资源中的底栏及通用玻璃高亮统一为 `#1AFFFFFF`（10% 白）；共享胶囊基底保持 `#18000000` 烟熏黑，选中层为 `#0A5B8FF9` 极淡品牌蓝并以 `#245B8FF9` 蓝光标记选中。顶部分段控件继续复用 6vp 共享玻璃参数并支持水平拖动；重复背景、第二模糊层和旧式暗染色均已删除 |
| 深浅色设置 | PASS | “我的”页通过可拖动的 6vp 单层玻璃齿轮 FAB 进入独立原生设置页；总览使用圆角分组，只显示“外观主题 / 首页帖子样式”、当前值和进入箭头。外观详情以两列大预览选择“浅色 / 深色”，下方单独提供“跟随系统”开关；点击先更新本地响应式状态，再应用并持久化主题，因此边框和圆形勾选会在点击当帧移动。旧双套底栏图标偏好、总览分段控件、四枚 SVG 和三段设置介绍文字已移除；总览与详情内容均锚定标题栏下方，个人主页不直接堆放外观控件 |
| 普通组件 systemMaterial | NOT RUN | 当前工程 compile/target API 24；`uiMaterial.ImmersiveMaterial` 与 ArkUI `.systemMaterial()` 从 API 26 提供。本轮不伪造缺失类型，待升级 API 26 SDK 后接入 |
| 首页连续分页 | PASS | 解码服务端真实 `p` href，去除 30 条客户端上限，`LazyForEach` 接近底部时加载下页并按 topicId 去重 |
| 页面顶栏密度 | PASS | Home、板块、搜索、我的、设置、发表、详情、官方登录和诊断标题栏全部统一为 22vp、Bold；首页与具体板块的“新评论 / 新帖子”均使用 46vp 单项宽、30vp 高与 12vp 标签，通过收窄横向和增加纵向厚度消除扁平感，内层按钮、活动层和外层均使用显式满圆并裁剪的胶囊；外层累计上移 2vp，标签不再反向补偿。1320×2856 模拟器最终边界为首页标题 `[42,189][914,279]`、切换器 `[942,175][1278,280]`、首项按钮 `[949,182][1110,273]`、首项标签 `[966,203][1093,252]`；按钮与标签的可见纵向中心都为 227.5px，完全重合 |
| 全局字号 | PASS | `DesignSystem.Typography` 固定为 12 档：11/12/13/14/15/16/17/18/20/22/24/26vp。页面标题 22，主题/板块名 17，紧凑标题 16，正文 15，元信息 13，说明/分段 12，底栏 11；旧名称仅为同值兼容别名。所有业务文字的裸数字 `fontSize` 已收口，Symbol/Path/FAB 图标尺寸不计入文字档位 |
| 板块 | PASS | 首页板块标签按板块使用独立颜色；根目录展示 16vp 色标、17vp/500 真实名称、公开简介、主题数与进入箭头，首行上移 12vp，使首项标题与页面标题可见边界保留约 17.1vp。进入具体板块后的主题标题同样与首页统一为 17vp/500，元信息保持 13vp且继续使用紧凑列表结构；进入单个板块后才请求真实 `/forum/{id}` GET，“新评论 / 新帖子”位于板块名右侧的同一标题行，返回按钮统一为 40vp 玻璃区和 28vp/700 `chevron_left` |
| 首页主题排版选择 | PASS | 设置详情以两张原生帖子缩略预览选择并持久化两种用户选项：“标题优先”为标题、标签、作者/回复/时间三行，默认启用；“作者优先”为头像旁作者与最近活跃时间/回复数、下方标题、末行标签。详情不再显示额外的预览说明段落；选择先更新本地响应式状态，圆形勾选即时移动。两种真实首页标题均为 17vp、500 字重；作者优先头像由 48vp 缩至 38vp。运行时切换会重建对应 `LazyForEach` 分支；置顶/精华/热/抽奖中/卡片进行中/卡片已结束分别使用蓝/紫/红/粉/青/灰语义胶囊并适配深浅主题；板块、搜索和个人页仍保持原紧凑结构。数据模型未提供首帖发布时间，因此作者优先只显示真实 `lastReplyAt`，不伪造字段 |
| 搜索与个人页 | PASS | 原生 Search/Profile 页、标题/正文/回复搜索契约、当前用户与用户 feed 映射已实现；未登录 Search 不创建输入、提交或范围切换控件，只显示与 Profile 完全同尺寸、同位置的共享门禁，两页父级顶部内边距统一为 24vp。登录后搜索输入删除系统默认左右内边距和额外顶部空白；输入外层与提交按钮统一为 42vp，提交端与回复端共用同一个 24vp/800 系统 `arrow_up`，仅旋转 90°形成向右箭头，并继续使用 6vp 单层玻璃；“标题 / 正文 / 回帖”范围切换独立收至每段 52×32vp 的紧凑满圆胶囊 |
| 主题详情排版 | PASS | 主楼/回复使用头像左、作者和正文右；楼中楼保留父楼层级；详情摘要、正文和回复移除独立 surface，仅保留低对比细分隔；详情与发表主题页共用 40vp 单层玻璃返回按钮，内部 `chevron_left` 为 28vp/700；摘要顶部内边距由最初 20vp 收至 4vp，使主题标题累计上移 16vp，骨架首帧同步；帖子内“回复”动作使用 Capsule、圆角与 clip，点击不再闪出矩形状态层；普通页面 Web 节点 0 |
| 正文与图片 | PASS | 网页“展开全文”等控件不进入 ContentBlock；原生 Image 成功显示外部 WebP；改为可视区懒加载，不阻塞文字 |
| 发帖与回复实现 | PASS | 原生编辑器和简约回复栏已接入 `WriteRepository`；回复输入已删除左侧编辑图标及其预留空白，输入外层与发送按钮统一为 42vp 高，发送端复用单层液态玻璃并使用 24vp/800 的系统 `arrow_up`。箭头始终使用品牌蓝且不降低透明度，已删除 `arrow_up_circle_fill` 形成的第二个蓝色实心圆底；未登录时按钮仍可进入官方登录。发表主题页未登录时不渲染发布、板块、标题和正文控件，仅显示无外框登录门禁；门禁通过顶部锚定布局固定在标题栏正文区域起点 12vp 内，不再因短内容落到页面中下部。登录后显示 40vp 圆润玻璃发布按钮；标题输入（48vp）与正文输入在上，板块选择器在下，全部真实板块以三列 40vp 满圆 Chip 展示，未选中使用烟熏玻璃底与 1.25vp 高光边，选中使用 `compose_forum_selected_bg` 品牌蓝底与品牌蓝边，不再出现灰色选中态。Transport 仅 allowlist `/topic_edit` 和 `/reply_edit`；单元测试仅用 fake transport 校验字段 |
| 写入结果判定 | PASS（模拟器构建；真机待复验） | BBS1 在写入成功后以 302 跳转到新主题页，此前 RCP 未跟随 POST 重定向导致 3xx 被判为失败并误报“服务器未接受本次提交”。`RcpForumTransport.postForm` 现在以 GET 跟随最多 3 跳同源重定向并记录最终 URL；`WriteRepository` 依次以最终 URL、非 HTML 2xx 正文、登录页判定确认结果，新主题在无法确认时先经 `findTopicByTitle` 反查再报告，避免把已成功的发布误报为失败或诱导二次发帖 |
| 会话生命周期 | PASS（模拟器构建；真机待复验） | 冷启动经 `restorePersistedSession()` 从 ArkWeb 持久 Cookie 恢复内存会话；`M1Runtime.verifyActiveSession()` 以 60s 节流 + 在途去重在回前台、进入“我的”时向服务端复核，服务端不识别即清内存并回调 UI；写入遇到登录页响应立即判定 `authExpired` 并清会话；每次完成官方登录递增 `loginGeneration` 触发 Profile 重建，解决“登录后仍显示未登录、需切页刷新”的问题 |
| 真实社区 POST | NOT RUN | 未自动发帖或回复，没有为验收创造社区垃圾内容；P0-8 历史状态不变 |
| 登录完成返回 | PASS | 官方登录原生头部读取系统顶部安全区，标题和“完成并返回”整体避开状态栏/挖孔区，旧“临时网页登录……”说明已删除；关闭时先从 UI 移除临时 ArkWeb，下一帧再抓取 Cookie/刷新；手工复验 600ms 后 Profile=1、Web=0，专项设备测试通过 |
| 性能样本 | PASS（API 24 模拟器 + API 26 真机） | 匿名首页 Preferences 快照先呈现再实时刷新；模拟器同口径冷启动首主题平均由约 2736ms 降至 1131ms。板块/搜索/个人分页列表改为 `LazyForEach + IDataSource` 并保留 6 个离屏缓存节点。Mate 80 Pro Max 真机在 90Hz 首页双向惯性滑动 5 轮时 RenderService >16.67ms、>33ms、>66ms 均为 0；未缓存主题首文本 396ms，缓存命中首文本 28ms。真机无线 HDC 冷进程语义检测 5 次平均约 2005ms，包含工具轮询地板；完整口径见 `docs/performance.md` |
| 自动测试 | NOT RUN（当前） | 删除测试源码前的历史结果为 `hvigor test` 91/91、`hvigor onDeviceTest` 13/13；按维护者要求，`entry/src/test`、`entry/src/ohosTest` 与 mock 已于 2026-08-26 清理，后续改动不得继续借用旧结果宣称自动回归 PASS |
| 模拟器 signed HAP | PASS | Pura 90 API 24 构建、覆盖安装、启动成功；最终 Home `dumpLayout` Web 0，进程 Fatal 0、`UI_FALLBACK` 0、Cookie 泄露 0、HTTP POST 0；全局 6vp 单层玻璃已截图复验，控件内文字不再与底层内容抢读 |
| API 26 真机最终复验 | NOT RUN | HDC 重启后只发现 `127.0.0.1:5555` 模拟器，Windows 未枚举 HDC Interface；待手机重新建立 HDC 连接后再安装复验，不能用模拟器结果代替 |

M3 当前是已通过模拟器的候选版。在 API 26 真机重连且完成最终复验前，不将整个 M3 宣称为 PASS；真实发帖/回复只能由用户在 App 中明确确认。

### 2.9 原生性审计（2026-08-26）

本节把“鸿蒙原生组件”“外部内容”和“网页界面”分开判断，避免把网络图片或 HTML 数据源误判成网页套壳。

| 审计范围 | 结论 | 代码证据与边界 |
| --- | --- | --- |
| 正式页面与导航 | 原生 | Home、Forums、Search、Profile、Settings、Compose、TopicDetail 均由 ArkUI 和 UI Design Kit 构建；根壳使用 `HdsNavigation / HdsTabs`，普通页面 `Web` 节点为 0 |
| 底栏与操作图标 | 原生 | 三枚系统 `SymbolGlyph` 加一枚 ArkUI `Path` 首页图标；不存在 SVG、HTML 或位图 Tab 图标。`Path` 是原生绘制，但首页字形并非系统内置 Symbol |
| 玻璃与沉浸材质 | 原生 ArkUI | HDS 标题栏配合能力探测，普通控件使用 ArkUI `backgroundEffect`。工程 target API 24，因此 API 26 才提供的普通组件 `.systemMaterial()` 仍为 `NOT RUN`；这表示“不是该 API 26 系统材质原语”，不表示使用了网页或跨端渲染 |
| 网络与协议转换 | 原生执行 | 唯一正式 Transport 为 Remote Communication Kit；BBS1 HTML 在 TaskPool 中由版本化单遍状态机解码，不构建 DOM/CSSOM、不执行网页脚本、不使用 ArkWeb 网络桥 |
| 头像与帖子图片 | 原生组件 + 外部媒体 | URL 来自 linux.sb/CDN，但显示组件是 ArkUI `Image`，使用原生懒加载与失败回退；外部图片内容本身不等于非原生页面 |
| 官方登录正文 | **唯一非 ArkUI 可见内容** | `OfficialLoginPage.ets` 中唯一一个 `Web` 节点加载 `https://linux.sb/login`；其头部与关闭按钮仍为 ArkUI。此临时网页只负责官方账号登录，关闭后销毁 |
| Cookie 衔接 | 平台原生服务，非可见 UI | `CookieSessionBroker.ets` 调用 ArkWeb `WebCookieManager` 读取必要 Cookie，并只在内存中交给 RCP；它不创建页面 |
| 运行时第三方框架 | 无 | `oh-package.json5` 与 `entry/oh-package.json5` 的运行时 dependencies 为空；无 React Native、Flutter、uni-app、Cordova、axios 或自带 WebView 套壳 |

源码门禁 `scripts/NoWebOutsideLogin.ps1` 已通过：ArkWeb import 仅位于 `services/auth`，`Web` 构造器仅位于 `OfficialLoginPage.ets`。因此，若把“原生”定义为“全部可见内容均为 ArkUI”，当前唯一例外就是官方登录网页；若把“原生”定义为“使用 HarmonyOS 平台组件”，ArkWeb 本身也是系统组件，但其中呈现的站点登录正文仍然是网页而非 ArkUI。

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

- 匿名首页第一页由原生 Preferences 保存公开快照，优先显示后后台刷新；最长 12 小时且不缓存登录态、Cookie、搜索或个人 feed；
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
contracts/fixtures/              合成或脱敏协议样本，不提交真实 Cookie
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
- 可共享 `build-profile.json5` 不保存开发机证书路径、Profile 路径、keystore 路径或密码；本地签名只在 DevEco Studio/开发机配置，不提交真实签名证书、Profile、私钥与密码；
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
