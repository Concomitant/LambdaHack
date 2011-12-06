module Game.LambdaHack.Content.RoomKind
  ( RoomKind(..), Cover(..), rvalidate
  ) where

import qualified Data.List as L

data RoomKind = RoomKind
  { rsymbol  :: Char
  , rname    :: String
  , rfreq    :: Int
  , rcover   :: Cover     -- ^ how to fill whole room based on the corner
  , rfence   :: Bool      -- ^ whether to fence the room with solid border
  , rtopLeft :: [String]  -- ^ plan of the top-left corner of the room
  }
  deriving Show

data Cover =
    CTile     -- ^ tile the corner plan, cutting off at the right and bottom
  | CStretch  -- ^ fill symmetrically all corners and stretch their borders
  | CReflect  -- ^ tile separately and symmetrically the quarters of the room
  deriving Show

rvalidate :: [RoomKind] -> [RoomKind]
rvalidate = L.filter (\ RoomKind{..} ->
  let dxcorner = case rtopLeft of [] -> 0 ; l : _ -> L.length l
  in dxcorner == 0 || L.any (/= dxcorner) (L.map L.length rtopLeft))
