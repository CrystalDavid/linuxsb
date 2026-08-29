# 架构规范

## 目标与边界

烧饼社区是 LinuxSB 的非官方 HarmonyOS 原生客户端。普通业务页面必须由 ArkUI / UI Design Kit 绘制，网络请求统一走 Remote Communication Kit（RCP）；ArkWeb 仅可作为用户主动打开的官方登录页面，不能成为首页、详情、搜索或个人页的业务容器。

```text
ArkUI Page / Component
  ↓ 只处理展示和交互
ViewModel
  ↓
Repository
  ↓
RcpForumTransport
  ↓
linux.sb BBS1 HTML
  ↓
版本化轻量解码器（TaskPool）
  ↓
领域模型 → PresentationMapper → ArkUI
```

登录是唯一例外：

```text
原生登录入口
  ↓
OfficialLoginPage 中的临时 ArkWeb
  ↓
WebCookieManager 读取 bbs_auth / bbs_csrf
  ↓
仅在内存中构造 Cookie Header
  ↓
销毁 ArkWeb，普通业务继续走 RCP
```

## 目录职责

| 路径 | 职责 | 禁止事项 |
| --- | --- | --- |
| `entry/src/main/ets/views/pages/` | 页面结构、导航目的地、页面级状态绑定 | 直接解析 HTML、读取 Cookie、绕过 Repository 发请求 |
| `entry/src/main/ets/views/components/` | 可复用 ArkUI 组件 | 写入业务会话、复制页面级网络逻辑 |
| `entry/src/main/ets/viewmodels/` | 页面状态与用例编排 | 依赖具体 ArkUI 节点 |
| `entry/src/main/ets/services/repository/` | 聚合缓存、Transport 与领域模型 | 直接控制页面布局 |
| `entry/src/main/ets/services/transport/` | RCP 路由、GET/POST 契约、响应指纹 | 输出 Cookie 值、隐式真实写入 |
| `entry/src/main/ets/services/protocol/` | BBS1 版本化解码、TaskPool 任务 | DOM/CSSOM、CSS 选择器、整页正则解析 |
| `entry/src/main/ets/services/presentation/` | 领域模型到 UI 模型的映射 | 网络请求和会话管理 |
| `entry/src/main/ets/services/auth/` | 临时网页登录和内存会话衔接 | 持久化 Cookie、在普通页创建 Web 节点 |
| `entry/src/main/ets/services/payment/` | 华为 IAP 环境检查、一次性商品下单与消耗确认 | 自建支付页面、接触银行卡/支付密码、复用论坛 Cookie |
| `entry/src/main/ets/common/theme/` | 字号、颜色语义、布局 token | 页面内新增不可追踪的全局常量 |
| `entry/src/main/ets/common/ui/` | 共享沉浸式材质、标题栏和布局策略 | 为同一控件叠加第二层模糊或不透明底色 |

## 依赖规则

- Page / Component 可以依赖 ViewModel、展示模型、主题 token 和共享 UI 组件。
- ViewModel 可以依赖 Repository，不得依赖具体 Page。
- Repository 可以依赖 Transport、协议解码、缓存和领域模型。
- Transport 不得依赖 UI；协议解码不得依赖 ArkWeb。
- 运行时不引入 React Native、Flutter、uni-app、Cordova、axios 或网页网络桥。
- 图片是远程内容，但必须由原生 `Image` 承载并进行可视区懒加载。
- 华为支付是独立系统能力：页面只能调用 `DeveloperSupportService`，该服务只依赖 IAP Kit 与 UIAbility 上下文，不得依赖论坛 Transport、Repository 或会话 Broker。

## 协议解码

- 以已知 BBS1 版本和结构为契约，不追求“任意网页通用解析器”。
- 使用单遍 tokenizer / 状态机；不构建 DOM，不加载 CSS，不执行页面 JavaScript。
- 解码在 TaskPool 执行，主线程只接收领域模型。
- 缺失字段应产生可诊断的警告或降级状态，不得编造回复、作者或统计数。
- 列表按服务端分页链接连续加载，按稳定 ID 去重；不得恢复客户端 30 条硬上限。
- 称号与个人扩展页统一经 `PortalRepository -> PortalDecodeTask -> PortalPageDecoder` 读取登录态 HTML；解码器按当前 linux.sb 的明确类名提取称号卡、完整称号池、交易、会话、积分、收藏、通知与烧饼钱包，不把原始 HTML 交给页面。
- Portal 页面切换采用路径快照和排队重载：过期请求不得覆盖当前子页。通知中的 `/topic/{id}?replyid={id}` 先进入原生主题路由，再由详情 ViewModel 继续分页并定位目标回复；私信回复通知的 `blockquote` 仅作为“我的原消息”识别依据，不进入正文，并将原站 `/direct_messages/{id}?draft=...` 绑定为原生“回复TA”动作。
- 私信列表链接进入 `/direct_messages/{partner_id}`；会话发送只在用户点击发送后，通过 `PortalRepository.submit` 向同一路径 POST `_csrf / partner_id / content`。linux.sb 的成功写入以同源 302 回跳为提交成功证据；即使随后读取结果页失败，也不得把已经落库的私信误报为“服务器未接受”。烧饼兑换只向 `/community_wallet_redeem` POST `_csrf / code`。两者都复用内存登录会话与同源写入白名单，不在 Page 内直接请求网络。
- 个人设置读取 `/profile`，`PortalPageDecoder` 解码资料字段、当前 `bio/avatar_style/avatar_seed` 与同页保存表单；用户名改为 `/username_change`，预置头像改为 `/avatar_upload`，图库头像由 `M1Runtime` 居中裁剪为 200×200 JPEG 后经 `PortalRepository.uploadAvatar -> RcpForumTransport.postMultipartFile` 以 `avatar` 字段上传。页面只负责编辑状态和明确确认，不直接访问网络。资料页包含正常密码输入框，因此会话失效检测必须同时命中真实 `/login` 表单，不能只凭 `name="password"` 判定。

## 性能数据链路

- 匿名首页第一页允许写入原生 Preferences 快照；命中后先呈现再实时刷新。登录态、Cookie、搜索和个人 feed 不进入该快照。
- 首页、板块、搜索和个人主题列表使用 ArkUI `LazyForEach + IDataSource`；追加分页必须以 `onDataAdd` 精准通知，不得恢复全量 `ForEach`。
- 离屏缓存数量由共享列表统一维护，当前主题列表只保留 3 个离屏节点；带点击回调、嵌套状态组件或生命周期的主题行不得为追求警告清零强行加 `@Reusable` 或改成 Builder。
- 个人设置的预置头像使用水平 `List + LazyForEach`，远程图片请求固定为 96px PNG 并按 48vp 解码；不得恢复一次创建全部远程 SVG。称号池、我的称号和在售交易卡片也通过 `IDataSource` 懒创建。
- 主题列表的相对时间与组合元信息在 PresentationMapper 中预计算，行组件滚动期间不得重复解析日期或拼接同一组元信息。
- HDS 标题栏渐进模糊半径保持 12vp；禁用态动作按钮不创建实时背景采样。冻结底栏仍使用独立视觉配方，不得借性能改动修改。
- 主题预取只在滚动停止后执行，最多 3 个候选和 2 个 worker；滚动开始、页面离开或会话变化必须取消。
- 产品 GET 不在 UI 热路径同步计算完整 SHA-256；只有诊断探针和写请求审计允许生成响应指纹。
- 性能指标、工具和当前实测统一维护在 [performance.md](performance.md)。

## 图片上传（外链图床）

- 背景：linux.sb 当前账号组的附件配额为 0MB，站点不下发附件上传器，服务端 `attachment_upload` 通道不可用；图片改走第三方外链图床（美团图床 https://695402.xyz/mt/）。
- 端点：主 `https://aapi.helioho.st/upload.php`，备 `https://mtbed.netsons.org/upload.php`（`RcpForumTransport` 的上传白名单同时放行主备）。
- 契约：匿名 `multipart/form-data`，文件字段名 `image`；响应 JSON 为 `{code, data:{url, name}, msg}`，仅 `code === 200` 且 `data.url` 非空视为成功。
- 产物：成功时把图片 URL 包成 `![name](url)` 的 markdown 片段返回给编辑器，由 UI 插入正文；`name` 需剔除 `[`、`]` 与换行，避免破坏 markdown 语法。
- 分层：`WriteRepository.uploadAttachment` 仍是对外唯一入口（签名与 `AttachmentUploadResult` 不变），`M1Runtime.uploadImage` 只负责沙箱暂存与调用；换图床不触及任何业务页面内部 UI。
- 登录态：图床为匿名服务，上传不再要求论坛会话；会话仍然只约束发帖/回帖本身。
- 失败处理：优先展示图床返回的 `msg`；传输层异常提示“图床暂时无法访问，请稍后重试”，其余兜底“上传失败，请重试”。

## 投喂开发者与反馈

```text
SettingsPage ArkUI 底部弹窗
  ↓ 用户点击明确金额
DeveloperSupportService
  ↓ queryEnvironmentStatus
IAP Kit createPurchase
  ↓ 华为账号与系统收银台
finishPurchase（一次性消耗型商品）
```

- 四个商品 ID 固定为 `linuxsb_tip_coin_1`、`linuxsb_tip_water_5`、`linuxsb_tip_coffee_9_9`、`linuxsb_tip_pro_50`，类型均为 `ProductType.CONSUMABLE`。所谓“pro 订阅”只是一次性赞助档位名称，不产生自动续费、会员权益或论坛账号权益。
- 价格、币种、订单和支付凭据由华为 IAP/AGC 管理；应用不自建收银台，不读取银行卡或支付密码，不把购买数据写入日志、Preferences 或仓库。
- 商品未配置、地区/账号不支持、用户取消或系统支付失败时，页面只显示明确失败/取消结果，不改变论坛状态，也不得本地伪造成功。
- “反馈”直接调用现有 `openTopicLocation(17803, 0, ...)`，进入 ArkUI 原生主题详情；不打开外部浏览器，也不增加 ArkWeb 边界。

## 原生性检查

普通业务页的运行时布局树必须为 Web 节点 0。`scripts/NoWebOutsideLogin.ps1` 是静态边界检查；设备验收还需对首页、板块、搜索、个人页和主题详情执行 `dumpLayout`。

## 上游参考

可以在已获授权的范围内参考 ArkDO 固定提交 `7680996437b3b877aa5c69ac2f55529297a2ea52`，但必须保留烧饼社区自己的品牌、BBS1 协议模型、RCP 网络架构与签名配置。不得复制上游证书、密码、Profile、Cookie、截图或未获授权的资产。
