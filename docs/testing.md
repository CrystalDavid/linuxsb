# 验证与验收规范

## 当前验证能力

按维护者 2026-08-26 的明确要求，仓库不再保留 `entry/src/test/`、`entry/src/ohosTest/` 与 `entry/src/mock/`。同时移除了 Hypium / Hamock 依赖和 `ohosTest` target。

删除前最后一次完整记录为：单元测试 91 / 91 `PASS`，Pura 90 API 24 模拟器设备测试 13 / 13 `PASS`。这只是历史证据，不能用于证明删除之后的新代码已经自动回归；当前活动自动测试状态统一为 `NOT RUN`。

## 1.1.0 邀请测试新增门槛

| 项目 | 方法 | 当前状态 |
| --- | --- | --- |
| 设置总览第二组 | API 24 模拟器打开设置，检查“投喂开发者 / 反馈”、两行高度、分割线与深浅色 | 浅色可视检查 `PASS`；深色本轮 `NOT RUN` |
| 投喂弹窗 | 点击“投喂开发者”，检查四行名称、金额、一次性说明、关闭按钮与底部安全区 | API 24 模拟器 `PASS` |
| 反馈路由 | 点击“反馈”，确认进入 `topic/17803` 的原生详情且普通页面 Web 节点为 0 | API 24 模拟器 `PASS` |
| 我的交易排版 | 检查发布卡字段顺序为“称号 / 单价 / 状态 / 编号日期”，并检查“交易记录”标题额外 8vp 顶部间距 | API 24 模拟器截图与布局树 `PASS` |
| 华为支付 | AGC 沙盒账号逐档打开系统收银台，覆盖取消、无效商品、成功购买和消耗确认 | `NOT RUN`：尚未配置/确认 AGC 商品与沙盒交易 |
| 邀请测试包 | release/托管签名 `.app`、合法性解析、安装启动 | `NOT RUN`：本地 debug HAP 不替代发布包 |

AGC 只读核对补充：现有 1.0.0 测试包合法性“已达标”，现有测试群组和用户仍可复用；这不证明 1.1.0 已上传或可安装。商品管理列表为空，因此四档 IAP 收银台端到端验收仍为 `NOT RUN`。

支付验收不得使用本地伪造成功。四档商品需在 AGC 与源码商品 ID 一一对应，收银台显示金额必须分别为 CNY 1.00、5.00、9.90、50.00；点击取消后应用显示取消，不应显示成功；成功后不得产生自动续费或论坛权益。

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

## 性能验收

涉及启动、首页、主题详情、列表或缓存的变化，还必须按 [performance.md](performance.md) 的同口径步骤执行：5 次冷启动、未缓存/已缓存主题、首页和受影响列表各 5 轮双向惯性滑动、RenderService 三档卡顿帧，以及 HiSmartPerf CPU/PSS 采样。

模拟器上 SmartPerf `fps=0` 是无效值；不得写成 0 FPS，也不得用它代替 RenderService `hitchs`。API 24 模拟器通过只能证明当前 60Hz 回归没有复现问题，90/120Hz 与真实温控表现仍需 API 26 真机验证。

## 设备验收

涉及 UI、导航、登录、网络或状态持久化的变化还必须：

1. 覆盖安装最新 signed HAP；
2. 启动目标 Ability；
3. 对修改涉及的页面逐一操作；
4. 抓取新截图与 `dumpLayout`，不能复用旧图冒充本轮证据；
5. 检查进程日志中的 Fatal、`UI_FALLBACK`、Cookie 值和意外 HTTP POST；
6. 结束时恢复用户约定的页面与主题状态。

普通业务页面必须满足 Web 节点 0。官方登录页关闭后，应先移除 ArkWeb，再读取必要 Cookie 并刷新；关闭后的普通页面仍应恢复 Web 节点 0。

### Pura 90 双系统矩阵

涉及 SDK、沉浸材质、共享玻璃或底栏的变化，当前先用同一份 target 24 / compatible 23 signed HAP 分别验证：

1. Pura 90 API 24：确认系统版本，覆盖安装，启动 `EntryAbility`，确认进程存活；分别检查浅色/深色的唯一通透风格，证明只有一层 `backgroundEffect`、底层内容仍可辨，且没有白膜、双层模糊或崩溃。
2. Pura 90 API 26：安装同一 target 24 HAP，确认启动、深浅色与 HDS 能力日志；该步骤验证向上运行兼容和 HDS 能力探测，不能据此宣称普通组件命中 API 26 `ImmersiveMaterial`。
3. 若另行建立 target 26 产品，必须再生成独立 signed HAP：API 24 验证 compatible 23 回退，API 26 验证原生 `systemMaterial` / `ImmersiveMaterial` 命中，且同一节点没有残留 `backgroundEffect`。
4. 两台模拟器分别记录 `PASS`、`FAIL` 或 `NOT RUN`。只启动了其中一台时，禁止概括成“API 23–26 已验证”。
5. API 26 模拟器只验证兼容与功能分支，不替代 API 26 真机的动态刷新率、温控、功耗和最终光学观感。

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
- API 24 模拟器、API 26 模拟器与 API 26 真机分别记录；任一模拟器通过不得表述为另一系统或真机通过。
- P0 / P0-B 的历史证据见 `p0-report.md`，当前里程碑状态见 `project-status.md`。

## 未来重新引入自动测试

如维护者决定恢复自动化回归：

- 纯逻辑与协议测试放入 `entry/src/test/`；
- 设备集成测试放入 `entry/src/ohosTest/`；
- mock 配置放入 `entry/src/mock/`；
- 同步恢复 Hypium / Hamock 依赖和 `ohosTest` target；
- 新结果从 `NOT RUN` 开始记录，不能继承删除前的 PASS。
