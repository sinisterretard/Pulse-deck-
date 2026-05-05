--!strict
local Config = {
    GAME_NAME = "PULSE DECK ARENA",
    MATCH_DURATION = 240,
    COUNTDOWN_DURATION = 3,
    DECK_SIZE = 5,
    MAX_SELECTABLE_HEROES = 8,
    SWITCH_COOLDOWN = 0.75,
    HERO_RESPAWN_TIME = 9,
    SUDDEN_DEATH_ENABLED = true,
    SOLO_BOT_START_DELAY = 8,
    SCORE_HERO_ELIMINATION = 35,
    SCORE_ASSIST = 10,
    SCORE_GENERATOR_DESTROY = 150,
    CORE_MAX_HEALTH = 1400,
    GENERATOR_MAX_HEALTH = 450,
    HEALTH_PICKUP_AMOUNT = 40,
    HEALTH_PICKUP_RESPAWN = 18,
    AMMO_PICKUP_RESPAWN = 16,
    ADMIN_USER_IDS = {},
    TEAM_RED = "Red",
    TEAM_BLUE = "Blue",
    RED_COLOR = Color3.fromRGB(255, 70, 70),
    BLUE_COLOR = Color3.fromRGB(60, 200, 255),
    MAP = {
        RED_CORE = Vector3.new(-128, 8, 0),
        BLUE_CORE = Vector3.new(128, 8, 0),
        RED_GENERATORS = {
            Vector3.new(-105, 6, 30),
            Vector3.new(-105, 6, -30),
        },
        BLUE_GENERATORS = {
            Vector3.new(105, 6, 30),
            Vector3.new(105, 6, -30),
        },
        RED_SPAWN_PADS = {
            Vector3.new(-135, 3, 22),
            Vector3.new(-135, 3, -22),
        },
        BLUE_SPAWN_PADS = {
            Vector3.new(135, 3, 22),
            Vector3.new(135, 3, -22),
        },
    },
}

return Config
