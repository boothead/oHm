{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Ohm.Component
  (
    Processor(..)
  , Component(..)
  , appModel
  , runComponent
  ) where

import Control.Monad.Trans.Reader
import Control.Monad.State
import MVC
import Ohm.HTML (Renderer, domChannel, newTopLevelContainer, renderTo)

newtype Processor edom ein m = Processor
  { 
    runProcessor :: edom -> Producer ein m ()
  } deriving (Monoid)

data Component env ein model edom = Component {
   
    -- | The processing function of a 'Model' for this component
    model :: ein -> model -> model
    
    -- | A renderer for 'Model' creating 'HTML' produces 'DOMEvent's
  , render :: Renderer edom model
  
    -- | A processor of events emitted from the UI
    --
    -- This has the choice of feeding events back into the model
  , domEventsProcessor :: Processor edom ein (ReaderT env IO)
  }

appModel :: (e -> m -> m) ->  Model m e m
appModel fn = asPipe $ forever $ do
  m <- await
  w <- lift $ get
  let w' = fn m w
  lift $ put w'
  yield w'
  

runComponent
  ::  forall model env ein edom. (Show model)
  => model 
  -> env
  -> Component env ein model edom
  -> IO (Output ein)
runComponent s env Component{..} = do
  (domSink, domSource) <- spawn Unbounded
  (modelSink, modelSource) <- spawn Unbounded
  
  runEvents $ for (fromInput domSource) (runProcessor domEventsProcessor)
           >-> (toOutput modelSink)
  void . forkIO . void $ runMVC s (appModel model) $ app modelSource domSink
  return modelSink
  where
    runEvents :: Effect (ReaderT env IO) () -> IO ()
    runEvents = void . forkIO . (flip runReaderT $ env) . runEffect
    app :: Input ein -> Output edom -> Managed (View model, Controller ein)
    app eventSource domSink = managed $ \k -> do
      let render' = render (domChannel domSink)
      componentEl <- newTopLevelContainer
      renderTo componentEl $ render' s
      k (asSink (debugRender render' componentEl), asInput eventSource)
    --debugRender :: ()
    debugRender f el mdl = do
      print mdl
      renderTo el $ f mdl
      

