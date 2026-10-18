"""Exercise the native bridge against a private fake daemon, never the live one."""

import argparse
import json
import os
from pathlib import Path
import select
import socket
import struct
import subprocess
import tempfile
import unittest


parser = argparse.ArgumentParser()
parser.add_argument("--binary", required=True)
args, remaining = parser.parse_known_args()


class NativeRecovery(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="tether-native-test-")
        self.addCleanup(self.directory.cleanup)
        root = Path(self.directory.name)
        (root / "tether").mkdir(mode=0o700)
        self.listener = socket.socket(socket.AF_UNIX)
        self.addCleanup(self.listener.close)
        self.listener.settimeout(3)
        self.listener.bind(str(root / "tether/tetherd.sock"))
        self.listener.listen(1)
        env = os.environ | {"XDG_RUNTIME_DIR": str(root), "TETHER_NO_AUTOSTART": "1"}
        self.child = subprocess.Popen(
            [args.binary, "--native-host"], env=env,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        self.addCleanup(self.cleanup_child)
        self.connection, _ = self.listener.accept()
        self.addCleanup(self.connection.close)
        self.connection.settimeout(3)
        self.daemon = self.connection.makefile("rb")
        self.addCleanup(self.daemon.close)
        self.assertEqual(json.loads(self.daemon.readline()), {"command": "subscribe"})
        # Prove event forwarding is healthy before exercising disconnects.
        self.connection.sendall(b'{"command":"protocol_info"}\n')
        self.assertEqual(self.receive_browser(), {"command": "protocol_info"})

    def cleanup_child(self):
        if self.child.poll() is None:
            self.child.terminate()
            try:
                self.child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.child.kill()
                self.child.wait(timeout=2)
        for stream in (self.child.stdin, self.child.stdout, self.child.stderr):
            stream.close()

    def read_exact(self, count):
        data = b""
        while len(data) < count:
            self.assertTrue(select.select([self.child.stdout], [], [], 3)[0], "Browser response timed out")
            part = os.read(self.child.stdout.fileno(), count - len(data))
            self.assertTrue(part, "Unexpected native bridge EOF")
            data += part
        return data

    def receive_browser(self):
        size = struct.unpack("=I", self.read_exact(4))[0]
        return json.loads(self.read_exact(size))

    def send_browser(self, message):
        payload = json.dumps(message).encode()
        self.child.stdin.write(struct.pack("=I", len(payload)) + payload)
        self.child.stdin.flush()

    def assert_exits(self):
        try:
            self.child.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.fail("Bridge remained stuck after an endpoint disconnected")
        self.assertEqual(self.child.returncode, 0)

    def test_daemon_disconnect_with_idle_browser(self):
        self.connection.shutdown(socket.SHUT_RDWR)
        self.assert_exits()

    def test_daemon_disconnect_with_partial_browser_header(self):
        self.child.stdin.write(b"\x10\x00")
        self.child.stdin.flush()
        self.connection.shutdown(socket.SHUT_RDWR)
        self.assert_exits()

    def test_daemon_disconnect_with_partial_browser_payload(self):
        self.child.stdin.write(struct.pack("=I", 100) + b"{")
        self.child.stdin.flush()
        self.connection.shutdown(socket.SHUT_RDWR)
        self.assert_exits()

    def test_browser_disconnect_with_idle_daemon(self):
        self.child.stdin.close()
        self.assert_exits()

    def test_fragmented_and_back_to_back_frames(self):
        message = {"command": "protocol_info"}
        payload = json.dumps(message).encode()
        frame = struct.pack("=I", len(payload)) + payload
        for piece in (frame[:2], frame[2:6], frame[6:], frame + frame):
            self.child.stdin.write(piece)
            self.child.stdin.flush()
        for _ in range(3):
            self.assertEqual(json.loads(self.daemon.readline()), message)

    def test_diagnostics_are_not_forwarded_to_daemon(self):
        self.send_browser({"command": "autofill_diagnostic", "event": "filled"})
        self.send_browser({"command": "autofill_diagnostic", "event": "arbitrary untrusted text"})
        self.send_browser({"command": "autofill_diagnostic", "event": 42})
        self.send_browser({"command": "protocol_info"})
        self.assertEqual(json.loads(self.daemon.readline()), {"command": "protocol_info"})


if __name__ == "__main__":
    unittest.main(argv=[__file__, *remaining])
