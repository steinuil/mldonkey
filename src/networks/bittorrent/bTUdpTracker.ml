(** UDP trackers
  http://www.bittorrent.org/beps/bep_0015.html *)

let of_bits = Bitstring.string_of_bitstring
let bits = Bitstring.bitstring_of_string

exception Error of string

let fail fmt = Printf.ksprintf (fun s -> raise (Error s)) fmt

(** connect - obtain connection_id *)
let connect_request txn =
  of_bits [%bitstring {| 0x41727101980L : 64 ; 0l : 32 ; txn : 32 |}]

(** connect response with connection_id for future use *)
let connect_response s exp_txn =
  match%bitstring bits s with
  | {| 0l : 32 ; txn : 32 ; conn_id : 64 |} -> 
    if txn = exp_txn then conn_id else fail "error connect_response txn %ld expected %ld" txn exp_txn
  | {| 3l : 32; txn : 32; msg : -1 : string |} ->
    fail "error connect_response txn %ld : %s" txn msg
  | {| _ |}  -> fail "error connect_response (expected txn %ld) : %s" exp_txn (AnyEndian.dump_hex_s s)

(** announce *)
let announce_request conn txn ~info_hash ~peer_id (downloaded,left,uploaded) event ?ip:(_=0l) ?(key=0l) ~numwant port =
  of_bits [%bitstring
    {|conn : 64 ;
      1l : 32 ;
      txn : 32 ;
      info_hash : 20 * 8 : string;
      peer_id : 20 * 8 : string;
      downloaded : 64 ;
      left : 64 ;
      uploaded : 64 ;
      event : 32 ;
      0l : 32 ; (* ip *)
      key : 32 ; (* key *)
      numwant : 32 ; (* numwant *)
      port : 16 |}]

(** announce response *)
let announce_response s exp_txn =
  let rec clients rest l =
    match%bitstring rest with
    | {| ip : 32 ; port : 16 ; rest : -1 : bitstring |} -> clients rest ((ip,port)::l)
    | {| _ |} -> l
  in
  match%bitstring bits s with
  | {| 1l : 32 ; txn : 32 ; interval : 32 ; _leechers : 32 ; _seeders : 32 ;
      rest : -1 : bitstring |} -> 
        if txn = exp_txn then 
          (interval,clients rest []) 
        else
          fail "error announce_response txn %ld expected %ld" txn exp_txn
  | {| 3l : 32; txn : 32; msg : -1 : string |} ->
    fail "error announce_response txn %ld : %s" txn msg
  | {| _ |} -> fail "error announce_response (expected txn %ld) : %s" exp_txn (AnyEndian.dump_hex_s s)
