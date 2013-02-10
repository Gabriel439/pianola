{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE UndecidableInstances #-}

module Pianola.Model.Swing (
        GUI (..),
        Window (..),
        WindowInfo (..),
        Component (..),
        ComponentInfo (..),
        ComponentType (..),
        Cell (..),
        Tab (..),
--        menuflat,
--        popupflat,
--        contentsflat,
--        contentsflat',
        cType,
        titled,
        hasText,
        hasToolTip,
        hasName,
        click,
        toggle,
        clickCombo,
        listCell,
        tab,
        setText,
        mainWindow,
        childWindow,
        contentsPane,
        windowComponents,
        popupLayerComponents,
        selectInMenuBar
    ) where

import Prelude hiding (catch,(.))
import Data.Tree
import Data.ByteString (ByteString)
import qualified Data.Text as T
import Control.Category
import Control.Error
import Control.Error.Safe
import Control.Monad
import Control.Applicative
import Control.Monad
import Control.Monad.Base
import Control.Monad.Trans.Class
import Data.Sequence (ViewL(..),ViewR(..),viewl,viewr,fromList)
import Data.Foldable (toList)

import Pianola
import Pianola.Util
import Pianola.Geometry

type GUI m = Forest (WindowInfo m)

type Window m = Tree (WindowInfo m)

data WindowInfo m = WindowInfo 
    {
        _windowTitle::T.Text,
        _windowDim::(Int,Int),
        _menu::[Component m],
        _popupLayer:: [Component m],
        _contentsPane::Component m,
        _image::Nullipotent m Image,
        _escape::Sealed m,
        _close::Sealed m
    } 

type Component m = Tree (ComponentInfo m)

data ComponentInfo m = ComponentInfo 
    {
        _pos::(Int,Int),
        _dim::(Int,Int),
        _name::Maybe T.Text,
        _tooltip::Maybe T.Text,
        _text::Maybe T.Text,
        _enabled::Bool,
        _componentType::ComponentType m,
        _rightClick::Sealed m
    } 

data ComponentType m =
     Panel
    |Toggleable Bool (Bool -> Sealed m)
    |Button (Sealed m)
    |TextField (Maybe (T.Text -> Sealed m)) -- Nothing if not editable
    |Label
    |ComboBox (Maybe (Component m)) (Sealed m)
    |List [Cell m]
    |Table [[Cell m]]
    |Treegui (Forest (Cell m))
    |PopupMenu  
    |TabbedPane [Tab m]
    |Other T.Text

data Cell m = Cell 
    {
        renderer::Component m,
        clickCell::Sealed m,
        doubleClickCell::Sealed m,
        expand:: Maybe (Bool -> Sealed m)
    }

data Tab m = Tab
    {
        tabText::T.Text,
        tabTooltip::Maybe T.Text,
        isTabSelected:: Bool,
        selectTab::Sealed m
    }

cType:: Monad m => Glance m l (Component m) (ComponentType m)
cType = return._componentType.rootLabel

titled:: MonadPlus m => (T.Text -> Bool) -> Window n -> m (Window n)
titled f w = do
    guard . f $ _windowTitle . rootLabel $ w  
    return w

--menuflat:: MonadPlus m => WindowInfo n -> m (ComponentInfo n)
--menuflat = forestflat . _menu
-- 
--popupflat:: MonadPlus m => WindowInfo n -> m (ComponentInfo n)
--popupflat = forestflat . _popupLayer
-- 
--contentsflat:: MonadPlus m => WindowInfo n -> m (ComponentInfo n)
--contentsflat =  treeflat . _contentsPane
-- 
--contentsflat':: MonadPlus m => WindowInfo n -> m (Component n)
--contentsflat' =  treeflat' . _contentsPane
--
--wholewindowflat::MonadPlus m => WindowInfo n -> m (ComponentInfo n)
--wholewindowflat w = msum $ map ($w) [menuflat,popupflat,contentsflat]

hasText:: MonadPlus m => (T.Text -> Bool) -> Component n -> m (Component n)
hasText f c = do
    t <- justZ._text.rootLabel $ c 
    guard $ f t
    return c
 
hasToolTip:: MonadPlus m => (T.Text -> Bool) -> Component n -> m (Component n)
hasToolTip f c = do
    t <- justZ._tooltip.rootLabel $ c 
    guard $ f t
    return c

hasName:: MonadPlus m => (T.Text -> Bool) -> Component n -> m (Component n)
hasName f c = do
    t <- justZ._name.rootLabel $ c 
    guard $ f t
    return c

-- image::MonadBase n m => WindowInfo n -> m Image
-- image = liftBase . _image
-- 
-- close::MonadBase n m => WindowInfo n -> m (GUI n)
-- close = liftBase . _close
-- 
-- escape::MonadBase n m => WindowInfo n -> m (GUI n)
-- escape = liftBase . _escape
-- 
-- 
toggle:: MonadPlus n => Bool -> Component m -> n (Sealed m)
toggle b (_componentType.rootLabel -> Toggleable _ f) = return $ f b
toggle _ _ = mzero

-- 
-- 
click:: MonadPlus n => Component m -> n (Sealed m)
click (_componentType.rootLabel -> Button a) = return a
click _ = mzero

doClickByText :: (Functor m, Monad m) => (T.Text -> Bool) -> Pianola m l (Component m) ()
doClickByText txt = poke $ hasText txt >=> click

clickCombo:: MonadPlus n => Component m -> n (Sealed m)
clickCombo (_componentType.rootLabel -> ComboBox _ a) = return a
clickCombo _ = mzero

listCell:: MonadPlus m => Component n -> m (Cell n)
listCell (_componentType.rootLabel -> List l) = replusify l
listCell _ = mzero

tab:: MonadPlus m => Component n -> m (Tab n)
tab (_componentType.rootLabel -> TabbedPane p) = replusify p
tab _ = mzero




--rightClick:: MonadPlus m => ComponentInfo n -> m ()
--rightClick = liftBase . _rightClick

setText:: MonadPlus m => T.Text -> Component n -> m (Sealed n)
setText txt c = case (_componentType.rootLabel $ c) of
    TextField (Just f) -> return $ f txt
    _ -> mzero

-- end logic helpers
--

mainWindow :: (Functor m, Monad m) => Glance m l (GUI m) (Window m)
mainWindow = headZ  

childWindow :: (Functor m, Monad m) => Glance m l (Window m) (Window m)
childWindow = headZ.subForest

contentsPane :: Monad m => Glance m l (Window m) (Component m)
contentsPane = return._contentsPane.rootLabel 

windowComponents :: (Functor m, Monad m) => Glance m l (Window m) (Component m)
windowComponents = contentsPane >=> descendants 

popupLayerComponents :: (Functor m, Monad m) => Glance m l (Window m) (Component m)
popupLayerComponents = anyOf._popupLayer.rootLabel >=> descendants  

--withWindowTitled = (Functor m, Monad m) => (T.Text -> Bool) -> Pianola m l (Window m) a -> Pianola m l (Component m) a 
--withWindowTitled 

selectInMenuBar:: (Functor m,Monad m) => [T.Text -> Bool] -> Maybe Bool -> Pianola m l (Window m) ()
selectInMenuBar ps shouldToggleLast = 
    let go (firstitem,middleitems,lastitem) = do
           poke $ anyOf._menu.rootLabel >=> descendants >=> hasText firstitem >=> click
           let pairs = zip middleitems (click <$ middleitems) ++
                       [(lastitem, maybe click toggle shouldToggleLast)]
           forM_ pairs $ \(txt,action) -> 
               retryPoke 1 $ replicate 7 $  
                   popupLayerComponents >=> hasText txt >=> action
           when (isJust shouldToggleLast) $ replicateM_ (length pairs) 
                                                  (poke $ return._escape.rootLabel)
        clip l = (,,) <$> headZ l <*> (initZ l >>= tailZ)  <*> lastZ l
    in maybe pianofail go (clip ps)
