{-# LANGUAGE CPP #-}
-- | Re-export the operations of the chosen raw frontend
-- (determined at compile time with cabal flags).
module Game.LambdaHack.Client.UI.Frontend.Chosen
  ( RawFrontend(..), chosenStartup, stdStartup, nullStartup
  , frontendName
  ) where

import Control.Concurrent
import qualified Game.LambdaHack.Client.Key as K
import Game.LambdaHack.Client.UI.Animation (SingleFrame (..))
import Game.LambdaHack.Common.ClientOptions

#ifdef VTY
import qualified Game.LambdaHack.Client.UI.Frontend.Vty as Chosen
#elif CURSES
import qualified Game.LambdaHack.Client.UI.Frontend.Curses as Chosen
#else
import qualified Game.LambdaHack.Client.UI.Frontend.Gtk as Chosen
#endif

import qualified Game.LambdaHack.Client.UI.Frontend.Std as Std

-- | The name of the chosen frontend.
frontendName :: String
frontendName = Chosen.frontendName

data RawFrontend = RawFrontend
  { fdisplay      :: Maybe SingleFrame -> IO ()
  , fpromptGetKey :: SingleFrame -> IO K.KM
  , fsyncFrames   :: IO ()
  , fescMVar      :: !(Maybe (MVar ()))
  , fdebugCli     :: !DebugModeCli
  }

chosenStartup :: DebugModeCli -> (RawFrontend -> IO ()) -> IO ()
chosenStartup fdebugCli cont =
  Chosen.startup fdebugCli $ \fs ->
    cont RawFrontend
      { fdisplay = Chosen.fdisplay fs
      , fpromptGetKey = Chosen.fpromptGetKey fs
      , fsyncFrames = Chosen.fsyncFrames fs
      , fescMVar = Chosen.sescMVar fs
      , fdebugCli
      }

stdStartup :: DebugModeCli -> (RawFrontend -> IO ()) -> IO ()
stdStartup fdebugCli cont =
  Std.startup fdebugCli $ \fs ->
    cont RawFrontend
      { fdisplay = Std.fdisplay fs
      , fpromptGetKey = Std.fpromptGetKey fs
      , fsyncFrames = Std.fsyncFrames fs
      , fescMVar = Std.sescMVar fs
      , fdebugCli
      }

nullStartup :: DebugModeCli -> (RawFrontend -> IO ()) -> IO ()
nullStartup fdebugCli cont =
  -- Std used to fork (async) the server thread, to avoid bound thread overhead.
  Std.startup fdebugCli $ \_ ->
    cont RawFrontend
      { fdisplay = \_ -> return ()
      , fpromptGetKey = \_ -> return K.escKM
      , fsyncFrames = return ()
      , fescMVar = Nothing
      , fdebugCli
      }
