module Page.Home exposing (..)

import BigInt
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input exposing (thumb)
import Html.Attributes
import Material.Icons.Outlined exposing (build, cloud_off, face, favorite, language, notifications_active, paid, security)
import Palette exposing (..)
import UI exposing (Icon, heading, icon, inputHint, subHeading, viewContact, viewFactTable, viewFooter)
import Utils exposing (bigIntDivToFloat, bigIntMulFloat, formatWithDecimals, safeBigInt)



-- MODEL


type alias Model =
    { tokensStaked : Int
    , unlockedTokensShare : Int
    , stakingRatio : Int
    , validatorFee : Float
    , uptime : Float
    }



-- INIT


init : ( Model, Cmd Msg )
init =
    ( { tokensStaked = 0
      , unlockedTokensShare = 35
      , stakingRatio = 70
      , validatorFee = 4
      , uptime = 100
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = Noop
    | TokensStakedChanged String
    | UnlockedTokensShareChanged Float
    | StakingRatioChanged Float
    | ValidatorFeeChanged Float
    | UptimeChanged Float


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Noop ->
            ( model, Cmd.none )

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

        UnlockedTokensShareChanged share ->
            ( { model | unlockedTokensShare = round share }, Cmd.none )

        StakingRatioChanged ratio ->
            ( { model | stakingRatio = round ratio }, Cmd.none )

        ValidatorFeeChanged fee ->
            ( { model | validatorFee = fee }, Cmd.none )

        UptimeChanged uptime ->
            ( { model | uptime = uptime }, Cmd.none )



-- VIEW


viewHeader : Device -> Model -> Element Msg
viewHeader device model =
    column
        [ Font.center
        , spacing small
        , Font.size 48
        , paddingXY small 0
        , Background.color darkShades
        , Font.color white
        , Font.extraLight
        , paddingXY small
            (case device.class of
                Phone ->
                    xLarge

                _ ->
                    xxLarge
            )
        , width fill
        , Border.shadow
            { offset = ( toFloat xxSmall, toFloat xxSmall )
            , size = 0
            , blur = toFloat small
            , color = blackAlpha 0.4
            }
        ]
        [ paragraph [] [ text "Stake and maximise your rewards." ]
        ]


viewBenefit : Device -> Icon Msg -> String -> List (Element Msg) -> Element Msg
viewBenefit device icon_ title content =
    let
        ( widthBox, paddingBoxX, paddingBoxY ) =
            case device.class of
                Phone ->
                    ( fill, small, normal )

                _ ->
                    ( minimum 450 fill, normal, normal )
    in
    column [ alignTop, width widthBox, spacing xSmall, paddingXY paddingBoxX paddingBoxY ]
        [ row []
            [ el [ Font.color mainBrand, width <| px 48 ] <| icon normal icon_
            , el [ Font.size (small + xxSmall) ] <| text title
            ]
        , row [ width fill ]
            [ paragraph [ paddingEach { top = 0, bottom = 0, left = 48, right = 0 }, Font.size small ]
                content
            ]
        ]


viewBenefits : Device -> Model -> Element Msg
viewBenefits device model =
    let
        row_ =
            case device.class of
                Phone ->
                    column

                _ ->
                    wrappedRow
    in
    column [ spacing normal, width fill ]
        [ paragraph [ Font.center, width fill, paddingXY small 0, spacing small ] [ heading "Why stake your Radix with me?" ]
        , el [ width <| maximum 1000 fill, centerX ] <|
            row_
                [ htmlAttribute <| Html.Attributes.style "justify-content" "center"
                ]
                [ viewBenefit device cloud_off "Decentralised" [ text "A core principle of decentralised ledgers (DLT) like Radix is decentralisation. That is why my validator is not hosted at common cloud providers but multiple smaller ones." ]
                , viewBenefit device paid "Low Fees" [ text "My validator fee is low with only 3.4%. Low fees combined with high uptime ensure that your rewards are maximised. You can calculate your expected APY in my staking calculator." ]
                , viewBenefit device language "High availability" [ text "Multiple backup nodes in different data centers allow to maximise uptime. I also developed seamless upgrade and failover scripts to achieve zero maintenance downtime." ]
                , viewBenefit device favorite "Commitment" [ text "I want to make Radix a success and put a lot of effort into my validator. Also, I will only be staking on my own node and putting my money where my mouth is." ]
                , viewBenefit device notifications_active "Realtime Alerts" [ text "The validator is constantly monitored 24/7 in real time to immediately trigger alerts in case of outtakes to minimise downtime." ]
                , viewBenefit device
                    build
                    "Experience"
                    [ text "I have a lot of experience in running production-grade servers as a software developer and also wrote a "
                    , link [ Font.color cello, Font.semiBold, mouseOver [ Font.color mainBrand ] ]
                        { url = "https://github.com/fpieper/fpstaking/blob/main/docs/validator_guide.md"
                        , label = text "validator guide"
                        }
                    , text " to help other node-runners configuring their validator in a secure way."
                    ]
                , viewBenefit device security "Secure" [ text "The validator and failover node are hardened with best security practices to minimise attack vectors and are protected against DDOS attacks." ]
                , viewBenefit device face "Transparent" [ text "Since I stumbled across Radix I had a lot of fun researching possible competitors and therefore am quite active and known in the community." ]
                ]
        ]


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
            , label = Input.labelAbove [] <| text "Staked Tokens"
            }
        , Input.slider
            sliderStyle
            { onChange = UnlockedTokensShareChanged
            , label =
                Input.labelAbove [] <|
                    row [ width fill ]
                        [ text "Unlocked Tokens"
                        , el [ Font.color darkShades, Font.semiBold, alignRight ] <|
                            text <|
                                String.fromInt model.unlockedTokensShare
                                    ++ "%"
                        ]
            , min = 35
            , max = 100
            , step = Just 5
            , value = toFloat model.unlockedTokensShare
            , thumb =
                thumb
            }
        , Input.slider
            sliderStyle
            { onChange = StakingRatioChanged
            , label =
                Input.labelAbove [] <|
                    row [ width fill ]
                        [ text "Staking Ratio"
                        , el [ Font.color darkShades, Font.semiBold, alignRight ] <|
                            text <|
                                String.fromInt model.stakingRatio
                                    ++ "%"
                        ]
            , min = 0
            , max = 100
            , step = Just 5
            , value = toFloat model.stakingRatio
            , thumb =
                thumb
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
            circulating =
                bigIntMulFloat (toFloat model.unlockedTokensShare / 100) (safeBigInt "3842000000")

            totalStaked =
                bigIntMulFloat (toFloat model.stakingRatio / 100) circulating

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
                [ { key = text "Circulating"
                  , value =
                        el [ alignRight ] <| text <| formatWithDecimals 2 (bigIntDivToFloat circulating (safeBigInt "1000000000")) ++ "B XRD"
                  }
                , { key = text "Total Staked"
                  , value = el [ alignRight ] <| text <| formatWithDecimals 2 (bigIntDivToFloat totalStaked (safeBigInt "1000000000")) ++ "B XRD"
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


viewUptime : Model -> Element Msg
viewUptime model =
    column [ centerX, spacing normal ]
        [ el [ centerX ] <| heading "Uptime"
        , el [ centerX ] <| text "Coming soon"
        ]


viewValidatorAddress : Element Msg
viewValidatorAddress =
    column [ centerX, spacing normal ]
        [ el [ centerX, Font.center ] <| heading "Validator Address"
        , paragraph
            [ centerX
            , Border.color mainBrand
            , Border.width 3
            , Border.rounded 5
            , padding normal
            , width fill
            , mouseOver [ Background.color white ]
            , htmlAttribute <| Html.Attributes.style "word-break" "break-all"
            ]
            [ text "rv1qfxktwkq9amdh678cxfynzt4zeua2tkh8nnrtcjpt7fyl0lmu8r3urllukm"
            ]

        --}
        ]


view : Device -> Model -> Element Msg
view device model =
    column [ width fill, spacing xLarge, Font.color darkShades, paddingXY 0 0 ]
        [ viewHeader device model
        , viewBenefits device model
        , viewValidatorAddress
        , viewStakingCalculator device model
        , viewUptime model
        , viewContact
        , viewFooter
        ]
