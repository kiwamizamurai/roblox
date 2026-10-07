-- サーバーとクライアントの両方から require できる設定
return {
	Nights = 30, -- この夜数を生き延びたら勝ち
	Milestones = { 10, 20, 30 }, -- 達成を知らせる夜（バッジは管理画面で別途作る）
	DaySeconds = 75,
	NightSeconds = 90,
	CountdownSeconds = 4,
	ResultSeconds = 8,

	Lamp = {
		MaxFuel = 100,
		StartFuel = 70,
		DrainDay = 0.2, -- 1秒あたりの燃料の減り
		DrainNight = 0.8,
		FuelPerWood = 12,
		LightRangeMax = 55, -- 燃料が満タンのときの光の半径
		LightRangeMin = 8,
	},

	Resources = { Wood = 16, Scrap = 8, RespawnSeconds = 12, MinFromLamp = 14, AreaRadius = 95 },

	Player = {
		AttackCooldown = 0.45,
		AttackRange = 10,
		AttackDamage = 25,
		WeaponDamagePerLevel = 10,
		WeaponMaxLevel = 5,
		WeaponCost = 6, -- スクラップ。実際の費用は WeaponCost * (現在Lv + 1)
		ScrapDropChance = 0.5, -- 怪物を倒したときにスクラップを落とす確率
	},

	Monsters = {
		BaseCount = 3,
		PerNight = 0.7, -- 夜が進むごとに増える数
		PerExtraPlayer = 2, -- 2人目以降1人につき増える数
		MaxAlive = 25,
		Health = 60,
		HealthPerNight = 6,
		Speed = 11,
		SpeedPerNight = 0.15,
		MaxSpeed = 18,
		SpawnRadius = 110,
		AggroRange = 35, -- この距離にプレイヤーがいれば追いかける。いなければランプへ向かう
		TouchDamage = 12,
		TouchCooldown = 1,
		LampHitFuel = 4, -- ランプに取りついたとき減る燃料
		LampHitCooldown = 1.2,
		LightDps = 15, -- 光の中で1秒に受けるダメージ
		LightSlow = 0.5, -- 光の中の移動速度の倍率
	},

	-- 季節イベントの差し込み口。例: { Name = "Halloween", MonsterColor = Color3.fromRGB(255, 120, 0) }
	Event = nil,
}
