module type S = sig
  type t

  val length : t -> int

  val get : t -> int -> char

  val blit : t -> int -> bytes -> int -> int -> unit
end

module String : S with type t = string = struct
  type t = string

  let length = String.length

  let get = String.unsafe_get

  let blit = Bytes.unsafe_blit_string
end

module Bytes : S with type t = bytes = struct
  type t = bytes

  let length = Bytes.length

  let get = Bytes.unsafe_get

  let blit = Bytes.unsafe_blit
end
