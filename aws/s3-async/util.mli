open! Values
open! Core
open! Async

val put_object
  :  Awso.Cfg.t
  -> bucket:BucketName.t
  -> key:string
  -> string
  -> ( ETag.t
     , [ `Missing_etag
       | `Put_object of
         [ `AWS of PutObjectOutput.error | `Transport of Awso.Http.Io.Error.call ]
       ] )
     Result.t
     Deferred.t

val delete_object
  :  Awso.Cfg.t
  -> bucket:string
  -> key:string
  -> ( DeleteObjectOutput.t
     , [ `AWS of DeleteObjectOutput.error | `Transport of Awso.Http.Io.Error.call ]
     )
     Result.t
     Deferred.t

val put_file
  :  Awso.Cfg.t
  -> bucket:string
  -> key:string
  -> string
  -> ( string
     , [> `Put_object of
          [ `AWS of PutObjectOutput.error | `Transport of Awso.Http.Io.Error.call ]
       | `Missing_etag
       ] )
     result
     Deferred.t

type ('acc, 'error) callback =
  'acc
  -> total:int64
  -> loaded:int64
  -> key:string
  -> part:int64
  -> num_parts:int64
  -> [ `Complete of ETag.t
     | `Initial of MultipartUploadId.t
     | `Partition of ETag.t
     ]
  -> ('acc, 'error) Deferred.Result.t

val initialize_multipart
  :  Awso.Cfg.t
  -> bucket:string
  -> key:string
  -> ( [> `Upload_id of string ]
     , [> `Create_multipart_upload of
          [ `AWS of CreateMultipartUploadOutput.error
          | `Transport of Awso.Http.Io.Error.call
          ]
       | `Missing_upload_id
       ] )
     result
     Deferred.t

(** @param chunk_size The maximum size of a part for a multipart transfer. *)
val multipart
  :  Awso.Cfg.t
  -> ?chunk_size:Byte_units.t
  -> ?part:int
  -> ?file_offset:int64
  -> bucket:string
  -> key:string
  -> init:'acc
  -> cb:('acc, 'error) callback
  -> upload_id:string
  -> string
  -> ( 'acc * CompletedPart.t list
     , [> `Callback_error of 'acc * CompletedPart.t list * 'error
       | `Complete_multipart_upload of
         [ `AWS of CompleteMultipartUploadOutput.error
         | `Transport of Awso.Http.Io.Error.call
         ]
       | `Upload_part of
         [ `AWS of UploadPartOutput.error | `Transport of Awso.Http.Io.Error.call ]
       ] )
     result
     Deferred.t

val get_object
  :  Awso.Cfg.t
  -> ?range:Awso.Http.Range.t
  -> bucket:string
  -> key:string
  -> unit
  -> ( GetObjectOutput.t
     , [ `AWS of GetObjectOutput.error | `Transport of Awso.Http.Io.Error.call ]
     )
     result
     Deferred.t

module Source : sig
  val default_chunk_size : Byte_units.t

  module File : sig
    val slice
      :  total:int64
      -> file_size:int64
      -> chunk_size:int64
      -> int64
      -> int64 * int64

    val read_slice : start:int64 -> end_:int64 -> string -> string
    val default_num_parts : int64

    type stat =
      { chunk_size : int64
      ; file_size : int64
      ; partitions : int64
      }
    [@@deriving yojson]

    val stat : ?chunk_size:Byte_units.t -> string -> stat Deferred.t
    val load_all : string -> string * int64
  end
end

val map_bucket
  :  Awso.Cfg.t
  -> bucket:string
  -> f:(Object.t -> 'a Deferred.t)
  -> ( 'a list
     , [ `AWS of ListObjectsV2Output.error
       | `Transport of Awso.Http.Io.Error.call
       ] )
     result
     Deferred.t

val iter_bucket
  :  Awso.Cfg.t
  -> bucket:string
  -> f:(Object.t -> unit Deferred.t)
  -> ( unit
     , [ `AWS of ListObjectsV2Output.error
       | `Transport of Awso.Http.Io.Error.call
       ] )
     result
     Deferred.t
