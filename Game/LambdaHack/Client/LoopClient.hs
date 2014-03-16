{-# LANGUAGE FlexibleContexts #-}
-- | The main loop of the client, processing human and computer player
-- moves turn by turn.
module Game.LambdaHack.Client.LoopClient (loopAI, loopUI) where

import Control.Exception.Assert.Sugar
import Control.Monad
import qualified Data.EnumMap.Strict as EM
import qualified Data.Text as T

import Game.LambdaHack.Atomic
import Game.LambdaHack.Client.MonadClient
import Game.LambdaHack.Client.ProtocolClient
import Game.LambdaHack.Client.State
import Game.LambdaHack.Client.UI
import Game.LambdaHack.Common.Animation
import Game.LambdaHack.Common.Faction
import qualified Game.LambdaHack.Common.Kind as Kind
import Game.LambdaHack.Common.MonadStateRead
import Game.LambdaHack.Common.Msg
import Game.LambdaHack.Common.Response
import Game.LambdaHack.Common.State
import Game.LambdaHack.Content.ModeKind
import Game.LambdaHack.Content.RuleKind

initCli :: MonadClient m => DebugModeCli -> (State -> m ()) -> m Bool
initCli sdebugCli putSt = do
  -- Warning: state and client state are invalid here, e.g., sdungeon
  -- and sper are empty.
  cops <- getsState scops
  modifyClient $ \cli -> cli {sdebugCli}
  restored <- restoreGame
  case restored of
    Just (s, cli) | not $ snewGameCli sdebugCli -> do  -- Restore the game.
      let sCops = updateCOps (const cops) s
      putSt sCops
      putClient cli {sdebugCli}
      return True
    _ ->  -- First visit ever, use the initial state.
      return False

loopAI :: (MonadClientReadResponse ResponseAI m)
       => DebugModeCli -> (ResponseAI -> m ()) -> m ()
loopAI sdebugCli cmdClientAISem = do
  side <- getsClient sside
  restored <- initCli sdebugCli
              $ \s -> cmdClientAISem $ RespUpdAtomicAI $ UpdResumeServer s
  cmd1 <- receiveResponse
  case (restored, cmd1) of
    (True, RespUpdAtomicAI UpdResume{}) -> return ()
    (True, RespUpdAtomicAI UpdRestart{}) -> return ()
    (False, RespUpdAtomicAI UpdResume{}) -> do
      removeServerSave
      error $ T.unpack $
        "Savefile of client" <+> tshow side
        <+> "not usable. Removing server savefile. Please restart now."
    (False, RespUpdAtomicAI UpdRestart{}) -> return ()
    _ -> assert `failure` "unexpected command" `twith` (side, restored, cmd1)
  cmdClientAISem cmd1
  -- State and client state now valid.
  debugPrint $ "AI client" <+> tshow side <+> "started."
  loop
  debugPrint $ "AI client" <+> tshow side <+> "stopped."
 where
  loop = do
    cmd <- receiveResponse
    cmdClientAISem cmd
    quit <- getsClient squit
    unless quit loop

loopUI :: (MonadClientUI m, MonadClientReadResponse ResponseUI m)
       => DebugModeCli -> (ResponseUI -> m ()) -> m ()
loopUI sdebugCli cmdClientUISem = do
  Kind.COps{corule} <- getsState scops
  let title = rtitle $ Kind.stdRuleset corule
  side <- getsClient sside
  restored <- initCli sdebugCli
              $ \s -> cmdClientUISem $ RespUpdAtomicUI $ UpdResumeServer s
  cmd1 <- receiveResponse
  msg <- case (restored, cmd1) of
    (True, RespUpdAtomicUI UpdResume{}) -> do
      cmdClientUISem cmd1
      return $! "Welcome back to" <+> title <> "."
    (True, RespUpdAtomicUI UpdRestart{}) -> do
      cmdClientUISem cmd1
      return $! "Starting a new" <+> title <+> "game."  -- ignore old savefile
    (False, RespUpdAtomicUI UpdResume{}) -> do
      removeServerSave
      error $ T.unpack $
        "Savefile of client" <+> tshow side
        <+> "not usable. Removing server savefile. Please restart now."
    (False, RespUpdAtomicUI UpdRestart{}) -> do
      cmdClientUISem cmd1
      return $! "Welcome to" <+> title <> "!"
    _ -> assert `failure` "unexpected command" `twith` (side, restored, cmd1)
  fact <- getsState $ (EM.! side) . sfactionD
  if playerAiLeader $ gplayer fact then
    -- Prod the frontend to flush frames and start showing then continuously.
    void $ displayMore ColorFull "The team is under AI control (ESC to stop)."
  else
    msgAdd msg
  -- State and client state now valid.
  debugPrint $ "UI client" <+> tshow side <+> "started."
  loop
  debugPrint $ "UI client" <+> tshow side <+> "stopped."
 where
  loop = do
    cmd <- receiveResponse
    cmdClientUISem cmd
    quit <- getsClient squit
    unless quit loop