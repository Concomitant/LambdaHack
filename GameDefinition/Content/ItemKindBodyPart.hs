-- | Body part definitions.
module Content.ItemKindBodyPart ( bodyParts ) where

import Game.LambdaHack.Common.Color
import Game.LambdaHack.Common.Dice
import Game.LambdaHack.Common.Effect
import Game.LambdaHack.Common.Flavour
import Game.LambdaHack.Common.Msg
import Game.LambdaHack.Content.ItemKind

bodyParts :: [ItemKind]
bodyParts =
  [fist, foot, tentacle, lash, noseTip, lip, claw, smallClaw, snout, venomTooth, venomFang, largeTail, jaw, largeJaw, pupil, armoredSkin, speedGland1, speedGland2, speedGland3, speedGland4, speedGland5, eye3, eye6, eye9, eye12, eye15, nostril, thorn]

fist,    foot, tentacle, lash, noseTip, lip, claw, smallClaw, snout, venomTooth, venomFang, largeTail, jaw, largeJaw, pupil, armoredSkin, speedGland1, speedGland2, speedGland3, speedGland4, speedGland5, eye3, eye6, eye9, eye12, eye15, nostril, thorn :: ItemKind

fist = ItemKind
  { isymbol  = '%'
  , iname    = "fist"
  , ifreq    = [("fist", 100)]
  , iflavour = zipPlain [BrCyan]
  , icount   = 2
  , iverbApply   = "punch"
  , iverbProject = "ERROR, please report: iverbProject"
  , iweight  = 2000
  , iaspects = []
  , ieffects = [Hurt (5 * d 1) 0]
  , ifeature = [Durable, Identified]
  , idesc    = ""
  , ikit     = []
  }
foot = fist
  { iname    = "foot"
  , ifreq    = [("foot", 50)]
  , icount   = 2
  , iverbApply   = "kick"
  , ieffects = [Hurt (5 * d 1) 0]
  , idesc    = ""
  }
tentacle = fist
  { iname    = "tentacle"
  , ifreq    = [("tentacle", 50)]
  , icount   = 4
  , iverbApply   = "slap"
  , ieffects = [Hurt (5 * d 1) 0]
  , idesc    = ""
  }
lash = fist
  { iname    = "lash"
  , ifreq    = [("lash", 100)]
  , icount   = 1
  , iverbApply   = "lash"
  , ieffects = [Hurt (5 * d 1) 0]
  , idesc    = ""
  }
noseTip = fist
  { iname    = "nose tip"
  , ifreq    = [("nose tip", 50)]
  , icount   = 1
  , iverbApply   = "poke"
  , ieffects = [Hurt (2 * d 1) 0]
  , idesc    = ""
  }
lip = fist
  { iname    = "lip"
  , ifreq    = [("lip", 10)]
  , icount   = 2
  , iverbApply   = "lap"
  , ieffects = [Hurt (2 * d 1) 0]  -- TODO: decrease Hurt, but use
  , idesc    = ""
  }
claw = fist
  { iname    = "claw"
  , ifreq    = [("claw", 50)]
  , icount   = 2  -- even if more, only the fore claws used for fighting
  , iverbApply   = "slash"
  , ieffects = [Hurt (7 * d 1) 0]
  , idesc    = ""
  }
smallClaw = fist
  { iname    = "small claw"
  , ifreq    = [("small claw", 50)]
  , icount   = 2
  , iverbApply   = "slash"
  , ieffects = [Hurt (3 * d 1) 0]
  , idesc    = ""
  }
snout = fist
  { iname    = "snout"
  , ifreq    = [("snout", 10)]
  , iverbApply   = "bite"
  , ieffects = [Hurt (2 * d 1) 0]
  , idesc    = ""
  }
venomTooth = fist
  { iname    = "venom tooth"
  , ifreq    = [("venom tooth", 100)]
  , icount   = 2
  , iverbApply   = "bite"
  , ieffects = [Hurt (3 * d 1) 0, Paralyze 3]
  , idesc    = ""
  }
venomFang = fist
  { iname    = "venom fang"
  , ifreq    = [("venom fang", 100)]
  , icount   = 2
  , iverbApply   = "bite"
  , ieffects = [Hurt (3 * d 1) 12]
  , idesc    = ""
  }
largeTail = fist
  { iname    = "large tail"
  , ifreq    = [("large tail", 50)]
  , icount   = 1
  , iverbApply   = "knock"
  , ieffects = [Hurt (9 * d 1) 0, PushActor (ThrowMod 400 25)]
  , idesc    = ""
  }
jaw = fist
  { iname    = "jaw"
  , ifreq    = [("jaw", 20)]
  , icount   = 1
  , iverbApply   = "rip"
  , ieffects = [Hurt (5 * d 1) 0]
  , idesc    = ""
  }
largeJaw = fist
  { iname    = "large jaw"
  , ifreq    = [("large jaw", 100)]
  , icount   = 1
  , iverbApply   = "crush"
  , ieffects = [Hurt (15 * d 1) 0]
  , idesc    = ""
  }
pupil = fist
  { iname    = "pupil"
  , ifreq    = [("pupil", 100)]
  , icount   = 1
  , iverbApply   = "gaze at"
  , ieffects = [Hurt (5 * d 1) 0, Paralyze 1]  -- TODO: decrease Hurt, but use
  , idesc    = ""
  }
armoredSkin = fist
  { iname    = "armored skin"
  , ifreq    = [("armored skin", 100)]
  , icount   = 1
  , iverbApply   = "bash"
  , iaspects = [ArmorMelee 50]
  , ieffects = []
  , ifeature = [EqpSlot EqpSlotArmorMelee "", Identified]
  , idesc    = ""
  }
speedGland1 = speedGland 1
speedGland2 = speedGland 2
speedGland3 = speedGland 3
speedGland4 = speedGland 4
speedGland5 = speedGland 5
eye3 = eye 3
eye6 = eye 6
eye9 = eye 9
eye12 = eye 12
eye15 = eye 15
nostril = fist
  { iname    = "nostril"
  , ifreq    = [("nostril", 100)]
  , icount   = 2
  , iverbApply   = "sniff"
  , iaspects = [SmellRadius 2]
  , ieffects = []
  , ifeature = [EqpSlot EqpSlotSmellRadius "", Identified]
  , idesc    = ""
  }
thorn = fist
  { iname    = "thorn"
  , ifreq    = [("thorn", 100)]
  , icount   = 7
  , iverbApply   = "impale"
  , iaspects = []
  , ieffects = [Hurt (3 * d 1) 0]
  , idesc    = ""
  }

speedGland :: Int -> ItemKind
speedGland n = fist
  { iname    = "speed gland"
  , ifreq    = [("speed gland" <+> tshow n, 100)]
  , icount   = 1
  , iverbApply   = "squeeze"
  , iaspects = [Periodic (intToDice $ 2 * n)]  -- TODO: also speed bonus?
  , ieffects = [Heal 1]
  , ifeature = [Identified]
  , idesc    = ""
  }

eye :: Int -> ItemKind
eye n = fist
  { iname    = "eye"
  , ifreq    = [("eye" <+> tshow n, 100)]
  , icount   = 2
  , iverbApply   = "focus"
  , iaspects = [SightRadius (intToDice n)]
  , ieffects = []
  , ifeature = [EqpSlot EqpSlotSightRadius "", Identified]
  , idesc    = ""
  }
