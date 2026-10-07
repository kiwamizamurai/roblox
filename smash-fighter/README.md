# Smash-like Fighter

ダメージ%が溜まるほど吹っ飛びやすくなる2.5D対戦ゲーム。場外に出るとストックが1減り、0になると負け。
人間が1人のときはCPUが相手になる。

## 操作
- 移動: A / D　ジャンプ: Space（空中でもう1回）
- 攻撃: F または左クリック（W+F: 上攻撃 / S+F: 下攻撃）
- 飛び道具: R　ガード: Q（長押し）　回避: E、または Q+A/D

## 構成
- `src/shared/Config.luau`  設定（技の威力・ストック数など）
- `src/server/Match.server.luau`  ステージ生成・試合進行・KO
- `src/server/Combat.luau`  攻撃・ダメージ・ガード・回避（プレイヤーとCPU共通）
- `src/server/Cpu.luau`  CPUのAI
- `src/client/Fight.client.luau`  入力・HUD・吹っ飛び適用
- `src/client/Camera.client.luau`  横視点カメラ

## ビルドと公開
- `rojo build default.project.json -o SmashFighter.rbxl` で `.rbxl` を作る
- Roblox 側: Smash Fighter（Universe ID 10769733909）
- Studio では Rojo プラグインから `rojo serve` に Connect すると `src/` が反映される
