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


(* HTTP Requests:
  GET, POST, HEAD, PUT, DELETE, TRACE, OPTIONS, CONNECT
*)


open BasicSocket
open Unix
open Url
open TcpBufferedSocket

  
type http_request =
  GET of url
| POST of url
| HEAD of url
| PUT of url
| DELETE of url
| TRACE of url
| OPTIONS of url option (* None = '*' *)
| CONNECT of string * int

type http_headers =
| Generic of string * string
| Referer of url

type content_handler = 
  int -> (string * string) list -> TcpBufferedSocket.t -> int -> unit
  
let string_of_header = function
  | Generic (a, b) -> a ^ ": " ^ b ^ "\r\n"
  | Referer u -> "Referer: " ^ (Url.to_string false u) ^ "\r\n"

let make_full_request url args headers ispost toproxy =
  let args = url.args@args in
  let res = Buffer.create 80 in
  let is_real_post = ispost && args <> [] in
  if is_real_post
  then Buffer.add_string res "POST "
  else Buffer.add_string res "GET ";
  if toproxy
  then Buffer.add_string res (Url.to_string false url)
  else (Buffer.add_string res url.file);
  if (not is_real_post) && args <> []
  then
    (Buffer.add_char res '?';
     let rec manage_args = function
      | [] -> assert false
      | [a, ""] ->
          Buffer.add_string res a
      | [a, b] ->
          Buffer.add_string res a; Buffer.add_char res '='; Buffer.add_string res b
      | (a,b)::l ->
          Buffer.add_string res a; Buffer.add_char res '='; Buffer.add_string res b;
          Buffer.add_char res '&'; manage_args l in
    manage_args args);
  Buffer.add_string res " HTTP/1.0\r\nHost: ";
  Buffer.add_string res url.server;
  Buffer.add_string res "\r\n";
  let manage_headers = function
    | [] -> ()
    | a::l -> Buffer.add_string res (string_of_header a) in
  manage_headers headers;
  Buffer.add_string res "User-Agent: Wget 1.4\r\n";
  Buffer.add_string res "Accept: */*\r\n";
  if is_real_post
  then
    (let post = Buffer.create 80 in
     let rec make_post = function
      | [] -> assert false
      | [a, b] ->
            Printf.bprintf post "%s%c%s" (Url.encode a) '=' (Url.encode b)
        | (a,b)::l ->
            Printf.bprintf post "%s%c%s%c" 
              (Url.encode a) '=' (Url.encode b) '&';
            make_post l in
     make_post args;
     Buffer.add_string res "Content-Type: application/x-www-form-urlencoded\r\nContent-Length: ";
     Buffer.add_string res (string_of_int (Buffer.length post));
     Buffer.add_string res "\r\n\r\n";
     Buffer.add_buffer res post)
  else
    Buffer.add_string res "\r\n";
  let s = Buffer.contents res in
  s

type get_args =
  Timeout of float
| Args of (string * string) list
| Headers of http_headers list
| Post
| Proxy of string * int

let split_head s =
  let rec iter pos1 res =
    try
      let pos3 = String.index_from s pos1 '\n' in
      let pos2 = if pos3 > 0 && s.[pos3 - 1] = '\r' then pos3 - 1 else pos3 in
      let line = String.sub s pos1 (pos2 - pos1) in
      if line = "" then List.rev res else
      iter (pos3+1) (line :: res)
    with _ -> 
        let last_line = String.sub s pos1 (String.length s - pos1) in
        List.rev (if last_line = "" then res else last_line :: res)
  in
  iter 0 []

let parse_header headers_handler sock header =
  let headers = split_head header in
  match headers with 
    [] -> failwith "Ill formed reply"
  | ans :: headers ->
      let ans_code = int_of_string (String.sub ans 9 3) in
      let headers = List.map (fun s ->
            let sep = String.index s ':' in
            let name_head = String.sub s 0 sep in
            let size = String.length s in
            let content_head = String.sub s (sep+2) (size-sep-2) in
            (name_head, content_head)
        ) headers in
      try
        headers_handler sock ans_code headers;
      with _ -> 
          TcpBufferedSocket.close sock "bad header"
  
let read_header header_handler  sock nread =  
  let b = TcpBufferedSocket.buf sock in
  let end_pos = b.pos + b.len in
  let new_pos = end_pos - nread in
  let new_pos = maxi 0 (new_pos - 1) in
  (*
  Printf.printf "received [%s]" (String.escaped 
      (String.sub b.buf new_pos nread));
print_newline ();
  *)
  let rec iter i =
    let end_pos = b.pos + b.len in
    if i < end_pos then
      if b.buf.[i] = '\n' && i <= end_pos - 2 then
        let c = b.buf.[i+1] in
        if c = '\n' then
          let len = i + 2 - b.pos in
          let header = String.sub b.buf b.pos len in
          buf_used sock len;
          header_handler sock header        
        else
        if c = '\r' && i <= end_pos - 3 && b.buf.[i+2] = '\n' then
          let len = i + 3 - b.pos in
          let header = String.sub b.buf b.pos len in
          buf_used sock len;
          header_handler sock header
        else 
          iter (i+1)
      else
        iter (i+1)
    else
      ()
  in
  iter new_pos

let http_reply_handler headers_handler =
  read_header (parse_header headers_handler)
  
let get_page url get_args content_handler f =
  let rec get_url level url =
    let args = ref [] in
    let headers = ref [] in
    let ispost = ref false in
    let timeout = ref 300.0 in
    let proxy = ref None in
    List.iter (function   
        Timeout t -> timeout := t
      | Args l -> args := l@ !args
      | Headers l -> headers := l @ !headers;
      | Post -> ispost := true
      | Proxy (h,p) -> proxy := Some (h,p)
    ) get_args;
    let args = !args in
    let headers = !headers in
    let ispost = !ispost in
    let timeout = !timeout in
    let proxy = !proxy in
    
    let request = make_full_request url args headers ispost (proxy <> None) in
    
    let server, port =
      match proxy with
      | None -> url.server, url.port
      | Some (s, p) -> s, p
    in
    let sock = TcpBufferedSocket.connect "http client connecting" (Ip.to_inet_addr (Ip.from_name server))
      port (fun _ _ -> ())
    in
    TcpBufferedSocket.write_string sock request;
    TcpBufferedSocket.set_reader sock (http_reply_handler 
        (default_headers_handler level))
    
  and default_headers_handler level sock ans_code headers =
    (*
    List.iter (fun (name, value) ->
        Printf.printf "[%s]=[%s]" name value;
        print_newline ();
    ) headers;
*)
    match ans_code with
      200 ->
(*
  Printf.printf "ans_code: %d" ans_code;
  print_newline ();
  List.iter (fun (name, content) ->
      Printf.printf "HEADER %s:%s" name content;
      print_newline ();) 
headers;
*)
        TcpBufferedSocket.set_closer sock (fun _ _ -> 
            f ());
        let content_length = ref (-1) in
        List.iter (fun (name, content) ->
            if String.lowercase name = "content-length" then
              try          
                content_length := int_of_string content
              with _ -> 
                  Printf.printf "bad content length [%s]" content;
                  print_newline ();
        ) headers;
        
        let content_handler = content_handler !content_length headers in
        set_reader sock content_handler;
        let buf = TcpBufferedSocket.buf sock in
        if buf.len > 0 then
          content_handler sock buf.len 
          
    | 302 ->
        Printf.printf "INDIRECTION"; print_newline ();
        if level < 10 then
          begin
            try
              let url = List.assoc "Location" headers in
              Printf.printf "Indirection %s" url; print_newline ();
              get_url (level+1) (Url.of_string url)
            
            with e ->
                List.iter (fun (name, value) ->
                    Printf.printf "[%s]=[%s]" name value;
                    print_newline ();
                ) headers
                
          end
          
    | _ ->
        Printf.printf "Http_client: bad reply %d" ans_code;
        print_newline ();
        close sock "bad reply";
        raise Not_found

  in get_url 0 url

  
let wget url f = 
    
  let file_buf = Buffer.create 1000 in
  let file_size = ref 0 in

  get_page (Url.of_string url) []
    (fun maxlen headers sock nread ->
        let buf = TcpBufferedSocket.buf sock in
        
        if nread > 0 then begin
            let left = 
              if maxlen >= 0 then
                mini (maxlen - !file_size) nread
              else nread
          in
          Buffer.add_string file_buf (String.sub buf.buf buf.pos left);
            buf_used sock left;
            file_size := !file_size + left;
            if nread > left then
              TcpBufferedSocket.close sock "end read"
        end)
  (fun _ ->  
      let s = Buffer.contents file_buf in
      if s = "" then begin  
            Printf.printf "Empty content for url %s" url;
          print_newline ();
        end;
      let filename = Filename.temp_file "http_" ".tmp" in
      File.from_string filename s;
      try
        (f filename : unit);
        Sys.remove filename 
      with  e ->  Printf.printf
            "Exception %s in loading downloaded file %s"
            (Printexc2.to_string e) filename;
          Sys.remove filename 
  )

  
let split_header header =     
  for i = 0 to String.length header - 1 do
    if header.[i] = '\r' then header.[i] <- '\n'
  done;
  String2.split_simplify header '\n'

let cut_headers headers =
  try
  List.map (fun s ->
      let pos = String.index s ':' in
      let len = String.length s in
      if pos+1 < len && s.[pos+1] = ' ' then
        String.lowercase (String.sub s 0 pos), String.sub s (pos+2) (len-pos-2)
      else
        String.lowercase (String.sub s 0 pos), String.sub s (pos+1) (len-pos-1)
  ) headers
  with e ->
      Printf.printf "Exception in cut_headers: %s" (Printexc2.to_string e);
      print_newline ();
      raise e