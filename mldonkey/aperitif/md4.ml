let rol n cnt = (num lsl cnt) lor (num lsr (32 - cnt))

let f x y z =
  (x land y) lor ((lnot x) land z)

let g x y z =
  (x land y) lor ((x land z) lor (y land z))

let h x y z = x lxor y lxor z

let digest ?(off = 0) ?len input =
  let len = Option.value (String.length input - off) len in
  let res_len =
    len + (64 - (len mod 64))
    + (if len mod 64 <= 56 then 0 else 64)
  in
  let res = Bytes.create res_len in
  Bytes.blit_string input off res 0 len;
  Bytes.set res len '\001';
  Bytes.set_int64_le res (res_len - 8) (Int64.of_int len);

  let a = ref 0x01234567 in
  let b = ref 0x89abcdef in
  let c = ref 0xfedcba98 in
  let d = ref 0x76543210 in

  for i = 0 to res_len / 16 - 1 do
    for j = 0 to 15 do
      Bytes.set res j (String.get input (i * 16 + j))
    done;

    let aa = !a in
    let bb = !b in
    let cc = !c in
    let dd = !d in

    let x k s =
      a := rol (!a + (f !b !c !d) + Bytes.get k) s
  done;


