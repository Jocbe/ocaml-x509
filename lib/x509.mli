(** Modules for X509 (RFC5280) handling *)

module Cs : sig
  val hex_to_cs : string -> Cstruct.t
  val dotted_hex_to_cs : string -> Cstruct.t
end

(** A parser for PEM files *)
module Pem : sig
  (** [parse pem] is [(name * data) list], in which the [pem] is parsed into its components, each surrounded by [BEGIN name] and [END name]. The actual [data] is base64 decoded. *)
  val parse : Cstruct.t -> (string * Cstruct.t) list
end

(** A parser for X509 certificates in PEM format *)
module Cert : sig
  (** The type of a certificate  *)
  type t = Certificate.certificate

  (** [of_pem_cstruct pem] is [t list], where all certificates of the [pem] are extracted *)
  val of_pem_cstruct  : Cstruct.t -> t list

  (** [of_pem_cstruct1 pem] is [t], where the single certificate of the [pem] is extracted *)
  val of_pem_cstruct1 : Cstruct.t -> t
end

(** A parser for unencrypted private RSA keys certificates in PEM format *)
module PK : sig
  (** The private RSA key type *)
  type t = Nocrypto.Rsa.priv

  (** [of_pem_cstruct pem] is [t list], where all private keys of [pem] are extracted *)
  val of_pem_cstruct  : Cstruct.t -> t list

  (** [of_pem_cstruct1 pem] is [t], where the private key of [pem] is extracted *)
  val of_pem_cstruct1 : Cstruct.t -> t
end

(** The authenticator for a certificate chain *)
module Authenticator : sig
  (** result of an authentication, either [`Ok] or [`Fail] with a reason *)
  type res = [ `Ok of Certificate.certificate | `Fail of Certificate.certificate_failure ] Lwt.t

  (** abstract authenticator type *)
  type t = ?host:Certificate.host -> Certificate.stack -> res

  (** [authenticate authenticator ?host stack] is [result], where the given [authenticator] verifies the certificate [stack], given an optional [host] name. *)
  val authenticate : t -> ?host:Certificate.host -> Certificate.stack -> res

  (** [chain_of_trust ?time trust_anchors] is [authenticator], which uses the given [time] and set of [trust_anchors] to verify the certificate chain. This is an implementation of the algorithm in RFC5280. *)
  val chain_of_trust : ?time:float -> Cert.t list -> t

  (** [server_fingerprint ?time hash fingerprints] is an [authenticator] which uses the given [time] to verify the certificate chain - if successful the [hash] of the server certificate is checked against the entry in the fingerprint list. *)
  val server_fingerprint : ?time:float -> hash:Nocrypto.Hash.hash -> fingerprints:(string * Cstruct.t) list -> t

  (** [null] is [authenticator], which always returns [`Ok]. For testing purposes only. *)
  val null : t
  val test : Certificate.certificate option ref -> t
  (*val remote : Unix.sockaddr -> (string * int) -> t*)
  (*val dummy : 'a option ref -> t*)
end
