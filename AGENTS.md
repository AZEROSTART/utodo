# 项目约定（utodo）

> 个人偏好见 `~/AGENTS.md`；这里只写这个项目特有的。

## 提交与推送

- 每完成一项工作（测试/验证通过）：先提交，随即 `git push`，不用等用户提醒
- 推送目标：当前分支推当前分支；要合主线时先 `git merge --ff-only` 进 `main` 再推 `main`
- 远端是 `origin` = `https://github.com/AZEROSTART/utodo.git`（公开仓库）
- 不 force push，不改写已推送的历史
