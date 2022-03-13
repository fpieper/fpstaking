module Page.Validators exposing (..)

import BigInt exposing (BigInt)
import Color.Interpolate exposing (interpolate)
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import FormatNumber
import FormatNumber.Locales exposing (Decimals(..), usLocale)
import GatewayApi exposing (Group, Validator, getValidatorsRequest)
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
import UI exposing (Icon, fromUiColor, heading, icon, inputHint, sliderStyle, subHeading, thumb, toUiColor, viewContact, viewFactTable, viewFooter)
import Utils exposing (bigIntDivToFloat, bigIntMulFloat, bigIntSum, formatWithDecimals, safeBigInt, toXRD)



-- MODEL


type alias Model =
    { validators : RemoteData Http.Error (List Validator)
    , totalStake : BigInt
    , tokensStaked : Int
    , validatorFee : Float
    , uptime : Float
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
                , "rv1qtztn2t7smu8nn3gk9cnh9cl66ju7z9kvmatpqyx5h295v4304xmwnjf43n"
                , "rv1qwe3k036lrj79s06e8cx2kzcsrjmenxgug6d045jzer29sur3cfyv4r0a3t"

                --, "rv1qggt5w4g800k5w3du63g0j86u8ayaqkzdgyxfkw3uc93826zxef22gjr64m"
                --, "rv1q0m9329x6tywt3kggatrtr8ut8qvxqw9lsfw2w8phrvvv2qydw9xsk88slq"
                --, "rv1q0xq9jg3vcuvelflpdvkcvzvgtsd6k0tprf5u734nnl4xq06hecajc40rqw"
                ]
            , buildGroup "CaviarNine"
                [ "rv1qdfhzmygv2vmxuc4702pttrpkep0vkc06a64zlenmvujn2yvq2u3y93e8ky"
                , "rv1q29pg6kl80m43h0mewh8w8zfnhnpg50e3plwaexqx29vq2savjnzkdn89kp"
                ]

            {--, buildGroup "✅RadCrew"
                [ "rv1qgaftlzpdxaacv3jmf0x9vlys3ap0mngfea8gsedph4ckaya0gqe6h9mv6f"
                , "rv1qf53n265drur37lkqcun5sa8j0h0aqpvpuxh3r2nz7xzdskvwcy9zkpyh42"
                ]--}
            , buildGroup "ITS Australia and Ideomaker"
                [ "rv1qgk7asalvem6y06asnxwt8rgx05gvl9vzrldnkshvat3uysxmkx9gmkv7y2"
                , "rv1qg923hl7f725cs06eg5gmdcy4pfvpa8mfnjcw669traquj28c96z5w0rld0"
                ]

            {--, buildGroup "🔗 Radixnode.io"
                [ "rv1qwqvrexkz0qdgve9jxk4c8s35n9n4wucgm0m8pahgqyc2py6raf7g9uf9j7"
                , "rv1q0lskvu7awu4rgzju3pth6a7eqk3zazrnlqnxwqtehr7td4he2zfck5yruz"
                ]--}
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
            , buildGroup "RadixFoundation"
                [ "rv1qgxn3eeldj33kd98ha6wkjgk4k77z6xm0dv7mwnrkefknjcqsvhuu30c6hh"
                , "rv1qwrrnhzfu99fg3yqgk3ut9vev2pdssv7hxhff80msjmmcj968487uc0c0nc"
                , "rv1qf2x63qx4jdaxj83kkw2yytehvvmu6r2xll5gcp6c9rancmrfsgfwttnczx"
                , "rv1qt2zy2cuf3ssx25zspkzg29qzlwf3tcdhud3908y8x5veytgv4ykwh9w0ty"
                , "rv1q0zdrxc7u6e296yjptd4yqdl3m9g5nk4zk97ta46rt2fuye05y38vcqdxul"
                , "rv1q0gnmwv0fmcp7ecq0znff7yzrt7ggwrp47sa9pssgyvrnl75tvxmvke8uxe"
                , "rv1q29j87g5s05vf8l7ele9543r6n4sda0kj548jnncx6jqscrl40vw6m3s805"
                , "rv1qt3t0tezvfqdyjzkyepmjh3rvp5mu3lfa824rq6kl3j2xlh9ptkq504xyuq"
                , "rv1qfhdl4zcu3tntaa9dpa4gmndcggrw9a97ee485sswstzxx9w7qsrqvp8j2n"
                , "rv1q0fnnp2ncmtkyyz4fz6q69x3hpnu95r8jndzh6zyxh0kr98v8t5fw6w4gj3"
                , "rv1qgzea7fs4f9jxj3s55uw98tsvujzef6uuwjxptea4zya2yywkgcm2m772ts"
                , "rv1q25v040ejdlwxy5lu4688la66w8l0kqh383psyaadqp58jmsz75wgqgk0j3"
                , "rv1q0c0frnkguvsynghlw84f82nfh82mpr6d2fxamlcn4pcpz8zsgcrcquhlk3"
                , "rv1qt22v09sl9ptdujtz8tz3g3dc4m93439jyq6jf2jwf5ea668r2ycvyuv7z5"
                , "rv1q0k9hxla6phcamc7laxa0juawg9t9vtspx6ux2s0nal07x8uk5ylzye7lhd"
                , "rv1qwxf0ytqa8damm3vr2jgq04nejev043xy509q0vkrhdhchs7n79fvewxsvv"
                , "rv1qfyk8r20jpwxjmzkvkkxu247vmffr4dl3vkqj9gsmcpp5f6mxpgxcscwj6m"
                , "rv1qgvahu9vl6fslx8m6stdherjkvztqxm60fhmctjl0ueqfhledd5ds8pnyty"
                , "rv1qdakpg9s90sha6z9q7rug43ucdyc82aqw6hlxcfr2t8rrse589se26mf90m"
                , "rv1qwp64k6s05kcl0c86cumezyeh4twzy7eduwz4enf35udhfhfvelkseawyu2"
                , "rv1qft2plmngnkn6f2xp2zcl944twzyylh4s50aa2q2n6wh37gnqtfwyz9as5w"
                , "rv1qdpavrvzvrsljlh7u7mxg3zqszcya9yrpxk9d77grhtm4cxgwhlh69a2hkm"
                , "rv1qgdue83wgezwrdsn2ngqnqpa74euykulngsqxernzkzcspkpula4kle75q6"
                , "rv1qgcw6z26qr3mslfjkz82s7qtmgqnugq9amsnl8jwqzxhtrax4mqk7qsl6vu"
                ]
            , buildGroup "AMR Node 🇷🇺 and RadStaking 🇷🇺"
                [ "rv1q03txhtq9d4v79len5jk65hzecgzdwqr94cu9pqd3v0r8dp923r9z37n7hw"
                , "rv1qf3hq39mnxx6ln5yfy5gmgnm2vuxvpjxm8rhymqahq09n4vntyk77a5nfre"
                ]
            , buildGroup "DogeCube and RadixDLT Staking"
                [ "rv1qgw68kqkryhgxvcvp04wfss0k76svxkqv3zvf57rcvrkuzdluu9ay4snzxc"
                , "rv1qd9wlc66dzssnkzwja2mrnxsdezzkmxg00xqzrkn4039zpghaj0rs43mz63"
                ]
            , buildGroup "XRDScan"
                [ "rv1q250v8v6a7s6594tlvv6ndkk880dc3mgxaqssa4jeet890qczty9vesjmvn"
                , "rv1qw00edymt8x7ch63s4ukyncgq6ggr2krsdlyg6rz5g6zgt4a4qyacl2a5hy"
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
    ( { validators = Loading
      , totalStake = BigInt.fromInt 0
      , tokensStaked = 0
      , validatorFee = 4
      , uptime = 100
      }
    , getValidatorsRequest GotValidators
    )



-- UPDATE


type Msg
    = TokensStakedChanged String
    | ValidatorFeeChanged Float
    | UptimeChanged Float
    | GotValidators (Result Http.Error (List Validator))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TokensStakedChanged tokens ->
            ( if String.length tokens == 0 then
                { model | tokensStaked = 0 }

              else
                case String.toInt tokens of
                    Just t ->
                        { model | tokensStaked = t }

                    Nothing ->
                        model
            , Cmd.none
            )

        ValidatorFeeChanged fee ->
            ( { model | validatorFee = fee }, Cmd.none )

        UptimeChanged uptime ->
            ( { model | uptime = uptime }, Cmd.none )

        GotValidators validators ->
            case validators of
                Ok allValidators ->
                    let
                        validators_ =
                            List.filter .registered allValidators
                    in
                    ( { model
                        | validators = Success <| addGroups validators_
                        , totalStake =
                            validators_
                                |> List.map .totalDelegatedStake
                                |> List.take 100
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


viewStakingCalculator : Device -> Model -> Element Msg
viewStakingCalculator device model =
    column
        [ centerX
        , spacing normal
        , padding
            (case device.class of
                Phone ->
                    small

                _ ->
                    large
            )
        , Background.color mainBrand
        , Font.color darkShades
        , Border.rounded 5
        , Border.shadow
            { offset = ( toFloat xxSmall, toFloat xxSmall )
            , size = 0
            , blur = toFloat xSmall
            , color = blackAlpha 0.1
            }
        ]
        [ paragraph [ Font.center ]
            [ subHeading "How much staking rewards do I earn?"
            ]
        , Input.text
            [ inputHint mainBrand <| text "XRD"
            , Background.color mainBrand
            , Border.color darkShades
            , Font.semiBold
            ]
            { onChange = TokensStakedChanged
            , text =
                String.fromInt model.tokensStaked
                    |> (\t ->
                            if t == "0" then
                                ""

                            else
                                t
                       )
            , placeholder = Nothing
            , label = Input.labelAbove [] <| text "Staked Tokens / Wallet Address"
            }
        , Input.slider
            sliderStyle
            { onChange = ValidatorFeeChanged
            , label =
                Input.labelAbove [] <|
                    row [ width fill ]
                        [ text "Validator Fee"
                        , el [ Font.color darkShades, Font.semiBold, alignRight ] <|
                            text <|
                                formatWithDecimals 1 model.validatorFee
                                    ++ "%"
                        ]
            , min = 0
            , max = 20
            , step = Just 0.1
            , value = model.validatorFee
            , thumb =
                thumb
            }
        , Input.slider
            sliderStyle
            { onChange = UptimeChanged
            , label =
                Input.labelAbove [] <|
                    row [ width fill ]
                        [ text "Uptime"
                        , el [ Font.color darkShades, Font.semiBold, alignRight ] <|
                            text <|
                                formatWithDecimals 2 model.uptime
                                    ++ "%"
                        ]
            , min = 98
            , max = 100
            , step = Just 0.02
            , value = model.uptime
            , thumb =
                thumb
            }
        , let
            totalStaked =
                toXRD model.totalStake

            stakingShare =
                bigIntDivToFloat (BigInt.fromInt model.tokensStaked) totalStaked * 100

            feeFactor =
                1 - (model.validatorFee / 100)

            uptimeFactor =
                ((model.uptime / 100) - 0.98) / 0.02

            stackingRewards =
                (stakingShare / 100) * 300000000 * feeFactor * uptimeFactor

            apy =
                if model.tokensStaked == 0 then
                    0

                else
                    (stackingRewards / toFloat model.tokensStaked) * 100
          in
          row [ width fill, spacing normal ]
            [ viewFactTable [ width fill, spacing small ]
                []
                [ { key = text "Total Staked"
                  , value = el [ alignRight ] <| text <| formatWithDecimals 3 (bigIntDivToFloat totalStaked (safeBigInt "1000000000")) ++ "B XRD"
                  }
                , { key = text "Rewards"
                  , value = el [ alignRight, Font.semiBold ] <| text <| String.fromInt (round stackingRewards) ++ " XRD"
                  }
                , { key = text "APY"
                  , value = el [ alignRight, Font.semiBold ] <| text <| formatWithDecimals 2 apy ++ " %"
                  }
                ]
            ]
        ]


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
    String.left 2 address
        ++ "…"
        ++ String.right 7 address


type SortOrder
    = Ascending
    | Descending


isOwnValidator : Validator -> Bool
isOwnValidator validator =
    validator.address == "rv1qfxktwkq9amdh678cxfynzt4zeua2tkh8nnrtcjpt7fyl0lmu8r3urllukm"


viewValidators : Device -> List Validator -> Color -> SortOrder -> Bool -> Element Msg
viewValidators device validators zoneColor sortOrder combine =
    let
        sortedValidators =
            List.sortWith
                (\a b ->
                    case
                        if combine then
                            BigInt.compare (nodeRunnerStake a) (nodeRunnerStake b)

                        else
                            BigInt.compare a.totalDelegatedStake b.totalDelegatedStake
                    of
                        LT ->
                            if sortOrder == Ascending then
                                LT

                            else
                                GT

                        EQ ->
                            EQ

                        GT ->
                            if sortOrder == Ascending then
                                GT

                            else
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
                            let
                                style =
                                    if isOwnValidator validator then
                                        [ cellPadding
                                        , Font.medium
                                        , centerX
                                        , centerY
                                        , Background.color darkShades
                                        , padding small
                                        , Font.color white
                                        , mouseOver [ alpha 0.95 ]
                                        , Border.rounded 5
                                        , Border.shadow
                                            { offset = ( toFloat xxSmall, toFloat xxSmall )
                                            , size = 0
                                            , blur = toFloat small
                                            , color = blackAlpha 0.4
                                            }
                                        ]

                                    else
                                        [ mouseOver [ Font.color zoneColor ], cellPadding, Font.medium, centerX, centerY ]
                            in
                            link style
                                { url = validator.infoUrl
                                , label = text trimmedName
                                }
              }
            , { header = headerCell [ Font.alignRight ] <| text "Combined Operator Stake"
              , width = shrink
              , view =
                    \index validator ->
                        case validator.group of
                            Nothing ->
                                if combine then
                                    stakeCell validator.totalDelegatedStake validator.stakeShare

                                else
                                    el [ cellPadding, Font.alignRight, centerX, centerY ] <| text "= validator"

                            Just group ->
                                stakeCell group.totalStake group.stakeShare
              }
            , { header = headerCell [ Font.alignRight ] <| text "Validator Stake"
              , width = shrink
              , view =
                    \index validator ->
                        case validator.group of
                            Nothing ->
                                if combine then
                                    el [ cellPadding, Font.alignRight, centerX, centerY ] <| text "= combined"

                                else
                                    stakeCell validator.totalDelegatedStake validator.stakeShare

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
            , { header = headerCell [ Font.alignRight ] <| text "Uptime"
              , width = shrink
              , view =
                    \index validator ->
                        el [ cellPadding, Font.alignRight, centerX, centerY ] <|
                            text <|
                                formatWithDecimals 2 validator.uptimePercentage
                                    ++ "%"
              }

            {--, { header = headerCell [ Font.alignRight ] <| text "Proposals Completed"
              , width = shrink
              , view =
                    \index validator ->
                        el [ cellPadding, Font.alignRight, centerX, centerY ] <|
                            text <|
                                String.fromInt validator.proposalCompleted
              }
            , { header = headerCell [ Font.alignRight ] <| text "Proposals Missed"
              , width = shrink
              , view =
                    \index validator ->
                        el [ cellPadding, Font.alignRight, centerX, centerY ] <|
                            text <|
                                String.fromInt validator.proposalsMissed
              }--}
            , { header = headerCell [ Font.alignRight ] <| text "Fee"
              , width = shrink
              , view =
                    \index validator ->
                        el [ cellPadding, Font.alignRight, centerX, centerY ] <|
                            text <|
                                formatWithDecimals 2 validator.fee
                                    ++ "%"
              }

            {--, { header = headerCell [ Font.alignRight ] <| text "Yearly Operator Income"
              , width = shrink
              , view =
                    \index validator ->
                        el [ cellPadding, Font.alignRight, centerX, centerY ] <|
                            text <|
                                FormatNumber.format { usLocale | decimals = Exact 0 } (validator.stakeShare * validator.fee * 100 * 30000)
              }--}
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


viewValidatorZone : Device -> (Int -> Coloring -> Html Msg) -> String -> Color -> String -> List Validator -> List String -> SortOrder -> Bool -> Element Msg
viewValidatorZone device icon_ headingLabel color_ emptyMessage validators description sortOrder combine =
    column [ width fill, spacing normal ]
        [ headingWithIcon icon_ headingLabel color_
        , column [ spacing normal, centerX ] <| List.map (\t -> paragraph [ spacing small, centerX, width <| maximum 800 fill, Font.center ] [ text t ]) description
        , if List.isEmpty validators then
            text emptyMessage

          else
            viewValidators device validators color_ sortOrder combine
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
                [ column [ width fill, spacing large ]
                    [ let
                        safeValidators =
                            List.filter
                                (\validator ->
                                    case validator.group of
                                        Just group ->
                                            group.stakeShare < 0.02

                                        Nothing ->
                                            validator.stakeShare < 0.02
                                )
                                top100validators
                      in
                      viewValidatorZone device
                        sentiment_very_satisfied
                        "SAFE ZONE"
                        malachite
                        "No validators in safe zone currently."
                        safeValidators
                        [ "The validators in the safe zone do not have more than 2% of combined node operator stake and therefore are good candidates for increasing network decentralisation and security." ]
                        Ascending
                        True
                    , let
                        warningValidators =
                            List.filter
                                (\validator ->
                                    case validator.group of
                                        Just group ->
                                            0.02 <= group.stakeShare && group.stakeShare < 0.03

                                        Nothing ->
                                            0.02 <= validator.stakeShare && validator.stakeShare < 0.03
                                )
                                top100validators
                      in
                      viewValidatorZone device
                        sentiment_neutral
                        "WARNING ZONE"
                        portlandOrange
                        "No validators in warning zone currently."
                        warningValidators
                        [ "The validators in the warning zone have quite some stake. Maybe better pick another validator of the safe zone." ]
                        Ascending
                        True
                    , let
                        dangerValidators =
                            List.filter
                                (\validator ->
                                    case validator.group of
                                        Just group ->
                                            group.stakeShare >= 0.03

                                        Nothing ->
                                            validator.stakeShare >= 0.03
                                )
                                top100validators
                      in
                      viewValidatorZone device
                        sentiment_very_dissatisfied
                        "DANGER ZONE"
                        crimson
                        "No validators in danger zone currently."
                        dangerValidators
                        [ "The validators in the danger zone have too much stake and stakers should not select them to increase network security."
                        , "Be warned: Your cat will die otherwise."
                        ]
                        Ascending
                        True
                    , viewValidatorZone device
                        sentiment_neutral
                        "NOT IN NEXT EPOCH"
                        portlandOrange
                        "No validators out of top 100 currently."
                        beyond100validators
                        [ "The following validators will be not be selected for the next epoch. You will not earn rewards in this case." ]
                        Descending
                        False
                    ]
                ]

        Failure err ->
            paragraph []
                [ text "Error loading validators!"
                ]

        NotAsked ->
            none


viewStatistics : Model -> Element Msg
viewStatistics model =
    case model.validators of
        Success _ ->
            el [ centerX ] <| text <| "Total Stake: " ++ formatStake model.totalStake ++ " XRD"

        _ ->
            none


viewCallToAction : Element Msg
viewCallToAction =
    link
        [ centerX
        , Background.color darkShades
        , padding small
        , Font.color white
        , mouseOver [ alpha 0.95 ]
        , Border.rounded 5
        , Border.shadow
            { offset = ( toFloat xxSmall, toFloat xxSmall )
            , size = 0
            , blur = toFloat small
            , color = blackAlpha 0.4
            }
        ]
        { url = "/"
        , label = text "Stake on 🚀 Florian Pieper Staking"
        }


view : Device -> Model -> Element Msg
view device model =
    column [ width fill, spacing xLarge, Font.color darkShades, paddingXY 0 0 ]
        [ viewHeader device model
        , viewStatistics model

        --, viewStakingCalculator device model
        , viewCallToAction
        , viewValidatorZones device model
        , viewContact
        , viewFooter
        ]
