#!/usr/bin/env python3
"""Exercise the patched bundle's actual storage functions without desktop secrets.

Run after patch_app.py: python3 test_storage.py <extracted-app-directory>.
Only Electron's key provider/UI are stubbed; file reads and AES-GCM are real.
Every failure runs in its own process and must exit before mutating the fixture.
"""

import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path

ID = r"[A-Za-z_$][\w$]*"


def match(source: str, pattern: str) -> re.Match[str]:
    matches = list(re.finditer(pattern, source, re.DOTALL))
    if len(matches) != 1:
        raise AssertionError(f"expected one bundle marker {pattern!r}, found {len(matches)}")
    return matches[0]


def snapshot(root: Path) -> dict[str, bytes | None]:
    return {str(p.relative_to(root)): p.read_bytes() if p.is_file() else None for p in sorted(root.rglob("*"))}


HARNESS = r"""
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=process.argv[2],scenario=process.argv[3],realSetTimeout=setTimeout;
const key=Buffer.alloc(32,7),calls={decrypt:0,encrypt:0,dialogs:0};
process.on('exit',()=>console.log(JSON.stringify(calls)));
global.setTimeout=(f,ms,...args)=>realSetTimeout(f,ms===90000?300:Math.min(ms,1),...args);
const __FS__=Object.create(fs);
__FS__.readFileSync=(p,...args)=>{
if((scenario==='key-unreadable'&&p.endsWith('storage.dek'))||(scenario==='data-unreadable'&&p.endsWith('.enc')))throw Error('fixture read failure');
return fs.readFileSync(p,...args)};
__FS__.writeFileSync=(p,b,...args)=>{
if(scenario==='partial-key-write'&&typeof p==='number'){fs.writeFileSync(p,b.subarray(0,3));throw Error('fixture partial write')}
return fs.writeFileSync(p,b,...args)};
__FS__.openSync=(...args)=>{if(scenario==='key-open-failed')throw Error('fixture open failure');return fs.openSync(...args)};
__FS__.fsyncSync=(...args)=>{if(scenario==='key-fsync-failed')throw Error('fixture fsync failure');return fs.fsyncSync(...args)};
__FS__.renameSync=(...args)=>{if(scenario==='key-rename-failed')throw Error('fixture rename failure');return fs.renameSync(...args)};
if(scenario==='key-temp-collision'){calls.tempName='storage.dek.tmp-'+process.pid;fs.writeFileSync(root+'/'+calls.tempName,'preexisting-key-remnant')}
const __ELECTRON__={
app:{getPath:()=>root,isReady:()=>true,isPackaged:true,exit:code=>{if(scenario==='exit-throws')throw Error('fixture exit failure');process.exit(code)}},
dialog:{showErrorBox:()=>{calls.dialogs++;if(scenario==='dialog-throws')throw Error('fixture dialog failure');if(scenario==='reentrant-failure')granolaLinuxStorageFatal('fixture reentrant failure')}},
safeStorage:{
decryptStringAsync:async()=>{calls.decrypt++;
if(['decrypt-rejected','dialog-throws','exit-throws','reentrant-failure'].includes(scenario))throw Error('PRIVATE-NOTE-FRAGMENT');
if(scenario==='temporarily-unavailable')throw Error('temporarily unavailable');
if(scenario==='decrypt-timeout')return new Promise(()=>{});
return{result:(scenario==='invalid-key'?Buffer.alloc(31):key).toString('base64'),shouldReEncrypt:['partial-key-write','key-rename-failed','rotation-success','key-open-failed','key-fsync-failed','key-temp-collision'].includes(scenario)}},
encryptStringAsync:async()=>{calls.encrypt++;
if(scenario==='encrypt-rejected')throw Error('PRIVATE-NOTE-FRAGMENT');
if(scenario==='encrypt-timeout')return new Promise(()=>{});
return Buffer.from('fixture-encrypted-dek')},
isEncryptionAvailable:()=>{throw Error('synchronous storage must not be queried on failure')},
isAsyncEncryptionAvailable:async()=>true}};
const __CRYPTO__=crypto,__PATH__=require('node:path'),__OS__={default:require('node:os')},__STREAM__=require('node:stream');
const __LOGGER__=level=>{if(level==='error')throw Error('unexpected upstream error recovery')};
__RETRY_FUNCTION__
__STORAGE_FUNCTIONS__
(async()=>{
let result=await __READ_STORAGE__('cache-v6.json');
assert.deepEqual(result,['existing-key','rotation-success'].includes(scenario)?{fixture:true}:{});
// A resolved key operation must cancel the deadline, not exit later.
await new Promise(r=>realSetTimeout(r,500));
assert.equal(calls.dialogs,0);
if(['first-run','rotation-success'].includes(scenario))assert.equal(fs.readFileSync(root+'/storage.dek').toString(),'fixture-encrypted-dek');
})().catch(e=>{console.error(e);process.exit(1)});
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    args = parser.parse_args()
    source = (args.app / "dist-electron/main/index.js").read_text()
    start = match(source, rf"var {ID}=12,{ID}=16;function {ID}\(e\)\{{let t=").start()
    end = match(source, rf"var {ID}=\(\{{file:e,writeThrottleMs:t=100,writeCooldownMs:n=0\}}\)=>").start()
    storage = source[start:end]
    if "granolaLinuxStorageFatal" not in storage:
        raise AssertionError("run patch_app.py before the storage regressions")
    path_alias, electron = match(storage, rf"return\(0,({ID})\.join\)\(({ID})\.app\.getPath\(`userData`\),`storage.dek`\)").groups()
    retry = match(storage, rf"return ({ID})\(\(\)=>{ID}\.safeStorage\.decryptStringAsync\(e\)").group(1)
    replacements = {
        "__FS__": match(storage, rf"async function {ID}\(\)\{{let e={ID}\(\);if\(!\(0,({ID})\.existsSync\)\(e\)\)").group(1),
        "__ELECTRON__": electron,
        "__CRYPTO__": match(storage, rf"\(0,({ID})\.randomBytes\)\(32\)").group(1),
        "__PATH__": path_alias,
        "__OS__": match(storage, rf"`dek-created`,\{{fileSize:n.length,systemUptimeSeconds:Math.round\(({ID})\.default\.uptime\(\)\)").group(1),
        "__STREAM__": match(storage, rf"new ({ID})\.Transform\(").group(1),
        "__LOGGER__": match(storage, rf"(?<![\w$])({ID})\(`info`,`dek-created`,").group(1),
        "__RETRY_FUNCTION__": match(source, rf"async function {re.escape(retry)}\(e,t\)\{{.*?throw {ID}\}}").group(),
        "__STORAGE_FUNCTIONS__": storage,
        "__READ_STORAGE__": match(storage, rf"async function ({ID})\(e\)\{{let t={ID}\(`\$\{{e\}}.enc`\)").group(1),
    }
    harness = HARNESS
    for marker, value in replacements.items():
        harness = harness.replace(marker, value)
    scenarios = [
        "existing-key", "first-run", "decrypt-rejected", "temporarily-unavailable",
        "decrypt-timeout", "invalid-key", "key-unreadable", "missing-key",
        "bad-json", "bad-ciphertext", "data-unreadable", "encrypt-rejected",
        "encrypt-timeout", "dialog-throws", "exit-throws", "partial-key-write",
        "key-rename-failed", "rotation-success", "missing-key-db", "missing-key-data-temp",
        "missing-key-key-temp", "reentrant-failure",
        "key-open-failed", "key-fsync-failed", "key-temp-collision",
    ]
    with tempfile.TemporaryDirectory(prefix="granola-storage-test-") as temporary:
        work = Path(temporary)
        script = work / "storage.js"
        script.write_text(harness)
        subprocess.run(["node", "--check", args.app / "dist-electron/main/index.js"], check=True)
        for scenario in scenarios:
            root = work / scenario
            root.mkdir()
            if scenario not in ("first-run", "encrypt-rejected", "encrypt-timeout") and not scenario.startswith("missing-key"):
                (root / "storage.dek").write_bytes(b"fixture-original-dek")
            if scenario == "first-run":
                (root / "declarative_performance_observer.db").write_bytes(b"SQLite format 3\x00fixture")
            if scenario == "missing-key-db":
                for name in ("granola.db", "granola.db-wal", "granola.db-shm"):
                    (root / name).write_bytes(b"encrypted-database-fixture")
            elif scenario == "missing-key-data-temp":
                (root / "cache-v6.json.enc.tmp").write_bytes(b"encrypted-write-remnant")
            elif scenario == "missing-key-key-temp":
                (root / "storage.dek.tmp-recovery").write_bytes(b"encrypted-key-remnant")
            elif scenario not in ("first-run", "encrypt-rejected", "encrypt-timeout"):
                # Use the real crypto runtime to generate authenticated bytes.
                payload = '{"fixture":true}' if scenario != "bad-json" else "PRIVATE-NOTE-FRAGMENT"
                ciphertext = subprocess.check_output([
                    "node", "-e",
                    "const c=require('crypto'),k=Buffer.alloc(32,7),iv=Buffer.alloc(12,3),"
                    "e=c.createCipheriv('aes-256-gcm',k,iv);process.stdout.write(Buffer.concat("
                    "[iv,e.update(process.argv[1]),e.final(),e.getAuthTag()]));",
                    payload,
                ])
                (root / "cache-v6.json.enc").write_bytes(b"broken" if scenario == "bad-ciphertext" else ciphertext)
                (root / "supabase.json.enc").write_bytes(b"unrelated-encrypted-fixture")
            before = snapshot(root)
            result = subprocess.run(["node", script, root, scenario], capture_output=True, text=True, timeout=5)
            success = scenario in ("existing-key", "first-run", "rotation-success")
            assert result.returncode == (0 if success else 78), (scenario, result.returncode, result.stdout, result.stderr)
            calls = json.loads(result.stdout.strip().splitlines()[-1])
            assert calls["dialogs"] == (0 if success else 1), (scenario, calls)
            assert "PRIVATE-NOTE-FRAGMENT" not in result.stderr, (scenario, result.stderr)
            if scenario == "temporarily-unavailable":
                assert calls["decrypt"] == 5, calls
            if scenario == "first-run":
                assert snapshot(root) == {**before, "storage.dek": b"fixture-encrypted-dek"}
            elif scenario == "rotation-success":
                assert snapshot(root) == {**before, "storage.dek": b"fixture-encrypted-dek"}
            elif scenario == "key-temp-collision":
                assert snapshot(root) == {**before, calls["tempName"]: b"preexisting-key-remnant"}
            else:
                assert snapshot(root) == before, f"{scenario}: storage changed"
            if scenario in ("first-run", "rotation-success"):
                assert (root / "storage.dek").stat().st_mode & 0o777 == 0o600
            print(f"storage regression passed: {scenario}")


if __name__ == "__main__":
    main()
