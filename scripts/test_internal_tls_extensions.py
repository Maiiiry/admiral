#!/usr/bin/env python3
"""Static regression checks for generated internal TLS certificate policy."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TASKS = (ROOT / "ansible/roles/admiral_common/tasks/main.yml").read_text(encoding="utf-8")


def test_internal_ca_has_ca_constraints() -> None:
    assert 'basicConstraints=critical,CA:TRUE,pathlen:1' in TASKS
    assert 'keyUsage=critical,keyCertSign,cRLSign' in TASKS


def test_internal_server_has_tls_usage_constraints() -> None:
    assert 'basicConstraints=critical,CA:FALSE' in TASKS
    assert 'keyUsage=critical,digitalSignature,keyEncipherment' in TASKS
    assert 'extendedKeyUsage=serverAuth,clientAuth' in TASKS
    assert 'subjectKeyIdentifier=hash' in TASKS
    assert 'authorityKeyIdentifier=keyid,issuer' in TASKS


def test_portal_server_extensions_include_key_identifiers() -> None:
    portal_task = TASKS.split(
        "- name: Write portal-node SAN extensions to controller temporary file",
        1,
    )[1].split("\n- name:", 1)[0]

    assert "subjectKeyIdentifier=hash" in portal_task
    assert "authorityKeyIdentifier=keyid,issuer" in portal_task


def test_existing_leaf_verification_checks_trust_and_required_ip_san() -> None:
    verification_task = TASKS.split(
        "- name: Verify an existing admirald leaf against the configured CA",
        1,
    )[1].split("\n- name:", 1)[0]

    assert "- -CAfile" in verification_task
    assert "- -verify_ip" in verification_task
    assert "'127.0.0.1' if admiral_install_mode == 'single-node' else admiral_wireguard_ip" in verification_task
    assert "admiral_tls_leaf_needs_reissue" in TASKS

    reissue_task = TASKS.split(
        "- name: Determine whether the existing leaf must be replaced with a CA-signed certificate",
        1,
    )[1].split("\n- name:", 1)[0]
    csr_task = TASKS.split("- name: Generate admirald CSR with dynamic SAN", 1)[1].split("\n- name:", 1)[0]
    sign_task = TASKS.split("- name: Sign admirald certificate with CA on hub nodes", 1)[1].split("\n- name:", 1)[0]

    assert "admiral_tls_leaf_trust_check.rc != 0" in reissue_task
    assert "admiral_tls_leaf_needs_reissue" in csr_task
    assert "admiral_tls_leaf_needs_reissue" in sign_task


def test_dev_to_single_certificate_reconciliation_has_manual_regression_procedure() -> None:
    guide = (ROOT / "docs/sysadmin_guide.md").read_text(encoding="utf-8")

    assert "dev-node` to `--single-node` certificate" in guide
    assert "openssl verify -CAfile /etc/admiral/tls/ca.pem -verify_ip 127.0.0.1" in guide
