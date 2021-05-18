let default_alphabet = "0123456789ABCDEF"

let lowercase_alphabet = "0123456789abcdef"

let encode ?(alphabet = default_alphabet) ?(off = 0) ?len input =
  let real_len = String.length input in
  let len = Option.value ~default:(real_len - off) len in
  if len < 0 || off < 0 || off > real_len - len then Error "Invalid bounds"
  else if String.length alphabet <> 16 then Error "Invalid alphabet"
  else
    let res = Bytes.create (len * 2) in
    let chr = String.unsafe_get alphabet in
    for i = 0 to len - 1 do
      let c = Char.code (String.unsafe_get input (off + i)) in
      Bytes.unsafe_set res (i * 2) (chr ((c lsr 4) land 15));
      Bytes.unsafe_set res ((i * 2) + 1) (chr (c land 15))
    done;
    Ok (Bytes.unsafe_to_string res)

let%test _ = encode "SSSS.DYNAZENON" = Ok "535353532E44594E415A454E4F4E"

let%test _ =
  encode ~alphabet:lowercase_alphabet "SSSS.DYNAZENON"
  = Ok "535353532e44594e415a454e4f4e"

let%test _ = encode ~off:4 "DYNAZENON" = Ok "5A454E4F4E"

let%test _ = encode ~len:4 "DYNAZENON" = Ok "44594E41"

let%test _ = encode ~off:2 ~len:4 "DYNAZENON" = Ok "4E415A45"

let encode_exn ?alphabet ?off ?len input =
  match encode ?alphabet ?off ?len input with
  | Ok str -> str
  | Error err -> invalid_arg err

let decode ?(alphabet = default_alphabet) ?(off = 0) ?len input =
  let real_len = String.length input in
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
      let i0 = input.[off + (i * 2)] |> Hashtbl.find char_map in
      let i1 = input.[off + (i * 2) + 1] |> Hashtbl.find char_map in
      let c = (i0 lsl 4) lor i1 in
      Bytes.set res i (Char.chr c)
    done;
    Ok (Bytes.unsafe_to_string res)

let%test _ = decode "535353532E44594E415A454E4F4E" = Ok "SSSS.DYNAZENON"

let decode_exn ?alphabet ?off ?len input =
  match encode ?alphabet ?off ?len input with
  | Ok str -> str
  | Error err -> invalid_arg err
