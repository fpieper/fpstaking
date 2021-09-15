module ArchiveApi exposing (..)

import BigInt exposing (BigInt)
import Http exposing (Error, jsonBody)
import Json.Decode as Decode exposing (Decoder, andThen, bool, fail, field, int, list, string, succeed)
import Json.Decode.Pipeline exposing (hardcoded, required)
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


archiveEndpoint =
    "https://api.florianpieperstaking.com/archive"


getValidatorsRequest : (Result Error (List Validator) -> msg) -> Cmd msg
getValidatorsRequest msg =
    Http.post
        { url = archiveEndpoint
        , body = jsonBody getNextEpochSet
        , expect = Http.expectJson msg validatorsDecoder
        }


getStakePositionsRequest : String -> (Result Error (List StakePosition) -> msg) -> Cmd msg
getStakePositionsRequest address msg =
    Http.post
        { url = archiveEndpoint
        , body = jsonBody (getStakePositions address)
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


stakePositionDecoder : Decoder StakePosition
stakePositionDecoder =
    Decode.map2 StakePosition
        (field "amount" bigIntDecoder)
        (field "validator" string)


stakePositionsDecoder : Decoder (List StakePosition)
stakePositionsDecoder =
    field "result" <|
        list stakePositionDecoder


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


getStakePositions : String -> Encode.Value
getStakePositions address =
    Encode.object
        [ ( "jsonrpc", Encode.string "2.0" )
        , ( "method", Encode.string "account.get_stake_positions" )
        , ( "params"
          , Encode.object
                [ ( "address", Encode.string address )
                ]
          )
        , ( "id", Encode.int 1 )
        ]
