# Codex Instructions — 烧饼社区 P0-B 已通过基线

## 最高优先级

1. 开始工作前完整阅读 `PROJECT_BASELINE.md` 和 `P0_REPORT.md`。
2. **P0-B 已于 2026-08-23 在 API 26 真机通过。** 当前没有获准继续开发正式页面；后续工作必须等待用户给出新的明确任务。
3. P0 已在 API 26 真机验证 RCP、轻量解码、TaskPool、临时 ArkWeb 登录、Cookie 内存桥接和登录后 RCP；不得推翻该架构，不得改为常驻隐藏 ArkWeb。
4. 已验证结论：匿名 Topic 605 由服务端登录门控而只有主楼；登录后同一 `/topic/605` GET 含 5 条回复。不得重新猜测 AJAX、额外分页接口或 POST 路由，除非真实版本或结构证据发生变化。
5. 不复制 ArkDO 的源码、注释、资源、图标、截图、签名或品牌资产。
6. 不发送 POST，不发帖、回复、编辑或删除；不绕过验证码、WAF、权限或限流。
7. 不使用 DOMParser、CSS 选择器、整页正则或 ArkWeb 业务网络桥。
8. 不打印、提交、覆盖或记录 Cookie 值、签名密码、证书路径、Profile 路径、账号、通知或私密正文。

## 已冻结的 P0 基线

- `main` 的 P0 通过提交与标签不得重写。
- P0-1 至 P0-7 为 PASS；P0-8 真实写操作为 NOT RUN。
- `build-profile.json5` 的提交版本必须保持脱敏；本机签名版由用户本地保留，不得暂存或提交。
- `artifacts/`、日志、截图、匿名网页快照和签名文件不得进入公开提交。
- 当前开发分支是 `p0b/reply-source`。

## P0-B 已冻结结论

只回答一个问题：

> PASS 类型 1（同页解码）：登录后 `/topic/605` HTML 直接包含 5 条回复；不需要第二次网络请求。

真机证据为声明 5、实际 5、回复 ID 唯一、主楼未重复、楼层 1～5、最小字段完整、TaskPool 正常、`UI_FALLBACK = 0`、Cookie 泄露匹配 0。P0-B 通过不等于本轮获准开发完整首页、正式主题详情、个人中心或正式 UI。

## 强制调查顺序

1. **响应指纹**：分别记录匿名与登录后 Topic 605 的 status、finalUrl、contentType、contentEncoding、byteLength、SHA-256、BBS1 版本和请求耗时。
2. **结构探针**：新增诊断专用 `TopicStructureProbe`，扫描现有 HTML Token 流，只输出数量和布尔结构信号，不输出正文、用户名、Cookie 或完整 HTML。
3. **匿名快照**：只允许将一次匿名 Topic 605 HTML 保存到 `artifacts/p0b/`；不得保存登录后完整页面、请求头或 Cookie。
4. **最小 fixture**：从匿名快照提炼使用虚构作者和正文的最小结构测试，不把真实社区页面或真实帖子正文提交进仓库。
5. **对应源码**：按实际检测到的 BBS1 版本查找对应源码，核对主题渲染、回复循环、回复 ID、楼层、分页、插件 Hook 和 JavaScript 网络请求。
6. **路由判断**：只能从真实 HTML 或对应源码得到分页/回复路由；不得猜测 `?p=`、`?page=`、`/replies` 等地址。

## TopicStructureProbe 最小统计

- topic 链接数量；
- user 链接数量；
- reply 链接数量；
- `#1`、`#2` 等楼层锚点数量；
- `post-` / `reply-` ID 前缀数量；
- `data-floor` 等候选属性数量；
- `replyid` 参数数量；
- 候选回复容器数量；
- 分页链接数量；
- 页面声明回复数。

探针必须保持单遍或有限回溯，不建立 DOM，不保存正文块。

## 三个允许的实现分支

### A：回复已在同一 HTML

- 修复 `TopicProbeDecoder` 或新增 `ReplyDecoder`；
- 从同一响应得到主楼和回复；
- 不增加第二次网络请求。

### B：页面明确提供额外只读 GET 路由

- 实现 `ReplyPageRequestBuilder` 和 `ReplyPageDecoder`；
- 只使用 RCP GET；
- 合并时保持回复 ID 唯一、楼层合理、分页可确定。

### C：只能通过 POST 或状态不明的动态请求获得

- 不执行该请求；
- 标记 `REPLY_SOURCE_REQUIRES_NON_GET`；
- P0-B 状态为 BLOCKED，并在 `P0_REPORT.md` 说明需要用户另行授权或站长支持。

## 测试要求

将当前 7 个本地测试扩展到至少 12 个，必须覆盖：

- 回复容器正常解码；
- 主楼与回复区分；
- 实际楼层锚点变体；
- 重复链接去重；
- 声明数匹配与不匹配；
- 分页链接提取；
- 插件块不破坏普通回复；
- HTML 实体；
- 结构变化返回 `REPLY_STRUCTURE_MISMATCH`。

验收至少要求：声明 5、实际 5、回复 ID 唯一、楼层 1～5、无重复、无引用误判、TaskPool 正常、`UI_FALLBACK = 0`、Cookie 泄露匹配为 0。

## 构建与真机

1. 运行 `hvigor test`；
2. 运行 `hvigor onDeviceTest`；
3. 构建 signed HAP；
4. 安装到当前真实设备；
5. 最终 P0-B 必须使用真机 RCP 复验；模拟器结果不能替代；
6. 保留 PASS、FAIL、NOT RUN 的严格区分。

## 文档边界

只维护三份文档：

- `AGENTS.md`：当前唯一任务与约束；
- `PROJECT_BASELINE.md`：已验证架构和阶段门；
- `P0_REPORT.md`：在底部追加 P0-B 结果。

不得新建另一套 P0-B 报告、调查说明或成套设计文档。

## 停止条件

出现以下任一情况，停止实现并只更新报告：

- 只能通过 POST 或执行远程 JavaScript 获得回复；
- 结构或路由在同一版本下随机变化，无法形成稳定契约；
- 需要绕过站点安全机制；
- 必须用 ArkWeb 作为普通业务桥；
- 无法在不泄露账号、Cookie 或私密内容的情况下验证。

## 完成标准

P0-B 只有两种 PASS：

1. **同页解码 PASS**：Topic 605 HTTP 200，声明 5、实际 5，回复 ID 唯一，楼层 1～5，TaskPool 正常；
2. **额外 GET PASS**：从真实页面提取稳定 GET 路由，RCP GET 成功，回复数和分页契约明确。

其他结果必须明确写成 FAIL、NOT RUN 或 BLOCKED，不得用猜测填补证据。

当前实际结果是第 1 种：**同页解码 PASS**。真实写操作保持 **NOT RUN**；发帖、回复、编辑和删除继续固定禁用。
