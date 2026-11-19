# tpm-secret

Small CLI to seal/unseal secrets (passwords, tokens) using this machine's
TPM 2.0 chip, backed by `tpm2-tools`. Sealed secrets can only be unsealed by
this exact TPM.

## Requirements

- `tpm2-tools` (`tpm2_createprimary`, `tpm2_create`, `tpm2_load`, `tpm2_unseal`)
- Read/write access to `/dev/tpmrm0` - add yourself to the `tss` group:
  ```
  sudo usermod -aG tss "$USER"
  ```
  This takes effect on your next login. To use it immediately without
  logging out, start a new shell with the group active:
  ```
  newgrp tss
  ```

## Usage

```
./tpm-secret insert NAME [--no-pin]   # seal a secret (PIN required by default)
./tpm-secret get NAME                 # unseal and print a secret
./tpm-secret list                     # list stored secrets
./tpm-secret delete NAME [-f]         # delete a secret
```

### Avoiding repeated PIN prompts

`tpm-secret-agent` caches an unsealed secret in memory for a limited time
(default 6h), so you don't retype the PIN on every `get`:

```
./tpm-secret unlock NAME [NAME ...] [--ttl MINUTES]   # cache one or more (auto-starts the agent)
./tpm-secret agent-status [NAME]            # check a count, or a specific secret's status
./tpm-secret lock [NAME]                   # clear the cache early
```

`--ttl` is in minutes (default 360 = 6h), e.g. `--ttl 30` for 30 minutes,
`--ttl 60` for 1h, `--ttl 480` for 8h. Run `./tpm-secret unlock --help` for
more examples.

The agent only lives in memory for your session - nothing is written to
disk, and everything is gone on logout/reboot.

`agent-status` with no name only reports a count and the next expiry, not
which secrets are cached - any process running as you can reach the agent
socket, so a plain, unauthenticated listing of cached names would hand that
same process a ready-made target list of which secrets it can currently
read for free. Check a specific secret with `agent-status NAME` instead.

## Tests

```
./test.sh
```
Runs an integration test against the real TPM using a throwaway storage
directory and socket, so it never touches your real secrets.
