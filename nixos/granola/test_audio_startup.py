"""Start the generated WirePlumber configuration against a private PipeWire server."""

import contextlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def stop(process):
    process.terminate()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def check(config_path):
    audio_config = json.loads(Path(config_path).read_text())
    roles = {"unclassified": None, "call": "Communication", "music": "Music", "movie": "Movie"}
    config = {
        "context.properties": {
            "core.daemon": True, "core.name": "granola-test",
            "support.dbus": False, "default.clock.rate": 48000,
        },
        "context.spa-libs": {
            "audio.convert.*": "audioconvert/libspa-audioconvert",
            "support.*": "support/libspa-support",
        },
        "context.modules": [
            {"name": "libpipewire-module-" + name}
            for name in ("protocol-native", "client-node", "metadata", "access", "adapter", "link-factory")
        ] + audio_config["context.modules"],
        "node.rules": audio_config["node.rules"],
        "context.objects": [
            {"factory": "adapter", "args": {
                "factory.name": "support.null-audio-sink",
                "node.name": name,
                "media.name": name,
                "media.class": "Stream/Output/Audio",
                "audio.position": ["FL", "FR"],
                **({"media.role": role} if role else {}),
            }} for name, role in roles.items()
        ],
    }
    with tempfile.TemporaryDirectory(prefix="granola-startup-") as temp:
        root = Path(temp)
        config_dir = root / "config"
        overrides = config_dir / "wireplumber.conf.d"
        overrides.mkdir(parents=True)
        # Keep the real main profile and component loader; disable hardware and
        # D-Bus so the test cannot discover or control the user's devices.
        (overrides / "99-test.conf").write_text("""
wireplumber.profiles = { main = {
  hardware.audio = disabled
  hardware.bluetooth = disabled
  hardware.video-capture = disabled
  support.dbus = disabled
  support.system-dbus = disabled
} }
""")
        env = {
            **os.environ,
            "XDG_RUNTIME_DIR": temp,
            "PIPEWIRE_RUNTIME_DIR": temp,
            "PIPEWIRE_REMOTE": "granola-test",
            "XDG_CONFIG_HOME": str(root / "home-config"),
            "XDG_CONFIG_DIRS": str(root / "system-config"),
            "XDG_DATA_HOME": str(root / "data"),
            "XDG_STATE_HOME": str(root / "state"),
            "WIREPLUMBER_CONFIG_DIR": ":".join([
                str(config_dir),
                *(str(Path(path) / "wireplumber") for path in os.environ["XDG_DATA_DIRS"].split(":")),
            ]),
        }
        server_config = root / "pipewire.conf"
        # PipeWire's context.objects parser requires SPA-style array separators.
        server_config.write_text(json.dumps(config, indent=2).replace(",\n", "\n"))
        with (root / "startup.log").open("w+") as log, contextlib.ExitStack() as cleanup:
            processes = []

            def start(command):
                process = subprocess.Popen(command, env=env, stdout=log, stderr=log)
                processes.append(process)
                cleanup.callback(stop, process)

            def wait_for(predicate):
                deadline = time.monotonic() + 10
                while time.monotonic() < deadline:
                    assert all(p.poll() is None for p in processes), "audio service exited during startup"
                    if predicate():
                        return
                    time.sleep(0.05)
                raise AssertionError("audio startup/routing timed out")

            def routed():
                objects = json.loads(subprocess.check_output(["pw-dump"], env=env, timeout=3))
                nodes = [o["info"]["props"] for o in objects if o["type"].endswith(":Node")]
                expected = {str(p["object.serial"]) for p in nodes if p.get("node.name") in ("unclassified", "call")}
                targets = {
                    str(p.get("target.object")) for p in nodes
                    if p.get("node.name", "").startswith("input.granola_meeting_audio_")
                }
                # session-services.lua runs last, so this also waits for the
                # component loader to finish, beyond the routing script alone.
                ready = any("session.services" in o.get("info", {}).get("props", {}) for o in objects)
                return ready and len(expected) == 2 and targets == expected

            try:
                start(["pipewire", "-c", str(server_config)])
                wait_for(lambda: (root / "granola-test").exists())
                start(["wireplumber"])
                wait_for(routed)
            except BaseException:
                log.seek(0)
                print(log.read(), file=sys.stderr)
                raise
    print("Generated WirePlumber configuration starts; calls/unclassified captured, Music/Movie excluded")


if __name__ == "__main__":
    check(sys.argv[1])
