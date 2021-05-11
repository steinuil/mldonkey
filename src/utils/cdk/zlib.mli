exception Error of string * string

val compress:
  ?level: int -> ?header: bool -> 
  (bytes -> int) -> (bytes -> int -> unit) -> unit

val uncompress:
  ?header: bool -> (bytes -> int) -> (bytes -> int -> unit) -> unit

type stream

type flush_command =
    Z_NO_FLUSH
  | Z_SYNC_FLUSH
  | Z_FULL_FLUSH
  | Z_FINISH

external deflate_init: int -> bool -> stream = "camlzip_deflateInit"
external deflate:
  stream -> bytes -> int -> int -> bytes -> int -> int -> flush_command
         -> bool * int * int
  = "camlzip_deflate_bytecode" "camlzip_deflate"
external deflate_end: stream -> unit = "camlzip_deflateEnd"

external inflate_init: bool -> stream = "camlzip_inflateInit"
external inflate:
  stream -> bytes -> int -> int -> bytes -> int -> int -> flush_command
         -> bool * int * int
  = "camlzip_inflate_bytecode" "camlzip_inflate"
external inflate_end: stream -> unit = "camlzip_inflateEnd"

external update_crc: int32 -> bytes -> int -> int -> int32
                   = "camlzip_update_crc32"

val uncompress_string : bytes -> string
val uncompress_string2 : bytes -> string
val compress_string : ?level:int -> bytes -> bytes
val gzip_string : ?level:int -> string -> string

val zlib_version_num : unit -> string
