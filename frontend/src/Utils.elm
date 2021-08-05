module Utils exposing (..)

import BigInt exposing (BigInt)


roundBy : Int -> Float -> Float
roundBy decimals number =
    let
        factor =
            10.0 ^ toFloat decimals
    in
    toFloat (number * factor |> round) / factor


formatWithDecimals : Int -> Float -> String
formatWithDecimals decimals number =
    let
        number_ =
            roundBy decimals number
    in
    case number_ |> String.fromFloat |> String.split "." of
        [ n ] ->
            n ++ "." ++ String.repeat decimals "0"

        [ n, d ] ->
            n ++ "." ++ String.padRight decimals '0' d

        _ ->
            String.fromFloat number_



-- BIGINT


safeBigInt : String -> BigInt
safeBigInt input =
    input
        |> BigInt.fromIntString
        |> Maybe.withDefault (BigInt.fromInt 0)


bigIntMulFloat : Float -> BigInt -> BigInt
bigIntMulFloat rate number =
    BigInt.div
        (BigInt.mul (BigInt.fromInt <| round <| rate * 1000000000000)
            number
        )
        (safeBigInt "1000000000000")


bigIntDivToFloat : BigInt -> BigInt -> Float
bigIntDivToFloat a b =
    (BigInt.div (BigInt.mul a (safeBigInt "1000000000000")) b
        |> BigInt.toString
        |> String.toFloat
        |> Maybe.withDefault 0
    )
        / 1000000000000
