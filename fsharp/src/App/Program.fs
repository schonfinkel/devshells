open System

open App.Migrations
open FsToolkit.ErrorHandling

[<EntryPoint>]
let main _ =
    let configuration =
        match App.Settings.load () with
        | Ok c -> c
        | Error e -> failwith e

    result {
        let connection = configuration.Database.ToString()
        do! App.Migrations.migrate connection
        Console.WriteLine $"[DATABASE] Migrations successfully applied at: {configuration.Database.Hostname}!."
        return 0
    }
    |> Result.defaultWith App.Migrations.crashOnError
