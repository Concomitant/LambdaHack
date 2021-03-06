-- | Client monad for interacting with a human through UI.
module Game.LambdaHack.Client.UI.MsgClient
  ( msgAdd, msgReset, recordHistory
  , SlideOrCmd, failWith, failSlides, failSer, failMsg
  , lookAt, itemOverlay
  ) where

import Control.Applicative
import Control.Exception.Assert.Sugar
import Control.Monad
import qualified Data.EnumMap.Strict as EM
import Data.Maybe
import Data.Monoid
import Data.Text (Text)
import qualified Data.Text as T
import qualified Game.LambdaHack.Common.Kind as Kind
import qualified NLP.Miniutter.English as MU

import Game.LambdaHack.Client.CommonClient
import Game.LambdaHack.Client.ItemSlot
import Game.LambdaHack.Client.MonadClient hiding (liftIO)
import Game.LambdaHack.Client.State
import Game.LambdaHack.Client.UI.MonadClientUI
import Game.LambdaHack.Client.UI.WidgetClient
import Game.LambdaHack.Common.Actor
import Game.LambdaHack.Common.ActorState
import Game.LambdaHack.Common.Item
import Game.LambdaHack.Common.ItemDescription
import Game.LambdaHack.Common.Level
import Game.LambdaHack.Common.Misc
import Game.LambdaHack.Common.MonadStateRead
import Game.LambdaHack.Common.Msg
import Game.LambdaHack.Common.Point
import Game.LambdaHack.Common.Request
import Game.LambdaHack.Common.State
import qualified Game.LambdaHack.Common.Tile as Tile
import qualified Game.LambdaHack.Content.TileKind as TK

-- | Add a message to the current report.
msgAdd :: MonadClientUI m => Msg -> m ()
msgAdd msg = modifyClient $ \d -> d {sreport = addMsg (sreport d) msg}

-- | Wipe out and set a new value for the current report.
msgReset :: MonadClientUI m => Msg -> m ()
msgReset msg = modifyClient $ \d -> d {sreport = singletonReport msg}

-- | Store current report in the history and reset report.
recordHistory :: MonadClientUI m => m ()
recordHistory = do
  time <- getsState stime
  StateClient{sreport, shistory} <- getClient
  unless (nullReport sreport) $ do
    msgReset ""
    let nhistory = addReport shistory time sreport
    modifyClient $ \cli -> cli {shistory = nhistory}

type SlideOrCmd a = Either Slideshow a

failWith :: MonadClientUI m => Msg -> m (SlideOrCmd a)
failWith msg = do
  stopPlayBack
  let starMsg = "*" <> msg <> "*"
  assert (not $ T.null msg) $ Left <$> promptToSlideshow starMsg

failSlides :: MonadClientUI m => Slideshow -> m (SlideOrCmd a)
failSlides slides = do
  stopPlayBack
  return $ Left slides

failSer :: MonadClientUI m => ReqFailure -> m (SlideOrCmd a)
failSer = failWith . showReqFailure

failMsg :: MonadClientUI m => Msg -> m Slideshow
failMsg msg = do
  stopPlayBack
  let starMsg = "*" <> msg <> "*"
  assert (not $ T.null msg) $ promptToSlideshow starMsg

-- | Produces a textual description of the terrain and items at an already
-- explored position. Mute for unknown positions.
-- The detailed variant is for use in the targeting mode.
lookAt :: MonadClientUI m
       => Bool       -- ^ detailed?
       -> Text       -- ^ how to start tile description
       -> Bool       -- ^ can be seen right now?
       -> Point      -- ^ position to describe
       -> ActorId    -- ^ the actor that looks
       -> Text       -- ^ an extra sentence to print
       -> m Text
lookAt detailed tilePrefix canSee pos aid msg = do
  cops@Kind.COps{cotile=cotile@Kind.Ops{okind}} <- getsState scops
  itemToF <- itemToFullClient
  b <- getsState $ getActorBody aid
  stgtMode <- getsClient stgtMode
  let lidV = maybe (blid b) tgtLevelId stgtMode
  lvl <- getLevel lidV
  localTime <- getsState $ getLocalTime lidV
  subject <- partAidLeader aid
  is <- getsState $ getCBag $ CFloor lidV pos
  let verb = MU.Text $ if pos == bpos b
                       then "stand on"
                       else if canSee then "notice" else "remember"
  let nWs (iid, kit@(k, _)) = partItemWs k CGround localTime (itemToF iid kit)
      isd = case detailed of
              _ | EM.size is == 0 -> ""
              _ | EM.size is <= 2 ->
                makeSentence [ MU.SubjectVerbSg subject verb
                             , MU.WWandW $ map nWs $ EM.assocs is]
-- TODO: detailed unused here; disabled together with overlay in doLook              True -> "\n"
              _ -> makeSentence [MU.Cardinal (EM.size is), "items here"]
      tile = lvl `at` pos
      obscured | knownLsecret lvl
                 && tile /= hideTile cops lvl pos = "partially obscured"
               | otherwise = ""
      tileText = obscured <+> TK.tname (okind tile)
      tilePart | T.null tilePrefix = MU.Text tileText
               | otherwise = MU.AW $ MU.Text tileText
      tileDesc = [MU.Text tilePrefix, tilePart]
  if not (null (Tile.causeEffects cotile tile)) then
    return $! makeSentence ("activable:" : tileDesc)
              <+> msg <+> isd
  else if detailed then
    return $! makeSentence tileDesc
              <+> msg <+> isd
  else return $! msg <+> isd

-- | Create a list of item names.
itemOverlay :: MonadClient m
            => CStore -> LevelId -> ItemBag -> m Overlay
itemOverlay c lid bag = do
  localTime <- getsState $ getLocalTime lid
  itemToF <- itemToFullClient
  (itemSlots, organSlots) <- getsClient sslots
  let isOrgan = c == COrgan
      lSlots = if isOrgan then organSlots else itemSlots
  let !_A = assert (all (`elem` EM.elems lSlots) (EM.keys bag)
                    `blame` (c, lid, bag, lSlots)) ()
  let pr (l, iid) =
        case EM.lookup iid bag of
          Nothing -> Nothing
          Just kit@(k, _) ->
            let itemFull = itemToF iid kit
                -- TODO: add color item symbols as soon as we have a menu
                -- with all items visible on the floor or known to player
                -- symbol = jsymbol $ itemBase itemFull
            in Just $ makePhrase [ slotLabel l, "-"  -- MU.String [symbol]
                                 , partItemWs k c localTime itemFull ]
                      <> "  "
  return $! toOverlay $ mapMaybe pr $ EM.assocs lSlots
