# Changelog

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

- minimum OCaml is 4.14
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
