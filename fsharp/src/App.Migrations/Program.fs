namespace App

module Migrations =
    open System
    open System.Reflection

    open DbUp
    open DbUp.Engine
    open DbUp.Helpers
    open FsToolkit.ErrorHandling
    open Npgsql

    let private buildEngine (connectionString: NpgsqlConnection) =
        let connection = connectionString.ConnectionString
        DeployChanges.To.PostgresqlDatabase(connection).LogToConsole().WithTransaction().WithVariablesDisabled()

    let private performUpgrade (engine: UpgradeEngine) =
        let result = engine.PerformUpgrade()
        if result.Successful then Ok() else Error result.Error

    // i.e. functions/views/etc
    let private isRepeatableMigration (migration: string) = migration.Contains("/repeatable/")

    let migrate connectionString =
        let defaultEngine =
            (buildEngine connectionString)
                .WithScriptsEmbeddedInAssembly(Assembly.GetExecutingAssembly(), isRepeatableMigration >> not)
                .Build()

        let repeatableEngine =
            (buildEngine connectionString)
                .WithScriptsEmbeddedInAssembly(Assembly.GetExecutingAssembly(), isRepeatableMigration)
                .JournalTo(new NullJournal())
                .Build()

        performUpgrade defaultEngine
        |> Result.bind (fun _ -> performUpgrade repeatableEngine)

    [<EntryPoint>]
    let main _ =
        let configuration =
            match Settings.load () with
            | Ok c -> c
            | Error e -> failwith e

        let value =
            result {
                let connection = configuration.Database.ToString()
                use connectionString = new NpgsqlConnection(connection)
                do! migrate connectionString
            }

        match value with
        | Ok _ ->
            Console.WriteLine $"[DATABASE] Migrations successfully applied at: {configuration.Database.Hostname}!."
            0
        | Error exn ->
            Console.WriteLine(exn.ToString())
            1
