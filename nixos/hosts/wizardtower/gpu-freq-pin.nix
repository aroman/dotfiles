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
# delegate them, so the pin is a root unit the user may start/stop via polkit
# — no sudo prompt for agents to get stuck on.
let
  # This card's base clock (`nvidia-smi base-clocks`): the frequency NVIDIA
  # rates it to sustain within its power and thermal targets.
  clockMHz = "1470";

  nvidia = config.hardware.nvidia.package.bin;
  unit = "gpu-freq-pin.service";

  # Held by the wrapper for the whole run. It serializes runs — the pin is
  # system-global, so one run finishing would unpin another's — and it's what
  # the unit waits on, so the pin ends when the wrapper does, however it dies.
  lock = "/run/gpu-freq-pin.lock";

  gpu-freq-pin = pkgs.writeShellApplication {
    name = "gpu-freq-pin";
    runtimeInputs = [ pkgs.util-linux config.systemd.package nvidia ];
    text = ''
      if [ $# -eq 0 ]; then
        echo "usage: gpu-freq-pin <command> [args...]" >&2
        exit 2
      fi

      # Already inside a pinned run (a sweep script whose steps also use
      # gpu-freq-pin)? Then the pin is held, and taking the lock again would
      # deadlock. Check that the owning wrapper is actually an ancestor, not
      # just that the variable is set: a background process that outlives
      # the run inherits the variable too.
      inside_pinned_run() {
        local pid=$PPID key val
        while [ "$pid" -gt 1 ]; do
          [ "$pid" = "$GPU_FREQ_PIN_OWNER" ] && return 0
          while read -r key val; do
            [ "$key" = PPid: ] && break
          done < "/proc/$pid/status" || return 1
          pid=$val
        done
        return 1
      }
      if [ -n "''${GPU_FREQ_PIN_OWNER:-}" ] && inside_pinned_run; then
        exec "$@"
      fi

      exec 9<${lock}
      if ! flock -n 9; then
        echo "gpu-freq-pin: waiting for another pinned run to finish" >&2
        flock 9
      fi
      export GPU_FREQ_PIN_OWNER=$$

      # Stopping explicitly (rather than just letting the lock go) makes the
      # unpin finish before we return.
      trap 'systemctl --no-ask-password stop ${unit} || true' EXIT
      # restart, not start: if the previous run was SIGKILLed, systemd may
      # not have reaped its unit yet. A start would then be a no-op, and that
      # unit's late ExecStopPost would unpin us mid-run. restart finishes it
      # off first.
      systemctl --no-ask-password restart ${unit}

      # There's no way to read an active lock back, so give it a moment to
      # land (NVIDIA suggests 200–500 ms) and show what the card is doing.
      sleep 0.5
      echo "gpu-freq-pin: $(nvidia-smi --query-gpu=pstate,clocks.gr,clocks.mem,power.draw --format=csv,noheader)" >&2

      # Don't hand the lock down: a daemon the command leaves behind would
      # otherwise keep the card pinned, and other runs blocked, indefinitely.
      "$@" 9<&-
    '';
  };
in
{
  environment.systemPackages = [ gpu-freq-pin ];
  systemd.tmpfiles.rules = [ "f ${lock} 0600 ${username} - -" ];

  # The main process just waits for the wrapper's lock. The kernel releases it
  # when the wrapper exits or is SIGKILLed, the wait ends, and ExecStopPost
  # unpins — as it also does if the lock step itself failed.
  systemd.services.gpu-freq-pin = {
    description = "Pin NVIDIA graphics clock to ${clockMHz} MHz for profiling";
    # Sweeps may pin/unpin many times in quick succession; don't rate-limit.
    startLimitIntervalSec = 0;
    serviceConfig = {
      ExecStartPre = "${nvidia}/bin/nvidia-smi --lock-gpu-clocks=${clockMHz},${clockMHz}";
      ExecStart = "${pkgs.util-linux}/bin/flock ${lock} true";
      ExecStopPost = "${nvidia}/bin/nvidia-smi --reset-gpu-clocks";
    };
  };

  # Only this unit, only the verbs the wrapper uses, only this user. No
  # subject.local / subject.active check: agents reach this headless box over
  # SSH and tmux.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "${unit}" &&
          (action.lookup("verb") == "restart" || action.lookup("verb") == "stop") &&
          subject.user == "${username}") {
        return polkit.Result.YES;
      }
    });
  '';
}
