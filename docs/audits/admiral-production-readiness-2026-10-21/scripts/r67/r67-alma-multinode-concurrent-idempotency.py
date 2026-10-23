#!/usr/bin/env python3
"""Run concurrent same-key provision retries on the isolated R67 AlmaLinux lab."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import shlex
import subprocess
import sys
import time
from datetime import datetime, timezone

os.umask(0o077)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def write(path: pathlib.Path, data: str) -> None:
    path.write_text(data, encoding="utf-8")
    path.chmod(0o600)


def parse_json(path: pathlib.Path) -> object:
    text = path.read_text(encoding="utf-8")
    start = text.find("{")
    if start < 0:
        raise RuntimeError(f"no JSON object in {path.name}: {text[:200]!r}")
    value, _ = json.JSONDecoder().raw_decode(text[start:])
    return value


def run_ssh(
    base: list[str], remote: str, *, input_text: str | None = None, timeout: int = 60
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [*base, remote],
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )


def checked_ssh(
    base: list[str], remote: str, output: pathlib.Path, *, input_text: str | None = None
) -> str:
    result = run_ssh(base, remote, input_text=input_text)
    write(output, result.stdout)
    write(output.with_suffix(output.suffix + ".stderr"), result.stderr)
    if result.returncode:
        raise RuntimeError(f"remote command failed ({result.returncode}): {output.name}")
    return result.stdout


def list_instance_ids(base: list[str], customer: str, output: pathlib.Path) -> list[str]:
    remote = shlex.join(
        [
            "sudo",
            "-u",
            "validator",
            "env",
            "HOME=/home/validator",
            "admiralctl",
            "instances",
            "list",
            "--customer",
            customer,
            "--output",
            "json",
        ]
    )
    result = run_ssh(base, remote)
    write(output, result.stdout)
    write(output.with_suffix(output.suffix + ".stderr"), result.stderr)
    if result.returncode:
        return []
    try:
        rows = json.loads(result.stdout)
    except ValueError:
        return []
    if isinstance(rows, dict):
        rows = rows.get("instances", [])
    return [str(row["id"]) for row in rows if isinstance(row, dict) and row.get("id")]


def deprovision(base: list[str], instance_id: str, output: pathlib.Path) -> bool:
    remote = shlex.join(
        [
            "sudo",
            "-u",
            "validator",
            "env",
            "HOME=/home/validator",
            "admiralctl",
            "instances",
            "deprovision",
            instance_id,
            "--force",
            "--wait",
            "--wait-timeout",
            "10m",
            "--output",
            "json",
        ]
    )
    result = run_ssh(base, remote, timeout=620)
    write(output, result.stdout)
    write(output.with_suffix(output.suffix + ".stderr"), result.stderr)
    if result.returncode:
        return False
    try:
        return parse_json(output).get("status") == "succeeded"  # type: ignore[union-attr]
    except (RuntimeError, AttributeError):
        return False


def remote_inventory(base: list[str], instance_id: str, output: pathlib.Path) -> tuple[int, str]:
    remote = shlex.join(["sudo", "bash", "-s", "--", instance_id])
    script = r'''set -euo pipefail
instance_id=$1
uid=$(id -u admiral-apps)
run_as_apps() { runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"; }
containers=$(run_as_apps ps -a --filter "name=$instance_id" --format '{{.Names}}' | grep -F "$instance_id" || true)
pods=$(run_as_apps pod ps --format '{{.Name}}' | grep -F "$instance_id" || true)
volumes=$(run_as_apps volume ls --format '{{.Name}}' | grep -F "$instance_id" || true)
app_endpoint=$(run_as_apps port "admiral-${instance_id}-app" 80/tcp 2>/dev/null | head -n1 || true)
if [[ -n $containers ]]; then
  while IFS= read -r name; do printf 'container=%s\n' "$name"; done <<<"$containers"
else
  printf 'container=none\n'
fi
printf 'pods=%s\nvolumes=%s\napp_endpoint=%s\n' "${pods:-none}" "${volumes:-none}" "${app_endpoint:-none}"
'''
    result = run_ssh(base, remote, input_text=script)
    write(output, result.stdout)
    write(output.with_suffix(output.suffix + ".stderr"), result.stderr)
    count = sum(1 for line in result.stdout.splitlines() if line.startswith("container=admiral-"))
    return count, result.stdout


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ssh-key", required=True)
    parser.add_argument("--hub-known-hosts", required=True)
    parser.add_argument("--w1-known-hosts", required=True)
    parser.add_argument("--w2-known-hosts", required=True)
    parser.add_argument("--hub-ip", default="192.168.122.187")
    parser.add_argument("--w1-ip", default="192.168.122.188")
    parser.add_argument("--w2-ip", default="192.168.122.189")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    output = pathlib.Path(args.output)
    if not output.is_absolute() or output.exists():
        parser.error("--output must be an unused absolute path")
    output.mkdir(mode=0o700, parents=True)
    key = pathlib.Path(args.ssh_key)
    if not key.is_file():
        parser.error("SSH key is not a regular file")

    common = [
        "ssh",
        "-i",
        str(key),
        "-o",
        "IdentitiesOnly=yes",
        "-o",
        "BatchMode=yes",
        "-o",
        "StrictHostKeyChecking=yes",
    ]
    hub = [*common, "-o", f"UserKnownHostsFile={args.hub_known_hosts}", f"validator@{args.hub_ip}"]
    w1 = [*common, "-o", f"UserKnownHostsFile={args.w1_known_hosts}", f"validator@{args.w1_ip}"]
    w2 = [*common, "-o", f"UserKnownHostsFile={args.w2_known_hosts}", f"validator@{args.w2_ip}"]
    suffix = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + f"-{os.getpid()}"
    customer = f"r67-alma-idempotency-{suffix}"
    idem_key = f"r67-alma-idempotency-{suffix}"
    remote_dir = f"/var/tmp/adm-r67-alma-idempotency-{suffix}"
    release = f"{remote_dir}/release"
    fixture = pathlib.Path(__file__).resolve().parents[5] / "examples/apps/e2e-whoami.yaml"
    if not fixture.is_file():
        parser.error(f"fixture not found: {fixture}")

    metadata = {
        "test_id": "R67-ALMA-MN-CONCURRENT-IDEMPOTENCY",
        "candidate": "0.0.1rc5-67.el10",
        "source_commit": "833d15aa4f8e96be30d28dad169b9d06a4d9894d",
        "customer": customer,
        "idempotency_key": idem_key,
        "started_utc": utc_now(),
        "hub_ip": args.hub_ip,
        "workers": {"adm-r67-alma-mn-w1": args.w1_ip, "adm-r67-alma-mn-w2": args.w2_ip},
    }
    write(output / "metadata.json", json.dumps(metadata, indent=2) + "\n")

    procs: list[tuple[subprocess.Popen[bytes], object, object]] = []
    completed_ids: set[str] = set()
    success = False
    cleanup_done = False
    try:
        packages = [
            "admiral-common",
            "admirald",
            "admiralctl",
            "admiral-fleet",
            "admiral-harbor",
            "admiral-flagship",
        ]
        hub_q = shlex.join(["rpm", "-q", "--qf", "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n", *packages])
        checked_ssh(hub, hub_q, output / "hub-nevra.txt")
        for role, base in (("w1", w1), ("w2", w2)):
            checked_ssh(
                base,
                "rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' admiral-common admiral-fleet",
                output / f"{role}-nevra.txt",
            )
        for path in (output / "hub-nevra.txt", output / "w1-nevra.txt", output / "w2-nevra.txt"):
            lines = path.read_text(encoding="utf-8").splitlines()
            if not lines or any("0.0.1rc5-67.el10" not in line for line in lines):
                raise RuntimeError(f"non-R67 or non-EL10 package found in {path.name}")

        checked_ssh(hub, f"mkdir -m 0700 {shlex.quote(remote_dir)}", output / "remote-mkdir.txt")
        scp = [
            "scp",
            "-i",
            str(key),
            "-o",
            "IdentitiesOnly=yes",
            "-o",
            "BatchMode=yes",
            "-o",
            "StrictHostKeyChecking=yes",
            "-o",
            f"UserKnownHostsFile={args.hub_known_hosts}",
            str(fixture),
            f"validator@{args.hub_ip}:{remote_dir}/e2e-whoami.yaml",
        ]
        transfer = subprocess.run(scp, text=True, capture_output=True, check=False)
        write(output / "fixture-copy.stdout", transfer.stdout)
        write(output / "fixture-copy.stderr", transfer.stderr)
        if transfer.returncode:
            raise RuntimeError("fixture copy to hub failed")
        checked_ssh(
            hub,
            shlex.join(
                [
                    "sudo",
                    "-u",
                    "validator",
                    "env",
                    "HOME=/home/validator",
                    "admiralctl",
                    "apps",
                    "apply",
                    "--file",
                    f"{remote_dir}/e2e-whoami.yaml",
                ]
            ),
            output / "app-apply.json",
        )

        ready = [f"{remote_dir}/ready-{n}" for n in range(1, 4)]
        remote_provision = shlex.join(
            [
                "sudo",
                "-u",
                "validator",
                "env",
                "HOME=/home/validator",
                "admiralctl",
                "instances",
                "provision",
                "--app",
                "e2e-whoami",
                "--tier",
                "small",
                "--customer",
                customer,
                "--idempotency-key",
                idem_key,
                "--wait",
                "--wait-timeout",
                "10m",
                "--quiet",
                "--output",
                "json",
            ]
        )
        for n in range(1, 4):
            request_path = output / f"request-{n}.json"
            stderr_path = output / f"request-{n}.stderr"
            stdout_file = request_path.open("w", encoding="utf-8")
            stderr_file = stderr_path.open("w", encoding="utf-8")
            remote = f"touch {shlex.quote(ready[n-1])}; while [ ! -e {shlex.quote(release)} ]; do sleep 0.01; done; exec {remote_provision}"
            proc = subprocess.Popen(hub + [remote], text=True, stdout=stdout_file, stderr=stderr_file)
            procs.append((proc, stdout_file, stderr_file))
            metadata[f"request_{n}_ssh_started_utc"] = utc_now()
        write(output / "metadata.json", json.dumps(metadata, indent=2) + "\n")

        ready_deadline = time.monotonic() + 45
        while time.monotonic() < ready_deadline:
            result = run_ssh(hub, "for f in " + " ".join(map(shlex.quote, ready)) + "; do test -f \"$f\" || exit 1; done")
            if result.returncode == 0:
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("all three provision clients did not reach the remote barrier")
        checked_ssh(hub, f"touch {shlex.quote(release)}", output / "barrier-release.txt")
        for proc, stdout_file, stderr_file in procs:
            try:
                rc = proc.wait(timeout=620)
            finally:
                stdout_file.close()
                stderr_file.close()
            if rc != 0:
                raise RuntimeError(f"a concurrent provision CLI exited {rc}")

        rows = []
        for n in range(1, 4):
            response = parse_json(output / f"request-{n}.json")
            if not isinstance(response, dict):
                raise RuntimeError(f"request {n} response is not an object")
            row = {
                "operation_id": response.get("id") or response.get("operation_id"),
                "instance_id": response.get("instance_id"),
                "task_id": response.get("task_id"),
                "node_id": response.get("node_id"),
                "status": response.get("status"),
            }
            rows.append(row)
            if row["instance_id"]:
                completed_ids.add(str(row["instance_id"]))
        write(output / "response-summary.json", json.dumps(rows, indent=2) + "\n")
        if any(row["status"] != "succeeded" for row in rows):
            raise RuntimeError("at least one concurrent request did not succeed")
        for field in ("operation_id", "instance_id", "task_id", "node_id"):
            if len({row[field] for row in rows}) != 1 or not rows[0][field]:
                raise RuntimeError(f"concurrent replay responses diverged on {field}")
        instance_id = str(rows[0]["instance_id"])
        node_id = str(rows[0]["node_id"])
        if not instance_id.startswith("inst_") or node_id not in ("adm-r67-alma-mn-w1", "adm-r67-alma-mn-w2"):
            raise RuntimeError("unexpected instance ID or worker assignment")
        ids = list_instance_ids(hub, customer, output / "customer-instances.json")
        if ids != [instance_id]:
            completed_ids.update(ids)
            raise RuntimeError(f"customer has duplicate or unexpected instances: {ids}")

        healthy = False
        for poll in range(1, 61):
            show_remote = shlex.join(
                [
                    "sudo",
                    "-u",
                    "validator",
                    "env",
                    "HOME=/home/validator",
                    "admiralctl",
                    "instances",
                    "show",
                    instance_id,
                ]
            )
            state = run_ssh(hub, show_remote)
            state_path = output / f"health-poll-{poll:02d}.json"
            write(state_path, state.stdout)
            write(state_path.with_suffix(state_path.suffix + ".stderr"), state.stderr)
            if state.returncode == 0:
                try:
                    current = parse_json(state_path)
                    healthy = (
                        current.get("technical_status") == "running"
                        and current.get("health_status") == "healthy"
                        and current.get("effective_availability") == "available"
                    )
                except (RuntimeError, AttributeError):
                    healthy = False
            if healthy:
                break
            time.sleep(3)
        if not healthy:
            raise RuntimeError("instance did not converge to running/healthy/available within 180 seconds")

        worker_data = {
            "adm-r67-alma-mn-w1": (w1, args.w1_ip),
            "adm-r67-alma-mn-w2": (w2, args.w2_ip),
        }
        for worker_id, (base, _ip) in worker_data.items():
            count, inventory = remote_inventory(base, instance_id, output / f"{worker_id}-runtime-before-cleanup.txt")
            expected = 3 if worker_id == node_id else 0
            if count != expected:
                raise RuntimeError(f"{worker_id} has {count} instance containers; expected {expected}: {inventory}")
        assigned_inventory = (output / f"{node_id}-runtime-before-cleanup.txt").read_text(encoding="utf-8")
        endpoint_line = next((line for line in assigned_inventory.splitlines() if line.startswith("app_endpoint=")), "")
        endpoint = endpoint_line.removeprefix("app_endpoint=")
        if not endpoint or endpoint == "none" or ":" not in endpoint:
            raise RuntimeError(f"could not obtain workload endpoint from {node_id}")
        workload_url = f"http://{endpoint}/"
        http_cmd = shlex.join(
            ["curl", "--connect-timeout", "3", "--max-time", "10", "-fsS", "-o", "/dev/null", "-w", "%{http_code}", workload_url]
        )
        http = checked_ssh(hub, http_cmd, output / "workload-http.txt").strip()
        if http != "200":
            raise RuntimeError(f"workload endpoint returned HTTP {http!r}")

        if not deprovision(hub, instance_id, output / "deprovision.json"):
            raise RuntimeError("deprovision did not succeed")
        for worker_id, (base, _ip) in worker_data.items():
            count, inventory = remote_inventory(base, instance_id, output / f"{worker_id}-runtime-after-cleanup.txt")
            if count:
                raise RuntimeError(f"residual containers on {worker_id}: {inventory}")
        cleanup_done = True
        metadata.update({
            "instance_id": instance_id,
            "operation_id": rows[0]["operation_id"],
            "task_id": rows[0]["task_id"],
            "node_id": node_id,
            "workload_http": http,
            "finished_utc": utc_now(),
            "result": "PASS",
        })
        write(output / "metadata.json", json.dumps(metadata, indent=2) + "\n")
        print(f"result=PASS instance={instance_id} assigned_node={node_id}")
        success = True
    except Exception as exc:  # preserve the failure and still attempt cleanup
        metadata.update({"finished_utc": utc_now(), "result": "FAIL", "failure": str(exc)})
        write(output / "metadata.json", json.dumps(metadata, indent=2) + "\n")
        print(f"result=FAIL reason={exc}", file=sys.stderr)
    finally:
        for proc, stdout_file, stderr_file in procs:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
            if not stdout_file.closed:
                stdout_file.close()
            if not stderr_file.closed:
                stderr_file.close()
        if not cleanup_done:
            completed_ids.update(list_instance_ids(hub, customer, output / "cleanup-customer-instances.json"))
            for candidate in sorted(completed_ids):
                deprovision(hub, candidate, output / f"cleanup-{candidate}.json")
        run_ssh(hub, f"touch {shlex.quote(release)}")
        run_ssh(hub, f"rm -rf -- {shlex.quote(remote_dir)}")
        files = sorted(p for p in output.rglob("*") if p.is_file() and p.name != "SHA256SUMS")
        for path in files:
            path.chmod(0o600)
        manifest = "".join(
            f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(output).as_posix()}\n"
            for path in files
        )
        write(output / "SHA256SUMS", manifest)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
