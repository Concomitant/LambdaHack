-- | Organ definitions.
module Content.ItemKindOrgan ( organs ) where

import Game.LambdaHack.Common.Color
import Game.LambdaHack.Common.Dice
import Game.LambdaHack.Common.Flavour
import Game.LambdaHack.Common.Misc
import Game.LambdaHack.Common.Msg
import Game.LambdaHack.Content.ItemKind

organs :: [ItemKind]
organs =
  [fist, foot, tentacle, lash, noseTip, lip, claw, smallClaw, snout, sting, venomTooth, venomFang, largeTail, jaw, largeJaw, tooth, pupil, armoredSkin, speedGland2, speedGland4, speedGland6, speedGland8, speedGland10, eye2, eye3, eye4, eye5, nostril, thorn, vent, bonusHP, fissure]

fist,    foot, tentacle, lash, noseTip, lip, claw, smallClaw, snout, sting, venomTooth, venomFang, largeTail, jaw, largeJaw, tooth, pupil, armoredSkin, speedGland2, speedGland4, speedGland6, speedGland8, speedGland10, eye2, eye3, eye4, eye5, nostril, thorn, vent, bonusHP, fissure :: ItemKind

-- * Parameterized organs

speedGland :: Int -> ItemKind
speedGland n = fist
  { iname    = "speed gland"
  , ifreq    = [(toGroupName $ "speed gland" <+> tshow n, 100)]
  , icount   = 1
  , iverbHit = "spit at"
  , iaspects = [ AddSpeed $ intToDice n
               , Periodic
               , Timeout $ intToDice $ 100 `div` n ]
  , ieffects = [Recharging (RefillHP 1)]
  , ifeature = [Durable, Identified]
  , idesc    = ""
  }
speedGland2 = speedGland 2
speedGland4 = speedGland 4
speedGland6 = speedGland 6
speedGland8 = speedGland 8
speedGland10 = speedGland 10
eye :: Int -> ItemKind
eye n = fist
  { iname    = "eye"
  , ifreq    = [(toGroupName $ "eye" <+> tshow n, 100)]
  , icount   = 2
  , iverbHit = "glare at"
  , iaspects = [AddSight (intToDice n)]
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  }
eye2 = eye 2
eye3 = eye 3
eye4 = eye 4
eye5 = eye 5

-- * Human weapon organs

fist = ItemKind
  { isymbol  = '%'
  , iname    = "fist"
  , ifreq    = [("fist", 100)]
  , iflavour = zipPlain [BrRed]
  , icount   = 2
  , irarity  = [(1, 1)]
  , iverbHit = "punch"
  , iweight  = 2000
  , iaspects = []
  , ieffects = [Hurt (4 * d 1)]
  , ifeature = [Durable, EqpSlot EqpSlotWeapon "", Identified]
  , idesc    = ""
  , ikit     = []
  }
foot = fist
  { iname    = "foot"
  , ifreq    = [("foot", 50)]
  , icount   = 2
  , iverbHit = "kick"
  , ieffects = [Hurt (4 * d 1)]
  , idesc    = ""
  }

-- * Universal weapon organs

claw = fist
  { iname    = "claw"
  , ifreq    = [("claw", 50)]
  , icount   = 2  -- even if more, only the fore claws used for fighting
  , iverbHit = "slash"
  , ieffects = [Hurt (6 * d 1)]
  , idesc    = ""
  }
smallClaw = fist
  { iname    = "small claw"
  , ifreq    = [("small claw", 50)]
  , icount   = 2
  , iverbHit = "slash"
  , ieffects = [Hurt (3 * d 1)]
  , idesc    = ""
  }
snout = fist
  { iname    = "snout"
  , ifreq    = [("snout", 10)]
  , iverbHit = "bite"
  , ieffects = [Hurt (2 * d 1)]
  , idesc    = ""
  }
jaw = fist
  { iname    = "jaw"
  , ifreq    = [("jaw", 20)]
  , icount   = 1
  , iverbHit = "rip"
  , ieffects = [Hurt (5 * d 1)]
  , idesc    = ""
  }
largeJaw = fist
  { iname    = "large jaw"
  , ifreq    = [("large jaw", 100)]
  , icount   = 1
  , iverbHit = "crush"
  , ieffects = [Hurt (12 * d 1)]
  , idesc    = ""
  }
tooth = fist
  { iname    = "tooth"
  , ifreq    = [("tooth", 20)]
  , icount   = 3
  , iverbHit = "nail"
  , ieffects = [Hurt (3 * d 1)]
  , idesc    = ""
  }

-- * Monster weapon organs

tentacle = fist
  { iname    = "tentacle"
  , ifreq    = [("tentacle", 50)]
  , icount   = 4
  , iverbHit = "slap"
  , ieffects = [Hurt (4 * d 1)]
  , idesc    = ""
  }
lash = fist
  { iname    = "lash"
  , ifreq    = [("lash", 100)]
  , icount   = 1
  , iverbHit = "lash"
  , ieffects = [Hurt (4 * d 1)]
  , idesc    = ""
  }
noseTip = fist
  { iname    = "tip"
  , ifreq    = [("nose tip", 50)]
  , icount   = 1
  , iverbHit = "poke"
  , ieffects = [Hurt (2 * d 1)]
  , idesc    = ""
  }
lip = fist
  { iname    = "lip"
  , ifreq    = [("lip", 10)]
  , icount   = 2
  , iverbHit = "lap"
  , ieffects = [Hurt (2 * d 1)]  -- TODO: decrease Hurt, but use
  , idesc    = ""
  }

-- * Special weapon organs

thorn = fist
  { iname    = "thorn"
  , ifreq    = [("thorn", 100)]
  , icount   = 7
  , iverbHit = "impale"
  , ieffects = [Hurt (2 * d 1)]
  , idesc    = ""
  }
fissure = fist
  { iname    = "fissure"
  , ifreq    = [("fissure", 100)]
  , icount   = 2
  , iverbHit = "hiss at"
  , ieffects = [Burn 1]
  , idesc    = ""
  }
sting = fist
  { iname    = "sting"
  , ifreq    = [("sting", 100)]
  , icount   = 1
  , iverbHit = "sting"
  , iaspects = [Timeout $ 1 + d 5]
  , ieffects = [Burn 1, Recharging (Paralyze 3)]
  , idesc    = ""
  }
venomTooth = fist
  { iname    = "venom tooth"
  , ifreq    = [("venom tooth", 100)]
  , icount   = 2
  , iverbHit = "bite"
  , iaspects = [Timeout $ 3 + d 3]
  , ieffects = [Hurt (3 * d 1), Recharging (CreateOrgan (3 + d 3) "slow 10")]
  , idesc    = ""
  }
venomFang = fist
  { iname    = "venom fang"
  , ifreq    = [("venom fang", 100)]
  , icount   = 2
  , iverbHit = "bite"
  , iaspects = [Timeout $ 10 + d 5]
  , ieffects = [Hurt (3 * d 1), Recharging (CreateOrgan 0 "poisoned")]
  , idesc    = ""
  }
largeTail = fist
  { iname    = "large tail"
  , ifreq    = [("large tail", 50)]
  , icount   = 1
  , iverbHit = "knock"
  , iaspects = [Timeout $ 1 + d 3]
  , ieffects = [Hurt (8 * d 1), Recharging (PushActor (ThrowMod 400 25))]
  , idesc    = ""
  }
pupil = fist
  { iname    = "pupil"
  , ifreq    = [("pupil", 100)]
  , icount   = 1
  , iverbHit = "gaze at"
  , iaspects = [AddSight 7, Timeout $ 5 + d 5]
  , ieffects = [Hurt (4 * d 1), Recharging (Paralyze 5)]  -- TODO: decrease Hurt, but use
  , idesc    = ""
  }

-- * Armor organs

armoredSkin = fist
  { iname    = "armored skin"
  , ifreq    = [("armored skin", 100)]
  , icount   = 1
  , iverbHit = "bash"
  , iaspects = [AddArmorMelee 30, AddArmorRanged 30]
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  }

-- * Sense organs

nostril = fist
  { iname    = "nostril"
  , ifreq    = [("nostril", 100)]
  , icount   = 2
  , iverbHit = "snuff"
  , iaspects = [AddSmell 1]
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  }

-- * Assorted

vent = fist
  { iname    = "vent"
  , ifreq    = [("vent", 100)]
  , icount   = 1
  , iverbHit = "menace"
  , iaspects = [Periodic, Timeout $ (2 + d 4) |*| 10]
  , ieffects = [Recharging (Explode "boiling water")]
  , ifeature = [Durable, Identified]
  , idesc    = ""
  }
bonusHP = fist
  { iname    = "bonus HP"
  , ifreq    = [("bonus HP", 100)]
  , icount   = 1
  , iverbHit = "intimidate"
  , iaspects = [AddMaxHP 1]
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  }
