let ith c i = Int64.(shift_right c (i * 8) |> logand 0xFFL |> to_int)

let t1 c i = Array.unsafe_get Tiger_sboxes.t1 (ith c i)

let t2 c i = Array.unsafe_get Tiger_sboxes.t2 (ith c i)

let t3 c i = Array.unsafe_get Tiger_sboxes.t3 (ith c i)

let t4 c i = Array.unsafe_get Tiger_sboxes.t4 (ith c i)

let round a b c x m =
  let open Int64 in
  c := logxor !c x;
  a := sub !a (logxor (logxor (t1 !c 0) (t2 !c 2)) (logxor (t3 !c 4) (t4 !c 6)));
  b := add !b (logxor (logxor (t4 !c 1) (t3 !c 3)) (logxor (t2 !c 5) (t1 !c 7)));
  b := mul !b m

let pass a b c x m =
  round a b c x.(0) m;
  round b c a x.(1) m;
  round c a b x.(2) m;
  round a b c x.(3) m;
  round b c a x.(4) m;
  round c a b x.(5) m;
  round a b c x.(6) m;
  round b c a x.(7) m

let key_schedule x =
  x.(0) <- Int64.(sub x.(0) (logxor x.(7) 0xA5A5A5A5A5A5A5A5L));
  x.(1) <- Int64.logxor x.(1) x.(0);
  x.(2) <- Int64.add x.(2) x.(1);
  x.(3) <- Int64.(sub x.(3) (logxor x.(2) (shift_left (lognot x.(1)) 19)));
  x.(4) <- Int64.logxor x.(4) x.(3);
  x.(5) <- Int64.add x.(5) x.(4);
  x.(6) <-
    Int64.(sub x.(6) (logxor x.(5) (shift_right_logical (lognot x.(4)) 23)));
  x.(7) <- Int64.logxor x.(7) x.(6);
  x.(0) <- Int64.add x.(0) x.(7);
  x.(1) <- Int64.(sub x.(1) (logxor x.(0) (shift_left (lognot x.(7)) 19)));
  x.(2) <- Int64.logxor x.(2) x.(1);
  x.(3) <- Int64.add x.(3) x.(2);
  x.(4) <-
    Int64.(sub x.(4) (logxor x.(3) (shift_right_logical (lognot x.(2)) 23)));
  x.(5) <- Int64.logxor x.(5) x.(4);
  x.(6) <- Int64.add x.(6) x.(5);
  x.(7) <- Int64.(sub x.(7) (logxor x.(6) 0x0123456789ABCDEFL))

type error = string

module type One = sig
  val one_bit : char
end

module Make (I : Input.S) (O : One) = struct
  let pad_message off len input =
    let msg_len =
      len + (64 - (len mod 64)) + if len mod 64 <= 56 then 0 else 64
    in
    let msg = Bytes.create msg_len in
    I.blit input off msg 0 len;
    Bytes.set msg len O.one_bit;
    Bytes.set_int64_le msg (msg_len - 8) Int64.(mul (of_int len) 8L);
    (msg, msg_len)

  let digest ?(off = 0) ?len input =
    let len = Option.value ~default:(I.length input - off) len in
    if len < 0 || off < 0 || off > I.length input - len then
      Error "Invalid bounds"
    else
      let msg, msg_len = pad_message off len input in

      let a = ref 0x0123456789ABCDEFL in
      let b = ref 0xFEDCBA9876543210L in
      let c = ref 0xF096A5B4C3B2E187L in

      let block = Array.make 8 0L in

      for i = 0 to (msg_len / 64) - 1 do
        for j = 0 to 7 do
          block.(j) <- Bytes.get_int64_le msg ((i * 64) + (j * 8))
        done;

        let aa = !a in
        let bb = !b in
        let cc = !c in

        pass a b c block 5L;
        key_schedule block;
        pass c a b block 7L;
        key_schedule block;
        pass b c a block 9L;

        a := Int64.logxor !a aa;
        b := Int64.sub !b bb;
        c := Int64.add !c cc
      done;

      let out = Bytes.create 24 in

      Bytes.set_int64_le out 0 !a;
      Bytes.set_int64_le out 8 !b;
      Bytes.set_int64_le out 16 !c;

      Ok (Bytes.unsafe_to_string out)

  let digest_exn ?off ?len input =
    match digest ?off ?len input with
    | Ok str -> str
    | Error err -> invalid_arg err
end

module Make_tiger (O : One) = struct
  module Tiger_string = Make (Input.String) (O)
  module Tiger_bytes = Make (Input.Bytes) (O)

  let digest_string = Tiger_string.digest

  let digest_string_exn = Tiger_string.digest_exn

  let digest_bytes = Tiger_bytes.digest

  let digest_bytes_exn = Tiger_bytes.digest_exn
end

module Tiger = Make_tiger (struct
  let one_bit = '\x01'
end)

module Tiger2 = Make_tiger (struct
  let one_bit = '\x80'
end)

let unhex s = Base16.decode_string_exn ~alphabet:Base16.lowercase_alphabet s

let%test "empty string" =
  Tiger.digest_string_exn ""
  = unhex "3293ac630c13f0245f92bbb1766e16167a4e58492dde73f3"

let%test "short string 1" =
  Tiger.digest_string_exn "abc"
  = unhex "2aab1484e8c158f2bfb8c5ff41b57a525129131c957b5f93"

let%test "short string 2" =
  Tiger.digest_string_exn "Tiger"
  = unhex "dd00230799f5009fec6debc838bb6a27df2b9d6f110c7937"

let%test "single block string 1" =
  Tiger.digest_string_exn
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-"
  = unhex "f71c8583902afb879edfe610f82c0d4786a3a534504486b5"

let%test "single block string 2" =
  Tiger.digest_string_exn
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ=abcdefghijklmnopqrstuvwxyz+0123456789"
  = unhex "48ceeb6308b87d46e95d656112cdf18d97915f9765658957"

let%test "single block string 3" =
  Tiger.digest_string_exn
    "Tiger - A Fast New Hash Function, by Ross Anderson and Eli Biham"
  = unhex "8a866829040a410c729ad23f5ada711603b3cdd357e4c15e"

let%test "two block string 1" =
  Tiger.digest_string_exn
    "Tiger - A Fast New Hash Function, by Ross Anderson and Eli Biham, \
     proceedings of Fast Software Encryption 3, Cambridge."
  = unhex "ce55a6afd591f5ebac547ff84f89227f9331dab0b611c889"

let%test "two block string 2" =
  Tiger.digest_string_exn
    "Tiger - A Fast New Hash Function, by Ross Anderson and Eli Biham, \
     proceedings of Fast Software Encryption 3, Cambridge, 1996."
  = unhex "631abdd103eb9a3d245b6dfd4d77b257fc7439501d1568dd"

let%test "two block string 3" =
  Tiger.digest_string_exn
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-"
  = unhex "c54034e5b43eb8005848a7e0ae6aac76e4ff590ae715fd25"

let%test _ =
  Tiger.digest_string_exn "The quick brown fox jumps over the lazy dog"
  = unhex "6d12a41e72e644f017b6f0e2f7b44c6285f06dd5d2c5b075"

let%test _ =
  Tiger2.digest_string_exn "The quick brown fox jumps over the lazy dog"
  = unhex "976abff8062a2e9dcea3a1ace966ed9c19cb85558b4976d8"
