# Local helper scripts

Two small shell helpers written while debugging a GPU problem on an Acer Nitro ANV15-51 and while rebuilding the DAMX daemon by hand. They are **not part of upstream DAMX**. They are tailored to one setup (CachyOS, systemd, LightDM, NVIDIA open kernel modules 620.x, Ollama) and are kept here so they are not lost.

Read them before running: both stop services, and `nvidia-reload` ends the graphical session. The messages the scripts print are in Portuguese.

| Script | Purpose | Needs |
|---|---|---|
| [`nvidia-reload`](nvidia-reload) | Reload the NVIDIA kernel modules to release a GPU stuck in P5 after an AC unplug | root, `lsof`, run from a TTY |
| [`damx-daemon-update`](damx-daemon-update) | Rebuild `DAMX-Daemon` from the repo and swap it into `/opt/damx/daemon`, with backup and rollback | `python3`, network on first run, `sudo` to install |

Install by copying them somewhere on your `PATH` (for example `~/.local/bin`) and running `chmod +x` if needed, or run them from this folder.

## nvidia-reload

Releases a latch seen after unplugging AC while the GPU is under load: after AC returns, the dGPU stays in P5 with the memory clock at 810 MHz and `SW Power Cap: Active`, and normally only a reboot clears it. Background and measurements are in [NVIDIA/open-gpu-kernel-modules#1584](https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1584) and DAMX issue #304.

### When to use it

Only when the GPU is stuck. Check **under load**, because an idle GPU is in P8 whether it is healthy or not:

```
nvidia-smi --query-gpu=pstate,clocks.mem --format=csv,noheader
```

On the RTX 3050 6GB Laptop used here, healthy under load is `P0` and about 5411 MHz. Stuck is `P5` and 810 MHz.

### How to run it

It stops the display manager, so run it from a TTY (`Ctrl+Alt+F3`, on some laptops `Ctrl+Alt+Fn+F3`), not from a terminal inside the desktop. Use the full path, because the PATH of a TTY login may not include `~/.local/bin`:

```
~/.local/bin/nvidia-reload
```

It lists what it will stop and asks you to type `yes`.

| Option | Effect |
|---|---|
| `--dry-run` | Print the steps without running them, and without needing root |
| `--yes` | Skip the confirmation |

### What it does

1. Stops `ollama`, `nvidia-powerd` and `lightdm`.
2. Checks with `lsof` that nothing still holds `/dev/nvidia*`.
3. Unloads `nvidia_uvm nvidia_drm nvidia_modeset nvidia` and loads `nvidia_drm nvidia_uvm` again.
4. Runs `systemctl reset-failed nvidia-powerd`, then starts the three services again.

If something still holds the GPU, or the modules cannot be unloaded, it prints the reason and restores the services instead of continuing.

### Adapting it

Edit the `STOP` list at the top: use `sddm` or `gdm` instead of `lightdm`, drop `ollama` if you do not run it, and add any other service that uses CUDA.

### Status

The script itself has only been run with `--dry-run`. The same sequence done by hand cleared the latch once (43 tok/s with P0 and 5411 MHz, against 6 tok/s before). That is one measurement, not a series.

## damx-daemon-update

Rebuilds `DAMX-Daemon` from the checked-out repo and installs it over `/opt/damx/daemon/DAMX-Daemon`.

```
damx-daemon-update              # build and install (asks for the sudo password)
damx-daemon-update --build-only # build and smoke-test only, nothing under /opt is touched
damx-daemon-update --dry-run    # print the steps
```

### What it does

- **Builds the branch that is checked out.** It prints the commit it is building and adds `+dirty` if `DAMM-Daemon` has uncommitted changes, so check out the branch you want installed first.
- **Builds in a temp directory** with PyInstaller from a venv in `~/.cache/damx-build-venv` (created on the first run, which needs network). The tracked `DAMX-Daemon.spec` and the repo are left untouched.
- **Smoke test.** Without root the daemon refuses to start before it reads its arguments. Reaching that message, or printing the version, is taken as proof that the bundle imports and runs. It does not prove the daemon works end to end.
- **Installs with a backup.** Copies the current binary to `DAMX-Daemon.bak.<timestamp>`, stops the service, installs the new binary and starts the service. It waits up to 10 s for the service to be active and `/var/run/DAMX.sock` to exist. If not, it restores the backup.
- **Records what is installed** in `/opt/damx/daemon/BUILD_INFO` (commit and time) and keeps only the 3 newest backups.

The repo path defaults to `~/Div-Acer-Manager-Max`; set `DAMX_REPO` to use another one.

### Checking and reverting

```
cat /opt/damx/daemon/BUILD_INFO
sudo cp -p /opt/damx/daemon/DAMX-Daemon.bak.<timestamp> /opt/damx/daemon/DAMX-Daemon && sudo systemctl restart damx-daemon.service
```

To check that a daemon change took effect, look at the service log, for example `journalctl -u damx-daemon.service`. For the AC profile-restore fix: set `balanced-performance`, unplug AC for a few seconds, plug it back, and look for `Restoring balanced-performance profile after battery power`.

### Status

When this README was written, `--dry-run` and `--build-only` had been run and passed. The install step and the automatic rollback had not been exercised.

## scratch/

`teste.sh` and `teste.log` are the manual run (stop services, `lsof`, `modprobe -rv`) that `nvidia-reload` automates, and its output. They are kept as a record and are not meant to be run as-is.
