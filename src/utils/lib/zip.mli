(***********************************************************************)
(*                                                                     *)
(*                         The CamlZip library                         *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 2001 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License.         *)
(*                                                                     *)
(***********************************************************************)

(* $Id$ *)

(* Module [Zip]: reading and writing ZIP archives *)

(* This module provides functions for reading and writing ZIP archive
   files.  ZIP archives package one or more compressed files into
   a single ``ZIP file'' along with information about the files,
   including file name, date and time of last modification, user-provided
   comments, and a checksum to verify the integrity of each entry.
   The entries of a ZIP file are not necessarily actual files, and can
   actually consist of arbitrary data.

   The ZIP file format used in this module is identical to that
   implemented by the popular [pkzip] archiver under Windows,
   and by the Info-ZIP [zip] and [unzip] commands under Unix and Windows.
   This format is also identical to the JAR file format used by Java. *)

(*** Information on ZIP entries *)

type compression_method =
  | Stored (* data is stored without compression *)
  | Deflated

(* data is compressed with the ``deflate'' algorithm *)

(* Indicate whether the data in the entry is compressed or not. *)

type entry = {
  filename : string;
  (* file name for entry *)
  extra : string;
  (* extra information attached to entry *)
  comment : string;
  (* comment attached to entry *)
  methd : compression_method;
  (* compression method *)
  mtime : float;
  (* last modification time (seconds since epoch) *)
  crc : int32;
  (* cyclic redundancy check for data *)
  uncompressed_size : int;
  (* size of original data in bytes *)
  compressed_size : int;
  (* size of compressed data *)
  is_directory : bool;
  (* whether this entry represents a directory *)
  file_offset : int64;
}

(* for internal use *)

(* Description of an entry in a ZIP file. *)

(*** Reading from ZIP files *)

type in_file

(* Abstract type representing a handle opened for reading from
   a ZIP file. *)
val open_in : string -> in_file

(* Open the ZIP file with the given filename.  Return a
   handle opened for reading from this file. *)
val entries : in_file -> entry list

(* Return a list of all entries in the given ZIP file. *)
val comment : in_file -> string

(* Return the comment attached to the given ZIP file, or the
   empty string if none. *)
val find_entry : in_file -> string -> entry

(* [Zip.find_entry zf filename] returns the description of the
   entry having name [filename] in the ZIP file [zf].
   Raises [Not_found] if no such entry exists.
   The file name must match exactly; in particular, case is
   significant.  File names must use [/] (slash) as the directory
   separator.  The name of a directory must end with a trailing
   [/] (slash). *)
val read_entry : in_file -> entry -> string

(* [Zip.read_entry zf e] reads and uncompresses the data
   (file contents) associated with entry [e] of ZIP file [zf].
   The data is returned as a character string. *)
val copy_entry_to_channel : in_file -> entry -> out_channel -> unit

(* [Zip.copy_entry_to_channel zf e oc] reads and uncompresses
   the data associated with entry [e] of ZIP file [zf].
   It then writes this data to the output channel [oc]. *)
val copy_entry_to_file : in_file -> entry -> string -> unit

(* [Zip.copy_entry_to_file zf e destfile] reads and uncompresses
   the data associated with entry [e] of ZIP file [zf].
   It then writes this data to the file named [destfile].
   The file [destfile] is created if it does not exist,
   and overwritten otherwise.  The last modification date of
   the file is set to that indicated in the ZIP entry [e],
   if possible. *)
val close_in : in_file -> unit

(* Close the given ZIP file handle.  If the ZIP file handle was
   created by [open_in_channel], the underlying input channel
   is closed. *)

(*** Writing to ZIP files *)

type out_file

(* Abstract type representing a handle opened for writing to
   a ZIP file. *)
val open_out : ?comment:string -> string -> out_file

(* Create (or truncate to zero length) the ZIP file with
   the given filename.  Return a handle opened for writing
   to this file.  The optional argument [comment] is a
   comment string that is attached to the ZIP file as a whole
   (as opposed to the comments that can be attached to individual
   ZIP entries). *)
val add_entry :
  string ->
  out_file ->
  ?extra:string ->
  ?comment:string ->
  ?level:int ->
  ?mtime:float ->
  string ->
  unit

(* [Zip.add_entry data zf name] adds a new entry to the
                ZIP file [zf].  The data (file contents) associated with
                the entry is taken from the string [data].  It is compressed
                and written to the ZIP file [zf].  [name] is the file name
                stored along with this entry.  Several optional arguments
                can be provided to control the format and attached information
                of the entry:
   -            [extra]  extra data attached to the entry (a string).
                  Default: empty.
   -            [comment]  comment attached to the entry (a string)
                  Default: empty.
   -            [level]  compression level for the entry.  This is an integer
                  between 0 and 9, with 0 meaning no compression (store as is),
                  1 lowest compression, 9 highest compression.  Higher
                  levels result in smaller compressed data, but longer compression
                  times.  Default: 6 (moderate compression).
   -            [mtime]  last modification time (in seconds since the epoch).
                  Default: the current time. *)
val copy_channel_to_entry :
  in_channel ->
  out_file ->
  ?extra:string ->
  ?comment:string ->
  ?level:int ->
  ?mtime:float ->
  string ->
  unit

(* Same as [Zip.add_entry], but the data associated with the
   entry is read from the input channel given as first argument.
   The channel is read up to end of file. *)
val copy_file_to_entry :
  string ->
  out_file ->
  ?extra:string ->
  ?comment:string ->
  ?level:int ->
  ?mtime:float ->
  string ->
  unit

(* Same as [Zip.add_entry], but the data associated with the
   entry is read from the file whose name is given as first
   argument.  Also, the default value for the [mtime]
   optional parameter is the time of last modification of the
   file. *)
val close_out : out_file -> unit

(* Finish writing the ZIP archive by adding the table of
   contents, and close it. *)

(*** Error reporting *)

exception Error of string * string * string

(* Exception raised when an ill-formed ZIP archive is encountered,
   or illegal parameters are given to the functions in this
   module.  The exception is of the form
   [Error(ZIP_name, entry_name, message)] where [ZIP_name]
   is the name of the ZIP file, [entry_name] the name of
   the offending entry, and [message] an explanation of the
   error. *)
