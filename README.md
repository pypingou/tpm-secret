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
./tpm-secret unlock NAME [--ttl SECONDS]   # cache it (auto-starts the agent)
./tpm-secret agent-status                  # see what's cached and for how long
./tpm-secret lock [NAME]                   # clear the cache early
```

The agent only lives in memory for your session - nothing is written to
disk, and everything is gone on logout/reboot.

## Tests

```
./test.sh
```
Runs an integration test against the real TPM using a throwaway storage
directory and socket, so it never touches your real secrets.
