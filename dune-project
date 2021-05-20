(lang dune 2.7)

(using menhir 2.1)

(name mldonkey)

(version 3.1.7)

(license "GPL-2.0-only")

(generate_opam_files true)

(authors "mldonkey team")

(maintainers "ygrek@autistici.org")

(source
 (github steinuil/mldonkey))

(package
 (name mldonkey)
 (synopsis "Cross-platform multi-network peer-to-peer daemon")
 (description
  "Supported networks include:\n * eDonkey (with Overnet and Kad)\n * BitTorrent (with DHT)\n * Direct Connect\n * HTTP/FTP\nMLdonkey core runs as a background daemon and provides several control\ninterfaces : telnet, web, and binary protocol for third party GUIs.")
 (depends
  ocaml
  camlp4
  num
  ppx_inline_test
  ppx_bitstring
  menhir
  ocamlrss
  xml-light
  bitv
  base64))
