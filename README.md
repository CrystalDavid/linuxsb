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
| 玻璃与沉浸效果 | 原生 ArkUI | API 24 上使用 UI Design Kit 能力探测与 ArkUI `backgroundEffect`；普通控件尚未使用 API 26 才提供的 `.systemMaterial()` |
| 官方登录正文 | **非 ArkUI 页面** | 唯一非原生业务画面：临时 ArkWeb 中的 linux.sb 官方登录网页；关闭后普通页面 Web 节点恢复为 0 |
| 运行时第三方 UI 框架 | 无 | 项目没有 React Native、Flutter、uni-app、Cordova、WebView 套壳依赖；运行时依赖表为空 |

`scripts/NoWebOutsideLogin.ps1` 会阻止 ArkWeb 扩散到普通页面。`CookieSessionBroker` 虽然调用 ArkWeb 的 Cookie 管理器，但它不创建可见界面。

## 当前 UI 与细节

- 底部固定为“首页 / 板块 / 搜索 / 我的”四栏单层玻璃；首页发布使用独立可拖动 FAB。当前底栏实现由 `scripts/CheckBottomTabVisualLock.ps1` 锁定，未获明确要求不得修改。
- 首页保留“标题优先 / 作者优先”两种展示；作者优先头像为 38vp。置顶、精华、热、抽奖中、进行中、已结束均使用独立语义色。
- 主题详情返回按钮为 40vp 玻璃点击区、28vp/700 返回字形；摘要顶部内边距为 4vp，标题紧邻标题栏。
- 回复栏取消左侧编辑图标；输入框与发送按钮同为 44vp，发送图标保留 36vp/700 加粗样式。
- 未登录发表主题页只显示登录门禁。门禁固定在“发表主题”标题栏正下方，不带外框；板块、标题、正文与发布按钮均不渲染。
- 登录后发表主题页直接以两列网格展示全部真实板块，发布按钮为 40vp 圆润玻璃胶囊。
- 官方登录页标题和“完成并返回”按钮按系统顶部安全区下移；旧“临时网页登录……”说明已删除。
- 深浅色支持“跟随系统 / 浅色 / 深色”，首页展示偏好与主题偏好均本地持久化。

## 构建与验证

工程基线为 HarmonyOS 6.1、Stage 模型、ArkTS，兼容 API 23，当前 target API 24。请先在 DevEco Studio 中为本机配置调试签名；仓库不会保存证书路径、keystore 密码或 Profile 密码。

交付门槛：

```text
hvigor test
hvigor onDeviceTest
hvigor assembleHap
powershell -ExecutionPolicy Bypass -File scripts/NoWebOutsideLogin.ps1
powershell -ExecutionPolicy Bypass -File scripts/CheckBottomTabVisualLock.ps1
```

自动测试不会向真实社区发送 POST；真实发帖与回复只能由用户在 App 内明确确认。

## 文档

- `README.md`：当前技术路线、原生性审计和 UI 摘要。
- `PROJECT_BASELINE.md`：完整产品、架构、UI 细节、阶段状态和工程标准。
- `AGENTS.md`：后续实现必须遵守的代码、视觉、安全和测试约束。
- `P0_REPORT.md`：冻结的 P0 / P0-B 历史证据，不随当前 UI 迭代改写。
