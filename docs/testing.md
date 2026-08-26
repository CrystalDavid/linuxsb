# 验证与验收规范

## 当前验证能力

按维护者 2026-08-26 的明确要求，仓库不再保留 `entry/src/test/`、`entry/src/ohosTest/` 与 `entry/src/mock/`。同时移除了 Hypium / Hamock 依赖和 `ohosTest` target。

删除前最后一次完整记录为：单元测试 91 / 91 `PASS`，Pura 90 API 24 模拟器设备测试 13 / 13 `PASS`。这只是历史证据，不能用于证明删除之后的新代码已经自动回归；当前活动自动测试状态统一为 `NOT RUN`。

## 当前提交门槛

```powershell
hvigor assembleHap
powershell -ExecutionPolicy Bypass -File scripts/NoWebOutsideLogin.ps1
powershell -ExecutionPolicy Bypass -File scripts/CheckBottomTabVisualLock.ps1
git diff --check
```

其中：

- `assembleHap` 证明当前源码和资源能完整编译；
- `NoWebOutsideLogin` 防止 ArkWeb 扩散到官方登录以外的页面；
- `CheckBottomTabVisualLock` 防止已冻结底栏视觉被无关修改；
- `git diff --check` 阻止空白错误和冲突标记进入仓库。

## 设备验收

涉及 UI、导航、登录、网络或状态持久化的变化还必须：

1. 覆盖安装最新 signed HAP；
2. 启动目标 Ability；
3. 对修改涉及的页面逐一操作；
4. 抓取新截图与 `dumpLayout`，不能复用旧图冒充本轮证据；
5. 检查进程日志中的 Fatal、`UI_FALLBACK`、Cookie 值和意外 HTTP POST；
6. 结束时恢复用户约定的页面与主题状态。

普通业务页面必须满足 Web 节点 0。官方登录页关闭后，应先移除 ArkWeb，再读取必要 Cookie 并刷新；关闭后的普通页面仍应恢复 Web 节点 0。

## 视觉验收

- 不能只检查逻辑尺寸；必须检查截图中的实际可见边界。
- 对齐判断以文字和图标的光学中心为准，同时记录几何中心避免主观漂移。
- 深色模式重点检查白边亮度、选中蓝可读性和玻璃下方内容是否抢读。
- 设置预览重点检查状态圆点是否被裁剪，以及勾选是否在点击当帧移动。
- 底栏修改必须检查四枚图标的相对比例、基线、首页门洞横梁和连续拖动指示器。

## 安全日志硬门槛

- Cookie 值泄露：0
- `UI_FALLBACK`：0
- Fatal：0
- 自动化真实 POST：0
- 普通业务页 Web 节点：0

任一项不满足即为 `FAIL`，不能用“构建成功”覆盖。

## 状态口径

- 只有当命令或设备步骤在本轮真实执行并留下结果，才写 `PASS`。
- 设备离线、权限不足、测试源码不存在或步骤未执行一律写 `NOT RUN`，不推断通过。
- 模拟器与真机分别记录；API 24 模拟器通过不得表述为 API 26 真机通过。
- P0 / P0-B 的历史证据见 `p0-report.md`，当前里程碑状态见 `project-status.md`。

## 未来重新引入自动测试

如维护者决定恢复自动化回归：

- 纯逻辑与协议测试放入 `entry/src/test/`；
- 设备集成测试放入 `entry/src/ohosTest/`；
- mock 配置放入 `entry/src/mock/`；
- 同步恢复 Hypium / Hamock 依赖和 `ohosTest` target；
- 新结果从 `NOT RUN` 开始记录，不能继承删除前的 PASS。
