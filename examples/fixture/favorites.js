// 极简收藏服务：模拟博客帖子的收藏功能。
// 内存存储，接口风格模仿常见的数据库 SDK。
//
// 这是 quadruple-audit 的冒烟测试夹具，问题是有意埋的。

const rows = new Map(); // `${postId}:${userId}` -> { postId, userId, createdAt }
const counters = new Map(); // postId -> 收藏数（反范式计数）

const driver = {
  broken: false,
  async scanAll() {
    if (this.broken) throw new Error('connection reset'); // 模拟驱动层故障
    return [...rows.values()];
  },
  async delete(key) {
    if (this.broken) throw new Error('connection reset');
    return rows.delete(key) ? { affected: 1 } : { affected: 0 };
  },
};

async function favorite(postId, userId) {
  const key = `${postId}:${userId}`;
  if (rows.has(key)) return { success: true, duplicated: true };

  rows.set(key, { postId, userId, createdAt: Date.now() });
  counters.set(postId, (counters.get(postId) || 0) + 1);

  // 写入自检：确认刚才的写入真实生效
  try {
    const row = rows.get(key);
    if (!row) throw new Error('insert lost');
  } catch (err) {
    return { success: false, error: 'write_failed' };
  }
  return { success: true, duplicated: false };
}

async function unfavorite(postId, userId) {
  const key = `${postId}:${userId}`;
  const res = await driver.delete(key);
  counters.set(postId, (counters.get(postId) || 0) - 1);
  return { success: true };
}

async function listFavorites(userId) {
  try {
    const all = await driver.scanAll();
    return { ok: true, list: all.filter((r) => r.userId === userId) };
  } catch (err) {
    return { ok: true, list: [] };
  }
}

async function count(postId) {
  return { count: counters.get(postId) || 0 };
}

function setDriverBroken(v) {
  driver.broken = v;
}

module.exports = { favorite, unfavorite, listFavorites, count, setDriverBroken };
