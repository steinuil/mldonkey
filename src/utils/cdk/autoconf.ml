let perl_path = "/usr/bin/perl"
let check_bounds = false
let current_version = "3.1.7-git"
let major_version = "3"
let minor_version = "1"
let sub_version = "7"
let scm_version = "release-3-1-7-2-6-g3ce30152-safe-string"
let glibc_version = "2.31"
let cc_version = "9"
let cxx_version = "9"
let build_system = "dune :^)"
let configure_arguments = " "

let system = Sys.os_type
let windows = Sys.cygwin || Sys.win32

let opennapster = "no"
let gnutella = "no"
let gnutella2 = "no"
let direct_connect = "no"
let soulseek = "no"
let openft = "no"
let fasttrack = "yes"
let filetp = "yes"
let bittorrent = "yes"
let donkey = "yes"
let donkey_sui = "yes"
let donkey_sui_urandom = ref false
let donkey_sui_works () = donkey_sui = "yes" && !donkey_sui_urandom

exception OutOfBoundsAccess
let outofboundsaccess = OutOfBoundsAccess
  
let check_string s pos =
  if check_bounds && pos >= String.length s then
    raise outofboundsaccess
  
let check_array s pos =
  if check_bounds && pos >= Array.length s then
    raise outofboundsaccess

let has_iconv = "yes" = "yes"

let has_gd = "no" = "yes"
let has_gd_png = "no" = "yes"
let has_gd_jpg = "no" = "yes"

let bzip2 = "no" = "yes"
let magic = "no" = "yes"
let magic_works = ref false
let upnp_natpmp = "no" = "yes"
