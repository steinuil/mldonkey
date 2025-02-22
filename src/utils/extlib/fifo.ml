(*
 * Copyright 2001, 2002 b8_bavard, b8_fee_carabine, INRIA
 * 
 * This file is part of mldonkey.
 *
 * mldonkey is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * mldonkey is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with mldonkey; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *)

exception Empty

type 'a t = {
  mutable empty : bool;
  mutable inpos : int;
  mutable outpos : int;
  mutable array : 'a array;
  mutable size : int; (* bit Mask *)
}

let create () =
  {
    empty = true;
    inpos = 0;
    outpos = 0;
    array = Array.make 4 (Obj.magic ());
    size = 3;
  }

let iter f t =
  if not t.empty then
    if t.inpos > t.outpos then
      for i = t.outpos to t.inpos - 1 do
        f t.array.(i)
      done
    else (
      for i = t.outpos to t.size do
        f t.array.(i)
      done;
      for i = 0 to t.inpos - 1 do
        f t.array.(i)
      done )

let mem t v =
  try
    if not t.empty then
      if t.inpos > t.outpos then
        for i = t.outpos to t.inpos - 1 do
          if t.array.(i) = v then raise Exit
        done
      else (
        for i = t.outpos to t.size do
          if t.array.(i) = v then raise Exit
        done;
        for i = 0 to t.inpos - 1 do
          if t.array.(i) = v then raise Exit
        done );
    false
  with _ -> true

let realloc t =
  let len = Array.length t.array in
  let tab = Array.make (2 * len) t.array.(0) in
  let start = len - t.inpos in
  Array.blit t.array t.inpos tab 0 start;
  Array.blit t.array 0 tab start (len - start);
  t.array <- tab;
  t.outpos <- 0;
  t.inpos <- len;
  t.size <- (t.size * 2) + 1

let shrink t =
  if t.size > 3 then (
    let len = Array.length t.array in
    let tab = Array.make (len / 2) t.array.(0) in
    ( if t.outpos < t.inpos then (
      Array.blit t.array t.outpos tab 0 (t.inpos - t.outpos);
      t.inpos <- t.inpos - t.outpos )
    else
      let ol = len - t.outpos in
      Array.blit t.array t.outpos tab 0 ol;
      Array.blit t.array 0 tab ol t.inpos;
      t.inpos <- ol + t.inpos );
    t.array <- tab;
    t.outpos <- 0;
    t.size <- (t.size - 1) / 2 )

let put t e =
  (* lprintf "FIFO PUT"; lprint_newline (); *)
  if t.inpos = t.outpos && not t.empty then realloc t;
  t.array.(t.inpos) <- e;
  t.inpos <- (t.inpos + 1) land t.size;
  t.empty <- false;
  (* lprintf "FIFO NOT EMPTY %s" (string_of_bool t.empty); lprint_newline (); *)
  ()

let clear t =
  (* lprintf "FIFO CLEAR"; lprint_newline (); *)
  let tab = Array.make 4 t.array.(0) in
  t.array <- tab;
  t.size <- 3;
  t.empty <- true;
  t.inpos <- 0;
  t.outpos <- 0

let length t =
  (* lprintf "FIFO LEN"; lprint_newline (); *)
  if t.empty then 0
  else if t.inpos > t.outpos then t.inpos - t.outpos
  else
    let s = Array.length t.array in
    s + t.inpos - t.outpos

let take t =
  (* lprintf "FIFO TAKE"; lprint_newline (); *)
  if t.empty then raise Empty;
  if length t < (t.size + 1) / 4 then shrink t;
  let e = t.array.(t.outpos) in
  t.outpos <- (t.outpos + 1) land t.size;
  if t.outpos = t.inpos then clear t;
  e

let head t =
  if t.empty then raise Empty;
  t.array.(t.outpos)

let empty t =
  (* lprintf "FIFO EMPTY %s" (string_of_bool t.empty); lprint_newline (); *)
  t.empty

let to_list t =
  if t.empty then []
  else if t.inpos > t.outpos then (
    let len = t.inpos - t.outpos in
    let tab = Array.make len t.array.(0) in
    Array.blit t.array t.outpos tab 0 len;
    Array.to_list tab )
  else
    let s = Array.length t.array in
    let len = s + t.inpos - t.outpos in
    let tab = Array.make len t.array.(0) in
    Array.blit t.array t.outpos tab 0 (s - t.outpos);
    Array.blit t.array 0 tab (s - t.outpos) t.inpos;
    Array.to_list tab

let to_array t =
  if t.empty then [||]
  else if t.inpos > t.outpos then (
    let len = t.inpos - t.outpos in
    let tab = Array.make len t.array.(0) in
    Array.blit t.array t.outpos tab 0 len;
    tab )
  else
    let s = Array.length t.array in
    let len = s + t.inpos - t.outpos in
    let tab = Array.make len t.array.(0) in
    Array.blit t.array t.outpos tab 0 (s - t.outpos);
    Array.blit t.array 0 tab (s - t.outpos) t.inpos;
    tab

let put_back_ele t e =
  if t.inpos = t.outpos && not t.empty then realloc t;
  t.outpos <- (t.outpos - 1) land t.size;
  t.array.(t.outpos) <- e;
  t.empty <- false

let rec put_back t list =
  match list with
  | [] -> ()
  | ele :: tail ->
      put_back t tail;
      put_back_ele t ele

let reformat t =
  if not t.empty then (
    let s = Array.length t.array in
    let len = s + t.inpos - t.outpos in
    let tab = Array.make s t.array.(0) in
    Array.blit t.array t.outpos tab 0 (s - t.outpos);
    Array.blit t.array 0 tab (s - t.outpos) t.inpos;
    t.array <- tab;
    t.inpos <- len;
    t.outpos <- 0 )

let remove t e =
  if not t.empty then (
    if t.outpos >= t.inpos then reformat t;
    let rec iter t i j =
      (* Printf2.lprintf "i=%d j=%d inpos=%d outpos=%d\n"
         i j t.inpos t.outpos; print_newline (); *)
      if i >= t.inpos then (
        if i > j then (
          t.inpos <- j;
          if t.inpos = t.outpos then clear t ) )
      else
        let ee = t.array.(i) in
        if e = ee then iter t (i + 1) j
        else (
          if i > j then
            (* Printf2.lprintf "Move i=%d at j=%d" i j; print_newline ();  *)
            t.array.(j) <- ee;
          iter t (i + 1) (j + 1) )
    in
    iter t t.outpos t.outpos )

let%test_unit "test suite" =
  let t = create () in

  for i = 0 to 100 do
    put t i
  done;

  for _ = 0 to 80 do
    put t (take t)
  done;

  assert (length t = 101);

  for i = 56 to 76 do
    remove t i
  done;

  for _ = 0 to 79 do
    ignore (take t)
  done;

  assert (length t = 0)
