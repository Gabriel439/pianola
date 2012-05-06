{-# LANGUAGE TemplateHaskell #-}

module Main where

import Prelude hiding (catch,(.))
import System.IO
import System.Environment
import System.Console.GetOpt
import Data.Char
import qualified Data.Map as M
import Data.List
import Data.Lens.Common
import Data.Lens.Template
import Data.Default
import qualified Data.Text as T
import Control.Category
import Control.Monad
import Control.Monad.Error
import Control.Applicative
import Control.Exception

import Blaze.ByteString.Builder
import Data.MessagePack
import Data.MessagePack.Object
import Network.MessagePackRpc.Client
import Control.Concurrent
import Control.Monad
 
data Component = Component
    {
        _className::T.Text,
        _pos::(Int,Int),
        _dim::(Int,Int),
        _children::[Component]
    } deriving Show

instance Unpackable Component where
    get = undefined 

instance Packable Component  where
    from _ = undefined

instance OBJECT Component where
    toObject _ = undefined
    tryFromObject (ObjectArray arr) =   
        case arr of
          [o1, o2, o3, o4] -> do
            v1 <- tryFromObject o1
            v2 <- tryFromObject o2
            v3 <- tryFromObject o3
            v4 <- tryFromObject o4
            return (Component v1 v2 v3 v4)
          _ -> tryFromObjectError
    tryFromObject _ = tryFromObjectError

data Window = Window 
    {
        _windowTitle::T.Text,
        _windowDim::(Int,Int),
        _topc::Component,
        _ownedWindows::[Window]
    } deriving Show            

instance Unpackable Window where
    get = undefined 

instance Packable Window where
    from _ = undefined

instance OBJECT Window where
    toObject _ = undefined
    tryFromObject (ObjectArray arr) =   
        case arr of
          [o1, o2, o3, o4] -> do
            v1 <- tryFromObject o1
            v2 <- tryFromObject o2
            v3 <- tryFromObject o3
            v4 <- tryFromObject o4
            return (Window v1 v2 v3 v4)
          _ -> tryFromObjectError
    tryFromObject _ = tryFromObjectError
        
tryFromObjectError :: Either String a
tryFromObjectError = Left "tryFromObject: cannot cast"       
        
hello :: RpcMethod (T.Text -> Int -> IO [Window])
hello = method "hello"
 
main :: IO ()
main = do
  args <- getArgs 
  conn <- connect (head args) 26060
  wlist <- hello conn (T.pack "hello") 4
  mapM_ (putStrLn . show) wlist

