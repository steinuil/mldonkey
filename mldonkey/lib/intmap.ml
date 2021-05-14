include Map.Make(struct
  type t = int

  let compare = Int.compare
end)

let length = cardinal
  
let nth map n =
  List.nth (bindings map) n |> snd
      
let to_list map =
  let list = ref [] in
  iter (fun _ v -> list := v :: !list) map;
  !list
