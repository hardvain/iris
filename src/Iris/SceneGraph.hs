{-# LANGUAGE CPP #-}

-- | Compose drawable items into a scene graph.

module Iris.SceneGraph
       ( SceneNode (..)
       , makeScene

       , Effect
       , Visual (..)
       ) where


import           Control.Lens
import           Graphics.Rendering.OpenGL (($=))
import qualified Graphics.Rendering.OpenGL as GL

import           Iris.Backends
import           Iris.Camera
import           Iris.DrawGraph
import           Iris.Reactive
import           Iris.Transformation


-- | Recursive definition of a scene graph tree.
data SceneNode = Collection [SceneNode]
               | Transform (Behavior Transformation) SceneNode
               | EffectNode Effect SceneNode
               | VisualNode Visual


data Visual = Visual
  { drawFunc :: DrawFunc
  }

sceneB :: SceneNode -> Moment (Behavior DrawNode)
sceneB (Collection cs) = do cs' <- mapM sceneB cs
                            return $ groupNode <$> sequenceA cs'
sceneB (Transform bt n) = do n' <- sceneB n
                             return $ transNode <$> bt <*> ((: []) <$> n')
sceneB (VisualNode (Visual f)) = return $ pure $ DrawNode f
sceneB (EffectNode f n) = do n' <- sceneB n
                             return $ effectNode f <$> ((: []) <$> n')

#if !MIN_VERSION_base(4,8,0)
sequenceA :: Applicative f => [f a] -> f [a]
sequenceA = foldr k (pure [])
  where
    k f f' = (:) <$> f <*> f'
#endif

type Effect = IO ()

makeScene :: (Canvas a, Camera c) =>
             a ->
             SceneNode ->
             Maybe c ->
             MomentIO ()
makeScene win n maybeCam =
  do events <- makeEvents win

     -- Initialize camera and attach event handlers
     (root, winEventHandlers) <- attachCam maybeCam events n []
     attachEventHandlers events winEventHandlers

     let bTrans = aspectTrans <$> (events ^. canvasSizeObservable ^. behavior)
         root' = sceneRoot win (Transform bTrans root)

     -- Recurse through the scene graph to hook up the draw event and
     -- transformation behavior to all nodes.
     bGraph <- liftMoment $ sceneB root'
     let eDraw = drawGraph <$> bGraph <@ (events ^. drawEvent)
     reactimate eDraw

-- | If we have a camera, then initialize the reactive form of the camera, set
-- the camera node as root, and make the camera event handler the first event
-- handler.
attachCam :: (Camera c) =>
             Maybe c ->
             CanvasEvents ->
             SceneNode ->
             [CanvasEventHandler] ->
             MomentIO (SceneNode, [CanvasEventHandler])
attachCam maybeCam es n hs =
  case maybeCam of
    Nothing    -> return (n, hs)
    (Just cam) -> do (bCamTrans, camHandler) <- initCamera cam es
                     let n'  = Transform bCamTrans n
                         hs' = camHandler : hs
                     return (n', hs')


sceneRoot :: (Canvas a) => a -> SceneNode -> SceneNode
sceneRoot can = EffectNode (drawRoot can)

drawRoot :: (Canvas a) => a -> IO ()
drawRoot win =
  do winSize <- framebufferSize win
     GL.viewport $= (GL.Position 0 0, winSize)
     GL.scissor $= Just (GL.Position 0 0, winSize)

     GL.clearColor $= GL.Color4 0 0 0 1
     GL.depthFunc $= Just GL.Less
     GL.clear [GL.ColorBuffer, GL.DepthBuffer]
