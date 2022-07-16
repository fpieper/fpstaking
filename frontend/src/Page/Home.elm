module Page.Home exposing (..)

import BigInt exposing (BigInt)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import GatewayApi exposing (StakePosition, Validator, getStakePositionsRequest, getValidatorsRequest)
import Html.Attributes
import Http
import Loading exposing (LoaderType(..), defaultConfig)
import Material.Icons.Outlined exposing (build, cloud_off, face, favorite, language, notifications_active, paid, security)
import Page.Validators exposing (addGroups)
import Palette exposing (..)
import RemoteData exposing (RemoteData(..))
import UI exposing (Icon, heading, icon, inputHint, sliderStyle, subHeading, thumb, viewContact, viewFactTable, viewFooter)
import Utils exposing (bigIntDivToFloat, bigIntMulFloat, bigIntSum, formatWithDecimals, safeBigInt, toXRD)



-- MODEL


type alias Model =
    { validators : RemoteData Http.Error (List Validator)
    , stakedTokens : StakedTokens
    , stakedTokensRaw : String
    , totalStake : BigInt
    , validatorFee : Float
    , uptime : Float
    }


type StakedTokens
    = StakeAmount Int
    | WalletAddress String (RemoteData Http.Error (List StakePosition))



-- INIT


init : ( Model, Cmd Msg )
init =
    ( { validators = NotAsked
      , totalStake = BigInt.fromInt 0
      , stakedTokens = StakeAmount 0
      , stakedTokensRaw = ""
      , validatorFee = 0
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
    | GotStakePositions (Result Http.Error (List StakePosition))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TokensStakedChanged tokens ->
            let
                tokens_ =
                    String.trim tokens
            in
            if String.length tokens_ == 0 then
                ( { model | stakedTokens = StakeAmount 0, stakedTokensRaw = tokens }, Cmd.none )

            else if String.length tokens_ == 65 then
                ( { model | stakedTokens = WalletAddress tokens_ Loading, stakedTokensRaw = tokens }, getStakePositionsRequest tokens_ GotStakePositions )

            else
                case String.toInt tokens_ of
                    Just t ->
                        ( { model | stakedTokens = StakeAmount t, stakedTokensRaw = tokens }, Cmd.none )

                    Nothing ->
                        ( { model | stakedTokens = StakeAmount 0, stakedTokensRaw = tokens }, Cmd.none )

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

        GotStakePositions stakePositions ->
            case model.stakedTokens of
                StakeAmount _ ->
                    ( model, Cmd.none )

                WalletAddress address currentStakePositions ->
                    let
                        newStakePositions =
                            case stakePositions of
                                Ok stakePositions_ ->
                                    Success stakePositions_

                                Err error ->
                                    Failure error
                    in
                    ( { model
                        | stakedTokens = WalletAddress address newStakePositions
                      }
                    , Cmd.none
                    )



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
                , viewBenefit device paid "Low Fees" [ text "My validator fee is 3.4%. Low fees combined with high uptime ensure that your rewards are maximised. You can calculate your expected APY in my staking calculator." ]
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
            ((case model.stakedTokens of
                StakeAmount _ ->
                    [ inputHint mainBrand <| text "XRD" ]

                _ ->
                    []
             )
                ++ [ Background.color mainBrand
                   , Border.color darkShades
                   , Font.semiBold
                   ]
            )
            { onChange = TokensStakedChanged
            , text =
                model.stakedTokensRaw
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
            tokensStaked =
                case model.stakedTokens of
                    StakeAmount amount ->
                        amount

                    WalletAddress _ (Success positions) ->
                        positions
                            |> List.map (\p -> p.amount |> toXRD |> BigInt.toString |> String.toInt |> Maybe.withDefault 0)
                            |> List.sum

                    _ ->
                        0

            totalStaked =
                toXRD model.totalStake

            stakingShare =
                bigIntDivToFloat (BigInt.fromInt tokensStaked) totalStaked * 100

            feeFactor =
                1 - (model.validatorFee / 100)

            uptimeFactor =
                ((model.uptime / 100) - 0.98) / 0.02

            stakingRewardsYearly =
                (stakingShare / 100) * 300000000 * feeFactor * uptimeFactor

            stakingRewardsMonthly =
                stakingRewardsYearly / 12

            stakingRewardsDaily =
                stakingRewardsYearly / 365

            apy =
                if tokensStaked == 0 then
                    0

                else
                    (stakingRewardsYearly / toFloat tokensStaked) * 100
          in
          case model.stakedTokens of
            WalletAddress _ Loading ->
                el [ centerX, centerY ] <|
                    html <|
                        Loading.render
                            DoubleBounce
                            { defaultConfig | color = "#2E294E", size = toFloat large, speed = 1 }
                            Loading.On

            _ ->
                row [ width fill, spacing normal ]
                    [ viewFactTable [ width fill, spacing small ]
                        []
                        [ { key = text "Total Staked"
                          , value = el [ alignRight ] <| text <| formatWithDecimals 2 (bigIntDivToFloat totalStaked (safeBigInt "1000000000")) ++ "B XRD"
                          }
                        , { key = text "Staked"
                          , value = el [ alignRight ] <| text <| String.fromInt tokensStaked ++ " XRD"
                          }
                        , { key = text "Rewards (yearly)"
                          , value = el [ alignRight, Font.semiBold ] <| text <| String.fromInt (round stakingRewardsYearly) ++ " XRD"
                          }
                        , { key = text "Rewards (monthly)"
                          , value = el [ alignRight, Font.semiBold ] <| text <| String.fromInt (round stakingRewardsMonthly) ++ " XRD"
                          }
                        , { key = text "Rewards (daily)"
                          , value = el [ alignRight, Font.semiBold ] <| text <| String.fromInt (round stakingRewardsDaily) ++ " XRD"
                          }
                        , { key = text "APY"
                          , value = el [ alignRight, Font.semiBold ] <| text <| formatWithDecimals 2 apy ++ " %"
                          }
                        ]
                    ]
        ]


viewUptime : Model -> Element Msg
viewUptime model =
    let
        validator : Maybe Validator
        validator =
            case model.validators of
                Success validators ->
                    List.filter (\v -> v.address == "rv1qfxktwkq9amdh678cxfynzt4zeua2tkh8nnrtcjpt7fyl0lmu8r3urllukm") validators |> List.head

                _ ->
                    Nothing
    in
    column [ centerX, spacing normal ]
        [ el [ centerX ] <| heading "Uptime"
        , el [ centerX ] <|
            text <|
                case model.validators of
                    Success validators ->
                        validators
                            |> List.filter (\v -> v.address == "rv1qfxktwkq9amdh678cxfynzt4zeua2tkh8nnrtcjpt7fyl0lmu8r3urllukm")
                            |> List.head
                            |> Maybe.map (\v -> formatWithDecimals 2 v.uptimePercentage ++ "%")
                            |> Maybe.withDefault ""

                    _ ->
                        ""
        ]


viewValidators : Element Msg
viewValidators =
    column [ centerX, spacing normal ]
        [ el [ centerX, Font.center ] <| heading "Validators"
        , link
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
            { url = "/validators"
            , label = text "Show All Radix Validators"
            }
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
        , viewValidators
        , viewContact
        , viewFooter
        ]
