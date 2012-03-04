-- TODO: Add an export list, with sections, after the file is rewritten
-- according to #17.
-- | Game action monad and basic building blocks
-- for player and monster actions.
{-# LANGUAGE MultiParamTypeClasses, RankNTypes #-}
module Game.LambdaHack.Action
  ( ActionFun, Action, handlerToIO, end, rndToAction
  , Session(..), session, contentOps, contentf
  , tryWith, tryRepeatedlyWith, try, tryRepeatedly, debug
  , abort, abortWith, abortIfWith, neverMind
  , currentDiary, historyReset, msgAdd, msgReset
  , getCommand, displayNothingPush, displayPush, displayPrompt
  , displayMoreConfirm, displayMoreCancel
  , displayYesNo, displayChoice, displayOverlays
  , withPerception, currentPerception, updateAnyActor, updatePlayerBody
  , advanceTime, playerAdvanceTime
  , currentDate, registerHS, saveGameBkp, saveGameFile, dump
  ) where

import Control.Monad
import Control.Monad.State hiding (State, state, liftIO)
import qualified Data.IntMap as IM
import qualified Data.Map as M
import System.Time
import Data.Maybe
-- import System.IO (hPutStrLn, stderr) -- just for debugging

import Game.LambdaHack.Perception
import Game.LambdaHack.Display
import Game.LambdaHack.Draw
import Game.LambdaHack.Msg
import Game.LambdaHack.State
import Game.LambdaHack.Level
import Game.LambdaHack.Actor
import Game.LambdaHack.ActorState
import Game.LambdaHack.Content.ActorKind
import qualified Game.LambdaHack.Save as Save
import qualified Game.LambdaHack.Kind as Kind
import Game.LambdaHack.Random
import qualified Game.LambdaHack.Key as K
import Game.LambdaHack.Binding
import qualified Game.LambdaHack.HighScore as H
import qualified Game.LambdaHack.Config as Config

-- | The type of the function inside any action.
-- (Separated from the @Action@ type to document each argument with haddock.)
type ActionFun r a =
   Session                           -- ^ session setup data
   -> (State -> Diary -> IO r)       -- ^ shutdown continuation
   -> Perception                     -- ^ cached perception
   -> (State -> Diary -> a -> IO r)  -- ^ continuation
   -> IO r                           -- ^ failure/reset continuation
   -> State                          -- ^ current state
   -> Diary                          -- ^ current diary
   -> IO r

-- | Actions of player-controlled characters and of any other actors.
newtype Action a = Action
  { runAction :: forall r . ActionFun r a
  }

instance Show (Action a) where
  show _ = "an action"

-- TODO: check if it's strict enough, if we don't keep old states for too long,
-- Perhaps make state type fields strict for that, too?
instance Monad Action where
  return = returnAction
  (>>=)  = bindAction

instance Functor Action where
  fmap f (Action g) = Action (\ s e p k a st ms ->
                               let k' st' ms' = k st' ms' . f
                               in g s e p k' a st ms)

-- | Invokes the action continuation on the provided argument.
returnAction :: a -> Action a
returnAction x = Action (\ _s _e _p k _a st m -> k st m x)

-- | Distributes the session and shutdown continuation,
-- threads the state and diary.
bindAction :: Action a -> (a -> Action b) -> Action b
bindAction m f = Action (\ s e p k a st ms ->
                          let next nst nm x =
                                runAction (f x) s e p k a nst nm
                          in runAction m s e p next a st ms)

instance MonadState State Action where
  get     = Action (\ _s _e _p k _a  st ms -> k st  ms st)
  put nst = Action (\ _s _e _p k _a _st ms -> k nst ms ())

-- Instance commented out and action hiden, so that outside of this module
-- nobody can subvert Action by invoking arbitrary IO.
--   instance MonadIO Action where
liftIO :: IO a -> Action a
liftIO x = Action (\ _s _e _p k _a st ms -> x >>= k st ms)

-- | Run an action, with a given session, state and diary, in the @IO@ monad.
handlerToIO :: Session -> State -> Diary -> Action () -> IO ()
handlerToIO sess@Session{sfs, scops} state diary h =
  runAction h
    sess
    (\ ns ndiary -> Save.rmBkpSaveDiary ns ndiary
                 >> shutdown sfs)  -- get out of the game
    (perception scops state)  -- create and cache perception
    (\ _ _ x -> return x)    -- final continuation returns result
    (ioError $ userError "unhandled abort")
    state
    diary

-- | End the game, i.e., invoke the shutdown continuation.
end :: Action ()
end = Action (\ _s e _p _k _a s diary -> e s diary)

-- | Invoke pseudo-random computation with the generator kept in the state.
rndToAction :: Rnd a -> Action a
rndToAction r = do
  g <- gets srandom
  let (a, ng) = runState r g
  modify (\ state -> state {srandom = ng})
  return a

-- | The constant session information, not saved to the game save file.
data Session = Session
  { sfs   :: FrontendSession         -- ^ frontend session information
  , scops :: Kind.COps               -- ^ game content
  , skeyb :: Binding (Action ())     -- ^ binding of keys to commands
  }

-- | Invoke a session command.
session :: (Session -> Action a) -> Action a
session f = Action (\ sess e p k a st ms ->
                     runAction (f sess) sess e p k a st ms)

-- | Get the content operations.
contentOps :: Action Kind.COps
contentOps = Action (\ Session{scops} _e _p k _a st ms -> k st ms scops)

-- TODO: remove
-- | Get the content operations modified by a function (usually a selector).
contentf :: (Kind.COps -> a) -> Action a
contentf f = Action (\ Session{scops} _e _p k _a st ms -> k st ms (f scops))

-- | Set the current exception handler. First argument is the handler,
-- second is the computation the handler scopes over.
tryWith :: Action () -> Action () -> Action ()
tryWith exc h = Action (\ s e p k a st ms ->
                         let runA = runAction exc s e p k a st ms
                         in runAction h s e p k runA st ms)

-- | Take a handler and a computation. If the computation fails, the
-- handler is invoked and then the computation is retried.
tryRepeatedlyWith :: Action () -> Action () -> Action ()
tryRepeatedlyWith exc h = tryWith (exc >> tryRepeatedlyWith exc h) h

-- | Try the given computation and silently catch failure.
try :: Action () -> Action ()
try = tryWith (return ())

-- | Try the given computation until it succeeds without failure.
tryRepeatedly :: Action () -> Action ()
tryRepeatedly = tryRepeatedlyWith (return ())

-- | Debugging.
debug :: String -> Action ()
debug _x = return () -- liftIO $ hPutStrLn stderr _x

-- | Reset the state and resume from the last backup point, i.e., invoke
-- the failure continuation.
abort :: Action a
abort = Action (\ _s _e _p _k a _st _ms -> a)

-- | Print the given msg, then abort.
abortWith :: Msg -> Action a
abortWith msg = do
  msgReset msg
  displayPush
  abort

-- | Abort and print the given msg if the condition is true.
abortIfWith :: Bool -> Msg -> Action a
abortIfWith True msg = abortWith msg
abortIfWith False _  = abortWith ""

-- | Abort and conditionally print the fixed message.
neverMind :: Bool -> Action a
neverMind b = abortIfWith b "never mind"

-- | Get the current diary.
currentDiary :: Action Diary
currentDiary = Action (\ _s _e _p k _a st diary -> k st diary diary)

-- | Wipe out and set a new value for the history.
historyReset :: History -> Action ()
historyReset shistory = Action (\ _s _e _p k _a st Diary{sreport} ->
                                 k st Diary{..} ())

-- | Add to the current msg.
msgAdd :: Msg -> Action ()
msgAdd nm = Action (\ _s _e _p k _a st ms ->
                     k st ms{sreport = addMsg (sreport ms) nm} ())

-- | Wipe out and set a new value for the current msg.
msgReset :: Msg -> Action ()
msgReset nm = Action (\ _s _e _p k _a st ms ->
                       k st ms{sreport = singletonReport nm} ())

-- | Wait for a player command.
getCommand :: Session -> Action (K.Key, K.Modifier)
getCommand Session{sfs, skeyb} = do
  (nc, modifier) <- liftIO $ getAnyKey sfs True
  return $ case modifier of
    K.NoModifier ->
      (fromMaybe nc $ M.lookup nc $ kmacro skeyb, modifier)
    _ -> (nc, modifier)

-- | Wait for a player keypress.
getChoice :: [(K.Key, K.Modifier)] -> Session -> Action (K.Key, K.Modifier)
getChoice keys Session{sfs} = liftIO $ getKey sfs False keys

-- | A yes-no confirmation.
getYesNo :: Session -> Action Bool
getYesNo Session{sfs} = do
  (k, _) <- liftIO $ getKey sfs False [ (K.Char 'y', K.NoModifier)
                                      , (K.Char 'n', K.NoModifier)
                                      , (K.Esc, K.NoModifier)
                                      ]
  case k of
    K.Char 'y' -> return True
    _          -> return False

-- | Ignore unexpected kestrokes until a SPACE or ESC is pressed.
getConfirm :: Session -> Action Bool
getConfirm Session{sfs} = do
  (k, _) <- liftIO $ getKey sfs False [ (K.Space, K.NoModifier)
                                      , (K.Esc, K.NoModifier)
                                      ]
  case k of
    K.Space -> return True
    _       -> return False

-- | Push a wait for a single frame to the frame queue.
displayNothingPush :: Action ()
displayNothingPush =
  Action (\ Session{sfs} _e _p k _a s diary -> do
           displayNothing sfs
           k s diary ())

-- | Push the frame depicting the current level to the frame queue.
-- If there are any animations to play, they are pushed at this point, too,
-- and cleared. Only one screenful of the message is shown,
-- the rest is ignored.
displayPush :: Action ()
displayPush =
  Action (\ Session{sfs, scops} _e p k _a
            s@State{sanim} diary@Diary{sreport} -> do
            let over = splitReport sreport
                sNew = s {sanim=[]}
            displayAnimation sfs scops p sNew sanim
            displayLevel sfs True ColorFull scops p sNew over
            k sNew diary ())

-- | Display the current level. The prompt is displayed, but not added
-- to history. The prompt is appended to the current message
-- and only the first screenful of the resulting overlay is displayed.
displayPrompt :: ColorMode -> Msg -> Action ()
displayPrompt dm prompt =
  Action (\ Session{sfs, scops} _e p k _a s diary@Diary{sreport} -> do
             let over = splitReport $ addMsg sreport prompt
             displayLevel sfs False dm scops p s over
             k s diary ())

-- | Display a msg with a @more@ prompt. Return value indicates if the player
-- tried to abort/escape.
displayMoreConfirm :: ColorMode -> Msg -> Action Bool
displayMoreConfirm dm prompt = do
  displayPrompt dm (prompt ++ moreMsg)
  session getConfirm

-- | Print a message with a @more@ prompt, await confirmation
-- and ignore confirmation.
displayMoreCancel :: Msg -> Action ()
displayMoreCancel prompt = void $ displayMoreConfirm ColorFull prompt

-- | Print a yes/no question and return the player's answer.
displayYesNo :: Msg -> Action Bool
displayYesNo prompt = do
  -- Turn player's attention to the choice via BW colours.
  displayPrompt ColorBW (prompt ++ yesnoMsg)
  session getYesNo

-- | Display the current level. The prompt and the overlay are displayed,
-- but not added to history. The prompt is appended to the current message
-- and only the first line of the result is displayed.
-- The overlay starts on the second line.
displayOver :: ColorMode -> Msg -> Overlay -> Action ()
displayOver dm prompt overlay =
  Action (\ Session{sfs, scops} _e p k _a s diary@Diary{sreport} -> do
             let xsize = lxsize $ slevel s
                 msgPrompt = renderReport $ addMsg sreport prompt
                 over = padMsg xsize msgPrompt : overlay
             displayLevel sfs False dm scops p s over
             k s diary ())

-- | Print a prompt and an overlay and wait for a player keypress.
-- If many overlays, scroll screenfuls with SPACE. Do not wrap screenfuls
-- (in some menus @?@ cycles views, so the user can restart from the top).
displayChoice :: Msg -> [Overlay] -> [(K.Key, K.Modifier)]
              -> Action (K.Key, K.Modifier)
displayChoice prompt ovs keys = do
  let (over, rest, spc, more, keysS) = case ovs of
        [] -> ([], [], "", [], keys)
        [x] -> (x, [], "", [], keys)
        x:xs -> (x, xs, ", SPACE", [moreMsg], (K.Space, K.NoModifier) : keys)
  displayOver ColorFull (prompt ++ spc ++ ", ESC]") (over ++ more)
  (key, modifier) <- session $ getChoice $ (K.Esc, K.NoModifier) : keysS
  case key of
    K.Esc -> neverMind True
    K.Space | not (null rest) -> displayChoice prompt rest keys
    _ -> return (key, modifier)

-- | Print a msg and several overlays, one per page.
-- The return value indicates if the player tried to abort/escape.
displayOverlays :: Msg -> [Overlay] -> Action Bool
displayOverlays _      []     = return True
displayOverlays _      [[]]   = return True  -- extra confirmation at the end
displayOverlays prompt [x]    = do
  displayOver ColorFull prompt x
  return True
displayOverlays prompt (x:xs) = do
  displayOver ColorFull prompt (x ++ [moreMsg])
  b <- session getConfirm
  if b
    then displayOverlays prompt xs
    else return False

-- | Update the cached perception for the given computation.
withPerception :: Action () -> Action ()
withPerception h = Action (\ sess@Session{scops} e _ k a st ms ->
                            runAction h sess e (perception scops st) k a st ms)

-- | Get the current perception.
currentPerception :: Action Perception
currentPerception = Action (\ _s _e p k _a st ms -> k st ms p)

-- | Update actor stats. Works for actors on other levels, too.
updateAnyActor :: ActorId -> (Actor -> Actor) -> Action ()
updateAnyActor actor f = modify (updateAnyActorBody actor f)

-- | Update player-controlled actor stats.
updatePlayerBody :: (Actor -> Actor) -> Action ()
updatePlayerBody f = do
  pl <- gets splayer
  updateAnyActor pl f

-- | Advance the move time for the given actor.
advanceTime :: ActorId -> Action ()
advanceTime actor = do
  Kind.Ops{okind} <- contentf Kind.coactor
  time <- gets stime
  let upd m = m { btime = time + aspeed (okind (bkind m)) }
  -- A hack to synchronize the whole party:
  pl <- gets splayer
  s <- get
  -- If actor dead or not on current level, don't bother.
  when (memActor actor s) $ updateAnyActor actor upd
  when (actor == pl) $ do
    let updH a = if bparty a == heroParty then upd a else a
    modify (updateLevel (updateActor (IM.map updH)))

-- | Add a turn to the player time counter.
playerAdvanceTime :: Action ()
playerAdvanceTime = do
  pl <- gets splayer
  advanceTime pl

currentDate :: Action ClockTime
currentDate = liftIO getClockTime

registerHS :: Config.CP -> Bool -> H.ScoreRecord -> Action (String, [Overlay])
registerHS config write s = liftIO $ H.register config write s

saveGameBkp :: State -> Diary -> Action ()
saveGameBkp state diary = liftIO $ Save.saveGameBkp state diary

saveGameFile :: State -> Diary -> Action ()
saveGameFile state diary = liftIO $ Save.saveGameFile state diary

dump :: FilePath -> Config.CP -> Action ()
dump fn config = liftIO $ Config.dump fn config
