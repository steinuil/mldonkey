type error = string

val digest_string : ?off:int -> ?len:int -> string -> (string, error) result

val digest_string_exn : ?off:int -> ?len:int -> string -> string

val digest_bytes : ?off:int -> ?len:int -> bytes -> (string, error) result

val digest_bytes_exn : ?off:int -> ?len:int -> bytes -> string
