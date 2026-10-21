# Rocky Multi-Node hub power-cycle and WireGuard recovery

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Guest set: `rc5-r42-rocky-x86-multi-admin`, `...-worker1`, `...-worker2`; all Rocky Linux 10.2 x86_64, candidate Release 42.<br>
Source root: `748b703662eafdaf3919bad28787d0264f06bf16`.<br>
The VMs were isolated libvirt guests. No production systems were involved.

The three previously installed guests were powered off and started from their existing disks. No active app instances were present at the time. On hub startup, `wg-quick@wg-admiral` started successfully, but `/etc/wireguard/wg-admiral.conf` had zero `[Peer]` sections and `wg show wg-admiral peers` returned zero peers. Two root-owned mode-0600 fragments existed under `/etc/wireguard/peers.d/`. The systemd unit had no drop-ins and ran `/usr/bin/wg-quick up wg-admiral`, which loads the main `.conf` file.

The hub log shows `admirald` started at `14:03:59Z` and marked both workers offline at `14:04:31Z`. Both Fleet agents logged repeated request timeouts to `https://10.99.0.1:8080` for task claims and heartbeats. At this point the hub reported both workers `offline/degraded` and unavailable for provisioning. `admiral-fleet` remained active on both workers; no workload or data-loss claim is made because the cluster had no active workload.

Source review confirms the worker installer adds a peer to the hub's live interface with `wg set` and writes a durable fragment (`ansible/roles/admiral_fleet/tasks/main.yml`). The general WireGuard role can collect those fragments into the main configuration when that role runs (`ansible/roles/admiral_wireguard/tasks/main.yml` and `templates/wg-admiral.conf.j2`), but the standard boot unit does not read `peers.d` or render that configuration. The observed boot therefore lacked the peers despite their durable fragments.

For further lab tests, the hub config was manually reconstructed by appending the existing fragments to `wg-admiral.conf` and restarting `wg-quick@wg-admiral`; no source/package files were changed. The config then contained two peer sections, runtime peer count became two, recent handshakes appeared, and by `14:09:31Z` all three nodes were `active/healthy/available`. Explicitly targeted test apps subsequently reached `running/healthy` on both workers and their rootless containers were present. The elapsed time for the manual recovery step was not captured; this workaround is not a product fix.

This is a real guest power-cycle recovery failure for the existing installed configuration, followed by a manual recovery. It supports finding `ADM-F-005`. Reproduction: install a hub and two workers using the supported profile, verify peer fragments and heartbeats, power-cycle the hub guest, then compare peer count in `wg-admiral.conf`, `wg show`, worker heartbeats and node state. The expected regression result is that both peers and fresh heartbeats return without manually editing the hub config.
