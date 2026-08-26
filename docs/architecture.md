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
| `entry/src/main/ets/common/theme/` | 字号、颜色语义、布局 token | 页面内新增不可追踪的全局常量 |
| `entry/src/main/ets/common/ui/` | 共享沉浸式材质、标题栏和布局策略 | 为同一控件叠加第二层模糊或不透明底色 |

## 依赖规则

- Page / Component 可以依赖 ViewModel、展示模型、主题 token 和共享 UI 组件。
- ViewModel 可以依赖 Repository，不得依赖具体 Page。
- Repository 可以依赖 Transport、协议解码、缓存和领域模型。
- Transport 不得依赖 UI；协议解码不得依赖 ArkWeb。
- 运行时不引入 React Native、Flutter、uni-app、Cordova、axios 或网页网络桥。
- 图片是远程内容，但必须由原生 `Image` 承载并进行可视区懒加载。

## 协议解码

- 以已知 BBS1 版本和结构为契约，不追求“任意网页通用解析器”。
- 使用单遍 tokenizer / 状态机；不构建 DOM，不加载 CSS，不执行页面 JavaScript。
- 解码在 TaskPool 执行，主线程只接收领域模型。
- 缺失字段应产生可诊断的警告或降级状态，不得编造回复、作者或统计数。
- 列表按服务端分页链接连续加载，按稳定 ID 去重；不得恢复客户端 30 条硬上限。

## 原生性检查

普通业务页的运行时布局树必须为 Web 节点 0。`scripts/NoWebOutsideLogin.ps1` 是静态边界检查；设备验收还需对首页、板块、搜索、个人页和主题详情执行 `dumpLayout`。

## 上游参考

可以在已获授权的范围内参考 ArkDO 固定提交 `7680996437b3b877aa5c69ac2f55529297a2ea52`，但必须保留烧饼社区自己的品牌、BBS1 协议模型、RCP 网络架构与签名配置。不得复制上游证书、密码、Profile、Cookie、截图或未获授权的资产。
