# Production configuration placeholder probe

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Source: `748b703662eafdaf3919bad28787d0264f06bf16`.<br>
Classification: focused config-parser execution; not a full process/database deployment.

## Procedure and result

A temporary test in package `admirald/internal/config` ran the production `load(path)` function against a temporary INI containing valid required database URLs, admin token, token pepper and readable temporary TLS files, while retaining the shipped literal `__REQUIRED__` value for `secrets_key`, `fleet_callback_key`, `signing_key`, `task_encryption_key`, `session_hmac_key`, `harbor_api_token`, and Flagship credentials. It asserted that `load` returned no error and that `SecretsKey` and `FleetCallbackKey` still contained `__REQUIRED__`.

Command:

```bash
cd admirald
GOMAXPROCS=1 go test -p 1 ./internal/config -run '^TestAuditRequiredSecretPlaceholdersAreAccepted$' -v
```

Observed output:

```text
=== RUN   TestAuditRequiredSecretPlaceholdersAreAccepted
    audit_placeholder_tmp_test.go:45: production config load accepted placeholder secrets_key and fleet_callback_key
--- PASS: TestAuditRequiredSecretPlaceholdersAreAccepted (0.00s)
PASS
```

The temporary test source was removed after execution; no product source or test file was changed. This proves config parsing accepts those security-sensitive placeholders, but it does not start an `admirald` process or test cryptographic attacks. Static call-path review confirms `SecretsKey` feeds `secrets.NewManagerWithKeys`, while `FleetCallbackKey` is used as the HMAC key for authenticated Fleet callbacks. The parser rejects the placeholder for six keys but validates only emptiness for these two, so the literal is accepted in production configuration. See issue [#212](https://github.com/admiral-project/admiral/issues/212).

## Reproduction test source

Create `admirald/internal/config/audit_placeholder_tmp_test.go` with the following temporary test, run the command above, then remove the temporary file:

```go
package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestAuditRequiredSecretPlaceholdersAreAccepted(t *testing.T) {
	t.Setenv("ADMIRAL_ENV", "production")
	dir := t.TempDir()
	cert := filepath.Join(dir, "server.crt")
	key := filepath.Join(dir, "server.key")
	if err := os.WriteFile(cert, []byte("test-cert"), 0600); err != nil { t.Fatal(err) }
	if err := os.WriteFile(key, []byte("test-key"), 0600); err != nil { t.Fatal(err) }
	ini := "database_url=postgres://user:pass@127.0.0.1/admiral\n" +
		"queue_database_url=postgres://user:pass@127.0.0.1/admiral_queue\n" +
		"admin_token=test-admin-token\n" +
		"token_pepper=test-token-pepper\n" +
		"secrets_key=__REQUIRED__\n" +
		"fleet_callback_key=__REQUIRED__\n" +
		"signing_key=__REQUIRED__\n" +
		"task_encryption_key=__REQUIRED__\n" +
		"session_hmac_key=__REQUIRED__\n" +
		"harbor_api_token=__REQUIRED__\n" +
		"flagship_admin_user=__REQUIRED__\n" +
		"flagship_admin_pswd=__REQUIRED__\n" +
		"tls_cert_file=" + cert + "\n" +
		"tls_key_file=" + key + "\n"
	path := filepath.Join(dir, "admirald.ini")
	if err := os.WriteFile(path, []byte(ini), 0600); err != nil { t.Fatal(err) }
	cfg, err := load(path)
	if err != nil { t.Fatalf("configuration rejected placeholder unexpectedly: %v", err) }
	if cfg.SecretsKey != "__REQUIRED__" || cfg.FleetCallbackKey != "__REQUIRED__" {
		t.Fatal("expected the two security-sensitive placeholders to survive config loading")
	}
	t.Log("production config load accepted placeholder secrets_key and fleet_callback_key")
}
```
