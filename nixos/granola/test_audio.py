#!/usr/bin/env python3
"""Exercise the patched renderer's audio selection without opening any devices."""

import argparse
import json
import re
import subprocess
from pathlib import Path

ID = r"[A-Za-z_$][\w$]*"


def function_at(source: str, marker: str) -> tuple[str, str]:
    """Extract one of the small capture helpers from the actual patched JS."""
    hits = list(re.finditer(marker, source))
    if len(hits) != 1:
        raise AssertionError(f"expected one audio marker {marker!r}, found {len(hits)}")
    start = source.rfind("function ", 0, hits[0].start())
    if source[start - 6:start] == "async ":
        start -= 6
    name = re.match(rf"(?:async )?function ({ID})\(", source[start:])[1]
    opening = source.index("{", start)
    # These helpers have no unbalanced braces in strings or regexes.
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return name, source[start:end]


HARNESS = r"""
const assert=require('node:assert/strict'),vm=require('node:vm');
const label='Granola meeting audio';
const mic={kind:'audioinput',deviceId:'mic',groupId:'mic-group',label:'Microphone (echo cancelled)'};
const meeting={kind:'audioinput',deviceId:'meeting',groupId:'meeting-group',label};
let devices=[],calls=[],failure,enumerationFailure;
const stream={fixture:'meeting stream'},navigator={mediaDevices:{
enumerateDevices:async()=>{if(enumerationFailure)throw enumerationFailure;return devices},
getUserMedia:async options=>{calls.push(JSON.parse(JSON.stringify(options)));if(failure)throw failure;return stream},
getDisplayMedia:()=>{throw Error('must never capture desktop playback')}
}};
const context=vm.createContext({navigator,DOMException});
const acquire=vm.runInContext('__ACQUIRE__;__ACQUIRE_NAME__',context);
const choices=vm.runInContext('__CHOICES__;__CHOICES_NAME__',context);
const describe=vm.runInContext('__DESCRIBE__;__DESCRIBE_NAME__',context);
(async()=>{
devices=[mic,{...meeting,deviceId:'default'},{...meeting,deviceId:'communications'},
  {...meeting,kind:'audiooutput',deviceId:'output'},meeting];
assert.equal(await acquire(48000),stream);
assert.deepEqual(calls,[{audio:{deviceId:{exact:'meeting'},sampleRate:48000,
  echoCancellation:false,noiseSuppression:false,autoGainControl:false},video:false}]);
// Reacquisition must resolve the current device ID, never a stale/default ID.
devices=[mic,{...meeting,deviceId:'meeting-after-restart'}];
await acquire(16000);
assert.equal(calls.at(-1).audio.deviceId.exact,'meeting-after-restart');
assert.equal(calls.at(-1).audio.sampleRate,16000);
// Missing/alias-only/output-only matches cannot fall back to the mic/monitor.
for(const unavailable of [[mic],[mic,{...meeting,deviceId:'default'}],
  [mic,{...meeting,deviceId:'communications'}],[mic,{...meeting,kind:'audiooutput'}]]){
  devices=unavailable;calls=[];
  await assert.rejects(acquire(48000),e=>e.name==='NotFoundError');
  assert.equal(calls.length,0);
}
devices=[mic,meeting];
for(const name of ['NotFoundError','NotReadableError','OverconstrainedError']){
  calls=[];failure=new DOMException('fixture failure',name);
  await assert.rejects(acquire(48000),e=>e===failure);
  assert.equal(calls.length,1);
  assert.equal(calls[0].audio.deviceId.exact,'meeting');
}
failure=undefined;calls=[];enumerationFailure=new Error('enumeration failed');
await assert.rejects(acquire(48000),e=>e===enumerationFailure);
assert.equal(calls.length,0);
// The system track has its actual source label and cannot be chosen as mic.
assert.equal(await describe('system'),'Granola meeting audio');
const listed=choices([mic,meeting,{...mic,deviceId:'default'}],true);
assert.deepEqual(JSON.parse(JSON.stringify(listed)).map(d=>d.deviceId),['mic']);
console.log('audio selection: passed (exact source, reacquisition, failures, mic choices)');
})().catch(e=>{console.error(e);process.exitCode=1});
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    args = parser.parse_args()
    files = [p for p in (args.app / "dist-app").rglob("*.js")
             if "let devices=await navigator.mediaDevices.enumerateDevices(),source=" in p.read_text()]
    if len(files) != 1:
        raise AssertionError("run patch_app.py before the audio regressions")
    source = files[0].read_text()
    harness = HARNESS
    for key, marker in (
        ("ACQUIRE", r"let devices=await navigator\.mediaDevices\.enumerateDevices\(\),source="),
        ("CHOICES", r"\.label!==`Granola meeting audio`"),
        ("DESCRIBE", r"if\([^;]+===`system`\)return`Granola meeting audio`;"),
    ):
        name, code = function_at(source, marker)
        # JSON quoting keeps template literals and regexes intact in JS strings.
        harness = harness.replace(f"'__{key}__;__{key}_NAME__'", json.dumps(code + ";" + name))
    subprocess.run(["node", "-e", harness], check=True)


if __name__ == "__main__":
    main()
