# 样例报告

这是一次真实审查的脱敏输出。目标是某中型 React + Supabase 项目的「收藏」功能（社区帖子收藏、软件收藏、合集）。

- **输入**：`/quadruple-audit 检查收藏功能是否存在真实问题，会导致用户可见的错误或数据不一致`
- **配置**：3 个视角 × 3 个分区 = 9 个审查单元，`risk: high`
- **结果**：51 条候选 → 30 条低严重度按复现分级标「未复现」、21 条进入独立复现 → 10 条确认、11 条存疑、0 条排除
- **消耗**：约 6000 万 token

项目名、文件名已替换为占位符，问题本身保持原样。

---

# 四轮审查：收藏功能是否存在真实问题，会导致用户可见的错误或数据不一致

**结论：NEEDS CHANGES**

存在真实问题：收藏计数在历史上被双倍累加且从未回填，是持久性数据错误；另有个人中心角标与列表口径不一致、合集计数并发丢更新、失败态无限重试、部分写入不可重试等用户可见缺陷。确定性检查未跑成（项目无 `node_modules`），线上库实际状态与表级权限也无法核查，结论基于 schema 快照与迁移叠加。

## 确认的问题

| # | 问题 | 位置 | 严重度 | 修复方向 |
|---|---|---|---|---|
| 1 | 历史上两套计数触发器同时生效，每次收藏被加两次；修复时只删了多余触发器，全仓没有任何回填，偏差永久保留 | `migrations/20260813000100:387` | high | 写一次性回填把计数重算为 `count(*)`，删除孤儿函数，加回归检查防重复挂载 |
| 2 | 批量查询失败返回空对象，调用方生成新引用，effect 依赖自身写入的 state，失败态下无上限重试 | `services/favorite/batch.ts:62`<br>`components/UltraFastCommunity.tsx:138` | medium | 失败态短路并退避，保持稳定引用；把 unknown 传给按钮而不是 `?? false` |
| 3 | 读取方法在 catch 里返回空数组，查询失败被渲染成「暂无收藏」，组件的加载失败提示是死代码 | `services/favorite/index.ts:330` | medium | 错误上抛或返回可判别结果，UI 渲染错误态而非空态 |
| 4 | 状态检查把「未登录/查询失败/确实未收藏」压成同一个 false，配合 23505 只报错不回读，挂载期内无法自愈 | `services/favorite/index.ts:115` | medium | 返回三态，写入失败后回读权威状态，effect 依赖 `user.id` 并加请求序号 |
| 5 | 角标用 `count(*)` 不过滤帖子状态，列表过滤；偏差方向固定为角标 ≥ 列表 | `migrations/20260813000100:506`<br>`services/favorite/index.ts:284` | medium | 两处用同一过滤条件，或统一改成一致的视图/函数 |
| 6 | 合集计数重算在并发下丢失更新（真实 PG 实例实测：存储 2 / 实际 3） | `migrations/20260813000100:299` | medium | 改原子增量或加锁，补并发回归测试 |
| 7 | 批量保存任一失败即 throw，已写入不回滚；失败后基线不刷新，重试时已成功项命中「已在合集中」再次抛错 | `components/AddToCollectionDialog.tsx:105` | medium | 单事务 RPC 或逐项提交收集结果，已存在视为幂等成功 |
| 8 | 软件计数函数缺 `SECURITY DEFINER`，普通用户收藏时计数器更新命中 0 行 | `schema-snapshot.sql:22213` | low | 补 `SECURITY DEFINER` + 固定 `search_path`，并补 ACL 断言 |
| 9 | 取消收藏不校验删除行数，0 行也返回成功 | `services/favorite/index.ts:99` | low | 用 `.select()` 取受影响行数，区分幂等成功与授权失败 |
| 10 | 按钮计数只在挂载时取初始值，无同步 effect | `components/FavoriteButton.tsx:37` | low | 写入返回权威计数并回写 |

### 证据

1. baseline 同时挂了 `trigger_update_post_favorites_count` 与 `update_favorites_count_trigger`，两个函数都是 `+1`；迁移注释自认 "incremented twice"，随后只 `DROP TRIGGER`；全仓检索 `SET favorites_count = (` 零命中。
2. 依赖数组为 `[allPosts, favoriteStatusMap, isAuthenticated, userId]`；`missingIds.length === 0` 有短路，但失败时 map 永远拿不到 key，短路永不命中。
3. `} catch (error) { logger.error(...); return []; }`；组件的 `catch` 只在 service 抛异常时可达，而 service 从不抛。
4. `catch` 里 `return false`；`if (error.code === '23505') return { success: false, ... }`，无回读。
5. `(SELECT count(*) FROM user_post_favorites WHERE user_id = $1)` 对比 `.eq('forum_posts.status','published').is('deleted_at', null)`。
6. 触发器用「快照里 `count(*)` 后覆盖」且无行锁；两事务各自用旧快照算出旧值，后提交者覆盖先提交者。
7. `for (const id of toAdd) { if (!result.success) throw ... }`；`toRemove` 循环排在其后，抛错即全部跳过。
8. 函数头只有 `LANGUAGE plpgsql SET search_path TO ''`；`software` 的 UPDATE 策略只有 `is_admin()`。
9. `.delete().eq(...)` 后只 `if (error) throw`，无 `.select()`。
10. `useState(initialCount)` 无对应同步 effect；写入接口只返回 `{ success: true }`。

## 系统性缺陷（同一类毛病）

下面几条要分别动手修，但属于同一个设计缺陷模式。只修其中一条，等于没修。

- **读取失败被当成空结果**：#3 —— 合集侧的读取方法存在同一模式
- **写操作不检查实际结果**：#9 —— 合集更新/删除存在同一模式

## 存疑（需人工确认）

1. `schema-snapshot.sql:30890` — 存在 `FOR SELECT USING (true)` 的策略且从未删除，任何访客可读全部用户的收藏关系。**为什么判断不了**：需要核验线上策略与 PostgREST 暴露面，无线上库。
2. `scripts/check-community-deletion-acl.sql:277` — ACL 断言漏了软件计数函数，这正是 #8 长期未被发现的机制原因。**为什么判断不了**：属检测覆盖缺口，需确认脚本实际执行范围。
3. `schema-snapshot.sql:22032` — `update_post_collections_updated_at()` 有定义但从未挂载触发器，条目增删不更新合集时间。**为什么判断不了**：需核实所有写路径是否都显式赋值。
4. `migrations/20260813000100:27` — 合集表整表授予 UPDATE，所有者可任意改写计数列。**为什么判断不了**：快照不含完整表级 ACL。
5. `components/AddToCollectionDialog.tsx:279` — 输入框回车无在途判断，连按可创建同名合集。**为什么判断不了**：需确认合集名唯一约束与 UI 在途状态。
6. `components/FavoriteSoftware.tsx:52` — 取消收藏按钮无 disabled 或在途标志。**为什么判断不了**：重复请求多为幂等删除，实际可见后果需实测。
7. `adminPostService.ts:118` / `userContentService.ts:103` — `favorites_count` 硬编码为 0。**为什么判断不了**：需确认这些视图是否展示该字段。
8. `services/favorite/index.ts:240` — 软件下架后嵌入为 null，渲染成空条目。**为什么判断不了**：需确认 UI 对 null 的处理。
9. `types.ts:21` — `price` 声明必填但 DB 可空，NULL 被 `?? 0` 当成「免费」。**为什么判断不了**：需核对是否存在 NULL 数据。
10. `NotificationSettings.tsx:195` — 文案承诺「点赞或分享」通知，但分享/收藏通知不存在。**为什么判断不了**：属产品口径。
11. `schema-snapshot.sql:31232` — 允许本人 UPDATE 改 `post_id`，但触发器只覆盖 INSERT/DELETE。**为什么判断不了**：需确认是否存在实际更新路径。

## 已排除

没有排除项。（本轮 `refuted` 为 0，翻案复核无事可做。）

## 确定性检查

- `npm run typecheck` → **未能运行**：项目无 `node_modules`，`tsc` 不存在
- `npm test` / `npm run lint` → 同样无法运行

这不是「检查通过」，是「检查没做成」。

## 覆盖账本

### 已查

- 视角：数据一致性（读迁移与 schema 快照）、边界与并发（读组件代码）、契约一致性（对照类型与返回）
- 工作分区：收藏写入与计数、收藏展示与列表、合集与批量操作
- 审查单元：9 个（3 视角 × 3 分区）
- 复现：21 条候选进入独立复现（含空白猎手补查的 10 条），10 条成立、11 条存疑
- 归组：未发现可合并的同根因项
- 未复现：其余 30 条低严重度候选，按「复现分级」直接标注，未派复现者
- 空白猎手额外核查：32 个 Edge Function（零命中收藏相关）、定时任务、账号注销、软删除/恢复/永久删除、通知系统、搜索排序、管理后台、测试覆盖

### 未查 / 无法查

- 未确认线上库实际状态，数据一致性结论基于仓库里的数据库定义文件；实际 schema 若有漂移则未被覆盖
- `software` 表的表级 GRANT/REVOKE（快照不含 ACL），所以 #8 的两种失败形态（静默 0 行 vs 42501 回滚）无法区分
- 所有确定性检查（无 `node_modules`）
- 历史数据中计数翻倍的实际影响行数
- 各单元的详读/跳过清单由审查者自报，流程无法验证「是否真的读过」；能查的只有路径是否存在
