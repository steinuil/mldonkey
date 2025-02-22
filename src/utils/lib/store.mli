(* Copyright 2002 b8_bavard, b8_fee_carabine, INRIA *)
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

type 'a t

type index

val create : string -> 'a t

val add : 'a t -> 'a -> index

val get : 'a t -> index -> 'a

val remove : 'a t -> index -> unit

val close : 'a t -> unit

val update : 'a t -> index -> 'a -> unit

val set_attrib : 'a t -> index -> bool -> unit

val get_attrib : 'a t -> index -> bool

val index : index -> int

val dummy_index : index

val stats : 'a t -> int * int
