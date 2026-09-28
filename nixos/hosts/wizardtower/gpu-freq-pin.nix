{ config, pkgs, username, ... }:

# `gpu-freq-pin <cmd> [args...]` — run a GPU profiling job with the RTX 2060
# SUPER's graphics clock pinned, then unpin it.
#
# GPU timer queries on light, bursty work (Rive/Pixi in headless Chrome) come
# out bimodal because the card drops to P8 (300 MHz) between bursts — ~3 ms vs
# ~6 ms for the same frame. Pinning min=max sets a floor as well as a ceiling.
# Pin per run, not permanently, as profilers do (Nsight, ANGLE's perf runner):
# a permanent pin costs idle watts and the card's zero-RPM fan stop.
#
# Only the graphics clock can be pinned: `nvidia-smi -lmc` is Ampere+ only, so
# memory still follows the P-state. Clock locks need root and NVML can't
# delegate them, so the pin is a root unit the user may restart via polkit —
# no sudo prompt for agents to get stuck on.
#
# A run is the command and everything it starts, and the pin lasts exactly as
# long as any of that is still running. The run goes in its own cgroup (a
# scope in a dedicated slice of the user's systemd manager), which nothing it
# starts leaves by closing fds, forking, or detaching, and the unit unpins
# once that cgroup is empty. The one way out is asking systemd for a new unit
# (`systemd-run --user --scope` inside a run; windowed Chrome does it for XDG
# portals, but headless Chrome was checked to stay put, children included):
# such a process is no longer part of the run.
#
# Nothing here supervises the command: it's exec'd, and signals, Ctrl-C,
# timeout(1) and exit status behave exactly as if gpu-freq-pin weren't there.
# The flip side: anything a run leaves running in the background keeps the
# card pinned and makes the next run wait; `systemctl --user status
# gpufreqpin.slice` shows what.
let
  # This card's base clock (`nvidia-smi base-clocks`): the frequency NVIDIA
  # rates it to sustain within its power and thermal targets.
  clockMHz = "1470";

  # The booted system's nvidia-smi, not this configuration's: it's the one
  # that matches the loaded kernel module. After a switch that updates the
  # driver, the new nvidia-smi fails with a driver/library version mismatch
  # until reboot, so it could neither pin nor unpin.
  smi = "/run/booted-system/sw/bin/nvidia-smi";
  unit = "gpu-freq-pin.service";

  # Where every run's processes live. No dashes: in a slice name they mean
  # nesting.
  slice = "gpufreqpin.slice";

  # Serializes starting runs: taken before checking the slice is empty, and
  # held until this run's scope exists, so two runs can't both see it empty.
  lock = "/run/gpu-freq-pin.lock";

  # The first thing to run inside the new scope, so the pin can't outlive a
  # run that dies before its command even starts.
  pin-and-exec = pkgs.writeShellApplication {
    name = "gpu-freq-pin-in-scope";
    runtimeInputs = [ config.systemd.package ];
    text = ''
      # restart, not start: a start would be a no-op if the previous run's
      # unit were somehow still up, and its late ExecStopPost would then unpin
      # us mid-run.
      systemctl --no-ask-password restart ${unit}

      # There's no way to read an active lock back, so give it a moment to
      # land (NVIDIA suggests 200–500 ms) and show what the card is doing.
      sleep 0.5
      echo "gpu-freq-pin: $(${smi} --query-gpu=pstate,clocks.gr,clocks.mem,power.draw --format=csv,noheader)" >&2

      # Our scope exists now, so the lock has done its job; don't hand it on.
      exec "$@" 9<&-
    '';
  };

  gpu-freq-pin = pkgs.writeShellApplication {
    name = "gpu-freq-pin";
    runtimeInputs = [ pkgs.util-linux pkgs.gnugrep config.systemd.package ];
    text = ''
      if [ $# -eq 0 ]; then
        echo "usage: gpu-freq-pin <command> [args...]" >&2
        exit 2
      fi

      # Already inside a pinned run (a sweep whose steps also use
      # gpu-freq-pin)? Then the card is pinned, and waiting for the run to
      # finish would deadlock.
      if grep -qF '/${slice}/' /proc/self/cgroup; then
        exec "$@"
      fi

      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$UID}"
      events="/sys/fs/cgroup/user.slice/user-$UID.slice/user@$UID.service/${slice}/cgroup.events"
      waiting=
      say_waiting() {
        [ -n "$waiting" ] || echo "gpu-freq-pin: waiting for another pinned run to finish (systemctl --user status ${slice} shows what)" >&2
        waiting=1
      }

      exec 9<${lock}
      flock -n 9 || { say_waiting; flock 9; }
      # Wait out the previous run — everything it started, not just its
      # command — and then its unpin, so that a failed reset is reported here
      # rather than wiped by our restart.
      while grep -qsx 'populated 1' "$events"; do say_waiting; sleep 0.2; done
      while case "$(systemctl show -P ActiveState ${unit})" in
              activating|active|reloading|deactivating) true ;; *) false ;;
            esac; do
        sleep 0.1
      done
      if systemctl is-failed --quiet ${unit}; then
        echo "gpu-freq-pin: warning: resetting clocks after the last run failed (journalctl -u ${unit})" >&2
      fi

      # --expand-environment=no: systemd-run otherwise expands $VAR in the
      # command line itself, mangling `bash -c '...$x...'` sweeps.
      exec systemd-run --user --scope --slice=${slice} --collect --quiet \
        --expand-environment=no -- \
        ${pin-and-exec}/bin/gpu-freq-pin-in-scope "$@"
    '';
  };
in
{
  environment.systemPackages = [ gpu-freq-pin ];
  systemd.tmpfiles.rules = [ "f ${lock} 0600 ${username} - -" ];

  # The main process waits until every process in the run's slice has exited
  # — however they end, even SIGKILLed — and ExecStopPost then unpins, as it
  # also does if the lock step itself failed. Polled: cgroup.events can be
  # watched with inotify, but 200 ms of extra pin doesn't matter here.
  systemd.services.gpu-freq-pin = {
    description = "Pin NVIDIA graphics clock to ${clockMHz} MHz for profiling";
    # Sweeps may pin/unpin many times in quick succession; don't rate-limit.
    startLimitIntervalSec = 0;
    # A `nixos-rebuild switch` that touches this unit would otherwise stop it
    # mid-run and unpin under the workload. The next run's restart picks up
    # the new definition.
    restartIfChanged = false;
    path = [ pkgs.coreutils pkgs.gnugrep ];
    script = ''
      uid=$(id -u ${username})
      # Missing once systemd has cleaned up the empty slice: also done.
      events="/sys/fs/cgroup/user.slice/user-$uid.slice/user@$uid.service/${slice}/cgroup.events"
      while grep -qsx 'populated 1' "$events"; do sleep 0.2; done
    '';
    serviceConfig = {
      ExecStartPre = "${smi} --lock-gpu-clocks=${clockMHz},${clockMHz}";
      ExecStopPost = "${smi} --reset-gpu-clocks";
    };
  };

  # Only this unit, only restart, only this user. No subject.local /
  # subject.active check: agents reach this headless box over SSH and tmux.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "${unit}" &&
          action.lookup("verb") == "restart" &&
          subject.user == "${username}") {
        return polkit.Result.YES;
      }
    });
  '';
}
