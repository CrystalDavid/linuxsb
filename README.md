# 烧饼社区（HarmonyOS）

LinuxSB 的非官方 HarmonyOS 原生客户端。当前版本是 M3 模拟器验收候选：常规业务界面由 ArkUI / UI Design Kit 绘制，业务请求统一使用 RCP，只有用户主动打开的官方登录页使用临时 ArkWeb。

> 当前状态：2026-08-26。Pura 90 API 24 模拟器构建、安装和主要交互已验证；真实社区发帖/回复与本轮 API 26 真机最终复验仍为 `NOT RUN`。

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
| 首页、板块、搜索、我的、设置、发帖、主题详情、回复 | 原生 | 使用 ArkUI 与 `HdsNavigation / HdsTabs / HdsActionBar`，普通页面没有 `Web` 节点 |
| 底部 Tab 图标 | 原生 | 板块/搜索/我的使用系统 `SymbolGlyph`；首页使用 ArkUI `Path` 绘制，不使用 SVG 或位图 Tab 图标 |
| 网络、分页、搜索、写入 | 原生 | 统一使用 Remote Communication Kit；运行时没有 axios、fetch、网页网络桥或第三方跨端框架 |
| HTML 处理 | 原生执行，但数据源是网页协议 | BBS1 HTML 在 TaskPool 中由版本化状态机解码，不加载 CSS、不执行网页 JavaScript、不渲染 DOM |
| 头像与帖子图片 | 原生组件承载外部内容 | 图片来自网络 CDN，但由 ArkUI `Image` 懒加载和绘制 |
| 玻璃与沉浸效果 | 原生 ArkUI | API 24 上使用 UI Design Kit 能力探测与 ArkUI `backgroundEffect`；深色模式不再给玻璃胶囊叠加白色填充，基底改为 `#18000000` 的低强度烟熏黑，选中胶囊改为 `#0A5B8FF9` 的极淡品牌蓝。共享细边缘仍为 10% 白。方案参考华为应用市场底栏：烟熏底压住动态模糊采样到的白色内容，选中依靠 `#5B8FF9` 图标/文字和低强度蓝色局部光晕，不使用发白的实心胶囊。普通控件尚未使用 API 26 才提供的 `.systemMaterial()` |
| 官方登录正文 | **非 ArkUI 页面** | 唯一非原生业务画面：临时 ArkWeb 中的 linux.sb 官方登录网页；关闭后普通页面 Web 节点恢复为 0 |
| 运行时第三方 UI 框架 | 无 | 项目没有 React Native、Flutter、uni-app、Cordova、WebView 套壳依赖；运行时依赖表为空 |

`scripts/NoWebOutsideLogin.ps1` 会阻止 ArkWeb 扩散到普通页面。`CookieSessionBroker` 虽然调用 ArkWeb 的 Cookie 管理器，但它不创建可见界面。

## 当前 UI 与细节

- 底部固定为“首页 / 板块 / 搜索 / 我的”四栏单层玻璃；首页发布使用独立可拖动 FAB。当前底栏实现由 `scripts/CheckBottomTabVisualLock.ps1` 锁定，未获明确要求不得修改。
- 首页保留“标题优先 / 作者优先”两种展示；作者优先头像为 38vp。置顶、精华、热、抽奖中、进行中、已结束均使用独立语义色。
- 所有正式页标题栏统一为 22vp、Bold；首页、板块目录名称和具体板块主题标题统一为 17vp、500 字重。板块首行上移 16vp，在删除大块空白的同时保留适度标题间距。
- 首页与具体板块的“新评论 / 新帖子”共用 46vp 单项宽、30vp 高、12vp 标签的可拖动玻璃切换器；收窄横向并增加纵向厚度，使内层、活动层和外层呈饱满满圆胶囊。外层相对标题累计上移 2vp以避免整体下坠；标签不再做反向位移，文字可见中心与胶囊按钮几何中心完全重合。6vp 采样、1.08 饱和度、1.12 亮度、高光边缘、阴影和移动胶囊参数与冻结底栏一致，但不修改底栏本身。
- 搜索框去除 `TextInput` 的额外默认左右内边距，提示文字向图标靠近；42vp 玻璃提交按钮与输入框同高，复用回复按钮的 24vp/800 `arrow_up` 并旋转 90°形成向右箭头。
- 搜索范围“标题 / 正文 / 回帖”使用每段 52×32vp 的紧凑满圆胶囊，保持可点击与水平拖动，不跟随 42vp 主搜索控件放大。
- 主题详情返回按钮为 40vp 玻璃点击区、28vp/700 返回字形；摘要顶部内边距为 4vp，标题紧邻标题栏。
- 回复栏取消左侧编辑图标；输入框与玻璃发送按钮同为 42vp，发送端使用 24vp/800 的系统 `arrow_up`。箭头始终保持品牌蓝，不因未登录或空草稿变灰，且不再叠加蓝色实心圆底。
- 未登录搜索页不创建输入、提交或搜索范围切换控件，只显示与“我的”完全同尺寸、同位置的共享登录门禁；两页统一使用 24vp 父级顶部内边距，登录后搜索控件仍取消额外顶部内边距。
- 未登录发表主题页只显示登录门禁。门禁固定在“发表主题”标题栏正下方，不带外框；板块、标题、正文与发布按钮均不渲染。
- 登录后发表主题页直接以两列网格展示全部真实板块，发布按钮为 40vp 圆润玻璃胶囊。
- 官方登录页标题和“完成并返回”按钮按系统顶部安全区下移；旧“临时网页登录……”说明已删除。
- 深浅色支持“跟随系统 / 浅色 / 深色”，首页展示偏好与主题偏好均本地持久化。
- 设置页保持两级原生结构：总览只显示“外观主题 / 首页帖子样式”、当前值和进入箭头；主题详情使用浅色、深色两列大预览，预览底部四个状态色圆点完整收在卡片内，下方只保留独立“跟随系统”开关；首页样式使用两张帖子排版预览。三段旧介绍文字均已删除。点击后先更新本地响应式选择状态，再应用并持久化，因此边框和圆形勾选会立即跟随；总览和详情均锚定在标题栏下方。

### 全局字号规范

业务文字只使用 `DesignSystem.Typography` 定义的 11 / 12 / 13 / 14 / 15 / 16 / 17 / 18 / 20 / 22 / 24 / 26vp 十二档。每一档的使用场景、字重、行高以及深浅色玻璃参数统一维护在 [`docs/ui.md`](docs/ui.md)，README 不再复制第二份容易漂移的表格。

## 构建与验证

工程基线为 HarmonyOS 6.1、Stage 模型、ArkTS，兼容 API 23，当前 target API 24。请先在 DevEco Studio 中为本机配置调试签名；仓库不会保存证书路径、keystore 密码或 Profile 密码。

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
- [`docs/security.md`](docs/security.md)：登录、Cookie、写入、日志与签名边界。
- [`docs/project-status.md`](docs/project-status.md)：完整产品基线和当前阶段状态。
- [`docs/p0-report.md`](docs/p0-report.md)：冻结的 P0 / P0-B 历史证据。

根目录只保留 `README.md`、`AGENTS.md`、源码模块和构建入口；构建产物、截图、日志、本地 SDK 路径与签名材料均由 `.gitignore` 排除。
