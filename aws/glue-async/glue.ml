open! Values
open! Core
open! Async

type already_exists_error = [ `AlreadyExistsException ] [@@deriving yojson]

let create_database ?catalog_id ?description ~name cfg =
  Io.create_database
    ~cfg
    (CreateDatabaseRequest.make
       ?catalogId:(Option.map ~f:CatalogIdString.make catalog_id)
       ~databaseInput:
         (DatabaseInput.make
            ?description:(Option.map ~f:DescriptionString.make description)
            ~name:(NameString.make name)
            ())
       ())
  >>= function
  | Ok x -> return x
  | Error _ -> failwithf "Glue.create_database" ()
;;
