-- サーバーとクライアントの両方から require できる設定
return {
	RoundSeconds = 360, -- 追いかけ時間（チャイムが鳴ったら鬼の勝ち）
	HideSeconds = 10, -- 鬼が動き出すまで
	ResultSeconds = 8,
	CharmsNeeded = 5, -- 校門を開けるのに必要なお守りの数
	CharmHoldSeconds = 1.5,
	MinKids = 4, -- 子どもがこの人数になるまでCPUで埋める
	MaxPlayers = 8,
	Bounds = 290, -- マップの外に出たら戻す

	Kid = {
		WalkSpeed = 16,
		SprintSpeed = 23,
		StaminaMax = 100,
		SprintDrain = 25, -- 1秒あたり
		Regen = 12,
		RegenDelay = 1.2,
		ExhaustSeconds = 1.5,
		MaxBalloons = 3,
		StartBalloons = 2,
		ThrowCooldown = 0.8,
		BalloonSpeed = 70,
		BalloonGravity = 60,
		RescueHoldSeconds = 2,
		InvulnAfterRescue = 3,
		BucketCooldown = 8,
	},

	Oni = {
		WalkSpeed = 17.5,
		CatchRadius = 5,
		Scale = 1.3,
		StunSeconds = 2.5, -- 水風船が当たったときの停止
		SlowSeconds = 5, -- そのあとの鈍足
		SlowMultiplier = 0.6,
		Dash = { Cooldown = 9, Seconds = 1.2, Speed = 31 },
		Sense = { Cooldown = 18, Seconds = 3.5, Range = 80 },
		Slam = { Cooldown = 14, Radius = 14, StunSeconds = 2 },
	},

	Cpu = {
		OniName = "オニ",
		KidNames = { "タロウ", "ハナコ", "ケンタ", "ミキ" },
		OniSight = 60, -- CPUの鬼が子どもに気づく距離
	},

	-- Toolbox素材（後で入れる）。失敗したらPartsの簡易版にする
	Props = {},

	Event = nil, -- 季節イベントの差し込み口
}
