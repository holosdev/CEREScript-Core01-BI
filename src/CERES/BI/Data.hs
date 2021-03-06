module CERES.BI.Data where


import           Data.Function
import           Data.IntMap                    ( IntMap )
import qualified Data.IntMap                   as IM
import           Data.Set                       ( Set )

import           TextShow


import           Data.CERES.Data
import           Data.CERES.Type

import           CERES.BI.Data.Environment
import           CERES.BI.Type


-- | World stores everything
data World = World
  { worldSpools    :: Spools
  , worldValueList :: ValueList
  , worldState     :: WorldState
  , worldSITable   :: SpoolInstanceTable
  , worldTime      :: {-# UNPACK #-} !Time
  , worldTSSize    :: {-# UNPACK #-} !InternalTime
  } deriving Show

blankWorld = World
  { worldSpools    = IM.empty
  , worldValueList = IM.empty
  , worldState     = WorldState { evaluatedSpan = Nothing
                                , worldHistory  = IM.empty
                                , worldNHistory = IM.empty
                                , worldVars     = blankVM
                                , worldNVars    = blankVNM
                                , worldDict     = blankVM
                                , worldNDict    = blankVNM
                                , worldRG       = blankRG
                                }
  , worldSITable   = IM.empty
  , worldTime      = 0
  , worldTSSize    = 0
  }


type SpoolInstanceTable = IntMap SpoolInstanceRow

-- No Branch World yet
data WorldState = WorldState
  { evaluatedSpan :: TimeSpan
  , worldHistory  :: HistoricalTable
  , worldNHistory :: NHistoricalTable
  , worldVars     :: Variables
  , worldNVars    :: NVariables
  , worldDict     :: Dictionary
  , worldNDict    :: NDictionary
  , worldRG       :: RG
  } deriving (Show, Eq)

type TimeSpan = Maybe (Time, Time)
type HistoricalTable = IntMap EpochRow
type NHistoricalTable = IntMap NEpochRow
data EpochRow = EpochRow
  { eRowTime :: {-# UNPACK #-} !Time
  , values   :: Values
  } deriving (Show, Eq)
data NEpochRow = NEpochRow
  { nERowTime :: {-# UNPACK #-} !Time
  , nValues   :: NValues
  } deriving (Show, Eq)

type Values = ValueMap
type NValues = ValueNMap
type Dictionary = Values
type NDictionary = NValues
type Variables = Values
type NVariables = NValues

-- | Spools contains every spool code
type Spools = IntMap Spool
type Spool = CERESSpool

data CERESSpool = CERESSpool
  { csID              :: {-# UNPACK #-} !ID -- NOTE: ID of Spool code, not instance
  , csName            :: Name
  , csScript          :: Maker (World,Env) CEREScript CEREScript
  , csSINameMaker     :: Maker (World,Env) CEREScript Name
  , csSIReadVPMaker   :: Maker (World,Env) CEREScript (Set VPosition)
  , csSIWriteVPMaker  :: Maker (World,Env) CEREScript (Set VPosition)
  , csSIPriorityMaker :: Maker (World,Env) CEREScript Priority
  , csInitLocalVars   :: ValueMap
  , csInitLocalNVars  :: ValueNMap
  , csInitLocalTemp   :: ValueMap
  , csInitLocalNTemp  :: ValueNMap
  }

instance Eq CERESSpool where
  (==) = (==) `on` csID

instance Ord CERESSpool where
  compare = compare `on` csID

instance Show CERESSpool where
  show = toString . showb

instance TextShow CERESSpool where
  showb CERESSpool {..} =
    fromText "Spool(" <> showb csID <> fromText "): " <> fromText csName

data SpoolInstanceRow = SIRow
  { siRowTime :: Time
  , sis       :: SpoolInstances
  } deriving Show

type SpoolInstances = IntMap SpoolInstance

data SpoolInstance = SI
  { siID          :: {-# UNPACK #-} !ID
  , siName        :: Name
  , siPriority    :: {-# UNPACK #-} !Priority
  , siElapsedTime :: !Time
  , siRWVPSet     :: Set VPosition -- Only World, Dict, Var
  , siLocalVars   :: LocalVariables
  , siLocalNVars  :: LocalNVariables
  , siLocalTemp   :: LocalTemp
  , siLocalNTemp  :: LocalNTemp
  , siSpoolID     :: {-# UNPACK #-} !ID
  , siParentSIID  :: {-# UNPACK #-} !ID
  , siRestScript  :: CEREScript
  , siRG          :: RG
  , siF           :: World -> World
  }

instance Eq SpoolInstance where
  (==) = (==) `on` siID

instance Ord SpoolInstance where
  compare siA siB = if pCompared == EQ
    then (compare `on` siID) siA siB
    else pCompared
   where
    pCompared :: Ordering
    pCompared = (compare `on` siPriority) siA siB

instance Show SpoolInstance where
  show = toString . showb

instance TextShow SpoolInstance where
  showb SI {..} =
    fromText "SI("
      <> showb siID
      <> fromText "): "
      <> fromText siName
      <> fromText " <"
      <> showb siPriority
      <> fromText "> Based on Spool("
      <> showb siSpoolID
      <> ")"

data SIParams = SIParams
  { siIS :: SIIS
  }

type SIStatus = (SIParams, SpoolInstance)

type SIIS = SpoolInstanceInheritStatus
-- NOTE: SIJump takes relative time-slot
data SpoolInstanceInheritStatus = SIJump Int | SIEnd


type Input = (World, SpoolInstance, Env)
