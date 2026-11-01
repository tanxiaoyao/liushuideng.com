# 木子点灯 · 发文工作流

> 站点：https://liushuideng.com/（Astro + fuwari，部署于 GitHub Pages）
> 源码：`main` 分支 ｜ 产物：`gh-pages` 分支

## 一、日常发文（3 步）

### 第 1 步：写文章
在 `src/content/posts/` 新建 `拼音或英文-slug.md`：

```markdown
---
title: 文章标题
published: 2026-11-02
description: 一两句话摘要（列表页显示）
image: ""            # 封面图 URL（可留空）
tags: [标签1, 标签2]
category: ""
draft: false         # true = 不发布
---

正文 Markdown……图片用图床外链（https://image.liushuideng.com/...）
```

### 第 2 步：发布到博客
```bash
./deploy.sh
```
自动完成：构建 → 推送源码（main）→ 推送产物（gh-pages）→ GitHub Pages 自动更新（1~5 分钟生效）。

### 第 3 步：同步到内容平台（可选）
```bash
wechatsync sync src/content/posts/你的文章.md -t "文章标题" -p zhihu,csdn,cnblogs,juejin,bilibili
```
- 结果是各平台**草稿**，去各平台检查后手动点发布
- 按内容类型选平台：原理/教学 → 知乎首发；工具/踩坑 → CSDN 首发
- ⚠️ 发之前确认该平台没有发过同一篇（草稿箱搜索标题）

## 二、前置条件（一次性配置，均已配好）

| 项 | 状态 |
|---|---|
| git 推送凭据 | ✅ token 已存 `~/.git-credentials`（过期后去 GitHub 重新生成并 `git remote set-url`） |
| Chrome + 文章同步助手扩展 | ✅ 装在本机 Chrome |
| 扩展 ↔ CLI 的 Token | ✅ 两边一致（CLI 端是环境变量 `WECHATSYNC_TOKEN`） |

## 三、Wechatsync 使用要点（踩过的坑）

1. **扩展会休眠**（MV3 机制）：启动 CLI 前先点一下 Chrome 工具栏的扩展图标唤醒
2. **顺序很重要**：先启动 `wechatsync sync`（它占住 9527 端口）→ 再点扩展图标唤醒 → 扩展会主动连上来。反过来先唤醒后启动经常连不上
3. **端口被占**：报"已有实例正在运行"→ `fuser -k 9527/tcp 9528/tcp` 清掉残留进程
4. **一次同步一个 CLI 进程**：同步完确认进程退出，再发下一篇
5. 博客园登录过期：重新登录 https://i.cnblogs.com 后重发

## 四、平台发布状态记录（2026-11-02 迁移时点）

| 文章 | 知乎 | CSDN | 博客园 | 掘金 | B站 |
|---|---|---|---|---|---|
| 多层最短路 | ✅草稿 | ✅草稿 | ⚠️未发(登录过期) | ✅草稿 | ✅草稿 |
| 常用绘图工具 | ✅草稿 | ❓不确定 | ✅已发(2023) | ✅草稿 | ✅草稿 |
| 其余 26 篇 | ✅已发(2023) | ✅已发(2023) | 大部分已发 | — | — |

> 以后每发一篇新文章，在这里或自己的记录里打勾，防止重复。

## 五、站点结构备忘

- **博客**：`tanxiaoyao/liushuideng.com` 仓库 → GitHub Pages（`gh-pages` 分支，强制 HTTPS）→ 域名 `liushuideng.com`
- **图床**：`tanxiaoyao.github.io` 仓库 → 域名 `image.liushuideng.com`（与博客完全独立，互不影响）
- **DNS（阿里云）**：`@` 和 `www` → GitHub Pages；`image` → 图床（动 DNS 时切勿动 image 记录）
- **旧站存档**：`muzidiandeng.github.io`（Gridea 时代的仓库，账号已无法登录，作为历史存档）
- **Gitee 备份**：`tanxiaoyao/GrideaBackUp`（Gridea 源文件原始备份）
