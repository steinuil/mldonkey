(* Copyright 2001, 2002 b52_simon :), b8_bavard, b8_fee_carabine, INRIA *)
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

open CommonNetwork

open BTClients
open CommonOptions
open CommonFile
open CommonComplexOptions
open BasicSocket
open Options
open BTComplexOptions
open BTOptions
open BTGlobals
open BTTypes
open CommonTypes

let is_enabled = ref false
  
let disable enabler () =
  if !enabler then begin
      is_enabled := false;
      enabler := false;
      List.iter (fun file ->
          Hashtbl2.safe_iter (fun c -> disconnect_client c Closed_by_user) 
          file.file_clients) !current_files;
      (match !listen_sock with None -> ()
        | Some sock -> 
            listen_sock := None;
            TcpServerSocket.close sock Closed_by_user);
      if !!enable_bittorrent then enable_bittorrent =:= false
    end
    
let enable () =
  if not !is_enabled then
    let enabler = ref true in
    is_enabled := true;
  network.op_network_disable <- disable enabler;
  
  if not !!enable_bittorrent then enable_bittorrent =:= true;
  (*
  List.iter (fun s ->
      try
        let ip = Ip.from_name s in
        redirectors_ips := ip :: !redirectors_ips
      with _ -> ()
  ) !!redirectors;
*)

  (*
  Hashtbl.iter (fun _ file ->
      if file_state file <> FileDownloaded then
        current_files := file :: !current_files
  ) files_by_key;
*)

  
  BTClients.recover_files ();  
  add_session_timer enabler 60.0 (fun timer ->
      BTClients.recover_files ();
      BTClients.send_pings ());
  
  BTClients.listen ();
  ()
  
let _ =
  network.op_network_is_enabled <- (fun _ -> !!CommonOptions.enable_bittorrent);
  option_hook enable_bittorrent (fun _ ->
      if !!enable_bittorrent then network_enable network
      else network_disable network);
(*
  network.op_network_save_simple_options <- BTComplexOptions.save_config;
  network.op_network_load_simple_options <- 
    (fun _ -> 
      try
        Options.load bittorrent_ini;
      with Sys_error _ ->
          BTComplexOptions.save_config ()
);
  *)
  network.op_network_enable <- enable;
  network.network_config_file <- [bittorrent_ini];
  network.op_network_info <- (fun n ->
      { 
        network_netnum = network.network_num;
        network_config_filename = (match network.network_config_file with
            [] -> "" | opfile :: _ -> options_file_name opfile);
        network_netname = network.network_name;
        network_enabled = network.op_network_is_enabled ();
        network_uploaded = Int64.zero;
        network_downloaded = Int64.zero;
      });
  CommonInteractive.register_gui_options_panel "BitTorrent" 
  gui_bittorrent_options_panel
  
  
let main (toto: int) = ()
  