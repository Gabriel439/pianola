{-# LANGUAGE OverloadedStrings  #-}
{-# LANGUAGE FlexibleInstances #-}

module Main where

import Prelude hiding (catch,(.),id)
import System.Environment
import Data.Monoid
import Data.Tree
import qualified Data.Text as T
import Network 
import Control.Category
import Control.Monad
import Control.Error
import Control.Applicative
import Control.Proxy

import Pianola.Model.Swing.Driver

checkStatusBar :: (Monad m, ComponentLike c, Treeish (c m)) => (T.Text -> Bool) -> Pianola m LogEntry (c m) ()
checkStatusBar predicate = do
    with (descendants >=> hasName (=="status bar")) $ do
        statusText <- peek text
        logmsg $ "status text is: " <> statusText
        unless (predicate statusText) $ do
            logmsg $ "Unexpected text in status bar: " <> statusText
            pfail
    clickButtonByText (=="clear")

type Test = Pianola Protocol LogEntry (GUI Protocol) ()

testCase:: Test
testCase = with mainWindow $ do
    toFront
    with contentsPane $ do 
        poke $ descendants >=> hasText (=="En un lugar de la Mancha") 
                           >=> setText "Lorem ipsum dolor sit amet"
        checkStatusBar (=="Lorem ipsum dolor sit amet")
        poke $ descendants >=> hasText (=="open dialog") >=> click
        with window $ with childWindow $ with contentsPane $ do
            clickButtonByText (=="close dialog")
        logmsg "testing right click"
        rightClickByText (=="This is a label")
        logmsg "finding popup..."
        sleep 1
        pmaybe pfail $ retryPoke1s 4 $ window >=> popupItem >=> hasText (=="popupitem2") >=> click  
        checkStatusBar (=="clicked on popupitem2")
        sleep 1
    logmsg "foo log message"
    selectInMenuBar (Just True) $ map (==) ["Menu1","SubMenu1","submenuitem2"]
    logmsg "getting a screenshot"
    logcapture
    logmsg "now for a second menu"
    autolog $ selectInMenuBar Nothing $ map (==) ["Menu1","SubMenu1","submenuitem1"]
    sleep 2
    ralentize 2 $ with contentsPane $ do 
        logmsg "ralentizing dialog-related actions by two seconds"
        clickButtonByText (=="open dialog")
        with window $ with childWindow $ with contentsPane $ do
            clickButtonByText (=="click this")
            clickButtonByText (=="close dialog")
        checkStatusBar (=="clicked button in dialog")
    logmsg "opening a file chooser"
    with (contentsPane >=> descendants >=> hasText (=="Open file chooser")) $ do
        poke click
        with window $ with childWindow $ with contentsPane $ do
            poke $ descendants >=> hasText (=="") >=> setText "/tmp/foofile.txt"   
            clickButtonByText $ \txt -> or $ map (txt==) ["Open","Abrir"]
        sleep 1
    logmsg "working with a combo box"
    with contentsPane $ with descendants $ do 
        logmsg "this should show the combo"
        selectInComboBox (=="ccc")
        sleep 2
        selectTabByText (=="tab two")  
        sleep 2
        poke $ \g -> do
            Table ll <- return . cType $ g
            cell <- replusify . concat $ ll
            descendants . renderer >=> hasText (=="7") $ cell
            return $ clickCell cell
        sleep 2
        poke $ \g -> do
            Table ll <- return . cType $ g
            cell <- replusify . concat $ ll
            descendants . renderer >=> hasText (=="4") $ cell
            return $ doubleClickCell cell
        sleep 2
        poke $ \g -> do    
            Table {} <- return . cType $ g 
            children >=> hasText (=="4") >=> setText "77" $ g
        sleep 2
        selectTabByText (=="tab JTree a")  
        logmsg "tab change"
        sleep 2
        poke $ \g -> do    
            Treegui forest <- return . cType $ g
            cell <- replusify >=> descendants $ forest
            descendants . renderer . rootLabel >=> hasText (=="leaf a") $ cell
            (justZ . expand . rootLabel $ cell) <*> pure True
        sleep 2
        selectTabByText (=="labels")
    with contentsPane $ do
        sleep 1
        poke $ labeledBy (=="label2") >=> setText "hope this works!"
        sleep 2 
    close

main :: IO ()
main = do
  args <- getArgs 
  let addr = head args
      port = PortNumber . fromIntegral $ 26060
      endpoint = Endpoint addr port

  r <- runEitherT $ simpleSwingDriver endpoint testCase $ screenshotStream "/tmp"
  putStrLn $ "result: " <> case r of 
     Left err -> show err
     Right _ -> "all ok" 

