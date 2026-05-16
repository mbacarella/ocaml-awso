open! Values
open! Awso.Import

val get_cached_sso_token_file_path : cfg:Awso.Cfg.t -> string

val get_sso_role_request_and_cfg_exn
  :  cfg:Awso.Cfg.t
  -> cached_sso_token_file:string
  -> string
  -> GetRoleCredentialsRequest.t * Awso.Cfg.t

val get_sso_role_request_and_cfg
  :  cfg:Awso.Cfg.t
  -> cached_sso_token_file:string
  -> string
  -> (GetRoleCredentialsRequest.t * Awso.Cfg.t, exn) Result.t

val parse_role_credentials_response_exn
  :  (GetRoleCredentialsResponse.t, GetRoleCredentialsResponse.error) Result.t
  -> RoleCredentials.t option

val update_cfg_with_role_credentials_exn
  :  cfg:Awso.Cfg.t
  -> RoleCredentials.t option
  -> Awso.Cfg.t

val update_cfg_with_role_credentials
  :  cfg:Awso.Cfg.t
  -> RoleCredentials.t option
  -> (Awso.Cfg.t, exn) Result.t
