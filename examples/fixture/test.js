// 确定性检查：node test.js，以退出码判定。
const assert = require('node:assert');
const fav = require('./favorites.js');

(async () => {
  // 1. 正常收藏与取消
  await fav.favorite('p1', 'u1');
  assert.equal((await fav.count('p1')).count, 1);
  await fav.unfavorite('p1', 'u1');
  assert.equal((await fav.count('p1')).count, 0);

  // 2. 取消一个不存在的收藏，不应报成功
  const r = await fav.unfavorite('p1', 'u1'); // 上一行已取消，再取消应无行可删
  assert.equal(r.success, false, '未删除任何行却返回了 success:true');

  // 3. 计数不能漂移为负
  assert.equal((await fav.count('p1')).count, 0, '重复取消后计数漂移');

  // 4. 驱动故障时，读取应报告失败而不是空列表
  fav.setDriverBroken(true);
  const res = await fav.listFavorites('u1');
  assert.equal(res.ok, false, '读取失败被当成空结果');
  fav.setDriverBroken(false);

  console.log('all checks passed');
})().catch((err) => {
  console.error('FAILED: ' + err.message);
  process.exit(1);
});
