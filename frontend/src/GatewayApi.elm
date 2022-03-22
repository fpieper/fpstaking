module GatewayApi exposing (..)

import BigInt exposing (BigInt)
import Http exposing (Body, Error, Expect, header, jsonBody)
import Json.Decode as Decode exposing (Decoder, andThen, at, bool, fail, field, float, int, list, string, succeed)
import Json.Decode.Pipeline exposing (hardcoded, required, requiredAt)
import Json.Encode as Encode


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


type alias StakePosition =
    { amount : BigInt
    , validator : String
    }



-- HTTP


gatewayRequest : { endpoint : String, body : Body, expect : Expect msg } -> Cmd msg
gatewayRequest { endpoint, body, expect } =
    Http.request
        { method = "POST"
        , headers = [] --[ header "X-Radixdlt-Target-Gw-Api" "1.0.2" ]
        , url = "https://mainnet.clana.io/" ++ endpoint
        , body = body
        , expect = expect
        , timeout = Nothing
        , tracker = Nothing
        }


getValidatorsRequest : (Result Error (List Validator) -> msg) -> Cmd msg
getValidatorsRequest msg =
    gatewayRequest
        { endpoint = "validators"
        , body = jsonBody mainnetIdentifier
        , expect = Http.expectJson msg validatorsDecoder
        }


getStakePositionsRequest : String -> (Result Error (List StakePosition) -> msg) -> Cmd msg
getStakePositionsRequest address msg =
    gatewayRequest
        { endpoint = "account/stakes"
        , body = jsonBody (stakePositionsRequestBody address)
        , expect = Http.expectJson msg stakePositionsDecoder
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


validatorDecoder : Decoder Validator
validatorDecoder =
    Decode.succeed Validator
        |> requiredAt [ "stake", "value" ] bigIntDecoder
        |> requiredAt [ "info", "uptime", "uptime_percentage" ] float
        |> requiredAt [ "info", "uptime", "proposals_missed" ] int
        |> requiredAt [ "validator_identifier", "address" ] string
        |> requiredAt [ "properties", "url" ] string
        |> requiredAt [ "info", "owner_stake", "value" ] bigIntDecoder
        |> requiredAt [ "properties", "name" ] (Decode.map String.trim string)
        |> requiredAt [ "properties", "validator_fee_percentage" ] float
        |> requiredAt [ "properties", "registered" ] bool
        |> requiredAt [ "properties", "owner_account_identifier", "address" ] string
        |> requiredAt [ "properties", "external_stake_accepted" ] bool
        |> requiredAt [ "info", "uptime", "proposals_completed" ] int
        |> hardcoded Nothing
        |> hardcoded 0
        |> hardcoded 0


validatorsDecoder : Decoder (List Validator)
validatorsDecoder =
    field "validators" <|
        list validatorDecoder


stakePositionDecoder : Decoder StakePosition
stakePositionDecoder =
    Decode.map2 StakePosition
        (at [ "delegated_stake", "value" ] bigIntDecoder)
        (at [ "validator_identifier", "address" ] string)


stakePositionsDecoder : Decoder (List StakePosition)
stakePositionsDecoder =
    field "stakes" <|
        list stakePositionDecoder


mainnetIdentifier : Encode.Value
mainnetIdentifier =
    Encode.object
        [ ( "network_identifier"
          , Encode.object
                [ ( "network", Encode.string "mainnet" )
                ]
          )
        ]


stakePositionsRequestBody : String -> Encode.Value
stakePositionsRequestBody address =
    Encode.object
        [ ( "network_identifier"
          , Encode.object
                [ ( "network", Encode.string "mainnet" )
                ]
          )
        , ( "account_identifier"
          , Encode.object
                [ ( "address", Encode.string address )
                ]
          )
        ]
