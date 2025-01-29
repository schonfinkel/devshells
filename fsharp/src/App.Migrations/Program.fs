namespace App

module Migrations =
    open System
    open System.IO

    open DbUp
    open DbUp.Engine
    open FsToolkit.ErrorHandling
    
    type MigrationError = MigrationError of string
    
    // i.e. functions/views/etc
    let private isRepeatableMigration (migration: string) = migration.Contains("/repeatable/")
    let private isMainMigration (migration: string) = migration.Contains("/main/")

    let private buildEngine (conn: string) path (predicate: string -> bool) =
        DeployChanges.To
            .PostgresqlDatabase(conn)
            .LogToConsole().WithTransaction().WithVariablesDisabled()
            .WithScriptsFromFileSystem(path, predicate)
            .Build()

    let private attemptMigrationWithEngine (engine: UpgradeEngine) =
        let result = engine.PerformUpgrade()
        if result.Successful then Ok () else Error (MigrationError result.Error.Message)
        
    let private performUpgrade (engines: UpgradeEngine list) =
        engines
        |> List.traverseResultM attemptMigrationWithEngine
        |> Result.map (fun _ -> ())
 
    let migrate connectionString =
        let path = Path.Combine(__SOURCE_DIRECTORY__, "migrations")
        let defaultEngine = buildEngine connectionString path isMainMigration
        let repeatableEngine = buildEngine connectionString path isRepeatableMigration
        performUpgrade [defaultEngine; repeatableEngine]

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
        |> Result.defaultWith(fun (MigrationError e) -> Console.WriteLine e; 1)
