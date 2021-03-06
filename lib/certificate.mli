(** Certificate validation as described in RFC5280 and RFC6125. *)

(** abstract type of a certificate *)
type certificate

(** a stack of certificates: the server certificate and a list of intermediate certificates *)
type stack = certificate * certificate list

(** strict or wildcard matching of a server name *)
type host = [ `Strict of string | `Wildcard of string ]

(** [parse cstruct] is [certificate option] where the [cstruct] is parsed to a high-level [certificate] or failure *)
val parse       : Cstruct.t -> certificate option

(** [parse_stact cstructs] is [stack option] where the [cstructs] are parsed to high-level [certificates] or failure *)
val parse_stack : Cstruct.t list -> stack option

(** [cs_of_cert certificate] is [cstruct] the binary representation of the [certificate]. *)
val cs_of_cert  : certificate -> Cstruct.t

(** [asn_of_cert certificate] is [asn] the ASN.1 representation of the [certificate]. *)
val asn_of_cert : certificate -> Asn_grammars.certificate

(** possible failures while validating a certificate chain *)
type certificate_failure =
  | InvalidCertificate
  | InvalidSignature
  | CertificateExpired
  | InvalidExtensions
  | InvalidPathlen
  | SelfSigned
  | NoTrustAnchor
  | InvalidInput
  | InvalidServerExtensions
  | InvalidServerName
  | InvalidCA

(** variant of different public key types of a certificate *)
type key_type = [ `RSA | `DH | `ECDH | `ECDSA ]

(** [cert_type certificate] is [key_type], the public key type of the [certificate] *)
val cert_type           : certificate -> key_type

(** [cert_usage certificate] is [key_usage], the key usage extensions of the [certificate] *)
val cert_usage          : certificate -> Asn_grammars.Extension.key_usage list option

(** [cert_extended_usage certificate] is [extended_key_usage], the extended key usage extensions of the [certificate] *)
val cert_extended_usage : certificate -> Asn_grammars.Extension.extended_key_usage list option

(** [cert_hostnames certficate] is [hostnames], the list of hostnames mentioned in the [certifcate] *)
val cert_hostnames      : certificate -> string list

(** [wildcard_matches hostname certificate] is [result], depending on whether the certificate contains a wildcard name which the hostname matches. *)
val wildcard_matches    : string -> certificate -> bool


(** [verify_chain_of_trust ?host ?time ~anchors stack] is [validation_result], where the certificate [stack] is verified using the algorithm from RFC5280: The validity period of the given certificates is checked against the [time]. The X509v3 extensions of the [stack] are checked, then a chain of trust from some [anchors] to the server certificate is validated. Also, the server certificate is checked to contain the given [hostname] in its subject alternative name extension (or common name if subject alternative name is not present), either using wildcard or strict matching as described in RFC6125. The returned certificate is the trust anchor. *)
val verify_chain_of_trust :
  ?host:host -> ?time:float -> anchors:(certificate list) -> stack
  -> [ `Ok of certificate | `Fail of certificate_failure ]

(** [trust_fingerprint ?time hash fingerprints stack] is [validation_result], where the certificate [stack] is verified (using same RFC5280 algorithm). Instead of trust anchors, a map from hostname to fingerprint is provided, where the certificate is checked against. Lookup in the fingerprint list is based on the provided host. If no host is provided, [validation_result] is [`Fail]. *)
val trust_fingerprint :
  ?host:host -> ?time:float -> hash:Nocrypto.Hash.hash -> fingerprints:(string * Cstruct.t) list -> stack
  -> [ `Ok of certificate | `Fail of certificate_failure ]

(** [valid_cas ?time certificates] is [valid_certificates] which has filtered out those certificates which validity period does not contain [time]. Furthermore, X509v3 extensions are checked (basic constraints must be true). *)
val valid_cas : ?time:float -> certificate list -> certificate list

(** [common_name_to_string certificate] is [common_name] which is the extracted common name from the subject *)
val common_name_to_string         : certificate -> string

(** [certificate_failure_to_string failure] is [failure_string] which is a string describing the [failure]. *)
val certificate_failure_to_string : certificate_failure -> string

open Sexplib
val certificate_of_sexp : Sexp.t -> certificate
val sexp_of_certificate : certificate -> Sexp.t
