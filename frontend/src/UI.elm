module UI exposing (..)

import Element exposing (..)
import Element.Background as Background
import Element.Font as Font
import Html
import Material.Icons.Types exposing (Coloring(..))
import Palette exposing (..)



-- ICONS


type alias Icon msg =
    Int -> Coloring -> Html.Html msg


icon : Int -> Icon msg -> Element msg
icon size name =
    Element.html (name size Inherit)


heading : String -> Element msg
heading heading_ =
    paragraph [ Font.size normal ] [ text heading_ ]


subHeading : String -> Element msg
subHeading heading_ =
    paragraph [ Font.size smallNormal ] [ text heading_ ]


inputHint : Color -> Element a -> Attribute a
inputHint background hint =
    inFront <|
        el
            [ centerY
            , alignRight
            , Background.color background
            , paddingXY xSmall 0
            ]
            hint


viewFactTable : List (Attribute a) -> List (Attribute a) -> List { f | key : Element a, value : Element a } -> Element a
viewFactTable tableStyles cellStyles data =
    Element.table tableStyles
        { data = data
        , columns =
            [ { header = none
              , width = shrink
              , view =
                    \i ->
                        i.key
              }
            , { header = none
              , width = fill
              , view =
                    \i ->
                        el cellStyles <| i.value
              }
            ]
        }


viewContact : Element msg
viewContact =
    row [ centerX ]
        [ newTabLink [ centerX ]
            { url = "https://t.me/florianpieperstaking"
            , label =
                image
                    [ width <| px large
                    , mouseOver
                        [ alpha 0.9
                        ]
                    ]
                    { src = "images/Telegram_2019_simple_logo.svg", description = "Telegram logo" }
            }
        ]


viewFooter : Element msg
viewFooter =
    column
        [ centerX
        , paddingEach { top = 0, bottom = xLarge, left = normal, right = normal }
        , spacing small
        ]
        [ paragraph [ Font.center ] [ text "Radix Staking powered by Florian Pieper Staking" ]
        , el [ centerX ] <| text "2021"
        ]
