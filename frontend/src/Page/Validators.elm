module Page.Validators exposing (..)

import BigInt exposing (BigInt)
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input exposing (thumb)
import FormatNumber
import FormatNumber.Locales exposing (Decimals(..), usLocale)
import Html exposing (Html)
import Html.Attributes
import Http exposing (emptyBody, jsonBody)
import Json.Decode as Decode exposing (Decoder, andThen, bool, fail, field, int, list, string, succeed)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Json.Encode as Encode
import Loading exposing (Config, LoaderType(..), defaultConfig)
import Material.Icons exposing (check_circle, content_copy, dangerous, remove_circle, sentiment_neutral, sentiment_very_dissatisfied, sentiment_very_satisfied, warning)
import Material.Icons.Outlined exposing (build, cloud_off, face, favorite, language, notifications_active, paid, security)
import Material.Icons.Types exposing (Coloring)
import Palette exposing (..)
import RemoteData exposing (RemoteData(..))
import UI exposing (Icon, heading, icon, inputHint, subHeading, viewContact, viewFactTable, viewFooter)
import Utils exposing (bigIntDivToFloat, bigIntMulFloat, bigIntSum, formatWithDecimals, safeBigInt)



-- MODEL


type alias Model =
    { validators : RemoteData Http.Error (List Validator)
    , totalStake : BigInt
    }


type alias Validator =
    { totalDelegatedStake : BigInt
    , uptimePercentage : Float
    , proposalsMissed : Int
    , address : String
    , infoUrl : String
    , ownerDelegation : BigInt
    , name : String
    , fee : Float
    , registered : Bool
    , ownerAddress : String
    , acceptsExternalStake : Bool
    , proposalCompleted : Int
    , group : Maybe Group
    , rank : Int
    , stakeShare : Float
    }


type alias Group =
    { name : String
    , totalStake : BigInt
    , stakeShare : Float
    }


type alias GroupFull =
    { name : String
    , validators : List Validator
    , totalStake : BigInt
    }


addGroups : List Validator -> List Validator
addGroups validators =
    let
        validatorsByAddress : Dict String Validator
        validatorsByAddress =
            validators
                |> List.map (\v -> ( v.address, v ))
                |> Dict.fromList

        getValidators : List String -> List Validator
        getValidators addresses =
            addresses
                |> List.filterMap
                    (\address -> Dict.get address validatorsByAddress)

        buildGroup : String -> List String -> GroupFull
        buildGroup name addresses =
            let
                groupValidators =
                    getValidators addresses
            in
            { name = name
            , validators = groupValidators
            , totalStake = List.map .totalDelegatedStake groupValidators |> bigIntSum
            }

        groups =
            [ buildGroup "Artistizen"
                [ "rv1qdawnqw6l9dmsx287gvw3nl7tndx8agh9e0hmw24zdxnpdfp267exk8ljwu"
                , "rv1qggt5w4g800k5w3du63g0j86u8ayaqkzdgyxfkw3uc93826zxef22gjr64m"
                , "rv1q0m9329x6tywt3kggatrtr8ut8qvxqw9lsfw2w8phrvvv2qydw9xsk88slq"
                , "rv1q0xq9jg3vcuvelflpdvkcvzvgtsd6k0tprf5u734nnl4xq06hecajc40rqw"
                ]
            , buildGroup "CaviarNine"
                [ "rv1qdfhzmygv2vmxuc4702pttrpkep0vkc06a64zlenmvujn2yvq2u3y93e8ky"
                , "rv1q29pg6kl80m43h0mewh8w8zfnhnpg50e3plwaexqx29vq2savjnzkdn89kp"
                ]
            , buildGroup "✅RadCrew"
                [ "rv1qgaftlzpdxaacv3jmf0x9vlys3ap0mngfea8gsedph4ckaya0gqe6h9mv6f"
                , "rv1qf53n265drur37lkqcun5sa8j0h0aqpvpuxh3r2nz7xzdskvwcy9zkpyh42"
                ]
            , buildGroup "🔗 Radixnode.io"
                [ "rv1qwqvrexkz0qdgve9jxk4c8s35n9n4wucgm0m8pahgqyc2py6raf7g9uf9j7"
                , "rv1q0lskvu7awu4rgzju3pth6a7eqk3zazrnlqnxwqtehr7td4he2zfck5yruz"
                ]
            , buildGroup "RadixPool"
                [ "rv1q04u5zwtgffsqkvr08xqm6vpm3gwxh4uqwtjpx5p47ew0m0v8m5zs3m3jed"
                , "rv1q27pjz9zf4f37df493xzx6hgattjj6qdyn255u8a58eeyac7lg495xklqu7"
                ]
            , buildGroup "SKY"
                [ "rv1q2fj02guaut2k0fvxjngs77vlfr9mfrk7vmj6kvf22kwq7cww854jgjkhvf"
                , "rv1qfgl9cqd8cr5df54fahlkw9epxvmll0yvucndvt0ytt0t9nrmvs3zqeu75q"
                , "rv1q00l6tamghj5jzq6rzj7rh9yjyeaks2d207jnqm5d4lsgzutqte05d3kjv3"
                , "rv1qdwduz6jf7eghgmn7n7axtq54yrr0q4zttww2jghk8p8a6e4u2p0w4jnkvt"
                ]
            , buildGroup "StakeSafe"
                [ "rv1q0v80rfgsldx3zksfzurumdf5g3us8xa9sykf3fdevtrr557lgrmjv2cft5"
                , "rv1qdxg4r7ulqustdus02k8egkenfwknlvxs4hm2ynemp5knzykgwh2xfa53at"
                , "rv1qwsg60y9h6c0t0n93z70053jseygtd8n6ueg3tr7wn8krxv60fexcsnh0zq"
                ]
            ]

        validatorGroup : Dict String GroupFull
        validatorGroup =
            groups
                |> List.map (\group -> List.map (\v -> ( v.address, group )) group.validators)
                |> List.concat
                |> Dict.fromList

        totalStake : BigInt
        totalStake =
            validators
                |> List.map .totalDelegatedStake
                |> bigIntSum
    in
    validators
        |> List.map
            (\v ->
                { v
                    | group =
                        Dict.get v.address validatorGroup
                            |> Maybe.map
                                (\groupFull ->
                                    Group groupFull.name
                                        groupFull.totalStake
                                        (bigIntDivToFloat groupFull.totalStake totalStake)
                                )
                    , stakeShare = bigIntDivToFloat v.totalDelegatedStake totalStake
                }
            )
        |> List.sortWith (\a b -> BigInt.compare a.totalDelegatedStake b.totalDelegatedStake)
        |> List.reverse
        |> List.indexedMap (\index v -> { v | rank = index + 1 })



-- INIT


init : ( Model, Cmd Msg )
init =
    ( { validators = Loading, totalStake = BigInt.fromInt 0 }
    , getValidatorsRequest
    )



-- HTTP


getValidatorsRequest : Cmd Msg
getValidatorsRequest =
    Http.post
        { url = "https://mainnet.radixdlt.com/archive"
        , body = jsonBody getNextEpochSet
        , expect = Http.expectJson GotValidators validatorsDecoder
        }


bigIntDecoder : Decoder BigInt
bigIntDecoder =
    string
        |> andThen
            (\value ->
                case BigInt.fromIntString value of
                    Just number ->
                        succeed number

                    Nothing ->
                        fail "Invalid BigInt"
            )


floatDecoder : Decoder Float
floatDecoder =
    string
        |> andThen
            (\value ->
                case String.toFloat value of
                    Just number ->
                        succeed number

                    Nothing ->
                        fail "Invalid Float"
            )


validatorDecoder : Decoder Validator
validatorDecoder =
    Decode.succeed Validator
        |> required "totalDelegatedStake" bigIntDecoder
        |> required "uptimePercentage" floatDecoder
        |> required "proposalsMissed" int
        |> required "address" string
        |> required "infoURL" string
        |> required "ownerDelegation" bigIntDecoder
        |> required "name" (Decode.map String.trim string)
        |> required "validatorFee" floatDecoder
        |> required "registered" bool
        |> required "ownerAddress" string
        |> required "isExternalStakeAccepted" bool
        |> required "proposalsCompleted" int
        |> hardcoded Nothing
        |> hardcoded 0
        |> hardcoded 0


validatorsDecoder : Decoder (List Validator)
validatorsDecoder =
    field "result" <|
        field "validators" <|
            list validatorDecoder


getNextEpochSet : Encode.Value
getNextEpochSet =
    Encode.object
        [ ( "jsonrpc", Encode.string "2.0" )
        , ( "method", Encode.string "validators.get_next_epoch_set" )
        , ( "params"
          , Encode.object
                [ ( "size", Encode.int 200 )
                ]
          )
        , ( "id", Encode.int 1 )
        ]



-- UPDATE


type Msg
    = Noop
    | GotValidators (Result Http.Error (List Validator))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Noop ->
            ( model, Cmd.none )

        GotValidators validators ->
            case validators of
                Ok validators_ ->
                    ( { model
                        | validators = Success <| addGroups validators_
                        , totalStake =
                            validators_
                                |> List.map .totalDelegatedStake
                                |> bigIntSum
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | validators = Failure error }, Cmd.none )



-- VIEW


viewHeader : Device -> Model -> Element Msg
viewHeader device model =
    column
        [ Font.center
        , spacing small
        , Font.size normal
        , paddingXY small 0
        , Background.color darkShades
        , Font.color white
        , Font.extraLight
        , paddingXY 0
            (case device.class of
                Phone ->
                    small

                _ ->
                    normal
            )
        , width fill
        , Border.shadow
            { offset = ( toFloat xxSmall, toFloat xxSmall )
            , size = 0
            , blur = toFloat small
            , color = blackAlpha 0.4
            }
        ]
        [ paragraph [] [ text "Radix Validators" ]
        ]


toXRD : BigInt -> BigInt
toXRD subUnits =
    BigInt.div subUnits (safeBigInt "1000000000000000000")


formatStake : BigInt -> String
formatStake stake =
    stake
        |> toXRD
        |> BigInt.toString
        |> String.toFloat
        |> Maybe.withDefault 0
        |> FormatNumber.format { usLocale | decimals = Exact 0 }


formatPercentage : Float -> String
formatPercentage percentage =
    formatWithDecimals 2 (percentage * 100) ++ "%"


nodeRunnerStake : Validator -> BigInt
nodeRunnerStake validator =
    case validator.group of
        Nothing ->
            validator.totalDelegatedStake

        Just group ->
            group.totalStake


shortAddress : String -> String
shortAddress address =
    String.left 4 address
        ++ "…"
        ++ String.right 5 address


viewValidators : Device -> List Validator -> Color -> Element Msg
viewValidators device validators zoneColor =
    let
        sortedValidators =
            List.sortWith
                (\a b ->
                    case BigInt.compare (nodeRunnerStake a) (nodeRunnerStake b) of
                        LT ->
                            GT

                        EQ ->
                            EQ

                        GT ->
                            LT
                )
                validators

        cellPadding =
            paddingXY small small

        headerCell : List (Attribute msg) -> Element msg -> Element msg
        headerCell attributes content =
            el
                ([ Font.medium
                 , cellPadding
                 , Font.color <| whiteAlpha 0.9
                 , Background.color zoneColor
                 ]
                    ++ attributes
                )
            <|
                content

        stakeCell : BigInt -> Float -> Element Msg
        stakeCell stake stakeShare =
            row
                [ cellPadding
                , Font.alignRight
                , alignRight
                , centerX
                , centerY
                ]
                [ el [ alignRight ] <|
                    text <|
                        formatStake stake
                            ++ " / "
                , el [ alignRight, Font.extraBold, Font.color zoneColor ] <| text <| formatPercentage stakeShare ++ ""
                ]
    in
    Element.indexedTable [ width <| maximum 1400 fill, centerX, Font.size 14 ]
        { data = sortedValidators
        , columns =
            [ { header = headerCell [] <| text "Rank"
              , width = shrink
              , view =
                    \index validator ->
                        el [ cellPadding, centerX, centerY ] <| text <| "#" ++ String.fromInt validator.rank
              }
            , { header = headerCell [] <| text "Validator"
              , width = fill
              , view =
                    \index validator ->
                        let
                            trimmedName =
                                if String.length validator.name > 25 then
                                    String.left 25 validator.name ++ "…"

                                else
                                    validator.name
                        in
                        if String.isEmpty <| String.trim <| validator.infoUrl then
                            el [ cellPadding, Font.medium, centerX, centerY ] <| text trimmedName

                        else
                            link [ mouseOver [ Font.color zoneColor ], cellPadding, Font.medium, centerX, centerY ]
                                { url = validator.infoUrl
                                , label = text trimmedName
                                }
              }
            , { header = headerCell [ Font.alignRight ] <| text "Node Runner Stake"
              , width = shrink
              , view =
                    \index validator ->
                        case validator.group of
                            Nothing ->
                                stakeCell validator.totalDelegatedStake validator.stakeShare

                            Just group ->
                                stakeCell group.totalStake group.stakeShare
              }
            , { header = headerCell [ Font.alignRight ] <| text "Validator Stake"
              , width = shrink
              , view =
                    \index validator ->
                        case validator.group of
                            Nothing ->
                                el [ cellPadding, Font.alignRight, centerX, centerY ] <| text "= node runner"

                            Just group ->
                                stakeCell validator.totalDelegatedStake validator.stakeShare
              }
            , { header = headerCell [ Font.alignRight ] <| text "Owner Stake"
              , width = shrink
              , view =
                    \index validator ->
                        el
                            [ cellPadding
                            , Font.alignRight
                            , alignRight
                            , centerX
                            , centerY
                            ]
                        <|
                            text <|
                                formatStake validator.ownerDelegation
              }
            , { header = headerCell [ Font.alignRight ] <| text "Fee"
              , width = shrink
              , view =
                    \index validator ->
                        el [ cellPadding, Font.alignRight, centerX, centerY ] <|
                            text <|
                                formatWithDecimals 2 validator.fee
                                    ++ "%"
              }
            , { header = headerCell [ Font.alignRight ] <| text "Uptime"
              , width = shrink
              , view =
                    \index validator ->
                        el [ cellPadding, Font.alignRight, centerX, centerY ] <|
                            text <|
                                formatWithDecimals 2 validator.uptimePercentage
                                    ++ "%"
              }
            , { header = headerCell [] <| text "Address"
              , width = shrink
              , view =
                    \index validator ->
                        row [ cellPadding, spacing xSmall, centerX, centerY ]
                            [ text <|
                                shortAddress validator.address
                            , Input.button
                                [ Background.color <| blackAlpha 0.04
                                , htmlAttribute <| Html.Attributes.class "radix-address"
                                , htmlAttribute <| Html.Attributes.attribute "data-clipboard-text" validator.address
                                , Font.color <| blackAlpha 0.5
                                , padding xSmall
                                , Border.rounded 5
                                , mouseOver
                                    [ Background.color <| blackAlpha 0.1
                                    ]
                                ]
                                { onPress = Nothing
                                , label = icon 14 content_copy
                                }
                            ]
              }
            , { header = headerCell [] <| text "Open"
              , width = shrink
              , view =
                    \index validator ->
                        if validator.acceptsExternalStake then
                            el [ cellPadding, Font.color malachite, centerX, centerY ] <| icon small check_circle

                        else
                            el [ cellPadding, Font.color crimson, centerX, centerY ] <| icon small remove_circle
              }
            ]
        }


headingWithIcon : (Int -> Coloring -> Html msg) -> String -> Color -> Element msg
headingWithIcon icon_ label_ color_ =
    row [ centerX, spacing small, Font.color color_ ]
        [ el [] <| icon 48 icon_
        , el [ Font.size 48, Font.light ] <| text label_
        ]


viewValidatorZone : Device -> (Int -> Coloring -> Html Msg) -> String -> Color -> String -> List Validator -> List String -> Element Msg
viewValidatorZone device icon_ headingLabel color_ emptyMessage validators description =
    column [ width fill, spacing normal ]
        [ headingWithIcon icon_ headingLabel color_
        , column [ spacing normal, centerX ] <| List.map (\t -> paragraph [ spacing small, centerX, width <| maximum 800 fill, Font.center ] [ text t ]) description
        , if List.isEmpty validators then
            text emptyMessage

          else
            viewValidators device validators color_
        ]


viewValidatorZones : Device -> Model -> Element Msg
viewValidatorZones device model =
    case model.validators of
        Loading ->
            el [ centerX, centerY ] <|
                html <|
                    Loading.render
                        DoubleBounce
                        { defaultConfig | color = "#1CE67A", size = toFloat large, speed = 1 }
                        Loading.On

        -- LoadingState
        Success validators ->
            let
                top100validators =
                    List.filter (\v -> v.rank <= 100) validators

                beyond100validators =
                    List.filter (\v -> v.rank > 100) validators
            in
            column [ width fill, spacing xLarge ]
                [ el [ centerX ] <| text <| "Total Stake: " ++ formatStake model.totalStake
                , column [ width fill, spacing large ]
                    [ let
                        dangerValidators =
                            List.filter
                                (\validator ->
                                    case validator.group of
                                        Just group ->
                                            group.stakeShare >= 0.05

                                        Nothing ->
                                            validator.stakeShare >= 0.05
                                )
                                top100validators
                      in
                      viewValidatorZone device
                        sentiment_very_dissatisfied
                        "DANGER ZONE"
                        crimson
                        "No validators in danger zone currently."
                        dangerValidators
                        [ "The validators in the danger zone have way too much stake and stakers should not select them to increase network security."
                        , "Be warned: Your cat will die otherwise."
                        ]
                    , let
                        warningValidators =
                            List.filter
                                (\validator ->
                                    case validator.group of
                                        Just group ->
                                            0.03 <= group.stakeShare && group.stakeShare < 0.05

                                        Nothing ->
                                            0.03 <= validator.stakeShare && validator.stakeShare < 0.05
                                )
                                top100validators
                      in
                      viewValidatorZone device
                        sentiment_neutral
                        "WARNING ZONE"
                        portlandOrange
                        "No validators in warning zone currently."
                        warningValidators
                        [ "The validators in the warning zone still have a lot of stake. Maybe better pick another validator of the safe zone." ]
                    , let
                        safeValidators =
                            List.filter
                                (\validator ->
                                    case validator.group of
                                        Just group ->
                                            group.stakeShare < 0.03

                                        Nothing ->
                                            validator.stakeShare < 0.03
                                )
                                top100validators
                      in
                      viewValidatorZone device
                        sentiment_very_satisfied
                        "SAFE ZONE"
                        malachite
                        "No validators in safe zone currently."
                        safeValidators
                        [ "The validators in the safe zone do not have more than 3% of combined node runner stake and therefore are good candidates for increasing network decentralisation." ]
                    , viewValidatorZone device
                        sentiment_neutral
                        "NOT IN NEXT EPOCH"
                        portlandOrange
                        "No validators out of top 100 currently."
                        beyond100validators
                        [ "The following validators will be not be selected for the next epoch. You will not earn rewards in this case." ]
                    ]
                ]

        Failure err ->
            text "Error loading validators!"

        NotAsked ->
            none


view : Device -> Model -> Element Msg
view device model =
    column [ width fill, spacing xLarge, Font.color darkShades, paddingXY 0 0 ]
        [ viewHeader device model
        , viewValidatorZones device model
        , viewContact
        , viewFooter
        ]
