namespace App

open System

module Settings =
    open System.IO
 
    open FsConfig
    open FsToolkit.ErrorHandling

    [<Convention("DATABASE")>]
    type Database =
        { [<DefaultValue("127.0.0.1")>]
          Hostname: string
          [<DefaultValue("admin")>]
          Password: string
          [<DefaultValue("admin")>]
          User: string
          [<DefaultValue("app")>]
          Database: string
          [<DefaultValue("5432")>]
          Port: int }

        override this.ToString() =
            $"Server={this.Hostname};Port={this.Port};Database={this.Database};User Id={this.User};Password={this.Password};"

    [<Convention("APP")>]
    type AppSettings =
        { [<DefaultValue("DEVELOPMENT")>]
          Environment: AppEnvironment }

    and AppEnvironment =
        | DEVELOPMENT
        | TEST
        | PRODUCTION

    type Configuration =
        { App: AppSettings; Database: Database }

    let load () =
        result {
            let! database = EnvConfig.Get<Database>()
            let! app = EnvConfig.Get<AppSettings>()

            return { App = app; Database = database }

        }
        |> Result.mapError (fun error ->
            match error with
            | NotFound envVarName -> failwith $"Environment variable {envVarName} not found"
            | BadValue(envVarName, value) -> failwith $"Environment variable {envVarName} has invalid value {value}"
            | NotSupported msg -> failwith msg)
