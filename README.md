# 烧饼社区（HarmonyOS）

LinuxSB 的非官方 HarmonyOS 原生客户端。当前邀请测试候选版本为 **1.1.0（versionCode 1001000）**：常规业务界面由 ArkUI / UI Design Kit 绘制，业务请求统一使用 RCP，只有用户主动打开的官方登录页使用临时 ArkWeb。

> 当前状态：2026-08-29。活动产品使用 API 24 target、API 23 兼容下限；同一 HAP 需要分别在 Pura 90 API 24 与 API 26 验证。API 26 的通用 `ImmersiveMaterial` 只属于后续 target 26 产品，不能与当前 HDS 能力探测或 API 24 回退混为一谈。

## 技术路线

```text
ArkUI / UI Design Kit 页面
  ↓
ViewModel / Repository
  ↓
RcpForumTransport（Remote Communication Kit）
  ↓
linux.sb BBS1 HTML
  ↓
版本化单遍解码器（TaskPool，不构建 DOM/CSSOM）
  ↓
领域模型 / Presentation Mapper
  ↓
ArkUI 原生列表、详情、图片、编辑器与导航
```

登录是唯一例外：

```text
原生登录入口
  ↓
临时 ArkWeb 打开 https://linux.sb/login
  ↓
WebCookieManager 读取 bbs_auth / bbs_csrf
  ↓
仅在内存中生成 Cookie Header
  ↓
销毁 ArkWeb，后续业务继续走 RCP
```

## 原生性审计

| 范围 | 结论 | 说明 |
| --- | --- | --- |
| 首页、板块、称号、我的、搜索、设置、发帖、主题详情、回复 | 原生 | 使用 ArkUI 与 `HdsNavigation / HdsTabs / HdsActionBar`，普通页面没有 `Web` 节点 |
| 底部 Tab 图标 | 原生 | 板块/称号/我的使用系统 `SymbolGlyph`；首页使用 ArkUI `Path` 绘制，不使用 SVG 或位图 Tab 图标 |
| 网络、分页、搜索、写入 | 原生 | 统一使用 Remote Communication Kit；运行时没有 axios、fetch、网页网络桥或第三方跨端框架 |
| HTML 处理 | 原生执行，但数据源是网页协议 | BBS1 HTML 在 TaskPool 中由版本化状态机解码，不加载 CSS、不执行网页 JavaScript、不渲染 DOM |
| 头像与帖子图片 | 原生组件承载外部内容 | 图片来自网络 CDN，但由 ArkUI `Image` 懒加载和绘制 |
| 投喂开发者 | 原生华为能力 | ArkUI 底部弹窗选择一次性档位，由 IAP Kit `createPurchase` 打开华为收银台；应用不自建支付页，也不把论坛 Cookie 发送给华为 |
| 玻璃与沉浸效果 | 原生 ArkUI | 当前 API 23–24 普通组件统一使用 4vp / 1.42 饱和度 / 0.98 亮度 / 低 alpha 冷色 tint 的唯一一层 `backgroundEffect`，深浅模式分别取资源；HDS 标题栏继续能力探测并优先 `ADAPTIVE`。API 26 的通用 `ImmersiveMaterial` 需在 target 26 产品中另行守卫接入，迁移时不得删除当前回退 |
| 官方登录正文 | **非 ArkUI 页面** | 唯一非原生业务画面：临时 ArkWeb 中的 linux.sb 官方登录网页；关闭后普通页面 Web 节点恢复为 0 |
| 运行时第三方 UI 框架 | 无 | 项目没有 React Native、Flutter、uni-app、Cordova、WebView 套壳依赖；运行时依赖表为空 |

`scripts/NoWebOutsideLogin.ps1` 会阻止 ArkWeb 扩散到普通页面。`CookieSessionBroker` 虽然调用 ArkWeb 的 Cookie 管理器，但它不创建可见界面。

## 当前 UI 与细节

- 底部为 264×56vp 的“首页 / 板块 / 称号 / 我的”四栏单层通透玻璃。首页右侧以 8vp 间隔放置同高 56×56vp 发帖加号，Dock 总宽 328vp；“我的”同位置显示系统设置按钮；两枚右侧动作在浅色模式使用黑色主题前景、深色模式自动使用白色主题前景。板块与称号不显示右侧动作，托盘以既有弹簧曲线右移 32vp 后居中。当前四栏视觉实现由 `scripts/CheckBottomTabVisualLock.ps1` 锁定。
- 首页保留“标题优先 / 作者优先”两种展示；作者优先头像为 38vp。置顶、精华、热、抽奖中、进行中、已结束均使用独立语义色。
- 首页、板块、称号、我的四个根页左上角标题统一为 28vp、Bold；设置、发表、详情等压栈页保持 22vp、Bold。首页、板块目录名称和具体板块主题标题统一为 17vp、500 字重。板块首行上移 16vp，在删除大块空白的同时保留适度标题间距。
- 首页与具体板块使用标题栏右端的紧凑玻璃按钮：只显示居中的 15vp 当前排序文字，不显示展开箭头；点击后展开“新评论 / 新帖子 / 精华 / 抽奖 / 发卡 / 足迹”，板块目录页不显示该按钮。
- 搜索框去除 `TextInput` 的额外默认左右内边距，提示文字向图标靠近；42vp 玻璃提交按钮与输入框同高，复用回复按钮的 24vp/800 `arrow_up` 并旋转 90°形成向右箭头。
- 搜索范围“标题 / 正文 / 回帖”使用每段 52×32vp 的紧凑满圆胶囊，保持可点击与水平拖动，不跟随 42vp 主搜索控件放大。
- 标题栏搜索、筛选与所有返回按钮统一使用 40vp 点击区；搜索/返回图标统一为 24vp。首页搜索图标与筛选文字在浅色模式使用黑色主题前景、深色模式使用白色主题前景。主题详情摘要顶部内边距为 4vp，标题紧邻标题栏；滚动折叠后分类标签相对标题起点右缩 12vp。
- “我的”主题/回帖列表单独使用 40vp 头像，标题到分类标签及作者行的间距为 8vp；其他主题流继续保留各自既定头像尺寸和排版。
- “我的”入口为两行四列，并提供原生个人设置：展示真实账号资料，支持按原站契约修改用户名、头像、简介与密码；烧饼余额、兑换、收支明细和充值申请保持窄屏安全布局。
- 回复栏取消左侧编辑图标；输入框与玻璃发送按钮同为 42vp，发送端使用 24vp/800 的系统 `arrow_up`。箭头始终保持品牌蓝，不因未登录或空草稿变灰，且不再叠加蓝色实心圆底。
- 未登录搜索页不创建输入、提交或搜索范围切换控件，只显示与“我的”完全同尺寸、同位置的共享登录门禁；两页统一使用 24vp 父级顶部内边距，登录后搜索控件仍取消额外顶部内边距。
- 未登录发表主题页只显示登录门禁。门禁固定在“发表主题”标题栏正下方，不带外框；板块、标题、正文与发布按钮均不渲染。
- 登录后发表主题页直接以两列网格展示全部真实板块，发布按钮为 40vp 圆润玻璃胶囊。
- 官方登录页标题和“完成并返回”按钮按系统顶部安全区下移；旧“临时网页登录……”说明已删除。
- 深浅色支持“跟随系统 / 浅色 / 深色”，首页展示偏好与主题偏好均本地持久化。
- 全局玻璃只保留低遮罩的“通透”配方；奶白配方和设置入口已删除，升级时旧持久值自动迁移为通透。
- 页面结构层不再铺纯白或异色底板：称号卡片、设置分组、交易/表单卡片与空态都使用页面同色背景，仅由间距、细边和圆角区分。称号中心六个横向胶囊与交易子页胶囊复用 API 23–24 的单层通透玻璃；未选中透明采样，选中项保持主题主前景实底。
- “我的交易”固定分为发布记录和交易记录。发布卡按“称号 / 单价 / 状态 / 编号与日期”排列；交易记录标题与上方卡片保留额外 8vp 间距，流水采用无头像的紧凑分隔列表。
- 设置页保持两级原生结构：第一张两行圆角卡展示“外观主题 / 首页帖子样式”，第二张同规格卡展示“投喂开发者 / 反馈”。投喂弹窗提供硬币 ¥1、水 ¥5、咖啡 ¥9.9、pro 订阅 ¥50 四个**一次性、非自动续费**档位，并交由华为收银台处理；反馈直接进入原生帖子详情 `topic/17803`。主题详情使用浅色、深色两列大预览，首页样式使用两张帖子排版预览；选择状态先更新本地响应式状态，再应用并持久化。

### 全局字号规范

业务文字只使用 `DesignSystem.Typography` 定义的 11 / 12 / 13 / 14 / 15 / 16 / 17 / 18 / 20 / 22 / 24 / 26 / 28vp 十三档。每一档的使用场景、字重、行高以及深浅色玻璃参数统一维护在 [`docs/ui.md`](docs/ui.md)，README 不再复制第二份容易漂移的表格。

## 构建与验证

工程为 Stage 模型、ArkTS，当前 `targetSdkVersion` 是 API 24，`compatibleSdkVersion` 是 API 23。同一份 signed HAP 必须分别安装到 Pura 90 API 24 与 API 26 验证向上运行兼容和 HDS 能力探测；通用 API 26 `ImmersiveMaterial` 需要另一个 target 26 构建证据，不能由 API 24 HAP 推断。完整兼容契约见 [`docs/development.md`](docs/development.md)。

交付门槛：

```text
hvigor assembleHap
powershell -ExecutionPolicy Bypass -File scripts/NoWebOutsideLogin.ps1
powershell -ExecutionPolicy Bypass -File scripts/CheckBottomTabVisualLock.ps1
```

当前仓库按维护者要求不保留 `src/test`、`src/ohosTest` 和 mock 测试源码；91/91 单元测试与 13/13 模拟器设备测试是删除前的历史通过记录，保存在项目状态文档中，不代表未来改动已自动回归。当前提交必须至少完成 HAP 构建、两项静态保护脚本和人工设备复验。真实发帖与回复只能由用户在 App 内明确确认。

## 文档

- [`docs/index.md`](docs/index.md)：完整文档索引与更新规则。
- [`docs/architecture.md`](docs/architecture.md)：原生架构、目录职责与依赖边界。
- [`docs/ui.md`](docs/ui.md)：字号、色彩、深浅色玻璃、组件尺寸与交互规范。
- [`docs/development.md`](docs/development.md)：工程环境、仓库结构、构建与 Git 规范。
- [`docs/testing.md`](docs/testing.md)：单元、设备、视觉和安全验收门槛。
- [`docs/performance.md`](docs/performance.md)：原生缓存、懒列表、华为性能工具与当前实测数据。
- [`docs/security.md`](docs/security.md)：登录、Cookie、写入、日志与签名边界。
- [`docs/privacy-policy.md`](docs/privacy-policy.md)：面向测试用户和发布审核的隐私政策正文。
- [`docs/release-testing.md`](docs/release-testing.md)：真机安装、release 签名、邀请测试与 AppGallery Connect 阶段门。
- [`docs/project-status.md`](docs/project-status.md)：完整产品基线和当前阶段状态。
- [`docs/p0-report.md`](docs/p0-report.md)：冻结的 P0 / P0-B 历史证据。

根目录只保留 `README.md`、`AGENTS.md`、源码模块和构建入口；构建产物、截图、日志、本地 SDK 路径与签名材料均由 `.gitignore` 排除。
