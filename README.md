# 烧饼社区（HarmonyOS）

LinuxSB 的非官方 HarmonyOS 原生客户端。当前只进入 **P0 技术验证阶段**，尚未开始完整产品开发。

## 已冻结的主架构

```text
可见界面：ArkUI / UI Design Kit 原生绘制
普通业务：RCP 原生 HTTP
协议转换：版本化、单遍 BBS1 解码器，不构建 DOM、不加载 CSS
登录：仅登录页使用 ArkWeb
会话衔接：ArkWeb Cookie → CookieSessionBroker → RCP 会话
```

RCP 与 ArkWeb 不是两套竞争方案：RCP 是正式业务传输层，ArkWeb 只是官方网页登录入口。P0 的目的，是验证 Cookie 衔接及登录后 RCP 请求在真实 API 23 设备上是否成立。

## 文档

- `PROJECT_BASELINE.md`：合并后的产品、架构、UI、目录和工程标准。
- `AGENTS.md`：Codex 必须遵守的约束，以及首轮 P0 测试任务。

## 开始方式

1. 在 DevEco Studio 创建 API 23、ArkTS、Stage 模型的 Empty Ability 工程，项目名建议为 `ShaobingCommunity`。
2. 将本目录中的三个文件复制到仓库根目录。
3. 用 Codex 打开仓库，发送：

```text
严格按 AGENTS.md 执行当前 P0 任务。先检查仓库和构建环境，再实现、构建、测试并生成 P0_REPORT.md；不要扩展到完整产品功能。
```

Codex 官方支持通过仓库中的 `AGENTS.md` 获取代码库导航、测试命令和工程规范。
