# TODO

## fun stuff

### more I/O backends

- eio for sure
- riot?

### mirage

why not?

## botocore fields we silently throw away

### `sensitive`

botocore marks shapes that hold secrets (passwords, tokens, signed stuff)
with `"sensitive": true`.

The right move is redacting these if we would save to disk but not if we're using it in a protocol serializer.

Right now we just ignroe this.

### `deprecated`, `deprecatedMessage`, `deprecatedSince`

We should probably be mensches and emit `[@@ocaml.deprecated "..."]` warnings so users don't rely on things that are going to
be discontinued.

### `box`, `sparse`

### `contextParam`, `staticContextParams`, `operationContextParams`, `clientContextParams`

These feed the endpoint rule set evaluator (see below). ignored, so anything
where the host depends on a request parameter (s3 bucket names, kinesis
stream ids, cloudfront kv store account id) gets the wrong url or falls into
our shim.

### `requestcompression`, `unsignedpayload`, `readonly`, `awsQueryCompatible`

hints about request encoding/dispatch. we ignore. `unsignedPayload` is the
only one that actually matters in practice — s3 streaming uploads need it.

### operation-level `auth`

lists which signing schemes the operation accepts. we ignore and slap a
sigv4 sig on everything. fine for nearly everything, but cognito idp's
InitiateAuth advertises `smithy.api#noAuth` for unauth flows and we send a
sigv4 signature anyway. service doesn't complain but it's wrong.

## Protocols

### `smithy-rpc-v2-cbor`

Cloudwatch, gamelift, compute-optimizer, a few others advertise this as
their primary protocol. We pick the last protocol from `protocols[]` we
support (usually `query` or `json`), which keeps things working but means
we're talking the deprecated wire format.

## endpoints

### endpoint rule-set evaluator

botocore stopped putting newer services in `endpoints.json` and moved the
host mapping into per-service `endpoint-rule-set-1.json`. it's a conditional
tree (region -> partition -> fips/dualstack -> url). we hand-patch a handful
of services in `lib/codegen/botocore_endpoints.ml`
(`endpoint_prefix_shim`) because DNS won't resolve otherwise. proper fix is
a small evaluator for those rule sets and the shim goes away.

## generated code quality

### List/Map `to_header` / `of_string` blow up at runtime

Stubs raise when a list/map shape ends up in an HTTP header or query string.
some AWS APIs do put comma-separated lists in headers (polly's
`x-amzn-LexiconNames`) so calling those today panics.

### exception fields are always optional

## testing

Most services have never been exercised. Confirmed working end-to-end: ec2,
ebs, s3, sqs, route53, route53domains, cloudfront, sts, sso, cognito-idp,
geo-places. Everything else is theoretical. a `dogfood/` smoke test hitting
a cheap read-only operation per service would catch the bulk of regressions.

## awso-cli

Links as `byte_complete` bytecode because ARM64's `bl` displacement
(+/- 128MB) can't reach all 400+ service libs in a native build.

ocamlopt has grown more linker tricks since this was a problem, worth
re-checking whether native links on a modern ocaml without intervention.

## use Base inside of Jane_compat

we tried to cut the dependency cone down a bit by removing Base/Core in the lower-level
stuff, but we actually still need Base for expect tests and other lower level infrastructure.
So, Jane_compat could take advantage of better optimized stuff in Base now.

## unsupported_services blacklist (lib/codegen/cmd.ml)

The history of why most of those services are excluded has been lost.
Worth trying to re-add them and see what actually breaks today.

`license-manager-linux-subscriptions` and `license-manager-user-subscriptions`
are excluded specifically because they fail to build in opam's Windows CI:
the service names are long enough that combined with the opam build prefix
(`D:\a\opam-repository\opam-repository\_opam\.opam-switch\build\...`) and the
`awso_<svc>_<backend>__Values.cmt<rand>.tmp` filenames they emit, paths blow
the Windows 260 chars max path.

I'm going to guess nobody in the OCaml world cares about this and will leave it
alone until informed otherwise.
