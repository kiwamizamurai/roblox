# いなか小学校 おにごっこ（Countryside School Tag）

日本の田舎の小学校を舞台にした、非対称バトルの鬼ごっこ（Roblox）。鬼1人 vs 子ども。人が少ないときは CPU が入る。

## ルール
- 鬼：子どもに触れて「捕獲」する。スキル：ダッシュ（Q）・鬼の鼻（E）・どーん（R）
- 子ども：お守りを5個集めて校門を開け、外へ脱出する。水風船（F）を鬼に当てると、鬼が止まって遅くなる
- つかまった子どもは体育館の「ろうや」へ。ほかの子が E 長押しで助けられる
- 半数以上が脱出 → 子どもの勝ち／全員つかまる、またはチャイム（6分）→ 鬼の勝ち。少し待つと再戦
- 人間が1人のとき：鬼はCPU、あなたは子ども（CPUの子どもが加わる）

## 操作
| | PC | スマホ |
|---|---|---|
| 移動・ジャンプ | WASD・Space | 標準のスティック・ジャンプ |
| 子ども：ダッシュ / 水風船 | Shift（長押し）/ F | 画面の「ダッシュ」「投げる」 |
| 子ども：お守り・救出・水バケツ | E 長押し（近づくと表示） | 画面に出るボタン |
| 鬼：スキル | Q / E / R | 画面の「突進」「鼻」「どーん」 |

## 構成
- `src/shared/Config.luau` 時間・スタミナ・スキル・水風船など（バランス調整はここ）
- `src/server/Match.server.luau` 役割決定・隠れ時間・追いかけ・勝敗・再戦
- `src/server/State.luau` 状態・登場人物・通信
- `src/server/World.luau` 校舎・体育館・校庭・校門・田んぼ・小屋をコードで生成
- `src/server/Kids.luau` スタミナ・水風船・お守り・救出・脱出
- `src/server/Oni.luau` 捕獲と鬼のスキル
- `src/server/Cpu.luau` / `Nav.luau` CPUの鬼と子ども（PathfindingService）
- `src/server/Props.luau` Toolbox素材の読み込み（今は素材なし。失敗しても続行）
- `src/server/Save.luau` 勝利数の保存（DataStore。使えなくても続行）
- `src/client/Hud.client.luau` / `Controls.client.luau` HUD・入力・スマホボタン

## ビルド
`rojo build default.project.json -o build/InakaSchoolTag.rbxl` → Studio で開く

## テスト用の仕掛け
- `workspace` の属性 `TimeScale` に 10 を入れると、隠れ時間と追いかけ時間が10倍速になる

## 分かっている課題・未確認
- 複数人の同時プレイ、実機のスマホ、モバイルの負荷は未確認
- CPUの鬼が強く、人間が動かないと短時間でCPUの子どもを全員捕まえる（バランス未調整）
- CPUの子どもが開始直後に近くの砂場のお守りを取る（スポーン位置が近い）
- 画面左上の Roblox のチャット欄と、操作説明の表示が重なる
- Toolbox素材は未導入（`Config.Props` に入れると読み込む。使う場合は `ASSETS.md` に記録すること）
- バッジ・課金・季節イベントは未実装
