namespace App

module Migrations =
    open System
    open System.IO

    open DbUp
    open DbUp.Engine
    open DbUp.Helpers
    open FsToolkit.ErrorHandling

    type MigrationError = MigrationError of string

    // i.e. functions/views/etc
    let private isRepeatableMigration (migration: string) = migration.Contains("repeatable")
    let private isMainMigration (migration: string) = migration.Contains("main")

    let private setupBuilder (conn: string) path (predicate: string -> bool) =
        DeployChanges.To
            .PostgresqlDatabase(conn)
            .LogToConsole()
            .WithTransaction()
            .WithVariablesDisabled()
            .WithScriptsFromFileSystem(path, predicate)

    let private attemptMigrationWithEngine (engine: UpgradeEngine) =
        let result = engine.PerformUpgrade()

        if result.Successful then
            Ok()
        else
            Error(MigrationError result.Error.Message)

    let private performUpgrade (engines: UpgradeEngine list) =
        engines
        |> List.traverseResultM attemptMigrationWithEngine
        |> Result.map (fun _ -> ())

    let migrate connectionString =
        let path = Path.Combine(__SOURCE_DIRECTORY__, "migrations")
        if Directory.Exists path then
            let main = Path.Combine(path, "main")
            let repeatable = Path.Combine(path, "repeatable")
            let defaultEngine = (setupBuilder connectionString main isMainMigration).Build()
            let repeatableEngine =
                (setupBuilder connectionString repeatable isRepeatableMigration).JournalTo(new NullJournal()).Build()
            performUpgrade [ defaultEngine; repeatableEngine ]
        else
            Error (MigrationError $"Migration PATH = {path} does not exist")

    [<EntryPoint>]
    let main _ =
        let configuration =
            match Settings.load () with
            | Ok c -> c
            | Error e -> failwith e

        result {
            let connection = configuration.Database.ToString()
            do! migrate connection
            Console.WriteLine $"[DATABASE] Migrations successfully applied at: {configuration.Database.Hostname}!."
            return 1
        }
        |> Result.defaultWith (fun (MigrationError e) ->
            Console.WriteLine e
            1)
