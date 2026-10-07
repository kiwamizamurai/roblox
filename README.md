# roblox

Roblox ゲームのソースコード置き場。ゲームごとにフォルダを分けて管理する（各フォルダが Rojo プロジェクト）。

| フォルダ | ゲーム | 内容 |
|---|---|---|
| [smash-fighter](./smash-fighter) | Smash Fighter | スマブラ風の2.5D対戦ゲーム（CPU戦・最大4人） |
| [last-light](./last-light) | Last Light | 灯台の島で30夜を生き延びる協力サバイバル（1人でも可） |
| [inaka-school-tag](./inaka-school-tag) | いなか小学校 おにごっこ | 田舎の小学校で遊ぶ非対称バトルの鬼ごっこ（CPUあり） |

## 新しいゲームを足すとき
1. `<game-name>/` を作り、`default.project.json` と `src/` を置く
2. `<game-name>/README.md` に操作方法と構成を書く
3. この表に1行足す
