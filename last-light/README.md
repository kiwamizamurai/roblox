# Last Light

灯台の島で、ランプを守りながら30夜を生き延びる協力サバイバル（Roblox）。1人でも遊べる。

## 遊び方
- 昼：木材とスクラップを拾う（触れるだけ）。灯台のそばの木箱でランプに燃料（木材）を入れる
- 夜：霧の怪物が来る。光の中では弱って遅くなる。攻撃で倒すとスクラップを落とすことがある
- 作業台：スクラップで武器を強化（最大Lv5）
- ランプの燃料が切れたら敗北。30夜を生き延びたら勝利。どちらも少し待つと再戦
- 操作：WASD 移動 / Space ジャンプ / F・クリック 攻撃 / E 長押し 木箱・作業台（スマホは画面の「攻撃」ボタンと標準の移動）

## 構成
- `src/shared/Config.luau` 夜数・時間・燃料・怪物・武器の設定（バランス調整はここ）
- `src/server/Match.server.luau` 昼夜進行・勝敗・再戦
- `src/server/State.luau` 燃料・夜数・フェーズと通信（Remote）
- `src/server/World.luau` 島・灯台・燃料箱・作業台
- `src/server/Resources.luau` 木材・スクラップ
- `src/server/Monsters.luau` 怪物のAIとプレイヤーの攻撃
- `src/server/Save.luau` ベストの夜数の保存（DataStore。使えなくても続行）
- `src/client/Hud.client.luau` HUD・攻撃入力・スマホの攻撃ボタン

## ビルド
`rojo build default.project.json -o LastLight.rbxl`

## テスト用の仕掛け
- `workspace` の属性 `TimeScale` に 10 を入れると、昼夜が10倍速になる（動作確認用）
- `Config.Event` に `{ MonsterColor = ... }` を入れると、季節イベント用に怪物の色を変えられる

## 未確認・未実装
- 複数人の同時プレイ、実機のスマホ、DataStore の永続（セッションをまたいだ保存）は未確認
- バッジ、課金、季節イベント本体は未実装（バッジは管理画面での作成が必要）
