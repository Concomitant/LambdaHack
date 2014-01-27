-- | AI strategy operations implemented with the 'Action' monad.
module Game.LambdaHack.Client.StrategyAction
  ( targetStrategy, actionStrategy
  ) where

import Control.Exception.Assert.Sugar
import Control.Monad
import qualified Data.EnumMap.Strict as EM
import qualified Data.EnumSet as ES
import Data.Function
import Data.List
import Data.Maybe
import Data.Ord
import qualified Data.Traversable as Traversable

import Game.LambdaHack.Client.Action
import Game.LambdaHack.Client.State
import Game.LambdaHack.Client.Strategy
import Game.LambdaHack.Common.Ability (Ability)
import qualified Game.LambdaHack.Common.Ability as Ability
import Game.LambdaHack.Common.Action
import Game.LambdaHack.Common.Actor
import Game.LambdaHack.Common.ActorState
import qualified Game.LambdaHack.Common.Effect as Effect
import Game.LambdaHack.Common.Faction
import qualified Game.LambdaHack.Common.Feature as F
import Game.LambdaHack.Common.Item
import qualified Game.LambdaHack.Common.Kind as Kind
import Game.LambdaHack.Common.Level
import Game.LambdaHack.Common.Point
import Game.LambdaHack.Common.Random
import qualified Game.LambdaHack.Common.Random as Random
import Game.LambdaHack.Common.ServerCmd
import Game.LambdaHack.Common.State
import qualified Game.LambdaHack.Common.Tile as Tile
import Game.LambdaHack.Common.Time
import Game.LambdaHack.Common.Vector
import Game.LambdaHack.Content.ActorKind
import Game.LambdaHack.Content.ItemKind
import Game.LambdaHack.Content.RuleKind
import Game.LambdaHack.Content.TileKind as TileKind
import Game.LambdaHack.Utils.Frequency

-- | AI proposes possible targets for the actor. Never empty.
targetStrategy :: forall m. MonadClient m
               => ActorId -> m (Strategy (Target, ([Point], Point)))
targetStrategy aid = do
  Kind.COps{cotile=cotile@Kind.Ops{ouniqGroup}} <- getsState scops
  modifyClient $ \cli -> cli {sbfsD = EM.empty}
  b <- getsState $ getActorBody aid
  mtgtMPath <- getsClient $ EM.lookup aid . stargetD
  oldTgtUpdatedPath <- case mtgtMPath of
    Just (tgt, Just path) -> do
      mvalidPos <- aidTgtToPos aid (blid b) (Just tgt)
      if isNothing mvalidPos then return Nothing  -- wrong level
      else return $! case path of
        (p : q : rest, goal) ->
          if bpos b == p
          then Just (tgt, path)  -- no move last turn
          else if bpos b == q
               then Just (tgt, (q : rest, goal))  -- moved a step along path
               else Nothing  -- veered off the path
        ([p], goal) ->
          assert (bpos b == p && p == goal `blame` (aid, b, mtgtMPath))
            Just (tgt, path)  -- goal reached; stay there picking up items
        ([], _) -> assert `failure` (aid, b, mtgtMPath)
    Just (_, Nothing) -> assert `failure` (aid, b, mtgtMPath)
    Nothing -> return Nothing  -- no target assigned yet
  lvl <- getLevel $ blid b
  assert (not $ bproj b) skip  -- would work, but is probably a bug
  fact <- getsState $ \s -> sfactionD s EM.! bfid b
  allFoes <- getsState $ actorNotProjAssocs (isAtWar fact) (blid b)
  let nearby = 10
      nearbyFoes = filter (\(_, body) ->
                             chessDist (bpos body) (bpos b) < nearby) allFoes
      unknownId = ouniqGroup "unknown space"
      notEscape t = let notEffectEscape Effect.Escape{} = False
                        notEffectEscape _ = True
                    in all notEffectEscape $ Tile.causeEffects cotile t
      focused = bspeed b <= speedNormal
      setPath :: Target -> m (Strategy (Target, ([Point], Point)))
      setPath tgt = do
        mpos <- aidTgtToPos aid (blid b) (Just tgt)
        let p = fromMaybe (assert `failure` (b, tgt)) mpos
        (_, mpath) <- getCacheBfsAndPath aid p
        case mpath of
          Nothing -> assert `failure` "new target unreachable" `twith` (b, tgt)
          Just path ->
            return $! returN "pickNewTarget" (tgt, (bpos b : path, p))
      pickNewTarget :: m (Strategy (Target, ([Point], Point)))
      pickNewTarget = do
        -- TODO: for foes, items, etc. consider a few nearby, not just one
        cfoes <- closestFoes aid
        case cfoes of
          [] -> do
            citems <- closestItems aid
            case citems of
              [] -> do
                upos <- closestUnknown aid
                case upos of
                  Nothing -> do
                    ctriggers <- closestTriggers Nothing False aid
                    case ctriggers of
                      [] -> do
                        getDistant <-
                          rndToAction
                          $ oneOf [ closestTriggers Nothing True
                                  , fmap maybeToList . furthestKnown ]
                        kpos <- getDistant aid
                        case kpos of
                          [] -> return reject
                          p : _ -> setPath $ TPoint (blid b) p
                      p : _ -> setPath $ TPoint (blid b) p
                  Just p -> setPath $ TPoint (blid b) p
              (_, (p, _)) : _ -> setPath $ TPoint (blid b) p
          (_, (a, _)) : _ -> setPath $ TEnemy a False
      tellOthersNothingHere pos = do
        let f (tgt, _) = case tgt of
              TEnemyPos _ lid p _ -> p /= pos || lid /= blid b
              _ -> True
        modifyClient $ \cli -> cli {stargetD = EM.filter f (stargetD cli)}
        pickNewTarget
      updateTgt :: Target -> ([Point], Point)
                -> m (Strategy (Target, ([Point], Point)))
      updateTgt oldTgt updatedPath = case oldTgt of
        TEnemy a _ -> do
          body <- getsState $ getActorBody a
          if not focused  -- prefers closer foes
             && not (null nearbyFoes)  -- foes nearby
             && a `notElem` map fst nearbyFoes  -- old one not close enough
             || blid body /= blid b  -- wrong level
          then pickNewTarget
          else if bpos body == snd updatedPath
               then return $! returN "TEnemy" (oldTgt, updatedPath)
                      -- The enemy didn't move since the target acquired.
                      -- If any walls were added that make the enemy
                      -- unreachable, AI learns that the hard way,
                      -- as soon as it bumps into them.
               else do
                 let p = bpos body
                 (_, mpath) <- getCacheBfsAndPath aid p
                 case mpath of
                   Nothing -> pickNewTarget  -- enemy became unreachable
                   Just path ->
                      return $! returN "TEnemy" (oldTgt, (bpos b : path, p))
        _ | not $ null nearbyFoes -> pickNewTarget  -- prefer foes to anything
        TEnemyPos _ lid p _ ->
          -- Chase last position even if foe hides or dies,
          -- to find his companions.
          if lid /= blid b  -- wrong level
          then pickNewTarget
          else if p == bpos b
               then tellOthersNothingHere p
               else return $! returN "TEnemyPos" (oldTgt, updatedPath)
        TPoint lid pos -> do
          explored <- getsClient sexplored
          if lid /= blid b  -- wrong level
             || EM.null (lvl `atI` pos)  -- no items here any more
                && let t = lvl `at` pos
                   in t /= unknownId  -- not unknown any more
                      && not (Tile.isSuspect cotile t)  -- not suspect any more
                      && notEscape t  -- not an escape to trigger/occupy
                      && (ES.notMember lid explored  -- still things to explore
                          || pos == bpos b)  -- or reached, patrol elsewhere
          then pickNewTarget
          else return $! returN "TPoint" (oldTgt, updatedPath)
        TVector{} -> pickNewTarget
  case oldTgtUpdatedPath of
    Just (oldTgt, updatedPath) -> updateTgt oldTgt updatedPath
    Nothing -> pickNewTarget

-- | AI strategy based on actor's sight, smell, intelligence, etc.
-- Never empty.
actionStrategy :: forall m. MonadClient m
               => ActorId -> [Ability] -> m (Strategy CmdTakeTimeSer)
actionStrategy aid factionAbilities = do
  Kind.COps{coactor=Kind.Ops{okind}} <- getsState scops
  disco <- getsClient sdisco
  btarget <- getsClient $ getTarget aid
  Actor{bkind, bpos, blid} <- getsState $ getActorBody aid
  lvl <- getLevel blid
  let mk = okind bkind
      mfAid =
        case btarget of
          Just (TEnemy foeAid _) -> Just foeAid
          _ -> Nothing
      foeVisible = isJust mfAid  -- TODO: check aimability, within aFrequency
      lootHere x = not $ EM.null $ lvl `atI` x
      actorAbilities = acanDo mk `intersect` factionAbilities
      isDistant = (`elem` [ Ability.Trigger
                          , Ability.Ranged
                          , Ability.Tools
                          , Ability.Chase ])
      -- TODO: this is too fragile --- depends on order of abilities
      (prefix, rest)    = break isDistant actorAbilities
      (distant, suffix) = partition isDistant rest
      -- TODO: Ranged and Tools should only be triggered in some situations.
      aFrequency :: Ability -> m (Frequency CmdTakeTimeSer)
      aFrequency Ability.Trigger = if foeVisible then return mzero
                                   else triggerFreq aid
      aFrequency Ability.Ranged  = rangedFreq aid
      aFrequency Ability.Tools   = if not foeVisible then return mzero
                                   else toolsFreq disco aid
      aFrequency Ability.Chase   = if not foeVisible then return mzero
                                   else chaseFreq
      aFrequency ab              = assert `failure` "unexpected ability"
                                          `twith` (ab, distant, actorAbilities)
      chaseFreq :: MonadActionRO m => m (Frequency CmdTakeTimeSer)
      chaseFreq = do
        st <- chase aid True
        return $! scaleFreq 30 $ bestVariant st
      aStrategy :: Ability -> m (Strategy CmdTakeTimeSer)
      aStrategy Ability.Track  = track aid
      aStrategy Ability.Heal   = return reject  -- TODO
      aStrategy Ability.Flee   = return reject  -- TODO
      aStrategy Ability.Melee | Just foeAid <- mfAid = melee aid foeAid
      aStrategy Ability.Melee  = return reject
      aStrategy Ability.Pickup | not foeVisible && lootHere bpos = pickup aid
      aStrategy Ability.Pickup = return reject
      aStrategy Ability.Wander = chase aid False
      aStrategy ab             = assert `failure` "unexpected ability"
                                        `twith`(ab, actorAbilities)
      sumS abis = do
        fs <- mapM aStrategy abis
        return $! msum fs
      sumF abis = do
        fs <- mapM aFrequency abis
        return $! msum fs
      combineDistant as = fmap liftFrequency $ sumF as
  sumPrefix <- sumS prefix
  comDistant <- combineDistant distant
  sumSuffix <- sumS suffix
  return $! sumPrefix .| comDistant .| sumSuffix
            -- Wait until friends sidestep; ensures strategy is never empty.
            -- TODO: try to switch leader away before that (we already
            -- switch him afterwards)
            .| waitBlockNow aid

-- | A strategy to always just wait.
waitBlockNow :: ActorId -> Strategy CmdTakeTimeSer
waitBlockNow aid = returN "wait" $ WaitSer aid

-- | Strategy for a dumb missile or a strongly hurled actor.
track :: MonadActionRO m => ActorId -> m (Strategy CmdTakeTimeSer)
track aid = do
  btrajectory <- getsState $ btrajectory . getActorBody aid
  return $! if isNothing btrajectory
            then reject
            else returN "SetTrajectorySer" $ SetTrajectorySer aid

-- TODO: (most?) animals don't pick up. Everybody else does.
pickup :: MonadActionRO m => ActorId -> m (Strategy CmdTakeTimeSer)
pickup aid = do
  body@Actor{bpos, blid} <- getsState $ getActorBody aid
  lvl <- getLevel blid
  actionPickup <- case EM.minViewWithKey $ lvl `atI` bpos of
    Nothing -> assert `failure` "pickup of empty pile" `twith` (aid, bpos, lvl)
    Just ((iid, k), _) -> do  -- pick up first item
      item <- getsState $ getItemBody iid
      let l = if jsymbol item == '$' then Just $ InvChar '$' else Nothing
      return $! case assignLetter iid l body of
        Just _ -> returN "pickup" $ PickupSer aid iid k
        Nothing -> returN "pickup" $ WaitSer aid  -- TODO
  return $! actionPickup

-- Everybody melees in a pinch, even though some prefer ranged attacks.
melee :: MonadActionRO m
      => ActorId -> ActorId -> m (Strategy CmdTakeTimeSer)
melee aid foeAid = do
  Actor{bpos} <- getsState $ getActorBody aid
  Actor{bpos = fpos} <- getsState $ getActorBody foeAid
  let foeAdjacent = adjacent bpos fpos  -- MeleeDistant
  return $! foeAdjacent .=> returN "melee" (MeleeSer aid foeAid)

-- Fast monsters don't pay enough attention to features.
triggerFreq :: MonadClient m
            => ActorId -> m (Frequency CmdTakeTimeSer)
triggerFreq aid = do
  cops@Kind.COps{cotile=Kind.Ops{okind}} <- getsState scops
  dungeon <- getsState sdungeon
  explored <- getsClient sexplored
  b@Actor{bpos, blid, bfid, boldpos} <- getsState $ getActorBody aid
  fact <- getsState $ \s -> sfactionD s EM.! bfid
  lvl <- getLevel blid
  let spawn = isSpawnFact cops fact
      t = lvl `at` bpos
      feats = TileKind.tfeature $ okind t
      unexploredDepth nlid p =
        case ascendInBranch dungeon nlid p of
          [] -> False
          nlid2 : _ -> ES.notMember nlid2 explored
                       || unexploredDepth nlid2 p
      ben feat = case feat of
        F.Cause Effect.Escape{} | spawn -> 0  -- spawners lose if they escape
        F.Cause (Effect.Ascend p) ->  -- change levels sensibly, in teams
          let unexploredCurrent = ES.notMember blid explored
          in if unexploredCurrent
             then 0  -- don't leave the level until explored
             else if unexploredDepth blid (signum p)
             then 1000
             else if unexploredDepth blid (- signum p)
             then 0  -- wait for stairs in the opposite direciton
             else 2  -- everything explored, switch levels occasionally
        F.Cause ef -> effectToBenefit cops b ef
        _ -> 0
      benFeat = zip (map ben feats) feats
      -- Probably recently switched levels or was pushed to another level.
      -- Do not repeatedly switch levels or push each other between levels.
      -- Consequently, AI won't dive many levels down with linked staircases.
      recentlyAscended = bpos == boldpos
  if recentlyAscended then
    return mzero  -- TODO: make sure the actor does not stay here,
                  -- blocking the stairs and repeatedly pusing one another
                  -- between levels, unless this is Escape
  else
    return $! toFreq "triggerFreq" $ [ (benefit, TriggerSer aid (Just feat))
                                     | (benefit, feat) <- benFeat
                                     , benefit > 0 ]

-- Actors require sight to use ranged combat and intelligence to throw
-- or zap anything else than obvious physical missiles.
rangedFreq :: MonadClient m
           => ActorId -> m (Frequency CmdTakeTimeSer)
rangedFreq aid = do
  cops@Kind.COps{ coactor=Kind.Ops{okind}
                , coitem=Kind.Ops{okind=iokind}
                , corule
                , cotile
                } <- getsState scops
  disco <- getsClient sdisco
  btarget <- getsClient $ getTarget aid
  b@Actor{bkind, bpos, bfid, blid, bbag, binv} <- getsState $ getActorBody aid
  mfpos <- aidTgtToPos aid blid btarget
  case (btarget, mfpos) of
    (Just TEnemy{}, Just fpos) -> do
      lvl@Level{lxsize, lysize} <- getLevel blid
      let mk = okind bkind
          tis = lvl `atI` bpos
      fact <- getsState $ \s -> sfactionD s EM.! bfid
      foes <- getsState $ actorNotProjList (isAtWar fact) blid
      let foesAdj = foesAdjacent lxsize lysize bpos foes
          posWalkable pos1 = Tile.isWalkable cotile (lvl `at` pos1)
      -- TODO: also don't throw if any pos on trajectory is visibly
      -- not accessible from previous (and tweak eps in bla to make it
      -- accessible). Also don't throw if target not in range.
      s <- getState
      let eps = 0
          bl = bla lxsize lysize eps bpos fpos  -- TODO:make an arg of projectGroupItem
          permitted = (if aiq mk >= 10 then ritemProject else ritemRanged)
                      $ Kind.stdRuleset corule
          throwFreq bag multi container =
            [ (- benefit * multi,
              ProjectSer aid fpos eps iid (container iid))
            | (iid, i) <- map (\iid -> (iid, getItemBody iid s))
                          $ EM.keys bag
            , let benefit =
                    case jkind disco i of
                      Nothing -> -- TODO: (undefined, 0)   --- for now, cheating
                        effectToBenefit cops b (jeffect i)
                      Just _ki ->
                        let _kik = iokind _ki
                            _unneeded = isymbol _kik
                        in effectToBenefit cops b (jeffect i)
            , benefit < 0
            , jsymbol i `elem` permitted ]
      case bl of
        Just (pos1 : _) -> do
          mab <- getsState $ posToActor pos1 blid
          if not foesAdj  -- ProjectBlockFoes
             && asight mk  -- ProjectBlind
             && posWalkable pos1  -- ProjectBlockTerrain
             && maybe True (bproj . snd . fst) mab  -- ProjectBlockActor
          then return $! toFreq "throwFreq"
               $ throwFreq bbag 3 (actorContainer aid binv)
                 ++ throwFreq tis 6 (const $ CFloor blid bpos)
          else return $! toFreq "throwFreq blocked" []
        _ -> return $! toFreq "throwFreq no bla" []  -- ProjectAimOnself
    _ -> return $! toFreq "throwFreq no enemy target on level" []

-- Tools use requires significant intelligence and sometimes literacy.
toolsFreq :: MonadActionRO m
          => Discovery -> ActorId -> m (Frequency CmdTakeTimeSer)
toolsFreq disco aid = do
  cops@Kind.COps{coactor=Kind.Ops{okind}} <- getsState scops
  b@Actor{bkind, bpos, blid, bbag, binv} <- getsState $ getActorBody aid
  lvl <- getLevel blid
  s <- getState
  let tis = lvl `atI` bpos
      mk = okind bkind
      mastered | aiq mk < 5 = ""
               | aiq mk < 10 = "!"
               | otherwise = "!?"  -- literacy required
      useFreq bag multi container =
        [ (benefit * multi, ApplySer aid iid (container iid))
        | (iid, i) <- map (\iid -> (iid, getItemBody iid s))
                      $ EM.keys bag
        , let benefit =
                case jkind disco i of
                  Nothing -> 30  -- experimenting is fun
                  Just _ki -> effectToBenefit cops b $ jeffect i
        , benefit > 0
        , jsymbol i `elem` mastered ]
  return $! toFreq "useFreq" $
    useFreq bbag 1 (actorContainer aid binv)
    ++ useFreq tis 2 (const $ CFloor blid bpos)

moveTowards :: MonadClient m
            => ActorId -> Point -> Point -> Point -> m (Strategy Vector)
moveTowards aid source target goal = do
  cops@Kind.COps{coactor=Kind.Ops{okind}, cotile} <- getsState scops
  b <- getsState $ getActorBody aid
  assert (source == bpos b && adjacent source target) skip
  lvl <- getsState $ (EM.! blid b) . sdungeon
  fact <- getsState $ (EM.! bfid b) . sfactionD
  friends <- getsState $ actorList (not . isAtWar fact) $ blid b
  let mk = okind $ bkind b
      noFriends | asight mk = unoccupied friends  -- TODO: && animal or stupid
        -- TODO: but beware of trivial cycles from displacing repeatedly
        -- and also somehow hide friends from UI blind actors
                | otherwise = const True
      accessibleHere = accessible cops lvl source
      bumpableHere p =
        let t = lvl `at` p
        in Tile.isOpenable cotile t || Tile.isSuspect cotile t
      enterableHere p = accessibleHere p || bumpableHere p
  if noFriends target && enterableHere target then
    return $! returN "moveTowards adjacent" $ displacement source target
  else do
    let goesBack v = v == displacement source (boldpos b)
        nonincreasing p = chessDist source goal >= chessDist p goal
        isSensible p = nonincreasing p && noFriends p && enterableHere p
        sensible = [ ((goesBack v, chessDist p goal), v)
                   | v <- moves, let p = source `shift` v, isSensible p ]
        sorted = sortBy (comparing fst) sensible
        groups = map (map snd) $ groupBy ((==) `on` fst) sorted
        freqs = map (liftFrequency . uniformFreq "moveTowards") groups
    return $! foldr (.|) reject freqs

chase :: MonadClient m
      => ActorId -> Bool -> m (Strategy CmdTakeTimeSer)
chase aid foeVisible = do
  mtgtMPath <- getsClient $ EM.lookup aid . stargetD
  str <- case mtgtMPath of
    Just (_, Just ((p : q : _), goal)) -> moveTowards aid p q goal
    _ -> return reject  -- goal reached
  let fight = not foeVisible  -- don't pick fights if the real foe is close
  if fight
    then Traversable.mapM (moveOrRunAid False aid) str
    else Traversable.mapM (moveOrRunAid True aid) str

-- | Actor moves or searches or alters or attacks. Displaces if @run@.
moveOrRunAid :: MonadActionRO m
             => Bool -> ActorId -> Vector -> m CmdTakeTimeSer
moveOrRunAid run source dir = do
  cops@Kind.COps{cotile} <- getsState scops
  sb <- getsState $ getActorBody source
  let lid = blid sb
  lvl <- getLevel lid
  let spos = bpos sb           -- source position
      tpos = spos `shift` dir  -- target position
      t = lvl `at` tpos
  -- We start by checking actors at the the target position,
  -- which gives a partial information (actors can be invisible),
  -- as opposed to accessibility (and items) which are always accurate
  -- (tiles can't be invisible).
  tgts <- getsState $ posToActors tpos lid
  case tgts of
    [((target, _), _)] | run ->  -- can be a foe, as well as a friend
      if accessible cops lvl spos tpos then
        -- Displacing requires accessibility.
        return $! DisplaceSer source target
      else
        -- If cannot displace, hit. No DisplaceAccess.
        return $! MeleeSer source target
    ((target, _), _) : _ ->  -- can be a foe, as well as a friend
      -- Attacking does not require full access, adjacency is enough.
      return $! MeleeSer source target
    [] -> do  -- move or search or alter
      if accessible cops lvl spos tpos then
        -- Movement requires full access.
        return $! MoveSer source dir
        -- The potential invisible actor is hit.
      else if not $ EM.null $ lvl `atI` tpos then
        -- This is, e.g., inaccessible open door with an item in it.
        assert `failure` "AI causes AlterBlockItem" `twith` (run, source, dir)
      else if not (Tile.isWalkable cotile t)  -- not implied
              && (Tile.isSuspect cotile t
                  || Tile.isOpenable cotile t
                  || Tile.isClosable cotile t
                  || Tile.isChangeable cotile t) then
        -- No access, so search and/or alter the tile.
        return $! AlterSer source tpos Nothing
      else
        -- Boring tile, no point bumping into it, do WaitSer if really idle.
        assert `failure` "AI causes MoveNothing or AlterNothing"
               `twith` (run, source, dir)

-- | How much AI benefits from applying the effect. Multipllied by item p.
-- Negative means harm to the enemy when thrown at him. Effects with zero
-- benefit won't ever be used, neither actively nor passively.
effectToBenefit :: Kind.COps -> Actor -> Effect.Effect Int -> Int
effectToBenefit Kind.COps{coactor=Kind.Ops{okind}} b eff =
  let kind = okind $ bkind b
  in case eff of
    Effect.NoEffect -> 0
    (Effect.Heal p) -> 10 * min p (Random.maxDice (ahp kind) - bhp b)
    (Effect.Hurt _ p) -> -(p * 10)     -- TODO: dice ignored, not capped
    Effect.Mindprobe{} -> 0            -- AI can't benefit yet
    Effect.Dominate -> -100
    (Effect.CallFriend p) -> p * 100
    Effect.Summon{} -> 1               -- may or may not spawn a friendly
    (Effect.CreateItem p) -> p * 20
    Effect.ApplyPerfume -> 0
    Effect.Regeneration{} -> 0         -- bigger benefit from carrying around
    Effect.Searching{} -> 0
    Effect.Ascend{} -> 0               -- change levels sensibly, in teams
    Effect.Escape{} -> 10000           -- AI wants to win; spawners to guard
