
let o f g x = f (g x)

module Cs = struct

  open Cstruct
  include Nocrypto.Uncommon.Cs

  let begins_with cs target =
    let l1 = len cs and l2 = len target in
    l1 >= l2 && equal (sub cs 0 l2) target

  let ends_with cs target =
    let l1 = len cs and l2 = len target in
    l1 >= l2 && equal (sub cs (l1 - l2) l2) target

  let hex_to_cs = of_hex

  let dotted_hex_to_cs =
    o hex_to_cs (String.map (function ':' -> ' ' | x -> x))
end

module Pem = struct

  open Cstruct

  let null cs = Cstruct.len cs = 0

  let open_begin = of_string "-----BEGIN "
  and open_end   = of_string "-----END "
  and close      = of_string "-----"

  let catch f a =
    try Some (f a) with Invalid_argument _ -> None

  let tok_of_line cs =
    try
      if ( null cs ) then
        `Empty else
      if ( get_char cs 0 = '#' ) then
        `Empty else
      if ( Cs.begins_with cs open_begin &&
           Cs.ends_with cs close ) then
        `Begin (to_string @@ sub cs 11 (len cs - 16)) else
      if ( Cs.begins_with cs open_end &&
           Cs.ends_with cs close ) then
        `End (to_string @@ sub cs 9 (len cs - 14)) else
        `Data cs
    with Invalid_argument _ -> `Data cs

  let chop cs off len =
    let (a, b) = split cs off in (a, shift b len)

  let rec lines cs =
    let rec eol i =
      match get_char cs i with
      | '\r' when get_char cs (i + 1) = '\n' -> chop cs i 2
      | '\n' -> chop cs i 1
      | _    -> eol (i + 1) in
    match catch eol 0 with
    | Some (a, b) -> [< 'tok_of_line a ; lines b >]
    | None        -> [< 'tok_of_line cs >]

  let combine ilines =

    let rec accumulate t acc = parser
      | [< ' `Empty ; lines >] -> accumulate t acc lines
      | [< ' `Data cs ; lines >] -> accumulate t (cs :: acc) lines
      | [< ' `End t' when t = t' >] -> Cs.concat (List.rev acc)

    and block = parser
      | [< ' `Begin t ; body = accumulate t [] ; tail >] ->
        ( match catch Nocrypto.Base64.decode body with
          | None      -> invalid_arg "PEM: malformed Base64 data"
          | Some data -> (t, data) :: block tail )
      | [< ' _ ; lines >] -> block lines
      | [< >] -> []

    in block ilines

  let parse = o combine lines

end

let exactly_one ~what = function
  | []  -> invalid_arg ("No " ^ what)
  | [x] -> x
  | _   -> invalid_arg ("Multiple " ^ what)

module Cert = struct

  open Certificate

  type t = certificate

  let of_pem_cstruct cs =
    List.fold_left (fun certs -> function
      | ("CERTIFICATE", cs) ->
        ( match Certificate.parse cs with
          | Some cert -> certs @ [cert]
          | None      -> invalid_arg "X509: failed to parse certificate" )
      | _ -> certs)
    []
    (Pem.parse cs)

  let of_pem_cstruct1 =
    o (exactly_one ~what:"certificates") of_pem_cstruct
end

module PK = struct

  type t = Nocrypto.Rsa.priv

  let of_pem_cstruct cs =
    List.fold_left (fun pks -> function
      | ("RSA PRIVATE KEY", cs) ->
        ( match Asn_grammars.PK.rsa_private_of_cstruct cs with
          | Some pk -> pk :: pks
          | None    -> invalid_arg "X509: failed to parse rsa private key" )
      | _ -> pks)
    []
    (Pem.parse cs)

  let of_pem_cstruct1 =
    o (exactly_one ~what:"RSA keys") of_pem_cstruct
end

module Authenticator = struct
  
  open Lwt
  
  type res = [ `Ok of Certificate.certificate | `Fail of Certificate.certificate_failure ] Lwt.t
  type t = ?host:Certificate.host -> Certificate.stack -> res

  let authenticate t ?host stack = t ?host stack

  (* XXX
   * Authenticator just hands off a list of certs. Should be indexed.
   * *)
  (* XXX
   * Authenticator authenticates against time it was *created* at, not at the moment of
   * authentication. This has repercussions to long-lived authenticators; reconsider.
   * *)
  let chain_of_trust ?time cas =
    let cas = Certificate.valid_cas ?time cas in
    fun ?host stack ->
      return (Certificate.verify_chain_of_trust ?host ?time ~anchors:cas stack)

  let server_fingerprint ?time ~hash ~fingerprints =
    fun ?host stack ->
      return (Certificate.trust_fingerprint ?host ?time ~hash ~fingerprints stack)

  let null ?host:_ (c, _) = return (`Ok c)
  let test retval = fun ?host:host (c, _) -> 
    (*let sexp = Certificate.sexp_of_certificate c in*)
    retval := Some c;
    Printf.printf "\n1st certificate hostname: %s\n\n" (List.nth (Certificate.cert_hostnames c) 0) ;
			    return (`Fail Certificate.InvalidExtensions)
  
  (* ts = trust server *)
  
  (*let remote ts_addr (dst_host, dst_port) =
    let rec rec_val_block ic count =
      if count <= 0 then "FAILED!\n"
      else
      try
        Printf.printf "Try... ";
	Lwt_main.run(Lwt_io.flush_all ());
        let ret = Lwt_main.run(Lwt_io.read_value ic) in
        Printf.printf "Success\n";
	Lwt_main.run(Lwt_io.flush_all ());
        ret
      with End_of_file -> 
        Printf.printf "Fail.\n";
	Lwt_main.run(Lwt_io.flush_all ());
        (Unix.sleep 1; rec_val_block ic (count-1))
    in
    fun ?host:host (c, cs) ->
      Lwt_main.run begin
	lwt (ts_ic, ts_oc) = Lwt_io.open_connection ts_addr in
	let ts_req = ((dst_host, dst_port), c) in
	Lwt_io.write_value ts_oc ts_req;
	lwt y = rec_val_block ts_ic 10 in
        let x = match y with 
	  | Some c -> c
	  | None -> Bytes.create 10
	in 
	Lwt_io.print x;
      end
      `Ok c*)

  (*let dummy out = 
    fun ?host:host (c, cs) ->
      out := Some (host, (c, cs));
      `Ok c*)
end

