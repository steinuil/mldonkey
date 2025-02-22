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

val string_ncmp : string -> string -> int -> bool
(** compare two strings, looking just the first n characters *)

val search_from : string -> int -> string -> int
(** [search_from doc pos str] search the first occurence of the string
    [str] in [doc], starting at index [pos] *)

val replace : string -> char -> string -> string
(** [replace doc c str] replace all the occurences of the char [c] in
    [doc] by the string [str] *)

val split : string -> char -> string list

val splitn : string -> char -> int -> string list
(** [split str c] split the string [str] in substrings separated by
    the character [c] *)

val split_simplify : string -> char -> string list
(** [split_simplify str c] split the string [str] in substrings separated by
    the character [c], removing empty sub-strings. *)

val unsplit : string list -> char -> string
(** [unsplit str c] reverse operation of [split] *)

val words : string -> string list

val convert : 'a -> (Buffer.t -> 'a -> char -> 'a) -> string -> string
(** [convert init f s] iterates on all characters of [s], calling [f] to 
    fill a generated buffer using a status value, [init] being the initial
    status for the first call to [f]. It returns the content of the buffer. *)

val before : string -> int -> string
(** [before s pos] returns the substring of [s] starting at pos 0 and 
    of length [pos]. *)

val after : string -> int -> string
(** [after s pos] returns the end substring of [s] starting at [pos]. *)

val cut_at : string -> char -> string * string
(** [cut_at s c] returns the substrings of [s] before and after the first [c]
    in [s]. The second substring is empty if [s] doesn't contain [c].
    The first [c] of [s] is not contained in the two substrings. *)

val check_prefix : string -> string -> bool
(** [check_prefix s prefix] checks whether [prefix] is a prefix of [s]. *)

val check_suffix : string -> string -> bool
(** [check_suffix s suffix] checks whether [suffix] is a suffix of [s]. *)

val upp_initial : string -> string
(** [upp_initial s] returns a copy of [s] with uppercase first character. *)

val subequal : string -> int -> string -> int -> int -> bool
(** [subequal s1 pos1 s2 pos2 len] checks without allocation whether
the sub-strings of [s1] at [pos1] of [len] and of [s2] at [pos2] of [len]
are equals. *)

val subcontains : string -> string -> bool
(** [subcontains s sub] checks whether [sub] appears in [s]. *)

val of_char : char -> string
(** [of_char c] returns the string containing one [c]. *)

val resize : string -> int -> string
(** [resize s len] returns a string of length [len] starting with [s]. *)

val init : int -> (int -> char) -> string

val tokens : string -> string list

val contains : string -> string -> bool
(** [contains s sub] checks whether [s] contains [sub] *)

val starts_with : (* string *) string -> (* start *) string -> bool
(** [starts_with s prefix] checks whether [s] starts with [prefix] *)

val replace_char : bytes -> char -> char -> unit
(** [replace_char s c1 c2] replaces char [c1] by char [c2] in [s] *)

val stem : string -> string list
(** [stem s] cuts the string [s] in small words, for indexation eg *)

val map : (char -> 'a) -> string -> 'a array

val iteri : (int -> char -> unit) -> string -> unit

val exists : (char -> bool) -> string -> bool

val existsi : (int -> char -> bool) -> string -> bool

val for_all : (char -> bool) -> string -> bool

val hex_string_of_string : string -> string

val dehtmlize : string -> string
(** [dehtmlize s] replace all <br> with \n and remove all remaining html tags from string [s] *)
