module Palette exposing (..)

import Element exposing (Color, rgb, rgb255, rgba, rgba255)



-- SPACING


xxxSmall : Int
xxxSmall =
    2


xxSmall : Int
xxSmall =
    4


xSmall : Int
xSmall =
    8


small : Int
small =
    16


smallNormal : Int
smallNormal =
    24


normal : Int
normal =
    32


large : Int
large =
    64


xLarge : Int
xLarge =
    128


xxLarge : Int
xxLarge =
    256



-- COLORS


white : Color
white =
    rgb 1 1 1


whiteAlpha : Float -> Color
whiteAlpha alpha =
    rgba 1 1 1 alpha


black : Color
black =
    rgb 0 0 0


blackAlpha : Float -> Color
blackAlpha alpha =
    rgba 0 0 0 alpha


transparent : Color
transparent =
    rgba 0 0 0 0



-- colormind.io


softPeach : Color
softPeach =
    rgb255 251 248 249


glacier : Color
glacier =
    rgb255 127 186 193


malachite : Color
malachite =
    rgb255 28 230 122


copperRust : Color
copperRust =
    rgb255 154 88 77


cello : Color
cello =
    rgb255 31 54 93



-- https://coolors.co/d7263d-f46036-00fb6b-2e294e-1b998b


spaceCadet : Color
spaceCadet =
    rgb255 46 41 78


blueCrayola : Color
blueCrayola =
    rgb255 0 117 242


crimson : Color
crimson =
    rgb255 215 38 61


portlandOrange : Color
portlandOrange =
    rgb255 244 96 54


lightShades : Color
lightShades =
    softPeach


lightAccent : Color
lightAccent =
    glacier


mainBrand : Color
mainBrand =
    malachite


darkAccent : Color
darkAccent =
    copperRust


darkShades : Color
darkShades =
    spaceCadet
