open System

open FsToolkit.ErrorHandling
open Npgsql

[<EntryPoint>]
let main _ =
    let configuration =
        match App.Settings.load () with
        | Ok c -> c
        | Error e -> failwith e

    let value =
        result {
            let connection = configuration.Database.ToString()
            use connectionString = new NpgsqlConnection(connection)
            do! App.Migrations.migrate connectionString
            ()
        }

    match value with
    | Ok _ ->
        Console.WriteLine $"[DATABASE] Migrations successfully applied at: {configuration.Database.Hostname}!."
        0
    | Error exn ->
        Console.WriteLine(exn.ToString())
        1
