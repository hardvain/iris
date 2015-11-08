{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeSynonymInstances #-}

-- | Utility module for functional reactive programming.

module Iris.Reactive
       ( Observable (..)
       , Subject (..)
       , asObservable
       , behavior
       , currentValue
       , event
       , handler
       , mapObservableIO
       , subject
       , tVarSubject
       ) where

import           Control.Concurrent.STM
import           Control.Lens
import           Control.Monad (void, (>=>))
import           Reactive.Banana
import           Reactive.Banana.Frameworks


-- | Wrapper around Event/Behavior pairs. Usually created in lieu of just an
-- Event when there is a meaningful value over time that is associated with the
-- event, like the cursor position or the window size.
data Observable a = Observable
  { _observableBehavior :: Behavior a
  , _observableEvent    :: Event a
  }
makeFields ''Observable


-- | Wrapper around a triple of Behavior, Event, and Handler. This is useful
-- over an `Observable` when the value of the Behavior is meant to be set from
-- the outside.
data Subject a = Subject
  { _subjectBehavior :: Behavior a
  , _subjectEvent    :: Event a
  , _subjectHandler  :: Handler a
  }
makeFields ''Subject

-- | Get current value of an object with a behavior.
currentValue :: (HasBehavior s (Behavior a)) => s -> MomentIO a
currentValue s = valueB $ s ^. behavior

-- | Create subject from initial value
subject :: a -> MomentIO (Subject a)
subject x0 =
  do (e, h) <- newEvent
     b <- stepper x0 e
     return $ Subject b e h

-- | View a subject as an observable. This makes the behavior/event pair
-- "read-only", as it hides the Handler to trigger the event.
asObservable :: Subject a -> Observable a
asObservable s = Observable (s ^. behavior) (s ^. event)

-- | Create a new Observable by mapping an IO function over the old observable.
mapObservableIO :: Observable a -> (a -> IO b) -> MomentIO (Observable b)
mapObservableIO o f =
  do v0 <- currentValue o
     x0 <- liftIO $ f v0
     s  <- subject x0
     reactimate $ (f >=> (s ^. handler)) <$> o ^. event
     return (asObservable s)

-- | Wrap a TVar with a reactive-banana Behavior/Event/Handler. Note that this
-- works only when the TVar is changed with the given Handler.
tVarSubject :: TVar a -> MomentIO (Subject a)
tVarSubject tvar =
  do currentVal <- liftIO $ readTVarIO tvar
     s <- subject currentVal
     reactimate $ (void . atomically . writeTVar tvar) <$> s ^. event
     return s
