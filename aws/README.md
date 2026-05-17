# aws/ — generated service bindings

Every directory here is generated from botocore JSON by `awso-codegen`.
**Do not edit any file in this tree by hand** — your edits will be wiped
out the next time someone runs:

```
make generate-code
```

Each `aws/<service>/` contains:

| Subdir | Contents | Library name |
|---|---|---|
| (root) | shared types / values / endpoints | `awso.<service>` |
| `async/` | Async I/O bindings, the `Cli` module | `awso-async.<service>` |
| `lwt/` | Lwt I/O bindings | `awso-lwt.<service>` |

A handful of services (`s3`, `ec2`, `cognito-idp`, `sqs`, `sso`, `glue`,
`sts`, `cognito-identity`) also have hand-written addendum files alongside
the generated code — see `lib/codegen/dune.ml`'s `has_addendum` for the
authoritative list. Those addendum files survive regeneration; everything
else is regenerated wholesale.

If something in here looks wrong, the fix lives in the generator at
`lib/codegen/`, not here. After fixing the generator, regenerate and
commit both the generator change and the resulting `aws/` diff.

The reason this tree is committed to git instead of being produced at
install time is explained in the [top-level README](../README.md#why-is-the-aws-tree-committed-to-git).
