# 性能架构与验收

## 目标与不可变边界

性能优化不得通过删减业务内容、降低图片质量、改变字号/间距/颜色、替换冻结底栏或隐藏加载错误来“制造”更快的观感。正式业务链路保持 HarmonyOS 原生实现：ArkUI / UI Design Kit 负责界面，RCP 负责网络，TaskPool 负责 BBS1 解码；ArkWeb 仍只允许用于用户主动打开的官方登录页。

60Hz 设备每帧预算为 16.67ms。模拟器只能用于回归和相对比较；90/120Hz 真机、温控降频、真实网络与 GPU 合成表现必须在目标手机上重新采样。

## 当前实现

### 首页首屏

- `HomeFeedDiskCache` 使用 HarmonyOS Preferences 保存匿名首页第一页快照。
- 只缓存公开匿名 `Home` scope，不保存 Cookie、登录态、搜索、个人 feed 或写入数据。
- 快照最长保留 12 小时；命中后先呈现，再始终发起实时刷新，不把旧数据伪装成最新数据。
- 成功响应延迟 300ms 写盘，避开首内容帧。
- 网络失败时保留已呈现快照，并继续暴露真实错误诊断。

### 长列表

- 首页和分页主题列表统一使用 ArkUI `LazyForEach + IDataSource`，不再由板块/搜索/个人页的全量 `ForEach` 一次创建全部已加载主题节点。
- 分页新增主题通过 `onDataAdd` 精准通知，重载才调用 `onDataReloaded`。
- 列表保留 6 个离屏缓存节点；主题行继续作为共享组件封装点击回调与两种固定排版，避免为复用装饰器引入函数参数和嵌套组件复用冲突。
- 首页滚动开始时取消预取，停止后从当前可见位置最多预取 3 个主题，延迟 900ms、最多 2 个并发 worker，避免预取和手势争抢。

### 主题详情与网络热路径

- 点击后立即 push 原生目的地并显示骨架；正文 GET、TaskPool 解码、映射和首内容帧都有 `M2R1TopicOpen` 时间点。
- 主题详情按匿名/登录态分区使用有限内存缓存并合并在途请求。
- 产品 GET 不再同步计算完整响应 SHA-256；响应指纹只保留在显式诊断探针和写请求审计中。
- HTML 解码保持单遍状态机并在 TaskPool 执行，主线程不构建 DOM/CSSOM。

## 2026-08-26 实测

环境：Pura 90 API 24 模拟器，OpenHarmony 6.1.1.125，1320×2856，60Hz。所有前后数据使用同一台虚拟设备和同一语义节点/trace 口径。

| 场景 | 优化前 | 优化后 | 结论 |
| --- | ---: | ---: | --- |
| 冷启动到 `home-first-topic` | 2726 / 3590 / 1892ms，平均 2736ms | 1171 / 1059 / 1232 / 1102 / 1090ms，平均 1131ms | 同口径平均缩短约 58.7%；`dumpLayout` 探测本身约有 1 秒量级地板 |
| 未缓存主题首内容 | 492–588ms，平均约 539ms | 470 / 480 / 475 / 497ms，另有一次网络离群 1175ms；中位 480ms | 中位缩短约 10.9%，但服务端/网络仍是主导变量，不能承诺每次都更快 |
| 已预取主题首内容 | 既有历史热缓存中位 35ms | 49 / 53 / 77ms | 仍明显低于 250ms 目标；不同主题内容规模不能直接作绝对前后比较 |
| 首页双向惯性滑动 5 轮 | >16.67 / 33 / 66ms 均为 0 | >16.67 / 33 / 66ms 均为 0 | 未复现拖动或松手跳帧 |
| 板块懒列表双向惯性滑动 5 轮 | 未单独记录 | >16.67 / 33 / 66ms 均为 0 | `LazyForEach + IDataSource` 版本未出现卡顿帧 |
| SmartPerf 滑动采样 | PSS 约 120–135MiB | PSS 124394KiB（约 121.5MiB），ArkTS Heap PSS 33914KiB（约 33.1MiB），CPU 峰值约 8.1% | 内存处于原采样区间，没有观察到缓存引入的持续增长 |

SmartPerf 在该模拟器上把 `fps` 固定返回 0，属于无效采样，不能写成“0 FPS”。帧异常以 RenderService `hitchs` 为准。

### Mate 80 Pro Max 真机复验

环境：HUAWEI Mate 80 Pro Max（`SGT-AL10`），HarmonyOS `7.0.0.102`，API 26，1320×2848，设备支持 30～120Hz 动态刷新；测试期间首页滑动实际进入 90Hz。2026-08-26 将最新签名 HAP 覆盖安装到真机后，普通首页 `Web` 节点为 0，应用可正常启动和浏览。

| 场景 | 真机结果 | 结论 |
| --- | ---: | --- |
| 首页双向惯性滑动 5 轮 | RenderService `>16.67 / 33 / 66ms` 均为 0 | 未复现拖动或松手跳帧；采样期间实际刷新率为 90Hz |
| 未缓存主题 16379 | 路由 0ms、目标页出现 10ms、骨架 25ms、网络正文完成 340ms、TaskPool 解码 28ms、首文本 396ms | `cacheHit=false`，一次网络请求；首图约 2297ms，图片仍受远端资源影响 |
| 已缓存主题 16277 | 目标页出现 7ms、首文本 28ms | `cacheHit=true`，首内容前网络请求数为 0，随后后台实时刷新 |
| 冷进程启动 5 次 | 1958 / 2071 / 2022 / 1867 / 2107ms，平均 2005ms | 通过无线 HDC 轮询 `dumpLayout` 检测，包含明显工具轮询地板，不可与模拟器绝对值直接比较 |

测试期间若手机前台被用户切换到其他应用，该轮数据立即作废，不纳入上表。真机 SmartPerf 的 FPS/PSS 联合长采样仍需在手机保持解锁、前台不被抢占的条件下补做；不能把后台进程的 `fps=0` 或其他应用的滑动结果归到本应用。

## 华为工具复验

### HiSmartPerf Device / SP_daemon

```powershell
hdc shell /bin/SP_daemon -N 12 -PKG com.david.shaobingcommunity -c -r -f
```

记录 CPU、PSS、ArkTS heap 和刷新率。模拟器 `fps=0` 时必须标记无效，不得据此计算平均帧率。工具说明见 [HiSmartPerf Device 指南](https://developer.huawei.com/consumer/cn/doc/doccenter-testing/smartperf-guidelines)。

### RenderService 卡顿帧

```powershell
hdc shell "hidumper -s RenderService -a 'shaobingcommunity0 fpsClear'"
hdc shell uitest uiInput fling 660 2250 660 500 12000 60
hdc shell "hidumper -s RenderService -a 'shaobingcommunity0 hitchs'"
```

每个方向单独清零，手势结束后等待惯性动画完全停止，再读取 >16.67 / 33 / 66ms 三档。分析方法参考华为的[滑动卡顿分析说明](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-performance-53)。

### DevEco Studio Profiler / hitrace

需要定位主线程、RenderService、TaskPool 或网络阶段时抓取 hitrace，并用 DevEco Studio Profiler 打开；不要只依据肉眼动画判断。Profiler 能力说明见 [DevEco Studio Profiler](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-insight-description)。

### CodeLinter

仓库 `code-linter.json5` 使用 `plugin:@performance/recommended`。本轮删除了含循环状态读取告警但已无引用的旧抽屉实现，并依据建议把高频主题列表改为懒创建节点。最终 CodeLinter 退出码为 0、错误 0、警告 13；13 条全部是 `@performance/avoid-overusing-custom-component-check` 的“优先 Builder”通用建议，没有剩余的列表、循环或同步计算专项告警。只有在组件不需要生命周期/响应状态、点击回调且不会破坏共享视觉封装时才转换，不能为了清零警告复制 UI；设置选择标记曾按建议试改 Builder，但设备复验发现勾选不再随状态移动，因此已回退。规则入口见 [CodeLinter 推荐规则](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-coderlinter-recommended-rules)。

## 闪电图标结论

- 自适应前景为 1024×1024；打包后 `foreground_lightning.png` 为 88409 bytes。
- 启动图标为 144×144、40098 bytes，低于 256×256 的启动资源检查阈值。
- 模拟器桌面截图中闪电、圆角蓝底和应用名均完整，视觉中心没有明显偏移；启动图标画布中心为 71.5/71.5。
- 当前没有图标解码或包体热点，不做重采样、重绘或几何移动，避免在没有真机桌面证据时改变品牌基线。

## 每次性能改动的最低验收

1. 构建并覆盖安装最新 HAP；
2. 冷启动至少 5 次，记录首个真实主题节点；
3. 未缓存与已缓存主题分别采样，分开报告网络和本地阶段；
4. 首页及受影响分页列表各做至少 5 轮双向惯性滑动；
5. 记录 RenderService 三档卡顿帧和 SmartPerf CPU/PSS；
6. 抓取新截图与 `dumpLayout`，确认普通页 Web 节点 0；
7. 运行视觉锁、原生边界、构建和 `git diff --check`；
8. API 26 真实设备重做 90/120Hz、温控和弱网测试，不能继承模拟器 PASS。
