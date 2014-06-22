-- | Actor (or rather actor body trunk) definitions.
module Content.ItemKindActor ( actors ) where

import qualified Data.EnumMap.Strict as EM

import Game.LambdaHack.Common.Ability
import Game.LambdaHack.Common.Color
import Game.LambdaHack.Common.Effect
import Game.LambdaHack.Common.Flavour
import Game.LambdaHack.Common.Misc
import Game.LambdaHack.Content.ItemKind

actors :: [ItemKind]
actors =
  [warrior, adventurer, blacksmith, forester, clerk, hairdresser, lawyer, peddler, taxCollector, projectile, eye, fastEye, nose, elbow, armadillo, gilaMonster, komodoDragon, hyena, alligator, thornbush]

warrior,    adventurer, blacksmith, forester, clerk, hairdresser, lawyer, peddler, taxCollector, projectile, eye, fastEye, nose, elbow, armadillo, gilaMonster, komodoDragon, hyena, alligator, thornbush :: ItemKind

warrior = ItemKind
  { isymbol  = '@'
  , iname    = "warrior"  -- modified if in hero faction
  , ifreq    = [("hero", 1), ("civilian", 1)]
  , iflavour = zipPlain [BrBlack]  -- modified if in hero faction
  , icount   = 1
  , iverbApply   = "ERROR, please report: iverbApply"
  , iverbProject = "ERROR, please report: iverbProject"
  , iweight  = 80000
  , iaspects = [ AddMaxHP 50, AddMaxCalm 50, AddSpeed 20
               , SightRadius 3 ]  -- no via eyes, but feel, hearing, etc.
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  , ikit     = [("fist", CBody), ("foot", CBody), ("eye 9", CBody)]
  }
adventurer = warrior
  { iname    = "adventurer" }
blacksmith = warrior
  { iname    = "blacksmith"  }
forester = warrior
  { iname    = "forester"  }

clerk = warrior
  { iname    = "clerk"
  , ifreq    = [("civilian", 1)] }
hairdresser = clerk
  { iname    = "hairdresser" }
lawyer = clerk
  { iname    = "lawyer" }
peddler = clerk
  { iname    = "peddler" }
taxCollector = clerk
  { iname    = "tax collector" }

projectile = ItemKind  -- includes homing missiles
  { isymbol  = '*'
  , iname    = "projectile"
  , ifreq    = [("projectile", 1)]  -- Does not appear randomly in the dungeon
  , iflavour = zipPlain [BrWhite]
  , icount   = 1
  , iverbApply   = "ERROR, please report: iverbApply"
  , iverbProject = "ERROR, please report: iverbProject"
  , iweight  = 0
  , iaspects = []
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  , ikit     = []
  }

eye = ItemKind
  { isymbol  = 'e'
  , iname    = "reducible eye"
  , ifreq    = [("monster", 60), ("horror", 60)]
  , iflavour = zipPlain [BrRed]
  , icount   = 1
  , iverbApply   = "ERROR, please report: iverbApply"
  , iverbProject = "ERROR, please report: iverbProject"
  , iweight  = 80000
  , iaspects = [ AddMaxHP 25, AddMaxCalm 50, AddSpeed 20
               , SightRadius 12 ]
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  , ikit     = [("lash", CBody), ("pupil", CBody)]
  }
fastEye = ItemKind
  { isymbol  = 'e'
  , iname    = "super-fast eye"
  , ifreq    = [("monster", 15), ("horror", 15)]
  , iflavour = zipPlain [BrBlue]
  , icount   = 1
  , iverbApply   = "ERROR, please report: iverbApply"
  , iverbProject = "ERROR, please report: iverbProject"
  , iweight  = 80000
  , iaspects = [ AddMaxHP 6, AddMaxCalm 50, AddSpeed 40
               , SightRadius 12 ]
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  , ikit     = [ ("lash", CBody), ("tentacle", CBody), ("tentacle", CBody)
               , ("speed gland 5", CBody), ("pupil", CBody) ]
  }
nose = ItemKind
  { isymbol  = 'n'
  , iname    = "point-free nose"
  , ifreq    = [("monster", 20), ("horror", 20)]
  , iflavour = zipPlain [Green]
  , icount   = 1
  , iverbApply   = "ERROR, please report: iverbApply"
  , iverbProject = "ERROR, please report: iverbProject"
  , iweight  = 80000
  , iaspects = [ AddMaxHP 35, AddMaxCalm 50, AddSpeed 18
               , SightRadius 0, SmellRadius 3 ]  -- depends solely on smell
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  , ikit     = [("nose tip", CBody), ("lip", CBody)]
  }
elbow = ItemKind
  { isymbol  = 'e'
  , iname    = "ground elbow"
  , ifreq    = [("monster", 10), ("horror", 20)]
  , iflavour = zipPlain [Magenta]
  , icount   = 1
  , iverbApply   = "ERROR, please report: iverbApply"
  , iverbProject = "ERROR, please report: iverbProject"
  , iweight  = 80000
  , iaspects = [ AddMaxHP 30, AddMaxCalm 50, AddSpeed 15
               , AddSkills $ EM.singleton AbMelee (-1)
               , SightRadius 4 ]  -- can always shoot
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  , ikit     = [ ("eye 12", CBody), ("armored skin", CBody)
               , ("speed gland 2", CBody)
               , ("any scroll", CInv), ("any scroll", CInv)
               , ("any scroll", CInv)
               , ("any arrow", CInv), ("any arrow", CInv), ("any arrow", CInv) ]
  }

armadillo = ItemKind
  { isymbol  = 'a'
  , iname    = "giant armadillo"
  , ifreq    = [("animal", 10), ("horror", 10)]
  , iflavour = zipPlain [Brown]
  , icount   = 1
  , iverbApply   = "ERROR, please report: iverbApply"
  , iverbProject = "ERROR, please report: iverbProject"
  , iweight  = 80000
  , iaspects = [ AddMaxHP 30, AddMaxCalm 50, AddSpeed 18
               , AddSkills $ EM.singleton AbTrigger (-1)
               , SightRadius 3 ]
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  , ikit     = [ ("claw", CBody), ("snout", CBody), ("armored skin", CBody)
               , ("nostril", CBody) ]
  }
gilaMonster = ItemKind
  { isymbol  = 'g'
  , iname    = "Gila monster"
  , ifreq    = [("animal", 10), ("horror", 10)]
  , iflavour = zipPlain [BrYellow]
  , icount   = 1
  , iverbApply   = "ERROR, please report: iverbApply"
  , iverbProject = "ERROR, please report: iverbProject"
  , iweight  = 80000
  , iaspects = [ AddMaxHP 15, AddMaxCalm 50, AddSpeed 15
               , AddSkills $ EM.singleton AbTrigger (-1)
               , SightRadius 3 ]
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  , ikit     = [ ("venom tooth", CBody), ("small claw", CBody)
               , ("speed gland 1", CBody)
               , ("eye 9", CBody), ("nostril", CBody) ]
  }
komodoDragon = ItemKind  -- bad hearing
  { isymbol  = 'd'
  , iname    = "Komodo dragon"
  , ifreq    = [("animal", 10), ("horror", 10)]
  , iflavour = zipPlain [Blue]
  , icount   = 1
  , iverbApply   = "ERROR, please report: iverbApply"
  , iverbProject = "ERROR, please report: iverbProject"
  , iweight  = 80000
  , iaspects = [ AddMaxHP 40, AddMaxCalm 50, AddSpeed 25
               , SightRadius 3 ]
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  , ikit     = [ ("large tail", CBody), ("jaw", CBody), ("small claw", CBody)
               , ("speed gland 2", CBody), ("armored skin", CBody)
               , ("eye 3", CBody), ("nostril", CBody) ]
  }
hyena = ItemKind
  { isymbol  = 'h'
  , iname    = "spotted hyena"
  , ifreq    = [("animal", 20), ("horror", 20)]
  , iflavour = zipPlain [Red]
  , icount   = 1
  , iverbApply   = "ERROR, please report: iverbApply"
  , iverbProject = "ERROR, please report: iverbProject"
  , iweight  = 80000
  , iaspects = [ AddMaxHP 30, AddMaxCalm 50, AddSpeed 35
               , SightRadius 3 ]
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  , ikit     = [("jaw", CBody), ("eye 9", CBody), ("nostril", CBody)]
  }
alligator = ItemKind
  { isymbol  = 'a'
  , iname    = "alligator"
  , ifreq    = [("animal", 10), ("horror", 10)]
  , iflavour = zipPlain [Blue]
  , icount   = 1
  , iverbApply   = "ERROR, please report: iverbApply"
  , iverbProject = "ERROR, please report: iverbProject"
  , iweight  = 80000
  , iaspects = [ AddMaxHP 50, AddMaxCalm 50, AddSpeed 17
               -- TODO: add innate armor, when it's not a drawback
               , SightRadius 3 ]
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  , ikit     = [ ("large jaw", CBody), ("large tail", CBody), ("claw", CBody)
               , ("armored skin", CBody), ("eye 9", CBody) ]
  }
thornbush = ItemKind
  { isymbol  = 't'
  , iname    = "thornbush"
  , ifreq    = [("animal", 10), ("horror", 10)]
  , iflavour = zipPlain [Brown]
  , icount   = 1
  , iverbApply   = "ERROR, please report: iverbApply"
  , iverbProject = "ERROR, please report: iverbProject"
  , iweight  = 80000
  , iaspects = [ AddMaxHP 30, AddMaxCalm 50, AddSpeed 20
               , AddSkills
                 $ EM.fromDistinctAscList (zip [minBound..maxBound] [-1..])
                   `addSkills` EM.fromList (zip [AbWait, AbMelee] [1..])
               , ArmorMelee 50 ]
  , ieffects = []
  , ifeature = [Durable, Identified]
  , idesc    = ""
  , ikit     = [("thorn", CBody)]
  }