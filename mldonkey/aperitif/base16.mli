val default_alphabet : string

val lowercase_alphabet : string

type error = string

val encode_string :
  ?alphabet:string -> ?off:int -> ?len:int -> string -> (string, error) result

val encode_bytes :
  ?alphabet:string -> ?off:int -> ?len:int -> bytes -> (string, error) result

val encode_string_exn :
  ?alphabet:string -> ?off:int -> ?len:int -> string -> string

val encode_bytes_exn :
  ?alphabet:string -> ?off:int -> ?len:int -> bytes -> string

val decode_string :
  ?alphabet:string -> ?off:int -> ?len:int -> string -> (string, error) result

val decode_bytes :
  ?alphabet:string -> ?off:int -> ?len:int -> bytes -> (string, error) result

val decode_string_exn :
  ?alphabet:string -> ?off:int -> ?len:int -> string -> string

val decode_bytes_exn :
  ?alphabet:string -> ?off:int -> ?len:int -> bytes -> string
