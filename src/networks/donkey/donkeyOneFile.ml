(* Copyright 2001, 2002 b8_bavard, b8_fee_carabine, INRIA *)
(*
    This file is part of mldonkey.

    mldonkey is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    mldonkey is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with mldonkey; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*)

open Int64ops
open Printf2
open Md4
open Options
  
open BasicSocket
open TcpBufferedSocket

open CommonSources
open CommonSwarming
open CommonInteractive
open CommonSearch
open CommonGlobals
open CommonComplexOptions
open CommonFile
open CommonClient
open CommonComplexOptions
open CommonTypes
open CommonOptions

open DonkeyMftp
open DonkeyImport
open DonkeyProtoCom
open DonkeyTypes
open DonkeyOptions
open DonkeyComplexOptions
open DonkeyGlobals
open DonkeyChunks
open DonkeyReliability
open DonkeyStats
  
  (*
  (*
  
let new_block file i =

  let begin_pos = chunk_pos i in
  let end_pos = chunk_end file i in
  {
    block_present = false;
    block_begin = begin_pos;
    block_end = end_pos;
    block_legacy = true;
    block_nclients = 0;
    block_contributors = [];
    block_zones = [];
    block_pos = i;
    block_file = file;
  }

let zone_present z =
  z.zone_begin >= z.zone_end

let sort_zones b =
  let zones = List.fold_left (fun zones z ->
        if zone_present z then zones else z :: zones
    ) [] b.block_zones
  in
  b.block_zones <- Sort.list (fun z1 z2 ->
      z1.zone_nclients < z2.zone_nclients ||
      (z1.zone_nclients == z2.zone_nclients &&
        z1.zone_begin < z2.zone_begin)
  ) zones


let rec create_zones file begin_pos end_pos list =
(*  lprintf "create_zones for %ld-%ld\n"
    begin_pos end_pos;
  *)
  if begin_pos = end_pos then list
  else
  let zone_end = Int64.add begin_pos zone_size in
(*  lprintf "ZONE END %ld\n" zone_end; *)
  let zone_end2 = if zone_end > end_pos then begin
(*        lprintf "%ld > %ld\n" zone_end
         end_pos;
*)
        end_pos

      end else zone_end in
(*  lprintf "CORRECTED ZONE END %ld\n" zone_end; *)
  create_zones file zone_end2 end_pos ({
      zone_begin = begin_pos;
      zone_end = zone_end2;
      zone_nclients = 0;
    } :: list )

        *)

let clean_client_zones c =
  match c.client_block with None -> ()
  | Some b ->
      c.client_block <- None;
(*      lprintf "client %d: clear block %d\n" (client_num c) b.block_pos; *)
      b.block_nclients <- b.block_nclients - 1;
      List.iter (fun z ->
          z.zone_nclients <- z.zone_nclients - 1) c.client_zones;
      sort_zones b;
      c.client_zones <- []

let query_zones c b =
  let file = client_file c in
  sort_zones b;
  match c.client_sock with
  | Connection sock ->

      set_rtimeout sock !queue_timeout;
        let module M = DonkeyProtoClient in
        let module Q = M.QueryBloc in
      let msg, len =
        match c.client_zones with
            [z] ->
              {
                Q.md4 = file.file_md4;
                Q.start_pos1 = z.zone_begin;
                Q.end_pos1 = z.zone_end;
                Q.start_pos2 = Int64.zero;
                Q.end_pos2 = Int64.zero;
                Q.start_pos3 = Int64.zero;
                Q.end_pos3 = Int64.zero;
              }, Int64.to_int (Int64.sub z.zone_end z.zone_begin)

          | [z1;z2] ->
              {
                Q.md4 = file.file_md4;
                Q.start_pos1 = z1.zone_begin;
                Q.end_pos1 = z1.zone_end;
                Q.start_pos2 = z2.zone_begin;
                Q.end_pos2 = z2.zone_end;
                Q.start_pos3 = Int64.zero;
                Q.end_pos3 = Int64.zero;
              }, Int64.to_int (Int64.sub z1.zone_end z1.zone_begin)

          | [z1;z2;z3] ->
              {
                Q.md4 = file.file_md4;
                Q.start_pos1 = z1.zone_begin;
                Q.end_pos1 = z1.zone_end;
                Q.start_pos2 = z2.zone_begin;
                Q.end_pos2 = z2.zone_end;
                Q.start_pos3 = z3.zone_begin;
                Q.end_pos3 = z3.zone_end;
              }, Int64.to_int (Int64.sub z1.zone_end z1.zone_begin)

          | _ -> assert false
      in
      let msg = M.QueryBlocReq msg in
      set_read_power sock (c.client_power + maxi 0 (file_priority file));
      CommonUploads.queue_download_request (fun _ ->
          direct_client_send c msg) len
  | _ -> assert false



(* create a list with all absent intervals *)

let put_absents file =

  let temp_chunk chunk =
    match chunk with
      PresentTemp | AbsentTemp | PartialTemp _ -> true
    | _ -> false
  in

  let rec iter_chunks_in i zs =
(*    lprintf "iter_chunks_in %d\n" i;  *)
    if i < file.file_nchunks then
    match zs with
      [] -> ()
      | (begin_pos, end_pos) :: tail ->
          (*
          lprintf "begin_pos %Ld (chnk end %Ld)\n" begin_pos
            (chunk_end file i);  *)
          if begin_pos >= chunk_end file i then
            iter_chunks_in (i+1) zs
          else
          if end_pos <= chunk_pos i then
            iter_chunks_in i tail
          else
          if begin_pos <= chunk_pos i && end_pos >= chunk_end file i then begin
(*              lprintf "full absent chunk %d\n" i;  *)
              file.file_chunks.(i) <- (
                if temp_chunk file.file_chunks.(i) then AbsentTemp else
                  AbsentVerified);
              iter_chunks_in (i+1) ((chunk_end file i, end_pos) :: tail)
            end else

          let b = new_block file i in
(*          lprintf "new_block %d\n" i; *)
          file.file_chunks.(i) <- (if temp_chunk file.file_chunks.(i) then
              PartialTemp b else PartialVerified b);
          iter_blocks_in i b zs

  and iter_blocks_in i b zs =
(*    lprintf "iter_blocks_in %d\n" i;  *)
    match zs with
      [] ->
        sort_zones b
    | (begin_pos, end_pos) :: tail ->
        if begin_pos >= b.block_end then begin
(*            lprintf "need sort_zones...\n";  *)
            sort_zones b;
            iter_chunks_in (i+1) zs
          end
        else
        if end_pos >= b.block_end then begin
(*            lprintf "need create_zones and sort_zones...\n"; *)
            b.block_zones <- create_zones file begin_pos b.block_end
              b.block_zones;
            sort_zones b;
            iter_chunks_in (i+1) ((b.block_end, end_pos) :: tail)
          end else begin
(*            lprintf "need create_zones ...\n";  *)
            b.block_zones <- create_zones file begin_pos end_pos b.block_zones;
            iter_blocks_in i b tail
          end


  in

  (*
  lprintf "nchunks %d\n" file.file_nchunks;

  List.iter (fun (i1,i2) ->
      lprintf "ABSENT: %Ld-%Ld\n" i1 i2;
  ) file.file_absent_chunks;
*)

  iter_chunks_in 0 file.file_absent_chunks


let print_time tm =
  let module U = Unix in
  lprintf "TIME %d/%d/%d %2d:%02d:%02d\n"
    tm.U.tm_mday tm.U.tm_mon tm.U.tm_year
    tm.U.tm_hour tm.U.tm_min tm.U.tm_sec

exception Block_selected

let rec find_client_zone c =
  match c.client_block with
    None ->
      find_client_block c
  | Some b ->
(* client_zones : les zones en cours de telechargement *)
(* block_zones : les zones disponibles pour telechargement *)
(*
      lprintf "Current zones for client:";
      List.iter (fun z ->
          lprintf "zone: %ld-%ld"
            (z.zone_begin) (z.zone_end)
      ) c.client_zones;
lprint_newline ();
  *)
      let z = match c.client_zones with
        | [z1] -> if zone_present z1 then [] else [z1]
        | [z1;z2] ->
            let z = if zone_present z2 then [] else [z2] in
            if zone_present z1 then z else z1 :: z
        | [z1;z2;z3] ->
            let z = if zone_present z3 then [] else [z3] in
            let z = if zone_present z2 then z else z2 :: z in
            if zone_present z1 then z else z1 :: z
        | _ -> []

      in
      let rem_zones = List.length b.block_zones in
(*      lprintf "Remaining %d zones\n" rem_zones; *)
      match z with
        [z1;z2;z3] -> ()
      | [z1;z2] when rem_zones <= 2 -> ()
      | [z1] when rem_zones <= 1 -> ()
      | [z1;z2] -> find_zone3 c b z1 z2 b.block_zones
      | [z1]  -> find_zone2 c b z1 b.block_zones
      | _ -> find_zone1 c b b.block_zones

and print_client_zones n b c =
  (match c.client_block with
      None -> lprintf "\n%d: CLIENT ZONES WITH NO BLOCK %d\n"
          (client_num c) n;
    | Some bb ->
        if b != bb then begin
            lprintf "\n%d: CLIENT ZONES WITH BAD BLOCK %d\n"
              (client_num c) n;
          end);
  if !verbose then begin
      lprintf "\n%d: ZONES IN %d" (client_num c) n;
      List.iter (fun z ->
          lprintf " [%Ld - %Ld]\n" (z.zone_begin)(z.zone_end);
      ) c.client_zones;
      lprint_newline ();
    end;

and find_zone3 c b z1 z2 zones =
  match zones with
    [] ->
      c.client_zones <- [z1;z2];
      print_client_zones 1 b c;
      query_zones c b
  | z :: zones ->
      if (not (zone_present z)) && z != z1 && z != z2 then begin
          c.client_zones <- [z1;z2;z];
          print_client_zones 2 b c;
          z.zone_nclients <- z.zone_nclients + 1;
          query_zones c b
        end
      else find_zone3 c b z1 z2 zones

and find_zone2 c b z1 zones =
  match zones with
    [] ->
      c.client_zones <- [z1];
      print_client_zones 3 b c;
      query_zones c b
  | z :: zones ->
      if (not (zone_present z)) && z != z1 then begin
          z.zone_nclients <- z.zone_nclients + 1;
          find_zone3 c b z1 z zones
        end
      else find_zone2 c b z1 zones

and find_zone1 c b zones =
  let file = client_file c in
  match zones with
    [] ->
      begin
(* no block to download !! *)
        c.client_zones <- [];
        printf_string "[BLOCK]";
        b.block_present <- true;
        b.block_nclients <- b.block_nclients - 1;
        file.file_chunks.(b.block_pos) <- PresentTemp;
        let state = verify_chunk file b.block_pos in
        if state = PresentVerified then begin
            valid_block_detected b;
            file.file_chunks.(b.block_pos) <- state;
            file.file_absent_chunks <- List.rev (find_absents file);
(*            lprintf "client %d: block %d finished\n" (client_num c) b.block_pos; *)
            c.client_block <- None;
          end else begin
            let message = Printf.sprintf "CORRUPTION DETECTED file %s chunk %d\n" (file_best_name file) b.block_pos in
            CommonEvent.add_event (Console_message_event message);
            corrupted_block_detected b;
            b.block_zones <- create_zones file b.block_begin b.block_end [];
            b.block_present <- false;
            b.block_legacy <- false;
            b.block_contributors <- [];
            add_file_downloaded file.file_file
              (Int64.sub b.block_begin b.block_end); (* negative *)
            file.file_chunks.(b.block_pos) <- PartialVerified b;
            Hashtbl.iter (fun _ c ->
                match c.client_block with
                  Some cb when cb == b ->
                    lprintf "client %d: block %d corrupted\n"
                      (client_num c) b.block_pos;
                    c.client_block <- None
                | _ -> ()
            ) connected_clients

          end;
      end;
      find_client_block c

  | z :: zones ->
      if (not (zone_present z)) then begin
          z.zone_nclients <- z.zone_nclients + 1;
          find_zone2 c b z zones
        end else
        find_zone1 c b zones

and zero_block file i =
(* disk fragmentation prevention:
   This should help the bad filesystems, and the others too ;)
   When a chunk is about to be used for the first time, zero it,
   allocating all the disk space at once *)
  try
    match file.file_chunks.(i) with
      AbsentTemp | AbsentVerified ->
        let chunk_begin = chunk_pos i in
        Unix32.allocate_chunk (file_fd file) chunk_begin
          (Int64.to_int ((chunk_end file i) -- chunk_begin))
(*
(*	   lprintf "Allocating disk space\n"; *)
          let final_pos = Unix32.seek64 (file_fd file)
            chunk_begin Unix.SEEK_SET in
          if final_pos <> chunk_begin then begin
              lprintf "BAD LSEEK %Ld/%Ld\n"
                (final_pos)
              (chunk_begin);
              raise Not_found
            end;
          let fd = try
              Unix32.force_fd (file_fd file)
            with e ->
                lprintf "In Unix32.force_fd\n";
                raise e
          in
          let buffer_size = 128 * 1024 in
          let buffer = String.make buffer_size '\001' in
          let remaining = ref (Int64.to_int (Int64.sub (chunk_end file i) chunk_begin)) in
          while !remaining > 0 do
            let len = mini !remaining buffer_size in
            Unix2.really_write fd buffer 0 len;
            remaining := !remaining - len;
          done;
*)

    | _ -> lprintf "Trying to zero some existing chunk!!\n";
  with _ -> ()

and check_file_block c file i max_clients force =
  if c.client_chunks.(i) then begin
      begin
        match file.file_chunks.(i) with
          AbsentTemp | PartialTemp _ ->
            lprintf "check_file_block: verify md4\n";
            verify_file_md4 file i file.file_chunks.(i)
        | _ -> ()
      end;

      match file.file_chunks.(i) with

      | AbsentVerified ->
          let b = new_block file i in
          b.block_zones <- create_zones file b.block_begin b.block_end [];

          b.block_nclients <- 1;
          if !verbose then begin
              lprintf "\n%d: NEW BLOCK [%Ld - %Ld]\n" (client_num c)
              (b.block_begin) (b.block_end);
            end;
          zero_block file i;
          b.block_legacy <- false;
          c.client_block <- Some b;
(*          lprintf "client %d: downloading %d absent\n"
            (client_num c) b.block_pos; *)

          file.file_chunks.(i) <- PartialVerified b;
          find_client_zone c;
          raise Block_selected

      | PartialVerified b ->
          if b.block_nclients < max_clients &&
            (not !!reliable_sources ||
              allowed_by_reliability b c >= force) then begin
              b.block_nclients <- b.block_nclients + 1;
              c.client_block <- Some b;
(*              lprintf "client %d: downloading partial block %d \n"
                (client_num c) b.block_pos; *)

              if !verbose then begin
                  lprintf "\n%d: NEW CLIENT FOR BLOCK [%Ld - %Ld]\n"
                    (client_num c)
                  (b.block_begin) (b.block_end);
                end;

              file.file_chunks.(i) <- PartialVerified b;
              find_client_zone c;
              raise Block_selected
            end
      | _ -> ()
    end
*)
    
(* Sort files in clients file queue in order of priority and percentage downloaded
   This way higher priority files will be asked/downloaded first if the client does have more
   than one file to offer.
   Only sort if client_block is not set.
   Once the block has been finished allow changing order.
*)

let sort_file_queue c =
  match c.client_download with
    Some _ -> ()
  | None ->
      match c.client_file_queue with
        [] -> ()
      | [ (file, chunks, up) ] ->
          if !verbose_download || c.client_debug then begin
              lprintf "sort_file_queue: single file. client(%d): %s, file(%d): %s\n" (client_num c) c.client_name (file_num file) (file_best_name file);
            end
      | (file, chunks, up) :: _ ->
          let fn = file_num file in
          if !verbose_download || c.client_debug then begin
              lprintf "sort_file_queue: multiple files. client(%d): %s, file(%d): %s\n" (client_num c) c.client_name (file_num file) (file_best_name file);
            end;
          c.client_file_queue <- List.stable_sort (fun (f1, _, _) (f2, _, _) ->
              let v = file_priority f2 - file_priority f1 in
              if v <> 0 then v else
              let s1 = if (file_size f1) > Int64.zero then
                  Int64.to_int (Int64.div (Int64.mul (file_downloaded f1) (Int64.of_int 100)) (file_size f1))
                else 0 in
              let s2 = if (file_size f2) > Int64.zero then
                  Int64.to_int (Int64.div (Int64.mul (file_downloaded f2) (Int64.of_int 100)) (file_size f2))
                else 0 in
              s2 - s1
          ) c.client_file_queue;
          match c.client_file_queue with
            [] -> ()
          | (file, chunks, _) :: _ ->
              if (file_num file) <> fn then begin
                  if !verbose_download || c.client_debug then begin
                      lprintf "sort_file_queue: queue change. client(%d): %s, file(%d): %s\n" (client_num c) c.client_name (file_num file) (file_best_name file);
                    end;
(*
(*                  c.client_chunks <- chunks; *)
(*                  c.client_all_chunks <- String.make file.file_nchunks '0'; *)
(*                  c.client_zones <- []; *)
                  for i = 0 to file.file_nchunks - 1 do
                    if c.client_chunks.(i)  then
                      c.client_all_chunks.[i] <- '1';
done;
  *)
                end

(*
and start_download c =
  if c.client_slot = SlotNotAsked then begin
      if !verbose_download then begin
          lprintf "start_download...\n";
        end;
      do_if_connected c.client_sock (fun sock ->
          sort_file_queue c;
          match c.client_file_queue with
            [] -> ()
          | (file, (chunks)) :: _ ->

              direct_client_send c (
                let module M = DonkeyProtoClient in
                let module Q = M.JoinQueue in
                M.JoinQueueReq Q.t);
              c.client_slot <- SlotAsked;

              restart_download c
      )
    end

and restart_download c =
  if !verbose_download || c.client_debug then begin
      lprintf "restart_download...\n";
    end;
  do_if_connected c.client_sock (fun sock ->
      sort_file_queue c;
      match c.client_file_queue with
        [] -> ()
      | (file, (chunks)) :: _ ->

(*          lprintf "client %d: restart download\n"  (client_num c) ; *)

          c.client_block <- None;
          c.client_chunks <- chunks;
          c.client_all_chunks <- String.make file.file_nchunks '0';
          c.client_zones <- [];

          for i = 0 to file.file_nchunks - 1 do
            if c.client_chunks.(i)  then
              c.client_all_chunks.[i] <- '1';
          done;
          if file.file_md4s = [] && file_size file > block_size then begin
              direct_client_send c (
                let module M = DonkeyProtoClient in
                let module C = M.QueryChunkMd4 in
                M.QueryChunkMd4Req file.file_md4);
            end;
          set_rtimeout sock !!queued_timeout;
          set_client_state c (Connected 0)
  )

and find_client_block c =
(* find an available block *)

  if !verbose_download || c.client_debug then begin
      lprintf "find_client_block: started\n";
    end;
  sort_file_queue c;
  match c.client_file_queue with
    [] ->
(* Emule may reconnect and give the slot without us asking for it.
    We have to fix this behavior in the future. *)
      if !verbose_download || c.client_debug then begin
          lprintf "Client %d: NO FILE IN QUEUE\n" (client_num c);
        end

  | (file, (chunks)) :: files ->

      if !verbose_download || c.client_debug then begin
          lprintf "File %s state %s\n"
            (file_best_name file)
          (string_of_file_state
              (file_state file));
        end;
      if file_state file <> FileDownloading then next_file c else

      if !verbose_download || c.client_debug then begin
          lprintf "find_client_block: continuing\n";
        end;

      if !verbose || c.client_debug  then begin
          for i = 0 to file.file_nchunks - 1 do
            lprint_char (match file.file_chunks.(i) with
              | PartialVerified _ -> 'P'
              | PartialTemp _ -> 'p'
              | AbsentVerified -> 'A'
              | AbsentTemp -> 'a'
              | PresentVerified -> 'D'
              | PresentTemp -> 'd')
          done;
          lprint_newline ();
        end;


      begin
        match c.client_block with
          None ->
            printf_string "[FREE]";
        | Some _ ->
            printf_string "[USED]";
      end;

      try
(* only break reliability barriers when in need *)
	for force = 1 to (if !!reliable_sources then 4 else 1) do

          let last = file.file_nchunks - 1 in

          if !!random_order_download then begin

              if !verbose_download || c.client_debug then begin
                  lprintf "find_client_block: random_order_download\n";
                end;

 	      let proportional_check_file_block c file i force =
 	        let n = 1 + (((!!sources_per_chunk-1) * Int64.to_int (chunk_compute_missing file i)) / Int64.to_int block_size) in
 		  check_file_block c file i n force in

 	      if c.client_chunks.(last) &&
 		(match file.file_chunks.(last) with
 		     PresentTemp | PresentVerified -> false
 		   | _ -> true) &&
 		file.file_available_chunks.(last) >= 10 then
 		  proportional_check_file_block c file last force;
	
 	      if c.client_chunks.(0) &&
 		(match file.file_chunks.(0) with
 		     PresentTemp | PresentVerified -> false
 		   | _ -> true) &&
 		file.file_available_chunks.(0) >= 10 then
 		  proportional_check_file_block c file 0 force;

(* chunks with MD4 already computed *)
              for i = 0 to last do
                let j = file.file_chunks_order.(i) in
                if c.client_chunks.(j) &&
                  (match file.file_chunks.(j) with
                      AbsentVerified -> true
                    | PartialVerified b -> true
                    | _ -> false
                  ) then
                  proportional_check_file_block c file j force
              done;

(* chunks whose computation will probably lead to only one MD4 *)
              for i = 0 to last do
                let j = file.file_chunks_order.(i) in
                if c.client_chunks.(j) &&
                  (match file.file_chunks.(j) with
                      AbsentTemp -> true
                    | PartialTemp b -> true
                    | _ -> false
                  ) then
                  proportional_check_file_block c file j force
              done;

(* rare chunks *)
(* while different clients should try to get different chunks, each client
   should try to complete the chunks it started: if the rare sources
   disappear, all partial chunks will become useless *)
 	      let min_availability = ref max_int in
 	      let max_availability = ref 0 in
 	      for i = 0 to last do
 		if c.client_chunks.(i) then begin
 		  if file.file_available_chunks.(i) < !min_availability then
 		    min_availability := file.file_available_chunks.(i);
 		  if file.file_available_chunks.(i) > !max_availability then
 		    max_availability := file.file_available_chunks.(i)
 		end
 	      done;

 	      let rare_level = !max_availability / 2 in
 	      if !min_availability <= rare_level then
		for i = 0 to last do
 		  let j = file.file_chunks_order.(i) in
 		  if c.client_chunks.(j) &&
 		    file.file_available_chunks.(j) <= rare_level then
                      check_file_block c file j max_int force
		done;

(* chunks with few clients *)
              for i = 0 to last do
                let j = file.file_chunks_order.(i) in
		proportional_check_file_block c file j force
              done;

(* chunks with several clients *)
              for i = 0 to last do
                let j = file.file_chunks_order.(i) in
                check_file_block c file j max_int force
              done;

            end else begin

              if !verbose_download then begin
                  lprintf "find_client_block: NOT RANDOM ORDER (last = %d)\n"
                  last;

                end;

              if c.client_chunks.(last) then
                check_file_block c file last max_int force;
              if last > 0 && c.client_chunks.(last-1) then
                check_file_block c file (last-1) max_int force;

(* chunks with MD4 already computed *)
              for i = 0 to file.file_nchunks - 1 do
                if c.client_chunks.(i) && (match file.file_chunks.(i) with
                      AbsentVerified -> true
                    | PartialVerified b -> true
                    | _ -> false
                  ) then
                  check_file_block c file i  !!sources_per_chunk force
              done;

(* chunks whose computation will probably lead to only one MD4 *)
              for i = 0 to file.file_nchunks - 1 do
                if c.client_chunks.(i) && (match file.file_chunks.(i) with
                      AbsentTemp -> true
                    | PartialTemp b -> true
                    | _ -> false
                  ) then
                  check_file_block c file i  !!sources_per_chunk force
              done;

(* rare chunks *)
              let rare_blocks = ref [] in
              for i = 0 to file.file_nchunks - 1 do
                if c.client_chunks.(i) && file.file_available_chunks.(i) = 1 then
                  rare_blocks := (Random.int 1000, i) :: !rare_blocks
              done;

              let rare_blocks = Sort.list (fun (c1,_) (c2,_) -> c1 <= c2)
                !rare_blocks in

              List.iter (fun (_,i) ->
                  check_file_block c file i max_int force) rare_blocks;

(* chunks with no client *)
              check_file_block c file last max_int force;
              if last > 0 then  check_file_block c file (last-1) max_int force;
              for i = 0 to file.file_nchunks - 1 do
                check_file_block c file i  !!sources_per_chunk force
              done;

(* chunks with several clients *)
              for i = 0 to file.file_nchunks - 1 do
                check_file_block c file i max_int force
              done

            end
	done;

        if !verbose_download || c.client_debug then begin
            lprintf "No block found ???\n";
            for i = 0 to file.file_nchunks - 1 do

              lprintf "%d: client %c source %s"
                i
                (if chunks.(i) then '1' else '0')
              (match file.file_chunks.(i) with
                  PresentTemp -> "p"
                | PresentVerified -> "P"
                | AbsentTemp -> "a"
                | AbsentVerified -> "A"
                | PartialTemp _ -> "d"
                | PartialVerified _ -> "D");
              lprint_newline ();
            done;
          end;


(* THIS CLIENT CANNOT HELP ANYMORE: USELESS FOR THIS FILE *)
        printf_string "[NEXT]";
        next_file c
      with
	  Block_selected -> ()
	| e ->
          if !verbose_download || c.client_debug then begin
              lprintf "find_client_block: exception %s\n"
                (Printexc2.to_string e);
              ()
            end

and next_file c =

  lprintf "next_file...\n";
  match c.client_file_queue with
    [] -> assert false
  | (file, (chunks) ) :: files ->
      DonkeyGlobals.remove_client_chunks file chunks;
      do_if_connected  c.client_sock (fun sock ->
          match files with
            [] ->
              lprintf "next_file: no more file\n";
              if not (client_has_a_slot (as_client c.client_client)) then begin
                  connection_delay c.client_connection_control;
(* This guy could still want to upload from us !!! *)
                  TcpBufferedSocket.close sock
                    (Closed_for_error "No file to download");
                  raise Block_selected
                end
          | _ ->
              c.client_file_queue <- files;
              restart_download c
      )

let disconnect_chunk ch =
  match ch with
  | PartialTemp b | PartialVerified b ->
      let file = b.block_file in
      b.block_present <- true;
      List.iter (fun z ->
          z.zone_begin <- file_size file;
      ) b.block_zones;
      b.block_zones <- []
  | AbsentTemp | AbsentVerified | PresentTemp  | PresentVerified -> ()

let random_chunks_order nchunks =
  let order = Array.create nchunks 0 in
  for i = 0 to nchunks - 1 do
    order.(i) <- i
  done;
(* Fisher-Yates shuffle *)
  for i = nchunks-1 downto 1 do
    let j = Random.int (i+1) in
    if i <> j then
      let temp = order.(i) in
      order.(i) <- order.(j);
      order.(j) <- temp
  done;
  order

let set_file_size file sz =

  if sz <> Int64.zero then begin

      if file_size file = Int64.zero then
        file.file_absent_chunks <- [Int64.zero, sz];
      file.file_file.impl_file_size <- sz;
      file.file_nchunks <- Int64.to_int (Int64.div
          (Int64.sub sz Int64.one) block_size)+1;

      if file.file_chunks = [||] then
        file.file_chunks <- Array.create file.file_nchunks (
          if not (Unix32.file_exists (file_disk_name file)) then begin
(*            lprintf "Setting Absent Verified chunks\n"; *)

              AbsentVerified
            end else begin
(*            lprintf "Setting Absent Verified chunks\n"; *)
              AbsentTemp

            end);

      file.file_chunks_order <- random_chunks_order file.file_nchunks;

      Unix32.ftruncate64 (file_fd file) sz; (* at this point, file exists *)

      put_absents file;

      file.file_initialized <- true;

      (*
      lprintf "AFTER put_absents:\n";
      for i = 0 to file.file_nchunks - 1 do
        lprintf "  chunk[%d]: %s" i
          (match file.file_chunks.(i) with
            PresentVerified ->
              "shared"
          | AbsentVerified -> "absent"
          | PartialVerified _ -> "partial"
          | PartialTemp _ -> "partial compute"
          | AbsentTemp -> "absent compute"
          | PresentTemp -> "present compute");
        lprint_newline ();
      done;
*)

      for i = 0 to file.file_nchunks - 1 do
        match file.file_chunks.(i) with
          PresentVerified ->
            DonkeyShare.must_share_file file;
        | _ -> ()
      done;


      compute_size file;
      (* verify_chunks file;  *)

(*
      List.iter (fun (p0,p1) ->
lprintf "%ld <---> %ld\n" (p0) (p1);
) file.file_absent_chunks;
  *)
    end


(*

   B--------------------------------------------------E       OK
   B--------------------E                                     OK
                      B-------------------------------E       OK
   B-----E                                                    OUT
                      B-----------E                           OUT
                                                 B----E       OUT
----------------|----------------------------|---------------------
         z.zone_begin                   z.zone_end


*)


let update_zone file begin_pos end_pos z =
  if z.zone_begin >= begin_pos && z.zone_end <= end_pos then begin
(* the zone has completely been downloaded *)

      add_file_downloaded file.file_file (Int64.sub z.zone_end z.zone_begin);

      if file_downloaded file > file_size file then begin
          lprintf "******* downloaded %Ld > %Ld size after update_zone ***** for %s\n"
            (file_downloaded file)
          (file_size file)
          (file_best_name file);
        end;

      file_must_update file;
      z.zone_begin <- z.zone_end;
      if !verbose && end_pos > z.zone_end then begin
          lprintf "EXCEEDING: %Ld>%Ld\n" (end_pos)
          (z.zone_end);
        end

    end else
  if z.zone_begin >= begin_pos && z.zone_begin < end_pos then begin
(* the block is at the beginning of the zone *)

      add_file_downloaded file.file_file (Int64.sub end_pos z.zone_begin);
      if file_downloaded file > file_size file then begin
          lprintf "******* downloaded %Ld > %Ld size after update_zone (2) ***** for %s\n"
            (file_downloaded file)
          (file_size file)
          (file_best_name file);
        end;

      z.zone_begin <- end_pos;
      file_must_update file;


    end else
  if z.zone_end > begin_pos && z.zone_end <= end_pos then begin
(* the block is at the end of the zone *)

      add_file_downloaded file.file_file (Int64.sub z.zone_end begin_pos);
      if file_downloaded file > file_size file then begin
          lprintf "******* downloaded %Ld > %Ld size after update_zone (3) ***** for %s\n"
            (file_downloaded file)
          (file_size file)
          (file_best_name file);
        end;

      z.zone_end <- begin_pos;
      file_must_update file;



    end

(*  else begin
      if !verbose then begin
          lprintf "CAN'T UPDATE ZONE %ld-%ld WITH %ld-%ld\n"
            (z.zone_begin)
          (z.zone_end)
          (begin_pos)
          (end_pos)
        end
    end
*)

(*
let best_name file =
  match file.file_filenames with
    [] -> Md4.to_string file.file_md4
  | name :: _ -> name
        *)

  (*
let move_file_to_done_files md4 =
  try
    let file = Hashtbl.find files_by_md4 md4 in
    file_completed (as_file file.file_file);

  with e ->
      lprintf "move_file_to_done_files NOT FOUND\n";
      raise e
        *)

(*
let remove_file md4 =
  try
    let file = Hashtbl.find files_by_md4 md4 in
    file_cancel (as_file file.file_file);
    Unix32.close (file_fd file);
    (try Sys.remove (file_disk_name file) with e ->
          lprintf "Exception %s in remove %s\n"
            (Printexc2.to_string e) (file_disk_name file);
          );
    (try Hashtbl.remove files_by_md4 file.file_md4 with _ -> ());
    (match file.file_shared with
        None -> ()
      | Some s -> CommonShared.shared_unshare (CommonShared.as_shared s));
    file.file_shared <- None;
(*    !file_change_hook file; *)
    current_files := List2.removeq file !current_files;
  with e ->
      lprintf "remove_file NOT FOUND\n";
      raise e
        *)

(*
This function is called periodically, to compute md4s of files being
downloaded. If a file is completely present, it is only added to the
downloaded list when all chunks have been verified.
*)

let check_downloaded_files () =
  List.iter check_file_downloaded !current_files;
  (try
      List.iter (fun file ->
          if file.file_md4s <> [] then
(* First check only md4s of potentially present chunks. This
will allow to fasten the sharing of these chunks. *)
            Array.iteri (fun i b ->
                match b with
                | PresentTemp ->
(*                      lprintf "verify file md4 %d %d\n"
                        file.file_num i;  *)
                    verify_file_md4 file i b;
                    compute_size file;
                    raise Not_found
                | _ -> ()
            ) file.file_chunks) !current_files;
      List.iter (fun file ->
          if file.file_md4s <> [] then
(* First check only md4s of potentially present chunks *)
            Array.iteri (fun i b ->
                match b with
                  PartialVerified _ | AbsentVerified
                | PresentVerified -> ()
                | _ ->
(*                      lprintf "verify file md4 %d %d\n"
                        file.file_num i;  *)
                    verify_file_md4 file i b;
                    compute_size file;
                    raise Not_found
            ) file.file_chunks
            ) !current_files;
    with _ -> ())

let check_files_md4s () =
  try
    check_downloaded_files ();
    DonkeyShare.check_shared_files ();

  with _ -> ()

let _ =
  file_ops.op_file_to_option <- (fun file ->
      if file.file_chunks <> [||] && file.file_initialized then begin
          file.file_absent_chunks <- List.rev (find_absents file);
          check_file_downloaded file;
        end;
      file_to_value file)
  
let client_has_chunks c file chunks =

  failwith "client_has_chunks not implemented"
  
  add_file_location file c;

  if file.file_chunks_age = [||] then
    file.file_chunks_age <- Array.create file.file_nchunks 0;
  let change_last_seen = ref false in
  let chunks_string = String.make file.file_nchunks '0' in
  for i = 0 to file.file_nchunks - 1 do
    if chunks.(i) then chunks_string.[i] <- '1';
    match file.file_chunks.(i) with
      PresentVerified | PresentTemp -> 
        file.file_chunks_age.(i) <- last_time ()
    | _ -> 
        if chunks.(i) then begin
            change_last_seen := true;
            file.file_chunks_age.(i) <- last_time ();
            set_request_result c file File_chunk;
          end 
  done;
  
  if !change_last_seen then begin
      try
        if !verbose_download then begin
            lprintf "client_has_chunks: change_last_seen\n"; 
          end;
        
        let last_seen =  Array2.min file.file_chunks_age in
        if last_seen > file.file_file.impl_file_last_seen then
          begin
            file.file_file.impl_file_last_seen <- last_seen;
            file_must_update_downloaded (as_file file.file_file);
          
          end;
        
        CommonEvent.add_event (File_update_availability
            (as_file file.file_file, as_client c.client_client, chunks_string));
        
        (
(*
         try
            
            let (c1, c2) = List.assq file c.client_file_queue in
            remove_client_chunks file c1;
            add_client_chunks file chunks;

            let len = Array.length c1 in
            Array.blit chunks 0 c1 0 len;
            Array.blit chunks 0 c2 0 len;

with Not_found ->
  *)
          add_client_chunks file chunks;
          if !verbose_download then begin
              lprintf "client_file_queue: ADDING FILE TO QUEUE\n"; 
            end;
          c.client_file_queue <- c.client_file_queue @ [
            file, chunks ]
        );
        start_download c
      
      with _ -> 
          if !verbose_download then begin
              lprintf "client_has_chunks: EXCEPTION\n"; 
            end
    end

*)

(** What to do when a file is finished
  @param file the finished file
*)         
let download_finished file = 
  if List.memq file !current_files then begin      
      current_files := List2.removeq file !current_files;
      DonkeyShare.remember_shared_info file (file_disk_name file);
      file_completed (as_file file);
(* TODO: disconnect from all sources *)
      (try
          let format = CommonMultimedia.get_info
              (file_disk_name file) in
          file.file_format <- format
        with _ -> ());
    end

(** Check if a file is finished or not.
  A file is finished if all blocks are verified.
  @param file The file to check status
*)
let check_file_downloaded file = 
  match file_state file with
    FileCancelled | FileShared | FileDownloaded -> ()
  | _ ->
      match file.file_swarmer with
        None -> ()
      | Some swarmer ->
          let bitmap = Int64Swarmer.verified_bitmap swarmer in
(*          lprintf "Verified bitmap: [%s]\n" bitmap; *)
          let rec iter i =
            if i =  String.length bitmap then true
            else
            if bitmap.[i] = '3' then iter (i+1) else false
          in
          let verified = iter 0 in
          if verified then begin
              if (file_size file <> Int64Swarmer.downloaded swarmer)
              then
                lprintf "DonkeyOneFile: Downloaded size differs after complete verification\n";
              download_finished file
            end
            
let check_files_downloaded () =
  List.iter check_file_downloaded !current_files;
  Hashtbl.iter (fun file_md4 file ->
      match file.file_shared with 
        Some _ -> ()
      | None ->
          match file.file_swarmer with
            None -> ()
          | Some swarmer ->
              let bitmap = Int64Swarmer.verified_bitmap swarmer in
              let rec iter i len =
                if i < len then
                  if bitmap.[i] = '3' then
                    DonkeyShare.must_share_file file
                  else
                    iter (i+1) len
              in
              iter 0 (String.length bitmap)
  ) files_by_md4
          
(* TODO: we should sort the downloads, probably before asking QueryFiles 
  messages. *)

let add_client_chunks c file client_chunks =
  match file.file_swarmer with
    None -> failwith "add_client_chunks: no swarmer"
  | Some swarmer ->
      let rec iter list =
        match list with
          (f, chunks, up) :: tail ->
            if f != file then iter tail
            else begin
                Int64Swarmer.update_uploader up
                (Int64Swarmer.AvailableBoolBitmap client_chunks);
                Array.blit client_chunks 0 chunks 0 (Array.length chunks)
              end
            
        | [] ->
            let up = Int64Swarmer.register_uploader swarmer (as_client c) 
              (Int64Swarmer.AvailableBoolBitmap client_chunks) in
            c.client_file_queue <-  c.client_file_queue @
              [file, client_chunks, up]
      in
      iter c.client_file_queue
      

(* let next_file _ = failwith "next_file not implemented" *)
      
(* clean_client_zones: clean all structures related to downloads when
   a client disconnects *)
let clean_current_download c = 
  match c.client_download with
    None -> ()
  | Some (file, up) ->
      Int64Swarmer.clear_uploader_block up;
      Int64Swarmer.clear_uploader_ranges up;
      c.client_download <- None

let send_get_range_request c file ranges = 
  match c.client_source.DonkeySources.source_sock with
  | Connection sock ->
      
      set_rtimeout sock !queue_timeout;
      let module M = DonkeyProtoClient in
      let module Q = M.QueryBloc in
      let msg, len =
        match ranges with
          [x1,y1,_] ->
            {
              Q.md4 = file.file_md4;
              Q.start_pos1 = x1;
              Q.end_pos1 = y1;
              Q.start_pos2 = zero;
              Q.end_pos2 = zero;
              Q.start_pos3 = zero;
              Q.end_pos3 = zero;
            }, y1 -- x1
        
        | [x1,y1,_; x2,y2,_] ->
            {
              Q.md4 = file.file_md4;
              Q.start_pos1 = x1;
              Q.end_pos1 = y1;
              Q.start_pos2 = x2;
              Q.end_pos2 = y2;
              Q.start_pos3 = zero;
              Q.end_pos3 = zero;
            }, y1 -- x1
        
        | [x1,y1,_; x2,y2,_; x3,y3,_ ] ->
            {
              Q.md4 = file.file_md4;
              Q.start_pos1 = x1;
              Q.end_pos1 = y1;
              Q.start_pos2 = x2;
              Q.end_pos2 = y2;
              Q.start_pos3 = x3;
              Q.end_pos3 = y3;
            }, y1 -- x1
        
        | _ -> assert false
      in
      let msg = M.QueryBlocReq msg in
      set_read_power sock (!!upload_power + maxi 0 (file_priority file));
      lprintf "QUEUE DOWNLOAD REQUEST\n";
      CommonUploads.queue_download_request (fun _ -> 
          direct_client_send c msg ) (Int64.to_int len) 
  | _ -> assert false
      
let rec get_from_client c =
  match c.client_download with
    None ->
      lprintf "get_from_client: no download\n";
      begin
        match c.client_file_queue with
          [] -> 
            
            lprintf "get_from_client: no more file\n";
            if not (client_has_a_slot (as_client c)) then begin
(*                connection_delay c.client_connection_control; *)
                match c.client_source.DonkeySources.source_sock with
                  Connection sock ->
                    TcpBufferedSocket.close sock
                      (Closed_for_error "No file to download");
                | _ -> ()
              end
        
        | (file, chunks, up) :: tail ->

(* Should we start a download without asking for a slot first ?? *)
            lprintf "get_from_client: next file\n";
            c.client_download <- Some (file,up);
            get_from_client c
      end
  
  | Some (file,up) ->
      
      try
        let b = Int64Swarmer.current_block up in
        let ranges = Int64Swarmer.current_ranges up in
        let before_find_range = List.length ranges in

(*        lprintf "WAITING FOR %d BLOCS\n" before_find_range; *)
        if before_find_range < 3 then
          let rec iter n =
            if n < 3 then
              try
                ignore (Int64Swarmer.find_range up);
                iter (n+1)
              with 
                Not_found -> n
            else n
          in
          let after_find_range = iter before_find_range in
          if after_find_range > before_find_range then 
            
            let ranges = Int64Swarmer.current_ranges up in
            send_get_range_request c file ranges;
            
          else
(* No new range to download in this block *)
              match ranges with
                [] ->
                  raise Not_found (* will query the next block *)
                  
              | _ -> 
(* Wait for the already requested ranges before requesting the next block *)
                  ()                  
              
        else
(* We already have 3 ranges in the current block *)
          ()
      with Not_found ->
          lprintf "get_from_client: no range\n";
          try
            let b = Int64Swarmer.find_block up in
            get_from_client c
            
          with Not_found ->
              lprintf "get_from_client: no block\n";
              match Int64Swarmer.current_ranges up with
                [] ->
(* We have nothing to wait for in the current file *)
                  begin
                    
                    lprintf "get_from_client: no expected ranges\n";
                    
                    c.client_download <- None;
                    Int64Swarmer.unregister_uploader up;
                    match c.client_file_queue with
                      [] -> assert false
                    | _ :: tail -> 
(* We can go to next file now *)
                        c.client_file_queue <- tail;
                        get_from_client c
                  end
              | _ -> 
(* We are still waiting for the previous requested ranges from this file *)
                  ()
                  
      
(* start_download: ask for a slot in the queue of the remote client,
  or start querying blocks if already in the queue *)
let request_slot c = 
    if c.client_slot = SlotNotAsked then begin
      if !verbose_download then begin
          lprintf "start_download...\n";
        end;
      do_if_connected c.client_source.DonkeySources.source_sock (fun sock ->
          sort_file_queue c;
          match c.client_file_queue with
            [] -> ()
          | (file, _,_ ) :: _ ->

              direct_client_send c (
                let module M = DonkeyProtoClient in
                let module Q = M.JoinQueue in
                M.JoinQueueReq Q.t);
              c.client_slot <- SlotAsked;
      )
    end
  
let block_received c t = 
  let module M = DonkeyProtoClient in  
  let module Q = M.Bloc in
  match c.client_download with
    None -> 
      lprintf "DonkeyOneFile.block_received: block received but no file !\n  Received: %s\n" (Md4.to_string t.Q.md4)
  | Some (file, up) ->
      
      if file.file_md4 <> t.Q.md4 then begin
          lprintf "DonkeyOneFile.block_received: block for bad file\n  Received: %s\n  Expected: %s\n" (Md4.to_string t.Q.md4) (Md4.to_string file.file_md4)
        end else begin
          DonkeySources.set_request_result c.client_source file.file_sources File_upload;
          
          c.client_rating <- c.client_rating + 10;
          
          let begin_pos = t.Q.start_pos in
          let end_pos = t.Q.end_pos in
          
          set_client_state c (Connected_downloading (file_num file));
          let len = Int64.sub end_pos begin_pos in
          if Int64.to_int len <> t.Q.bloc_len then begin
              lprintf "%d: inconsistent packet sizes\n" (client_num c);
              raise Not_found
            end;
          count_download c file len;

(* TODO: verify the received data has been requested *)
          
          let swarmer = Int64Swarmer.uploader_swarmer up in
          let old_downloaded = Int64Swarmer.downloaded swarmer in
          
          begin
            try
              Int64Swarmer.received up
                begin_pos
                t.Q.bloc_str t.Q.bloc_begin t.Q.bloc_len
            with
            | e ->
                let m =
(*		      Printf.sprintf "File %s begin_pos=%s bloc_begin=%d bloc_len=%d:\nError %s while writing block%s\n" (file_best_name file) (Int64.to_string begin_pos) t.Q.bloc_begin t.Q.bloc_len (Printexc2.to_string e)  *)
                  (match e with 
                      Unix.Unix_error (Unix.ENOSPC, _, _) -> " (Disk full?)"
                    | _ -> "") in
(*                    Printf2.lprint_string m; *)
                CommonEvent.add_event (Console_message_event m);
                if e <> End_of_file then begin
                    let m = "File paused.\n" in
                    Printf2.lprint_string m;
                    CommonEvent.add_event (Console_message_event m);
                    file_pause (as_file file);
                    raise e
                  end
          
          end;

(*            List.iter Int64Swarmer.alloc_range c.client_ranges; *)
          let new_downloaded = 
            Int64Swarmer.downloaded swarmer in
          c.client_downloaded <- c.client_downloaded ++ (
            new_downloaded -- old_downloaded);
(*
          if not (List.mem c.client_ip bb.block_contributors) then
            bb.block_contributors <- c.client_ip :: 
            bb.block_contributors;
*)          
          
          
          if new_downloaded <> old_downloaded then 
            add_file_downloaded file.file_file 
              (new_downloaded -- old_downloaded);
          if new_downloaded -- old_downloaded < end_pos -- begin_pos then
            lprintf "ALREADY RECEIVED: %Ld < %Ld\n"
              (new_downloaded -- old_downloaded)
            (end_pos -- begin_pos);
          
          get_from_client c

(*
                    
      begin
        match c.client_block with
          None -> 
            printf_string "NO BLOCK EXPECTED FROM CLIENT";
            raise Not_found
        | Some bb ->
            let str_begin = Int64.of_int t.Q.bloc_begin in
            
            if bb.block_present || begin_pos < bb.block_begin
                || begin_pos >= bb.block_end || end_pos > bb.block_end
            then 
              let chunk_num = Int64.to_int (Int64.div begin_pos block_size) 
              in
              lprintf "%d: Exceeding block boundaries\n" (client_num c);
              
              lprintf "%Ld-%Ld (%Ld-%Ld)\n" 
                (begin_pos) (end_pos)
              (bb.block_begin) (bb.block_end)
              ;
              
              List.iter (fun z ->
                  lprintf "zone: %Ld-%Ld"
                    (z.zone_begin) (z.zone_end)
              ) c.client_zones;

(* try to recover the corresponding block ... *)
              
              if bb.block_pos <> chunk_num then begin
                  lprintf "OLD BLOCK %d <> %d\n" bb.block_pos chunk_num;
                end else
                (              
                  match file.file_chunks.(chunk_num) with
                    PresentTemp | PresentVerified -> 
                      lprintf "ALREADY PRESENT\n"; 

(* Here, we should probably try to find a new block !! *)
                      DonkeyOneFile.clean_client_zones c;
                      DonkeyOneFile.find_client_block c                    
                  
                  | AbsentTemp | AbsentVerified ->
                      lprintf "ABSENT (not implemented)\n"; 
(* We receive information for a block we have not asked !! *)
                  
                  | PartialTemp b | PartialVerified b ->
                      
                      if b != bb then begin
                          lprintf "BLOCK DISAGREEMENT\n"; 
                        end else begin
                          lprintf "PARTIAL\n"; 

(* try to find the corresponding zone *)
                          List.iter (fun z ->
                              if z.zone_begin >= begin_pos &&
                                end_pos > z.zone_begin then begin
                                  lprintf "BEGIN ZONE MATCHES\n"; 
                                end else
                              if z.zone_begin < begin_pos &&
                                begin_pos < z.zone_end &&
                                z.zone_end < end_pos then begin
                                  lprintf "END ZONE MATCHES\n";
                                end 
                          
                          ) b.block_zones
                        end
                );              
              raise Not_found
            else
            try
              begin
                if c.client_connected then
                  printf_string "#[OUT]"
                else
                  printf_string "#[IN]";
                
                try
                  if !!buffer_writes then 
                    Unix32.buffered_write (file_fd file) 
                  else
                    Unix32.write (file_fd file) begin_pos
                      t.Q.bloc_str t.Q.bloc_begin t.Q.bloc_len

(*
                let final_pos = Unix32.seek64 (file_fd file) 
                  begin_pos Unix.SEEK_SET in
                if final_pos <> begin_pos then begin
                    lprintf "BAD LSEEK %Ld/%Ld\n"
                      (final_pos)
                    (begin_pos); 
                    raise Not_found
                  end;
                if c.client_connected then
                  printf_string "#[OUT]"
                else
                  printf_string "#[IN]";

(*            if !verbose then begin
                lprintf "{%d-%d = %Ld-%Ld}\n" (t.Q.bloc_begin)
                (t.Q.bloc_len) (begin_pos) 
                (end_pos);
              end; *)
                let fd = try
                    Unix32.force_fd (file_fd file) 
                  with e -> 
                      lprintf "In Unix32.force_fd\n"; 
                      raise e
                in
                Unix2.really_write fd t.Q.bloc_str t.Q.bloc_begin t.Q.bloc_len;
*)
              end;
              (try
                  List.iter (update_zone file begin_pos end_pos) c.client_zones;
                with e ->
(*                    lprintf "Exception %s while updating zones\n"
                      (Printexc2.to_string e); *)
                    raise e
              );
              (try
                  find_client_zone c
                with 
                | e ->
                    lprintf "Exception %s while searching for find client zone\n"
                      (Printexc2.to_string e);
                    raise e)
            
            with
              End_of_file ->
                lprintf "END OF FILE WITH CLIENT %s\n" c.client_name;
            | e ->
                lprintf "Exception %s while searching for new chunk\n"
                  (Printexc2.to_string e)
      
      end;      
*)
        end    
        
let search_found filter search md4 tags =
  let file_name = ref "" in
  let file_size = ref Int64.zero in
  let availability = ref 0 in
  let new_tags = ref [] in
  List.iter (fun tag ->
      match tag with
        { tag_name = "filename"; tag_value = String s } -> file_name := s
      | { tag_name = "size"; tag_value = Uint64 v } -> file_size := v
      | { tag_name = "availability";
	  tag_value = (Uint64 v| Fint64 v) } ->
          availability := Int64.to_int v;  new_tags := tag :: !new_tags
      | _ -> new_tags := tag :: !new_tags
  ) tags;
  try
    let rs = DonkeyIndexer.find_result md4 in
(*    lprintf "search_add_result\n";  *)
    CommonInteractive.search_add_result filter search rs.result_result; (* ADD AVAILABILITY *)
(*    lprintf "search_add_result DONE\n";  *)
    let doc = rs.result_index in
    let result = Store.get store doc in
(*    old_avail := !old_avail + !availability; *)
    if not (List.mem !file_name result.result_names) then begin
        DonkeyIndexer.add_name result !file_name;
        result.result_names <- !file_name :: result.result_names
      end
  with _ ->
      match result_of_file md4 tags with
        None -> ()
      | Some new_result ->
      try
        let rs = DonkeyIndexer.index_result new_result in
        let doc = rs.result_index in
(*        lprintf "search_add_result\n";  *)
        CommonInteractive.search_add_result filter search rs.result_result;
(*        lprintf "search_add_result DONE\n";  *)
        let result = Store.get store doc in
        ()
      with _ ->  (* the file was probably filtered *)
          ()
