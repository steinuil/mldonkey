let default_alphabet = "0123456789ABCDEF"

let lowercase_alphabet = "0123456789abcdef"

type error = string

module Make (I : Input.S) = struct
  let encode ?(alphabet = default_alphabet) ?(off = 0) ?len input =
    let real_len = I.length input in
    let len = Option.value ~default:(real_len - off) len in
    if len < 0 || off < 0 || off > real_len - len then Error "Invalid bounds"
    else if String.length alphabet <> 16 then Error "Invalid alphabet"
    else
      let res = Bytes.create (len * 2) in
      let chr = String.unsafe_get alphabet in
      for i = 0 to len - 1 do
        let c = Char.code (I.get input (off + i)) in
        Bytes.unsafe_set res (i * 2) (chr ((c lsr 4) land 15));
        Bytes.unsafe_set res ((i * 2) + 1) (chr (c land 15))
      done;
      Ok (Bytes.unsafe_to_string res)

  let encode_exn ?alphabet ?off ?len input =
    match encode ?alphabet ?off ?len input with
    | Ok str -> str
    | Error err -> invalid_arg err

  let decode ?(alphabet = default_alphabet) ?(off = 0) ?len input =
    let real_len = I.length input in
    let len = Option.value ~default:(real_len - off) len in
    if len < 0 || off < 0 || off > real_len - len || len mod 2 <> 0 then
      Error "Invalid bounds"
    else if String.length alphabet <> 16 then Error "Invalid alphabet"
    else
      let char_map =
        let t = Hashtbl.create 16 in
        String.iteri (fun i c -> Hashtbl.add t c i) alphabet;
        t
      in
      let res = Bytes.create (len / 2) in
      for i = 0 to (len / 2) - 1 do
        let i0 = I.get input (off + (i * 2)) |> Hashtbl.find char_map in
        let i1 = I.get input (off + (i * 2) + 1) |> Hashtbl.find char_map in
        let c = (i0 lsl 4) lor i1 in
        Bytes.set res i (Char.chr c)
      done;
      Ok (Bytes.unsafe_to_string res)

  let decode_exn ?alphabet ?off ?len input =
    match decode ?alphabet ?off ?len input with
    | Ok str -> str
    | Error err -> invalid_arg err
end

module Base16_string = Make (Input.String)
module Base16_bytes = Make (Input.Bytes)

let encode_string = Base16_string.encode

let encode_bytes = Base16_bytes.encode

let encode_string_exn = Base16_string.encode_exn

let encode_bytes_exn = Base16_bytes.encode_exn

let decode_string = Base16_string.decode

let decode_bytes = Base16_bytes.decode

let decode_string_exn = Base16_string.decode_exn

let decode_bytes_exn = Base16_bytes.decode_exn

let%test _ = encode_string "SSSS.DYNAZENON" = Ok "535353532E44594E415A454E4F4E"

let%test _ =
  encode_string ~alphabet:lowercase_alphabet "SSSS.DYNAZENON"
  = Ok "535353532e44594e415a454e4f4e"

let%test _ = encode_string ~off:4 "DYNAZENON" = Ok "5A454E4F4E"

let%test _ = encode_string ~len:4 "DYNAZENON" = Ok "44594E41"

let%test _ = encode_string ~off:2 ~len:4 "DYNAZENON" = Ok "4E415A45"

let%test _ = decode_string "535353532E44594E415A454E4F4E" = Ok "SSSS.DYNAZENON"

let%test _ =
  decode_string ~alphabet:lowercase_alphabet "535353532e44594e415a454e4f4e"
  = Ok "SSSS.DYNAZENON"

let%test _ = decode_string ~off:8 "44594E415A454E4F4E" = Ok "ZENON"

let%test _ = decode_string ~len:8 "44594E415A454E4F4E" = Ok "DYNA"

let%test _ = decode_string ~off:4 ~len:8 "44594E415A454E4F4E" = Ok "NAZE"
