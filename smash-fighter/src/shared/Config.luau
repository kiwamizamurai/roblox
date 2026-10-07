-- サーバーとクライアントの両方から require できる設定
return {
	Stocks = 3, -- 初期ストック数
	MaxPlayers = 4, -- これを超えて入った人は弾く（HUDとステージの広さの都合）
	CpuCount = 1, -- 人間が1人のときに出すCPUの数
	StageHalfWidth = 30, -- メインステージの半幅（CPUが端を判断するのに使う）
	Blast = { MinY = -70, MaxY = 90, X = 110 }, -- ここを出たらKO
	RespawnDelay = 1.5,
	RespawnInvincible = 2, -- 復活後の無敵秒数
	RespawnHeight = 22,
	CountdownSeconds = 3,
	ResultSeconds = 5,
	StunSeconds = 0.4, -- 被弾後に操作できない時間
	ExtraJumps = 1, -- 空中で追加できるジャンプ回数

	-- Center/Half は攻撃判定の箱（自分の中心から見た前方X・上方Y）
	Moves = {
		Jab = {
			Damage = 8, Cooldown = 0.4,
			Center = Vector2.new(3.5, 0.5), Half = Vector2.new(3.5, 3),
			Dir = Vector2.new(1, 0.7), Base = 45, Scale = 1.1,
		},
		Up = {
			Damage = 10, Cooldown = 0.6,
			Center = Vector2.new(0, 4), Half = Vector2.new(3.5, 4),
			Dir = Vector2.new(0.25, 1), Base = 55, Scale = 1.1,
		},
		Down = {
			Damage = 9, Cooldown = 0.6,
			Center = Vector2.new(3.5, -1.5), Half = Vector2.new(4, 2),
			Dir = Vector2.new(1, 0.2), Base = 50, Scale = 1.2,
		},
	},
	Special = { -- 飛び道具
		Damage = 6, Cooldown = 2, Speed = 75, Lifetime = 1.2, Radius = 2,
		Dir = Vector2.new(1, 0.4), Base = 35, Scale = 1,
	},
	Shield = { Max = 100, DrainPerSecond = 25, RegenPerSecond = 18, BreakStun = 2 },
	Dodge = { Seconds = 0.35, Speed = 70, Cooldown = 0.8 },
}
