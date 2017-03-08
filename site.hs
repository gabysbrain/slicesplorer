--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import       Data.Monoid ((<>))
import       Hakyll
import Control.Applicative ((<|>))
import       Control.Monad                   (forM_)
import System.FilePath (replaceExtension, replaceDirectory, takeFileName, takeBaseName)
import Data.List.Split (splitOneOf)
import Data.Strings (strStartsWith)
import           Data.Typeable (Typeable)
import           Data.Binary                   (Binary)

import Debug.Trace

--------------------------------------------------------------------------------

config :: Configuration
config = defaultConfiguration
  { deployCommand = "rsync -avr --delete _site/ torsnet6cs@sliceplorer.cs.univie.ac.at:evaluation_site/"
  }

datasets = ["ackley6d"]
technique = ["ct"]

main :: IO ()
main = hakyllWith config $ do
  match "images/*" $ do
    route   idRoute
    compile copyFileCompiler

  {-match "images/*_*.png" $ version "exImg" $ do-}
    {-route idRoute-}
    {-compile getResourceFilePath-}

  match "css/*.css" $ do
    route   idRoute
    compile compressCssCompiler

  match "css/*.hs" $ do
    route $ setExtension "css"
    compile $ getResourceString >>= withItemBody (unixFilter "runghc" [])

  match "solutions/*.md" $ do
    route $ setExtension "html"
    compile $ do
      exImgs <- loadAll "images/*.png"
      pandocCompiler
        >>= loadAndApplyTemplate "templates/task_solution.html" (exCtx exImgs)
        >>= loadAndApplyTemplate "templates/default.html" defaultContext
        >>= relativizeUrls

  match "tasks/*.md" $ do
    route $ setExtension "html"
    compile $ do
      exImgs <- loadAll "images/*.png"
      exDescs <- loadAll "solutions/*.html"
      pandocCompiler
        >>= loadAndApplyTemplate "templates/task_detail.html" (taskCtx exImgs exDescs)
        >>= loadAndApplyTemplate "templates/default.html" defaultContext
        >>= relativizeUrls

  match "index.html" $ do
    route idRoute
    compile $ do
      getResourceBody
        >>= applyAsTemplate defaultContext
        >>= loadAndApplyTemplate "templates/default.html" defaultContext
        >>= relativizeUrls

  match "templates/*" $ compile templateBodyCompiler


--------------------------------------------------------------------------------
exCtx :: [Item CopyFile] -> Context String
exCtx exImgs = 
  --imgListField "exImages" exImgCtx exImgs <>
  taskField      "task"      <>
  techniqueField "technique" <>
  imgField       "imgUrl"    <>
  defaultContext

dsExCtx :: [Item CopyFile] -> Context String
dsExCtx exImgs = 
  taskField      "task"      <>
  techniqueField "technique" <>
  --imgField       "imgUrl"    <>
  defaultContext

taskCtx :: [Item CopyFile] -> [Item String] -> Context String
taskCtx imgs descs = 
  taskField "name" <>
  datasetListField "datasets" datasetCtx (map makeItem datasets) descs <>
  defaultContext

datasetListField :: String -> [Item String] -> Context String -> [Item String] -> Context b
datasetListField fld descs ctx ds = 
  listFieldWith fld ctx 
  field' fld $ \i ->
    let ctx' = ctx $ filter (\ex -> itemTaskCode ex == itemBody i) descs
     in ListField ctx' ds

  listFieldWith fld ctx $ \i -> -- i here is the task we're looking at
    itemBody i
    --return $ taskExs i descs

taskDataCtx :: Context String
taskDataCtx = defaultContext
  --exImgCtx

{-exImgCtx :: Context CopyFile-}
{-exImgCtx =-}
  {-urlField "url" <>-}
  {-datasetInfoCtx-}

datasetCtx :: Context String
datasetCtx = 
  bodyField "name" <> -- technically this is the name but whatever
  dsInfo
  where
  dsInfo =
    Context $ \f a i ->
      let (Context c) = datasetInfo $ itemBody i
      in c f a i

imgField :: String -> Context String
imgField fld = field fld $ 
  return . itemImgPath

imgListField :: String -> Context CopyFile -> [Item CopyFile] -> Context a
imgListField fld ctx imgs = 
  listFieldWith fld ctx $ \i -> 
    return $ itemImages i imgs

taskField :: String -> Context String
taskField fld = field fld $ 
  return . humanizeTaskCode . itemTaskCode

techniqueField :: String -> Context String
techniqueField fld = field fld $
  return . humanizeTechniqueCode . itemTechniqueCode

itemTaskCode = itemCode 0

itemTechniqueCode = itemCode 1

itemTaskTechniqueCode i =
  itemTaskCode i <> "_" <> itemTechniqueCode i

itemImages i = filter cmp
  where
  cmp = (`strStartsWith` itemTechniqueCode i) 
      . takeBaseName . toFilePath . itemIdentifier

itemImgPath = 
  (`replaceDirectory` "/images/") . (`replaceExtension` "pdf") .
  toFilePath . itemIdentifier

imgTechniqueCode = itemCode 0

imgDataCode = itemCode 1

itemCode pos =
  (!! pos) . splitOneOf "_." . takeFileName . toFilePath . itemIdentifier

humanizeTaskCode :: String -> String
humanizeTaskCode "anomaly"      = "Find anomalies"
humanizeTaskCode "cluster"      = "Cluster"
humanizeTaskCode "correlate"    = "Correlate"
humanizeTaskCode "derive"       = "Derive"
humanizeTaskCode "distribution" = "Distribution"
humanizeTaskCode "extremum"     = "Find extrema"
humanizeTaskCode "filter"       = "Filter"
humanizeTaskCode "lookup"       = "Lookup"
humanizeTaskCode "range"        = "Range"
humanizeTaskCode code           = fail $ "Unknown task code: " <> code

humanizeTechniqueCode :: String -> String
humanizeTechniqueCode "ct" = "Contour tree"
humanizeTechniqueCode "hs" = "HyperSlice"
humanizeTechniqueCode "ms" = "Morse-smale complex (Gerber et al.)"
humanizeTechniqueCode "sp" = "1D slices"
humanizeTechniqueCode "ts" = "Topological spine"
humanizeTechniqueCode code = fail $ "Unknown technique code: " <> code

datasetInfo :: String -> Context a
datasetInfo "sinc2d" =
  constField "name" "Sinc function" <>
  constField "dims" "2"
datasetInfo "ackley6d" =
  constField "name" "Ackley function" <>
  constField "dims" "6"
datasetInfo "rosenbrock" =
  constField "name" "Rosenbrock function" <>
  constField "dims" "5"
datasetInfo "borehole" =
  constField "name" "Borehole" <>
  constField "dims" "8"
datasetInfo "boston-svm" =
  constField "name" "SVM w/ radial basis" <>
  constField "dims" "13"
datasetInfo "boston-nn" =
  constField "name" "Neural network w/ 26 node hidden layer" <>
  constField "dims" "13"
datasetInfo "fuel" =
  constField "name" "Fuel dataset" <>
  constField "dims" "3"
datasetInfo "neghip" =
  constField "name" "Neghip dataset" <>
  constField "dims" "3"
datasetInfo code = mempty

-- combine 2 lists using the key functions
-- FIXME: not efficient at all!
innerJoin :: (Eq c) => (a -> c) -> (b -> c) -> [a] -> [b] -> [(a,b)]
innerJoin k1 k2 l1 l2 =
  concatMap pairKey l1
  where
  pairKey e1 = map (\e2 -> (e1, e2)) $ filter (\e2 -> k1 e1 == k2 e2) l2

