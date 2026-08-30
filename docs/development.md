# 开发与仓库规范

## 工程环境

- HarmonyOS Stage 模型，ArkTS；当前活动产品使用 DevEco Studio 6.1.1 / API 24 SDK 编译，并要求在更高系统向上兼容运行。
- `compatibleSdkVersion`：6.1.0（API 23）。
- `targetSdkVersion`：6.1.1（API 24）。
- 当前邀请测试候选：`versionName 1.1.1`、`versionCode 1001001`、`buildVersion 3`。
- DevEco Studio / Hvigor 使用开发机本地 SDK；仓库不固定本机绝对路径。
- 普通组件的 `.systemMaterial()` / `ArkUI_ImmersiveMaterial` 从 API 26.0.0 提供，不能在当前 target 24 源码中假装已经启用。当前 HDS 组件保持能力探测，普通组件保持 API 23–24 单层回退；以后建立 target 26 产品时必须继续保留该回退。

## API 23–26 兼容与材质分支

这是当前工程的硬性兼容契约：

| 运行系统 | 构建方式 | 普通玻璃组件 | HDS 标题栏/底栏 | 必须验证 |
| --- | --- | --- | --- | --- |
| API 23–24 | API 24 SDK、target 24、compatible 23 | 唯一一层 `backgroundEffect`；全局通透 4vp / 1.42 / 0.98 / 低 alpha tint | `getSystemMaterialTypes()` 能力探测，不支持时保持单层回退 | 安装、启动、深浅色、底层内容可辨、无白膜与无崩溃 |
| API 26+（运行当前 HAP） | 同一 target 24 HAP | 继续使用经过验证的单层回退，不宣称普通组件原生材质 | 能力探测成功时优先 HDS `ADAPTIVE` | 安装、启动、深浅色、HDS 能力日志、向上运行兼容 |
| API 26+（未来 target 26 产品） | API 26 SDK、target 26、compatible 23 | API 守卫后的 `ImmersiveMaterial`；唯一通透风格映射 `ULTRA_THIN` | 原生 `systemMaterial` / 渐进模糊 | 单独构建证据、API 24 回退复验、API 26 原生材质命中 |

- 当前活动产品不得在无记录的情况下改写 target。若创建 target 26 产品，应使用独立、可复验的配置，并继续让 compatible 23 的同一产物接受 API 24 安装测试。
- 不得把 `compatibleSdkVersion` 提升到 24 或 26，除非用户明确决定放弃 API 23。
- 任何节点只能保留一个采样层。未来 API 26 分支进入前必须清除同节点回退 `backgroundEffect`；当前 API 23–24 路径不得叠第二个模糊或白色底板。
- API 24 不是“只求不崩”的次等目标：通透回退必须低 tint、小半径、保留色块与细边缘，深浅模式分别用资源色。
- API 24 模拟器看不到 API 26 原生能力不构成删除回退理由；API 26 系统能运行 target 24 HAP，也不等于普通组件已经命中 API 26 `ImmersiveMaterial`。

## 本机两个 DevEco Studio

- DevEco Studio 6.1.1：`C:\DevEcoStudio\6.1.1_Release\DevEco Studio\bin\devecostudio64.exe`。当前已验证存在，用于 API 24 构建和 Pura 90 API 24 模拟器。
- DevEco Studio 26.0.0 Beta2 的预定安装根目录是 `C:\DevEcoStudio\26.0.0\_Beta2`；只有该目录下实际的 `bin\devecostudio64.exe` 存在时才算可用。Windows 注册表残留安装路径或只有一个通用图标都不能当作文件存在证据。
- 两个版本可通过各自 `devecostudio64.exe` 共存打开，并可创建“DevEco 6.1.1”和“DevEco 26 Beta2”两个独立快捷方式；同一工程不要同时在两边写入或同步索引。

## 根目录规则

```text
ShaobingCommunity/
├─ AppScope/              # 应用级资源与配置
├─ entry/                 # 主 HAP 模块
├─ hvigor/                # Hvigor 配置
├─ scripts/               # 静态边界与视觉锁检查
├─ docs/                  # 专题规范、状态与历史证据
├─ AGENTS.md              # 实现约束入口
├─ README.md              # 项目入口与快速说明
├─ build-profile.json5    # 可共享、无本地签名的构建配置
├─ code-linter.json5
├─ hvigorfile.ts
└─ oh-package*.json5
```

根目录不得新增阶段性报告、截图、日志、HTML 快照或临时 Markdown。除 `README.md` 和 `AGENTS.md` 外，项目 Markdown 放入 `docs/`；生成证据保留在本地 `artifacts/`，不进入 Git。

## 构建

先在 DevEco Studio 中配置本机调试签名。仓库中的 `build-profile.json5` 必须保持 `signingConfigs: []`，不得写入证书路径、密码、keystore 或 Profile。

标准命令：

```powershell
hvigor assembleHap
powershell -ExecutionPolicy Bypass -File scripts/NoWebOutsideLogin.ps1
powershell -ExecutionPolicy Bypass -File scripts/CheckBottomTabVisualLock.ps1
```

当前 target 24 产品使用 DevEco 6.1.1 自带的 Hvigor、JBR 与 API 24 SDK。建立 target 26 产品时必须改用实际存在的 DevEco 26 Hvigor/JBR/API 26 SDK，不能只改 `build-profile.json5` 后继续用旧工具链。

## 代码约定

- 搜索文件优先使用 `rg` / `rg --files`。
- 全局视觉值放入 `DesignSystem.ets`、共享 UI 常量或资源色，不在页面复制。
- 业务文字字号引用 `Typography`；图标尺寸使用语义明确的组件常量。
- 页面只编排 UI 与状态；网络、解码、会话分别进入既定层。
- 当前仓库按维护者要求不保留自动测试源码；每次变更至少完成编译、两项静态保护脚本和与改动范围相称的设备复验。
- 如果未来重新引入自动测试，逻辑测试放入 `entry/src/test/`，设备测试放入 `entry/src/ohosTest/`，mock 配置放入 `entry/src/mock/`，同时恢复对应依赖与 target。
- 不修改已冻结底栏，除非用户明确要求；任何允许的修改都需同步更新锁定哈希与设备截图证据。

## 华为 IAP 开发配置

- 源码只保存稳定商品 ID，不保存商户证书、私钥、密码或订单：`linuxsb_tip_coin_1`、`linuxsb_tip_water_5`、`linuxsb_tip_coffee_9_9`、`linuxsb_tip_pro_50`。
- 四项都在 AppGallery Connect 配置为一次性消耗型商品，价格分别为 CNY 1.00、5.00、9.90、50.00；商品 ID 创建后不可随意改名。
- 代码使用 `@kit.IAPKit` 的 `queryEnvironmentStatus -> createPurchase -> finishPurchase`。只有用户点击某一金额后才允许打开华为收银台；列表展示和弹窗打开不得触发购买。
- 本地 UI/构建通过不等于支付通过。发布前必须使用 AGC 沙盒测试账号，逐档验证用户取消、无效商品、成功支付和消耗确认；真实扣款只由账号持有人明确操作。
- AGC 商品、支付服务、release 签名和邀请测试版本属于外部状态；修改前先只读核对，真正创建、上传或提交审核前必须获得账号持有人最终确认。

## Git 工作流

提交前：

```powershell
git status --short
git diff --check
git diff --cached --stat
git grep -n -I -E "(password|private.?key|bbs_auth|bbs_csrf)"
```

- 不丢弃工作树中来源不明的修改；先判断它是否属于用户正在开发的内容。
- 提交源码、测试、脚本与规范文档；不提交 `artifacts/`、`build/`、`.hvigor/`、`oh_modules/`、`.idea/`、`local.properties` 或签名材料。
- 推送前先 `fetch` 并确认远端没有需要人工合并的分叉；禁止用强制推送掩盖历史冲突。
- 提交信息说明结果，例如 `docs: organize project standards` 或 `feat: refine native community UI`。

## 文档同步

- UI token、共享组件几何或深浅色变化：更新 `docs/ui.md`，并在 `README.md` 保留简短摘要。
- 架构、网络或原生边界变化：更新 `docs/architecture.md` 与 `docs/security.md`。
- 测试集合或验收状态变化：更新 `docs/testing.md` 与 `docs/project-status.md`。
- 仓库结构、SDK 或命令变化：更新本文件和 `docs/index.md`。
