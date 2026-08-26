# 开发与仓库规范

## 工程环境

- HarmonyOS 6.1，Stage 模型，ArkTS。
- `compatibleSdkVersion`：6.1.0（API 23）。
- `targetSdkVersion`：6.1.1（API 24）。
- DevEco Studio / Hvigor 使用开发机本地 SDK；仓库不固定本机绝对路径。
- 普通组件的 `.systemMaterial()` 需要 API 26，当前 API 24 基线不得伪造类型或强行调用。

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

如果命令行未配置全局 Hvigor，应使用 DevEco Studio 自带的 Hvigor、JBR 21 和对应 SDK，不要为了单个工程污染系统 PATH。

## 代码约定

- 搜索文件优先使用 `rg` / `rg --files`。
- 全局视觉值放入 `DesignSystem.ets`、共享 UI 常量或资源色，不在页面复制。
- 业务文字字号引用 `Typography`；图标尺寸使用语义明确的组件常量。
- 页面只编排 UI 与状态；网络、解码、会话分别进入既定层。
- 当前仓库按维护者要求不保留自动测试源码；每次变更至少完成编译、两项静态保护脚本和与改动范围相称的设备复验。
- 如果未来重新引入自动测试，逻辑测试放入 `entry/src/test/`，设备测试放入 `entry/src/ohosTest/`，mock 配置放入 `entry/src/mock/`，同时恢复对应依赖与 target。
- 不修改已冻结底栏，除非用户明确要求；任何允许的修改都需同步更新锁定哈希与设备截图证据。

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
