
# oHm Om with Haskell in the middle

Om is awesome. oHm is a hommage to Om in GHCJS using Haskell's pipes,
mvc and pipes-concurrent libraries.

## Introduction

Ohm at its core is the idea of building an application as a pure left
fold over a stream of events. At a previous position we built a UI
that captured this model in clojurescript and Om, this is a port of
that architectural idea to Haskell.

### Set up

### Concepts

1.  Models

    Models are the state of your application. Here's the Model from the
    todo mvc example mentioned later:
    
    1.  State
    
            data ToDo = ToDo
              { _items :: [Item]
              , _editText :: String
              , _filter :: Filter
              } deriving Show
        
        In addition to the model you also need a updating function of type
        `mdlEvent -> model -> model` which is a left fold function that
        applies a to the Model resulting in the new Model. This
        function is one of the things you need to construct a .
    
    2.  <a id="fold" name="fold"></a>Fold
    
        Here's the model function from our todo mvc example:
        
            process :: Action -> ToDo -> ToDo
            process (NewItem str) todo = todo &~ do
               items %= (Item str False:)
               editText .= ""
            process (RemoveItem idx) todo = todo & items %~ deleteAt idx
            process (SetEditText str) todo = todo & editText .~ str
            process (SetCompleted idx c) todo = todo & items.element idx.completed .~ c
            process (SetFilter f) todo = todo & filter .~ f
        
        Note that MVC, one of the libraries that oHm is built on has a concept
        of a model too. In MVC Model refers to the pure transformation that
        happens within a Pipe and applies an event to the state to produce a
        new state. In oHm construction of an MVC Model happens with the
        `appModel` function that the `runComponent` function applies for you.

2.  Model Events

    Model Events represent events that happen in your domain to effect
    change to the state of the world. This is the `Action` type mentioned
    in the event -> model -> model function earlier:
    
        
        data Action
          = NewItem String
          | RemoveItem Index
          | SetEditText String
          | SetCompleted Index Bool
          | SetFilter Filter

3.  UI Events

    UI Events occur at the points of interaction between user and your
    app. These are the sorts of things that you'd attach callbacks to:
    changes, clicks, mouse moves etc. A `DOMEvent` type is provided to
    1.1.2.5 for these events.
    
    For simpler apps, like our todo mvc example, the UI could emit events
    which are passed straight through to the model.

4.  Processors

    Processors consume events of one type, say UI Events and produce
    Events of another type, with the ability to perform actions in some
    Monad. These are used to process the UI Events that a Component emits
    into a form that that component's model can use to update its state.
    
    In our simple todo mvc example, as we're using the same type for UI
    Events and Model Event, there's no processing and events are just
    passed straight through using the idProcessor.

5.  Renderers

    A Renderer is a function of type `DOMEvent a -> model -> HTML` where
    HTML is a virtual-dom representation of the UI.
    
    This is the top level `Renderer` from  todo mvc:
    
        
        todoView :: DOMEvent Action -> ToDo -> HTML
        todoView chan todo@(ToDo itemList _txtEntry currentFilter) =
          with div
            (classes .= ["body"])
            [ titleRender, itemsRender, renderFilters chan todo]
          where
          titleRender = with h1 (classes .= ["title"]) ["todos"]
          itemsRender = with ul (classes .= ["items"])
            (newItem chan todo : (P.map (renderItem chan) $ zip [0..] filteredItems))
          filteredItems = filterItems currentFilter itemList
    
    In this example `renderFilters`, `newItem`, and `renderItem` are all
    `Renderers` that each render a sub part of the UI
    
    One other point of interest is how `DOMEvents` work if we take the
    example of onInput:
    
        onInput :: MonadState HTML m => DOMEvent String -> m ()
    
    In our `newItem` Renderer
    
        newItem :: DOMEvent Action -> ToDo -> HTML  
        newItem chan todo =
          with li (classes .= ["newItem"])
            [ into form
              [ with input (do
                     attrs . at "placeholder" ?= "Create a new task"
                     props . at "value" ?= value
                     onInput $ contramap SetEditText chan)
                     []
                , with (btn click "Create") (attrs . at "hidden" ?= "true") ["Create"]
              ]
            ]
          where
          value = (todo ^. editText.to toJSString)
          click = (const $ (channel chan) $ NewItem (todo ^. editText))
    
    we only have a `DOMEvent Action` available to accept UI Events,
    whereas onInput takes a `DOMEvent String` so we need to adapt the
    `DOMEvent` passed to `newItem` to be one that takes a `String` for
    passing to `onInput`. `DOMEvent` happens to be an instance of the
    `Contravariant` class. You can thing of the `contramap` function being
    like an `fmap`, but applying its function to the input of something
    rather than the content.
    
        f :: String -> Action
        f = SetEditText
        -- We have a DOMEvent Action
        -- We want a DOMEvent String
        -- fmap   :: (a -> b) -> f a -> f b 
        contramap :: (a -> b) -> f b -> f a
        contramap :: (String -> Action) -> DOMEvent Action -> DOMEvent String

6.  Components

    A component packages up the three things that you provide into
    something that the framework can run, with an extra environment in
    `ReaderT` that the processor can use within its actions to route
    events that have an external effect (for example REST requests or
    socket.io calls)
    
        
        modelComp :: Component () Action ToDo Action
        modelComp = Component process todoView idProcessor
        
        main :: IO ()
        main = void $ runComponent initialToDo () modelComp

## Examples

### Todo MVC

<http://todomvc.com/>
The canonnical TODO MVC example demonstrates the basic moving parts of
oHm

### Socket.IO Chat

The socket.io example is a bit more involved and adds some new
concepts illustrating nesting components by adapting the types of processors
