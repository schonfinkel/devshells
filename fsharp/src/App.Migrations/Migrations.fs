namespace App

module Migrations =
    open System
    open System.IO

    open DbUp
    open DbUp.Engine
    open DbUp.Helpers
    open FsToolkit.ErrorHandling

    type UpgradeError =
        | BrokenMigrations of Message: string
        | MigrationPathDoesNotExist of Path: string

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
            Error(BrokenMigrations result.Error.Message)

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
            Error(MigrationPathDoesNotExist path)

    let crashOnError (e: UpgradeError) =
        let message =
            match e with
            | BrokenMigrations err -> err
            | MigrationPathDoesNotExist path -> path

        Console.WriteLine message
        1
