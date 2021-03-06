-- | Defines mouse interaction data and functions

module Iris.Mouse
       ( MouseButton (..)
       , MouseButtonState (..)
       , MouseButtonEvent
       ) where


-- | Enum for the mouse buttons used for plot interaction. Many backends define
-- more mouse buttons, and users can manually handle them if they want.
data MouseButton = MouseButtonLeft
                 | MouseButtonRight
                 | MouseButtonMiddle
                 deriving (Show, Eq, Ord)


-- | Simple enum for whether a mouse button is pressed or not.
data MouseButtonState = Pressed
                      | Released
                      deriving (Show, Eq)


-- | Used in backends to report when a mouse button is pressed or released.
type MouseButtonEvent = (MouseButton, MouseButtonState)
