let f x y z = Int32.(logor (logand x y) (logand (lognot x) z))

let g x y z = Int32.(logor (logand x y) (logor (logand x z) (logand y z)))

let h x y z = Int32.(logxor x (logxor y z))

let rol v s = Int32.(logor (shift_left v s) (shift_right_logical v (32 - s)))

let ff x a b c d k s = a := rol Int32.(add !a (add (f !b !c !d) x.(k))) s

let gg x a b c d k s =
  a := rol Int32.(add !a (add (g !b !c !d) (add x.(k) 0x5a827999l))) s

let hh x a b c d k s =
  a := rol Int32.(add !a (add (h !b !c !d) (add x.(k) 0x6ed9eba1l))) s

type error = string

module Make (I : Input.S) = struct
  let pad_message off len input =
    let msg_len =
      len + (64 - (len mod 64)) + if len mod 64 <= 56 then 0 else 64
    in
    let msg = Bytes.create msg_len in
    I.blit input off msg 0 len;
    Bytes.set msg len '\x80';
    Bytes.set_int64_le msg (msg_len - 8) Int64.(mul (of_int len) 8L);
    (msg, msg_len)

  let digest ?(off = 0) ?len input =
    let len = Option.value ~default:(I.length input - off) len in
    if len < 0 || off < 0 || off > I.length input - len then
      Error "Invalid bounds"
    else
      let msg, msg_len = pad_message off len input in

      let a = ref 0x67452301l in
      let b = ref 0xefcdab89l in
      let c = ref 0x98badcfel in
      let d = ref 0x10325476l in

      let block = Array.make 16 0l in

      for i = 0 to (msg_len / 64) - 1 do
        for j = 0 to 15 do
          block.(j) <- Bytes.get_int32_le msg ((i * 64) + (j * 4))
        done;

        let aa = !a in
        let bb = !b in
        let cc = !c in
        let dd = !d in

        ff block a b c d 0 3;
        ff block d a b c 1 7;
        ff block c d a b 2 11;
        ff block b c d a 3 19;
        ff block a b c d 4 3;
        ff block d a b c 5 7;
        ff block c d a b 6 11;
        ff block b c d a 7 19;
        ff block a b c d 8 3;
        ff block d a b c 9 7;
        ff block c d a b 10 11;
        ff block b c d a 11 19;
        ff block a b c d 12 3;
        ff block d a b c 13 7;
        ff block c d a b 14 11;
        ff block b c d a 15 19;

        gg block a b c d 0 3;
        gg block d a b c 4 5;
        gg block c d a b 8 9;
        gg block b c d a 12 13;
        gg block a b c d 1 3;
        gg block d a b c 5 5;
        gg block c d a b 9 9;
        gg block b c d a 13 13;
        gg block a b c d 2 3;
        gg block d a b c 6 5;
        gg block c d a b 10 9;
        gg block b c d a 14 13;
        gg block a b c d 3 3;
        gg block d a b c 7 5;
        gg block c d a b 11 9;
        gg block b c d a 15 13;

        hh block a b c d 0 3;
        hh block d a b c 8 9;
        hh block c d a b 4 11;
        hh block b c d a 12 15;
        hh block a b c d 2 3;
        hh block d a b c 10 9;
        hh block c d a b 6 11;
        hh block b c d a 14 15;
        hh block a b c d 1 3;
        hh block d a b c 9 9;
        hh block c d a b 5 11;
        hh block b c d a 13 15;
        hh block a b c d 3 3;
        hh block d a b c 11 9;
        hh block c d a b 7 11;
        hh block b c d a 15 15;

        a := Int32.add !a aa;
        b := Int32.add !b bb;
        c := Int32.add !c cc;
        d := Int32.add !d dd
      done;

      let out = Bytes.create 16 in

      Bytes.set_int32_le out 0 !a;
      Bytes.set_int32_le out 4 !b;
      Bytes.set_int32_le out 8 !c;
      Bytes.set_int32_le out 12 !d;

      Ok (Bytes.unsafe_to_string out)

  let digest_exn ?off ?len input =
    match digest ?off ?len input with
    | Ok str -> str
    | Error err -> invalid_arg err
end

module Md4_string = Make (Input.String)
module Md4_bytes = Make (Input.Bytes)

let digest_string = Md4_string.digest

let digest_string_exn = Md4_string.digest_exn

let digest_bytes = Md4_bytes.digest

let digest_bytes_exn = Md4_bytes.digest_exn

let unhex s = Base16.decode_string_exn ~alphabet:Base16.lowercase_alphabet s

let%test _ = digest_string_exn "" = unhex "31d6cfe0d16ae931b73c59d7e0c089c0"

let%test _ = digest_string_exn "a" = unhex "bde52cb31de33e46245e05fbdbd6fb24"

let%test _ =
  digest_string_exn ~len:1 "abc" = unhex "bde52cb31de33e46245e05fbdbd6fb24"

let%test _ = digest_string_exn "abc" = unhex "a448017aaf21d8525fc10ae87aa6729d"

let%test _ =
  digest_string_exn ~len:3 ~off:3 "012abc345"
  = unhex "a448017aaf21d8525fc10ae87aa6729d"

let%test _ =
  digest_string_exn "message digest" = unhex "d9130a8164549fe818874806e1c7014b"

let%test _ =
  digest_string_exn "abcdefghijklmnopqrstuvwxyz"
  = unhex "d79e1c308aa5bbcdeea8ed63df412da9"

let%test _ =
  digest_string_exn
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  = unhex "043f8582f241db351ce627e153e7f0e4"

let%test _ =
  digest_string_exn
    "12345678901234567890123456789012345678901234567890123456789012345678901234567890"
  = unhex "e33b4ddc9c38f2199c3e7b164fcc0536"
