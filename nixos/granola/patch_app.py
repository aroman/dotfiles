#!/usr/bin/env python3
"""Patches that let Granola's macOS payload run on Linux.

Operates on app.asar extracted to a plain directory, which Electron loads in
its place. Split-identity design from
https://github.com/bindusara-reddy/granola-linux-macos (MIT): Electron's
native side keeps seeing Linux (so Granola picks its browser/MediaDevices
capture path and a filtered PipeWire source for meeting audio), while only the
renderer's product identity and the platform label sent to api.granola.ai
claim macOS. The API 500s on platform=linux, which breaks sign-in.

Markers are regexes with the minifier's identifiers as capture groups, since
Granola's bundler renames them every release. Every patch must match exactly
once or the build fails: an unrecognised bundle must never ship half-patched.
"""

import argparse
import re
from pathlib import Path
from typing import Callable

# A minified JS identifier.
ID = r"[A-Za-z_$][\w$]*"


class Bundle:
    def __init__(self, root: Path):
        self.root = root

    def read(self, path: str) -> str:
        return (self.root / path).read_text(encoding="utf-8")

    def find(self, pattern: str) -> str:
        """The one JS file under dist-app/ that matches `pattern`."""
        found = [
            str(p.relative_to(self.root))
            for p in sorted((self.root / "dist-app").rglob("*.js"))
            if re.search(pattern, p.read_text(encoding="utf-8"))
        ]
        if len(found) != 1:
            raise SystemExit(f"error: expected one file matching {pattern!r}, found {found}")
        return found[0]

    def names(self, path: str, pattern: str, what: str) -> tuple[str, ...]:
        """The groups of the single match of `pattern`: minified names to call."""
        found = list(re.finditer(pattern, self.read(path)))
        if len(found) != 1:
            raise SystemExit(f"error: expected one {what} in {path}, found {len(found)}")
        return found[0].groups()

    def name(self, path: str, pattern: str, what: str) -> str:
        """Group 1 of the single match of `pattern`: a minified name to call."""
        return self.names(path, pattern, what)[0]

    def require(self, path: str, needle: str, why: str) -> None:
        if needle not in self.read(path):
            raise SystemExit(f"error: {path} lacks {needle!r}: {why}")

    def patch(self, path: str, pattern: str, replace: str | Callable[[re.Match[str]], str], *, label: str) -> None:
        patched, count = re.subn(pattern, replace, self.read(path))
        if count != 1:
            raise SystemExit(
                f"error: {label}: expected 1 match in {path}, found {count}. "
                "Granola's bundle changed; update the pattern."
            )
        (self.root / path).write_text(patched, encoding="utf-8")
        print(f"patched: {label} ({path})")


# Read by the noctalia plugin in noctalia-plugin/ (service.luau). Plain data
# with epoch-ms times (Luau has no date parser); `pid` lets the plugin tell
# that Granola is still running, and `id` keys dismissals. title:null means
# nothing is coming up or the menu-bar toggle is off. Uses no minified names,
# so it can't silently break on a bump; the join link `j` is resolved by the
# caller (see "next meeting file").
NEXT_MEETING_WRITER = r"""function granolaLinuxNextMeeting(n,e,j){try{
let f=require(`node:fs`),p=require(`node:path`),
d=p.join(process.env.XDG_RUNTIME_DIR||require(`node:os`).tmpdir(),`granola`),o=p.join(d,`next-meeting.json`);
f.mkdirSync(d,{recursive:!0});
f.writeFileSync(o+`.tmp`,JSON.stringify(n?{id:n.id??null,title:n.summary||`Meeting`,startMs:Date.parse(n.start?.dateTime)||null,endMs:Date.parse(n.end?.dateTime)||null,joinURI:j?.joinURI??null,joinApp:j?.conferenceSolutionName??null,pid:process.pid,updatedAt:e.getTime()}:{title:null,pid:process.pid,updatedAt:e.getTime()}));
f.renameSync(o+`.tmp`,o)}catch(t){console.error(`granola: next-meeting write failed`,t)}}
""".replace("\n", "")


def patch_storage(app: Bundle, main: str) -> None:
    """Fail closed on Linux: upstream's error recovery deletes keys and data."""
    electron = app.name(main, rf"=>({ID})\.safeStorage\.decryptStringAsync\(e\)", "safeStorage module")
    filesystem = app.name(
        main,
        rf"async function {ID}\(\)\{{let e={ID}\(\);if\(!\(0,({ID})\.existsSync\)\(e\)\)",
        "encrypted-key filesystem module",
    )
    helpers = r"""
var granolaLinuxStorageFailing=!1;
function granolaLinuxStorageFatal(stage){
if(granolaLinuxStorageFailing)process.exit(78);granolaLinuxStorageFailing=!0;
try{console.error(`granola: encrypted storage startup failed`,stage);
ELECTRON.dialog.showErrorBox(`Granola could not open local data`,
`Granola could not safely open its local data. Your encrypted files have been preserved. If your desktop keyring is locked, unlock it and reopen Granola. If this repeats, check the startup logs before changing any stored data.`)}
finally{try{ELECTRON.app.exit(78)}finally{process.exit(78)}}}
function granolaLinuxStorageWait(p){
if(process.platform!==`linux`)return p;
let t=setTimeout(()=>granolaLinuxStorageFatal(`key-access-timeout`),90000);
return p.finally(()=>clearTimeout(t))}
function granolaLinuxCheckMissingKey(p){
if(process.platform!==`linux`)return;
try{if(FILESYSTEM.readdirSync(require(`node:path`).dirname(p)).some(n=>n.endsWith(`.enc`)||n.endsWith(`.enc.tmp`)||/^granola\.db(?:-wal|-shm)?$/.test(n)||n.startsWith(`storage.dek.tmp-`)))granolaLinuxStorageFatal(`missing-key`)}
catch{granolaLinuxStorageFatal(`key-directory-read-failed`)}}
function granolaLinuxWriteKey(p,b){
let f=FILESYSTEM,t=p+`.tmp-${process.pid}`,fd,owned=!1;
try{fd=f.openSync(t,`wx`,0o600);owned=!0;f.writeFileSync(fd,b);f.fsyncSync(fd);f.closeSync(fd);fd=void 0;f.renameSync(t,p)}
catch{if(fd!==void 0)try{f.closeSync(fd)}catch{}if(owned)try{f.unlinkSync(t)}catch{}granolaLinuxStorageFatal(`key-write-failed`)}}
""".replace("ELECTRON", electron).replace("FILESYSTEM", filesystem).replace("\n", "")
    app.patch(
        main,
        rf"(async function {ID}\(\)\{{if\(({ID})\)return \2;if\(({ID})\)return \3;"
        rf"\3=process\.platform===`darwin`&&{ID}\.app\.isPackaged\?{ID}\(\):{ID}\(\);try\{{return \2=await )\3(,\2\}}finally\{{\3=null\}}\}})",
        lambda m: helpers + m[1] + f"granolaLinuxStorageWait({m[3]})" + m[4],
        label="bounded encrypted-storage startup",
    )
    app.patch(
        main,
        rf"(async function {ID}\(\)\{{let ({ID})={ID}\(\);if\(!\(0,{ID}\.existsSync\)\(\2\)\))return ({ID}\(\));try\{{let",
        r"\1{granolaLinuxCheckMissingKey(\2);return \3}try{let",
        label="preserve encrypted files when the key is missing",
    )
    # Re-encryption rotates the wrapping provider, not the data key. Never
    # truncate the sole wrapped key in place if writing or renaming fails.
    for event in ("dek-created", "dek-reencrypted"):
        app.patch(
            main,
            rf"(\(0,{ID}\.writeFileSync\)\(([^,;]+),({ID})\))(?=,{ID}\(`info`,`{event}`,)",
            r"(process.platform===`linux`?granolaLinuxWriteKey(\2,\3):\1)",
            label=f"atomic key write on {event}",
        )
    # Guard before the original log/catch body: those bodies unlink storage.dek
    # or *.enc and then initialize empty storage. A timeout must exit directly,
    # never reject into those destructive catches. Log fixed stages only; error
    # messages from JSON parsing can contain fragments of private notes.
    for event in (
        "dek-creation-failed",
        "dek-decryption-failed",
        "dek-invalid-length",
        "dek-read-failed",
        "encrypted-storage-dek-unavailable",
        "encrypted-storage-read-failed",
        "storage-read-failed",
    ):
        app.patch(
            main,
            rf"(?<![\w$])({ID}\(`error`,`{event}`,)",
            rf"process.platform===`linux`&&granolaLinuxStorageFatal(`{event}`),\1",
            label=f"preserve storage on {event}",
        )


def patch_audio(app: Bundle, capture: str) -> None:
    """Use filtered app playback; never fall back to the full desktop mix."""
    # The mic is still opened first (below), which grants MediaDevices labels.
    # Use an exact device constraint on every acquisition/reacquisition. A
    # missing source must fail rather than record an unrelated default device.
    app.patch(
        capture,
        rf"function ({ID})\(({ID})\)\{{return {ID}\(\)\?Promise\.resolve\({ID}\(\)\):"
        rf"navigator\.mediaDevices\.getDisplayMedia\(\{{audio:\{{sampleRate:\2\}},video:!1\}}\)\}}",
        lambda m: (
            f"async function {m[1]}({m[2]}){{"
            "let devices=await navigator.mediaDevices.enumerateDevices(),"
            "source=devices.find(d=>d.kind===`audioinput`&&d.deviceId!==`default`&&"
            "d.deviceId!==`communications`&&d.label===`Granola meeting audio`);"
            "if(!source)throw new DOMException(`Granola meeting audio source is unavailable`,`NotFoundError`);"
            "return navigator.mediaDevices.getUserMedia({audio:{deviceId:{exact:source.deviceId},"
            f"sampleRate:{m[2]},echoCancellation:!1,noiseSuppression:!1,autoGainControl:!1}},video:!1}})}}"
        ),
        label="filtered meeting audio instead of desktop loopback",
    )
    app.patch(
        capture,
        rf"(async function {ID}\(({ID}),{ID},{ID}\)\{{)(?=if\(\2===`system`&&)",
        r"\1if(\2===`system`)return`Granola meeting audio`;",
        label="filtered meeting source label",
    )
    # A virtual input is how Chromium captures the meeting track, but it is
    # not a microphone choice: selecting it there would duplicate call audio.
    app.patch(
        capture,
        rf"(return {ID}\.filter\(({ID})=>\2\.kind===`audioinput`&&)(\2\.deviceId!==\"default\")",
        r"\1\2.label!==`Granola meeting audio`&&\3",
        label="exclude meeting audio from microphone choices",
    )


def patch_granola(app: Bundle, macos_version: str) -> None:
    preload = "dist-electron/preload/preload.js"
    main = "dist-electron/main/index.js"

    # Linux uses browser capture. The permission probe still opens and stops
    # a display-capture stream, so its loopback handler is needed even though
    # meeting capture uses the filtered input patched below.
    app.require(main, "process.platform===`linux`", "Linux browser-audio branch is gone")
    app.require(main, "id:`loopbackAllDevices`", "Linux loopback handler is gone")
    patch_storage(app, main)

    # Electron translates systemd's SIGTERM into before-quit. Granola's
    # macOS handler cancels that event and only closes the primary window,
    # leaving its tray process alive and blocking graphical-session.target.
    # Use the app's full shutdown path, which stops transcription and flushes
    # pending work before exiting. Window-close-to-tray still uses its own
    # close handler; this only changes requests to terminate the whole app.
    shutdown = app.name(
        main,
        rf"\.powerMonitor\.on\(`shutdown`,\(\)=>\{{{ID}\(\)\|\|({ID})\(\)\}}\)",
        "graceful shutdown function",
    )
    app.patch(
        main,
        rf"(\.app\.on\(`before-quit`,async ({ID})=>\{{)",
        rf"\1if(process.platform===`linux`){{\2.preventDefault();await {shutdown}(`linux_app_quit`);return}}",
        label="Linux graceful app shutdown",
    )

    app.patch(preload, r"platform:process\.platform", "platform:`darwin`", label="renderer platform identity")
    app.patch(
        preload,
        r"osVersion:process\.getSystemVersion\(\)",
        f"osVersion:`{macos_version}`",
        label="renderer OS version identity",
    )
    app.patch(main, r"\?`Windows`:process\.platform", "?`Windows`:`macOS`", label="backend platform normalization")

    # systemPreferences.askForMediaAccess is macOS-only and throws on Linux;
    # PipeWire has no mic permission gate, so report "granted".
    app.patch(
        main,
        rf"async function ({ID})\(({ID})\)\{{\2\(await {ID}\.systemPreferences\.askForMediaAccess\(`microphone`\)\)\}}",
        r"async function \1(\2){\2(!0)}",
        label="Linux microphone permission bridge",
    )

    # Off macOS the primary window gets a Windows-style titleBarOverlay, which
    # Electron draws as min/max/close buttons in the top-right corner. The
    # renderer believes it's on macOS, so it leaves no room for them and they
    # land on top of the toolbar. Use the macOS window options everywhere;
    # on Linux that's a plain frameless window, which a tiling WM wants anyway.
    app.patch(
        main,
        rf"\.\.\.process\.platform===`darwin`\?({ID}):({ID}),backgroundColor:",
        r"...\1,backgroundColor:",
        label="macOS-style primary window chrome",
    )

    # The login service passes this flag; ordinary launches still show the
    # main window. Only suppress the initial show/focus, so tray clicks,
    # second-instance launches, deep links and reminders keep working.
    app.patch(
        main,
        rf"({ID}\(void 0,{ID},\{{)show:({ID}),focus:({ID})(\}}\),{ID}\(\),{ID}\.init\(\),)",
        r"\1show:!process.argv.includes(`--start-in-tray`)&&\2,"
        r"focus:!process.argv.includes(`--start-in-tray`)&&\3\4",
        label="start in tray on login",
    )

    # The quit / stop-transcribing confirmations are native dialogs made modal
    # to a never-shown, zero-opacity 1px helper window (a macOS centring
    # trick). On Wayland a GTK dialog transient for an unmapped parent draws
    # but ignores clicks. Drop the parent; the helper window is still created
    # and closed as before.
    for message, label in (
        (rf"{ID}\?`Stop transcribing\?`", "quit dialog parent"),
        (r"`Stop transcribing\?`", "stop-transcribing dialog parent"),
    ):
        app.patch(main, rf"(\.dialog\.showMessageBox\(){ID},(\{{message:{message})", r"\1\2", label=label)

    # Meeting reminders load the main index.html, so Electron retitles them
    # "Granola" -- indistinguishable from the main window for niri's window
    # rules. Keep the "Notification" title the window was created with.
    app.patch(
        main,
        rf"(({ID})\.loadURL\({ID}\(`!notification=\$\{{{ID}\}}`\)\))",
        r"\2.on(`page-title-updated`,e=>e.preventDefault()),\1",
        label="stable reminder window title",
    )

    # A granola:// link that launches Granola arrives only in argv. Granola
    # reads argv links in its second-instance handler, and on macOS gets cold
    # launches via open-url; Linux cold launches were dropped. Queue it as a
    # pending link, the way the open-url handler does before a window exists.
    find_link = app.name(main, rf"function ({ID})\((\w)\)\{{for\(let (\w) of \2\)try\{{if\({ID}\(new URL\(\3\)\)\)return \3\}}", "argv link finder")
    dedupe = app.name(main, rf"function ({ID})\(e\)\{{let t=Date\.now\(\);return {ID}&&{ID}\.url===e", "deep-link dedupe")
    queue = app.name(main, rf"var {ID}=null;function ({ID})\(e\)\{{({ID})=e\}}function {ID}\(\)\{{let e=\2;if\(\2=null,!e\)return null;try\{{let t={ID}\(new URL\(e\)\)", "pending deep-link setter")
    app.patch(
        main,
        rf"({ID}\(process\.argv\)),(?={ID}\(\),{ID}\.powerMonitor\.on\(`shutdown`)",
        rf"\1||(t=>t&&{dedupe}(t)&&{queue}(t))({find_link}(process.argv)),",
        label="cold-start deep link",
    )

    # "Show upcoming meetings in menu bar": Granola works out the next meeting
    # every minute and on every calendar change, but only on macOS, where it
    # becomes Tray.setTitle text (macOS-only in Electron). On Linux, write it
    # to $XDG_RUNTIME_DIR/granola/next-meeting.json for the bar widget, still
    # governed by that toggle.
    app.patch(
        main,
        rf"function ({ID})\(\)\{{if\(process\.platform!==`darwin`\)return!1;(let e={ID}\(`showUpcomingEventInMenuBar`\))",
        r"function \1(){\2",
        label="menu-bar meeting setting off macOS",
    )
    app.patch(
        main,
        rf"process\.platform===`darwin`&&({ID}\(\)&&\(({ID})\|\|=)",
        r"\1",
        label="menu-bar meeting timer off macOS",
    )
    app.patch(
        main,
        rf"(\.setToolTip\(`Granola`\),)process\.platform===`darwin`&&({ID}\(\),)",
        r"\1\2",
        label="menu-bar meeting start off macOS",
    )
    # Granola's own join-link resolver (conferenceData video entry, else a
    # Zoom/Meet/Teams/… URL in the description or location), as its tray menu
    # calls it: resolver(event, icons, userEmail).
    join_link, join_icons = app.names(main, rf"\?({ID})\({ID},({ID}),{ID}\)\?\?void 0:void 0", "join-link resolver")
    app.patch(
        main,
        rf"function ({ID})\(e=new Date\)\{{if\(!({ID})\|\|process\.platform!==`darwin`\)return;"
        rf"if\(!({ID})\(\)\)\{{\2\.setTitle\(``\);return\}}let\{{userEmail:t\}}=({ID})\(\),n=({ID})\(({ID}),e,({ID})\(t\)\);",
        lambda m: NEXT_MEETING_WRITER
        + f"function {m[1]}(e=new Date){{if(!{m[2]})return;"
        f"if(process.platform!==`darwin`){{let t={m[4]}().userEmail,n={m[3]}()?{m[5]}({m[6]},e,{m[7]}(t)):null;"
        f"return granolaLinuxNextMeeting(n,e,n?{join_link}(n,{join_icons},t):null)}}"
        f"if(!{m[3]}()){{{m[2]}.setTitle(``);return}}let{{userEmail:t}}={m[4]}(),n={m[5]}({m[6]},e,{m[7]}(t));",
        label="next meeting file",
    )
    app.patch(
        main,
        rf"({ID})&&process\.platform===`darwin`&&\1\.setTitle\(``\)\}}",
        r"\1&&(process.platform===`darwin`?\1.setTitle(``):granolaLinuxNextMeeting(null,new Date))}",
        label="next meeting file cleared when toggled off",
    )

    capture = app.find(rf"navigator\.mediaDevices\.getDisplayMedia\(\{{audio:\{{sampleRate:{ID}\}},video:!1\}}\)")
    patch_audio(app, capture)

    # Open the mic first so Chromium exposes input-device labels, then give
    # Bluetooth's A2DP -> HSP/HFP switch a moment to settle before opening
    # the filtered meeting track.
    app.patch(
        capture,
        rf",\[({ID}),({ID})\]={ID}\({ID}\)\?await Promise\.all\(\[({ID})\(`system`\),\3\(`microphone`\)\]\)"
        rf":\[await \3\(`system`\),await \3\(`microphone`\)\],",
        r",\2=await \3(`microphone`),\1=(await new Promise(e=>setTimeout(e,1500)),await \3(`system`)),",
        label="microphone-first stream acquisition",
    )

    # When that HSP/HFP switch recreates the tracks, Chromium can stop pulling
    # an AudioWorklet with no path to a destination. The processor writes
    # nothing to its output, so routing it to the destination is silent but
    # keeps the graph alive.
    app.patch(
        capture,
        rf"({ID})\.connect\(({ID})\);(let [^;]*=\(\)=>\{{let e={ID}\({ID}\);return Number\.isFinite\(e\))",
        r"\1.connect(\2).connect(\1.context.destination);\3",
        label="AudioWorklet keepalive",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, help="app.asar extracted to a directory")
    parser.add_argument("--macos-version", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"\d{1,2}(\.\d{1,2}){1,2}", args.macos_version):
        raise SystemExit(f"error: invalid macOS version {args.macos_version!r}")
    patch_granola(Bundle(args.app), args.macos_version)


if __name__ == "__main__":
    main()
