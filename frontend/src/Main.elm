module Main exposing (..)

import Browser
import Browser.Events
import Browser.Navigation as Nav
import Element exposing (..)
import Element.Background as Background
import Element.Font as Font
import Page.Home
import Page.Validators
import Palette exposing (..)
import Ports
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), oneOf, parse, s, top)



-- MAIN


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , page : PageModel
    , device : Device
    }


type PageModel
    = NoPage
    | PageHome Page.Home.Model
    | PageValidators Page.Validators.Model


type alias Flags =
    { width : Int
    , height : Int
    }


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        device =
            Element.classifyDevice flags

        ( pageModel, pageCmd ) =
            initByUrl url
    in
    ( { key = key
      , url = url
      , page = pageModel
      , device = device
      }
    , pageCmd
    )


initPage : ( b, Cmd a ) -> (b -> c) -> (a -> msg) -> ( c, Cmd msg )
initPage pageInit pageModelConstructor pageMsgConstructor =
    let
        ( model, cmd ) =
            pageInit
    in
    ( pageModelConstructor model, Cmd.map pageMsgConstructor cmd )


initHome : ( PageModel, Cmd Msg )
initHome =
    initPage Page.Home.init PageHome HomeMsg


initValidators : ( PageModel, Cmd Msg )
initValidators =
    initPage Page.Validators.init PageValidators ValidatorsMsg


initByUrl : Url -> ( PageModel, Cmd Msg )
initByUrl url =
    let
        route =
            parse routeParser url
    in
    case route of
        Nothing ->
            initHome

        Just RouteHome ->
            initHome

        Just RouteValidators ->
            initValidators



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | DeviceClassified Device
    | HomeMsg Page.Home.Msg
    | ValidatorsMsg Page.Validators.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.page ) of
        ( LinkClicked urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        ( UrlChanged url, _ ) ->
            let
                ( page, cmd ) =
                    initByUrl url
            in
            ( { model | url = url, page = page }
            , Cmd.batch [ Ports.setMetaDescription "", cmd ]
            )

        ( DeviceClassified device, _ ) ->
            ( { model | device = device }, Cmd.none )

        ( HomeMsg subMsg, PageHome subModel ) ->
            Page.Home.update subMsg subModel
                |> updatePage HomeMsg PageHome model

        ( ValidatorsMsg subMsg, PageValidators subModel ) ->
            Page.Validators.update subMsg subModel
                |> updatePage ValidatorsMsg PageValidators model

        _ ->
            ( model, Cmd.none )


updatePage :
    (subMsg -> msg)
    -> (subModel -> pageModel)
    -> { model | page : pageModel }
    -> ( subModel, Cmd subMsg )
    -> ( { model | page : pageModel }, Cmd msg )
updatePage msgConstructor modelConstructor model ( subModel, subMsg ) =
    ( { model | page = modelConstructor subModel }, Cmd.map msgConstructor subMsg )



-- ROUTE


type Route
    = RouteHome
    | RouteValidators


routeParser : Parser.Parser (Route -> a) a
routeParser =
    oneOf
        [ Parser.map RouteHome top
        , Parser.map RouteValidators (s "validators")
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Browser.Events.onResize <|
        \width height ->
            DeviceClassified (Element.classifyDevice { width = width, height = height })



-- VIEW
-- VIEW MAIN


viewPage : Device -> PageModel -> Element Msg
viewPage device page =
    case page of
        NoPage ->
            none

        PageHome subModel ->
            Element.map HomeMsg <| Page.Home.view device subModel

        PageValidators subModel ->
            Element.map ValidatorsMsg <| Page.Validators.view device subModel



-- Amatic SC


view : Model -> Browser.Document Msg
view model =
    { title = "Florian Pieper Staking"
    , body =
        [ layoutWith
            { options =
                [ focusStyle
                    { borderColor = Nothing
                    , backgroundColor = Nothing
                    , shadow = Nothing
                    }
                ]
            }
            [ Font.family
                [ Font.typeface "Roboto Mono"
                , Font.sansSerif
                ]
            , Background.color lightShades
            , Font.letterSpacing 1
            , Font.color <| blackAlpha 1
            , Font.size small
            ]
          <|
            column [ width fill ]
                [ viewPage model.device model.page
                ]
        ]
    }
