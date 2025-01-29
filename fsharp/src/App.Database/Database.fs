namespace App

open Npgsql.FSharp

module Database =
    let hello name = printfn "Hello %s" name
