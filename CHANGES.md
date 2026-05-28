# Changelog

## 0.9.1 (2026-05-28)

### New stuff

- `awso-eio`: backend for [Eio](https://github.com/ocaml-multicore/eio). Same 400+ services exposed as `awso-eio.<svc>`. Requires OCaml 5
- 13 services re-enabled that the codegen had skipped (apigateway, apigatewayv2, appconfig, appconfigdata, cloudhsm, codeguruprofiler, health, lex-runtime, mediaconnect, medialive, mq, s3control, sagemaker-runtime); 6 others (appsync, dataexchange, iottwinmaker, lexv2-runtime, pinpoint, workmailmessageflow) still excluded with documented codegen bugs to chase later
- `CREDITS.md`

### Compatibility & dep hygiene

- minimum OCaml is now 5.3.0 (we'd hoped to widen to 4.14 this release but ran out of time chasing compiler stack overflows on the giant generated tables; the door is open for 0.9.2)
- `tls >= 2.1.0`. Noticed [CVE-2026-45388](https://github.com/mirleft/ocaml-tls/security/advisories) (TLS 1.3 client missing `keyUsage`/`extendedKeyUsage` validation), decided to get ahead of it.
- `mirage-crypto-rng >= 1.2.0` for `Mirage_crypto_rng_unix.use_default` (the now-deprecated `initialize` is gone in our usage)
- `async_ssl` constrained to the `-2` opam-repository revisions that re-add `-Wno-implicit-function-declaration`. The intermediate `-1` revisions only suppressed `-Wno-incompatible-pointer-types`, which left the build broken on distros where OpenSSL ships without the deprecated `ENGINE_*` API (e.g. centos-10). Fixed upstream in [ocaml/opam-repository#29939](https://github.com/ocaml/opam-repository/pull/29939) and the corresponding source-archives PR. Note: this is broken where `async_ssl` is attempted on systems that have completely removed `openssl/engine.h`. Upstream should probably remove it.
- `core_unix`, `ppx_jane`, `async` floored at `v0.16.0` to match what we actually test against

### Code generation changes

- Parse the new botocore `enum` field on shape members
- Parse the legacy `httpChecksumRequired` operation trait (currently ignored since we don't auto-compute checksums; users still set `?contentMD5` themselves with `Awso.Client.content_md5_insecure` as a helper)

## 0.9.0 (2026-05-17)

Initial opam release, forked from [solvuu/awsm](https://github.com/solvuu/awsm), which was itself never released to opam.

### Architectural changes since the fork

- Replaced the lightweight higher kinded polymorphism with a functorized approach. (End users don't need to instantiate the functors, it's already done in the library)
- Restructured `aws/` into `aws/<service>/{async,lwt,sync}/`, each backend ships only what it needs.
- Eliminated the `Transport` variant from API responses; only AWS-side errors stay in `Result`, transport errors raise, similar to the convention Async follows.
- As advised by opam-repository crew, consolidated the per-service opam packages into sub-libraries under each backend. `opam install awso-async` pulls in every service binding under `awso-async.<svc>`. Same for `-lwt` and `-sync`.
- Pre-generate the `aws/` tree and commit it. opam install no longer runs the codegen, which means end users require ~25 less packages in their dependency cone.

### New stuff

- `awso-sync`: synchronous (blocking) backend implemented over libcurl. For scripts and CLIs where pulling in an async scheduler is overkill
- `awso-cli`: for fun, an everything including the kitchen sink binary that exposes every awso-async service as a composable subcommand, similar in spirit to the python aws-cli. Ships as bytecode because linking ~400 native service libraries exceeds ARM64 executable assembly size limits
- `dogfood/` tools used by maintainers to develop awso

### Compatibility & dep hygiene

- minimum OCaml is 5.0 (4.14 to be available next release!)
- now on dune 3.6
- removed Jane Street `Core` from the non-Async runtimes; non-async builds now use a very small `Jane_compat` shim under `lib/common/`
- replaced ad-hoc JSON with `Yojson.Safe.t` everywhere

### Code generation changes

- Freshened to [botocore 1.43.9](https://github.com/boto/botocore/releases/tag/1.43.9)
- Huge precomputed `endpoints.json` match table replaced with a memoised lookup
- Output shapes treat `required` as advisory. AWS itself routinely omits fields it marks required (`AccessDeniedException` with no `Message`, `GeocodeResponse` with no `PricingBucket`), so deserializers don't blow up when the service lies about its own spec. Input shapes still respect `required`. shim for newer services whose hostname doesn't follow `endpointPrefix` conventions (geo-places, geo-maps, geo-routes, iot-data, sso). snake-case and endpoint name/wire name fixes
- Escape odoc special characters in generated doc comments
- 22 retired AWS services that were dropped from botocore

See [TODO.md](./TODO.md) for things known to still be rough
