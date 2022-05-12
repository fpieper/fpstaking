module UI exposing (..)

import Color as ElmColor
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html
import Material.Icons.Types exposing (Coloring(..))
import Palette exposing (..)



-- ICONS


type alias Icon msg =
    Int -> Coloring -> Html.Html msg


icon : Int -> Icon msg -> Element msg
icon size name =
    Element.html (name size Inherit)



-- COLORS


toUiColor : ElmColor.Color -> Color
toUiColor color =
    color
        |> ElmColor.toRgba
        |> (\c -> rgba c.red c.green c.blue c.alpha)


fromUiColor : Color -> ElmColor.Color
fromUiColor color =
    color
        |> toRgb
        |> (\c -> ElmColor.fromRgba { red = c.red, green = c.green, blue = c.blue, alpha = c.alpha })



-- HEADING


heading : String -> Element msg
heading heading_ =
    paragraph [ Font.size normal ] [ text heading_ ]


subHeading : String -> Element msg
subHeading heading_ =
    paragraph [ Font.size smallNormal ] [ text heading_ ]



-- INPUT


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



-- TABLE


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
        , el [ centerX ] <| text "2022"
        ]



-- SLIDER


sliderStyle =
    [ Element.height (Element.px 30)

    -- Here is where we're creating/styling the "track"
    , Element.behindContent
        (Element.el
            [ Element.width Element.fill
            , Element.height (Element.px 1)
            , Element.centerY
            , Background.color darkShades
            , Border.rounded 0
            ]
            Element.none
        )
    ]


thumb : Input.Thumb
thumb =
    Input.thumb
        [ Element.width (Element.px 16)
        , Element.height (Element.px 16)
        , Border.rounded 8
        , Background.color darkShades
        ]
