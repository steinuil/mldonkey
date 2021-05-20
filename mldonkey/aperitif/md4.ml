(* let rol n cnt = (num lsl cnt) lor (num lsr (32 - cnt)) *)

(* let f x y z =
  (x land y) lor ((lnot x) land z) *)

let f x y z = Int32.(logor (logand x y) (logand (lognot x) z))

(* let g x y z =
  (x land y) lor ((x land z) lor (y land z)) *)

let g x y z = Int32.(logor (logand x y) (logor (logand x z) (logand y z)))

let h x y z = Int32.(logxor x (logxor y z))

let rol n cnt =
  Int32.(logor (shift_left n cnt) (shift_right_logical n (32 - cnt)))

let pad_message off len input =
  let msg_len =
    len + (64 - (len mod 64)) + if len mod 64 <= 56 then 0 else 64
  in
  let msg = Bytes.create msg_len in
  Bytes.blit_string input off msg 0 len;
  Bytes.set msg len '\001';
  Bytes.set_int64_le msg (msg_len - 8) (Int64.of_int len);
  (Bytes.unsafe_to_string msg, msg_len)

let digest ?(off = 0) ?len input =
  let len = Option.value ~default:(String.length input - off) len in
  let msg, msg_len = pad_message off len input in

  let a = ref 0x67452301l in
  let b = ref 0xefcdab89l in
  let c = ref 0x98badcfel in
  let d = ref 0x10325476l in

  let x = Bytes.create 16 in

  for i = 0 to (msg_len / 16) - 1 do
    Bytes.blit_string msg (i * 16) x 0 16;

    let aa = !a in
    let bb = !b in
    let cc = !c in
    let dd = !d in

    let r1 a b c d k s =
      a :=
        rol
          Int32.(
            add !a (add (f !b !c !d) (Int32.of_int (Char.code (Bytes.get x k)))))
          s
    in

    r1 a b c d 0 3;
    r1 d a b c 1 7;
    r1 c d a b 2 11;
    r1 b c d a 3 19;
    r1 a b c d 4 3;
    r1 d a b c 5 7;
    r1 c d a b 6 11;
    r1 b c d a 7 19;
    r1 a b d c 8 3;
    r1 d a b c 9 7;
    r1 c d a b 10 11;
    r1 b c d a 11 19;
    r1 a b c d 12 3;
    r1 d a b c 13 7;
    r1 c d a b 14 11;
    r1 b c d a 15 19;

    let r2 a b c d k s =
      a :=
        rol
          Int32.(
            add !a
              (add (g !b !c !d)
                 (add (Int32.of_int (Char.code (Bytes.get x k))) 0x5A827999l)))
          s
    in

    r2 a b c d 0 3;
    r2 d a b c 4 5;
    r2 c d a b 8 9;
    r2 b c d a 12 13;
    r2 a b c d 1 3;
    r2 d a b c 5 5;
    r2 c d a b 9 9;
    r2 b c d a 13 13;
    r2 a b c d 2 3;
    r2 d a b c 6 5;
    r2 c d a b 10 9;
    r2 b c d a 14 13;
    r2 a b c d 3 3;
    r2 d a b c 7 5;
    r2 c d a b 11 9;
    r2 b c d a 15 13;

    let r3 a b c d k s =
      a :=
        rol
          Int32.(
            add !a
              (add (h !b !c !d)
                 (add (Int32.of_int (Char.code (Bytes.get x k))) 0x6ED9EBA1l)))
          s
    in

    r3 a b c d 0 3;
    r3 d a b c 8 9;
    r3 c d a b 4 11;
    r3 b c d a 12 15;
    r3 a b c d 2 3;
    r3 d a b c 10 9;
    r3 c d a b 6 11;
    r3 b c d a 14 15;
    r3 a b c d 1 3;
    r3 d a b c 9 9;
    r3 c d a b 5 11;
    r3 b c d a 13 15;
    r3 a b c d 3 3;
    r3 d a b c 11 9;
    r3 c d a b 7 11;
    r3 b c d a 15 15;

    a := Int32.add !a aa;
    b := Int32.add !b bb;
    c := Int32.add !c cc;
    d := Int32.add !d dd
  done;

  Bytes.set_int32_le x 0 !a;
  Bytes.set_int32_le x 4 !b;
  Bytes.set_int32_le x 8 !c;
  Bytes.set_int32_le x 12 !d;

  Base16.encode_bytes_exn ~alphabet:Base16.lowercase_alphabet x

let%test _ = digest "" = "31d6cfe0d16ae931b73c59d7e0c089c0"

let%test _ = digest "a" = "bde52cb31de33e46245e05fbdbd6fb24"

let%test _ = digest "abc" = "a448017aaf21d8525fc10ae87aa6729d"

let%test _ = digest "message digest" = "d9130a8164549fe818874806e1c7014b"

let%test _ =
  digest "abcdefghijklmnopqrstuvwxyz" = "d79e1c308aa5bbcdeea8ed63df412da9"

let%test _ =
  digest "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  = "043f8582f241db351ce627e153e7f0e4"

let%test _ =
  digest
    "12345678901234567890123456789012345678901234567890123456789012345678901234567890"
  = "e33b4ddc9c38f2199c3e7b164fcc0536"

let%test_unit _ = digest "" |> print_endline
