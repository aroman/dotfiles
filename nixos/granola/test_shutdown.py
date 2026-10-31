#!/usr/bin/env python3
"""Exercise the patched bundle's before-quit handler without desktop data."""

import argparse
import json
import re
import subprocess
from pathlib import Path

ID = r"[A-Za-z_$][\w$]*"


def match(source: str, pattern: str) -> re.Match[str]:
    matches = list(re.finditer(pattern, source))
    if len(matches) != 1:
        raise AssertionError(f"expected one bundle marker {pattern!r}, found {len(matches)}")
    return matches[0]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    args = parser.parse_args()
    source = (args.app / "dist-electron/main/index.js").read_text()
    callback = match(
        source,
        rf"\.app\.on\(`before-quit`,(async {ID}=>\{{.*?\}})\),{ID}\(`open-settings`",
    ).group(1)
    shutdown = match(
        source,
        rf"\.powerMonitor\.on\(`shutdown`,\(\)=>\{{{ID}\(\)\|\|({ID})\(\)\}}\)",
    ).group(1)
    logger, dev, suppress, restarting = match(
        callback,
        rf"if\(({ID})\(`info`,`on-before-quit`,\{{isDev:({ID}),disableQuitConfirmation:({ID})\(\)\}}\),"
        rf"\2&&\(({ID})=!0\),!\(\2\|\|\3\(\)\)\)",
    ).groups()
    refuse = match(callback, rf"if\(({ID})\(\)\)\{{{ID}\.preventDefault\(\),{ID}\(`info`,`quit-refused-during-restart-prompt`\)").group(1)
    soft_close = match(callback, rf"preventDefault\(\),await ({ID})\(\)").group(1)
    aliases = dict(shutdown=shutdown, logger=logger, dev=dev, suppress=suppress,
                   restarting=restarting, refuse=refuse, softClose=soft_close)
    harness = r"""
const assert=require('node:assert/strict'),vm=require('node:vm');
const callback=__CALLBACK__,names=__ALIASES__;
(async()=>{
for(const platform of ['linux','darwin','win32']){
for(const dev of [false,true])for(const suppressed of [false,true])for(const refused of [false,true]){
  const calls=[],context={process:{platform}};
  Object.assign(context,{
    [names.logger]:()=>{},[names.dev]:dev,[names.restarting]:false,
    [names.suppress]:()=>suppressed,[names.refuse]:()=>refused,
    [names.softClose]:async()=>calls.push('soft-close'),
    [names.shutdown]:async reason=>{
      calls.push('stop-transcription');await Promise.resolve();
      calls.push('flush-pending-work');calls.push('exit');
      assert.equal(reason,'linux_app_quit');
    },
  });
  const handler=vm.runInNewContext('('+callback+')',context);
  const event={preventDefault:()=>calls.push('prevent-default')};
  await handler(event);
  const expected=platform==='linux'
    ? ['prevent-default','stop-transcription','flush-pending-work','exit']
    : dev||suppressed ? [] : refused ? ['prevent-default'] : ['prevent-default','soft-close'];
  assert.deepEqual(calls,expected,JSON.stringify({platform,dev,suppressed,refused}));
}
}
console.log('Passed 24 app shutdown scenarios');
})().catch(error=>{console.error(error);process.exitCode=1});
""".replace("__CALLBACK__", json.dumps(callback)).replace("__ALIASES__", json.dumps(aliases))
    subprocess.run(["node", "--check", args.app / "dist-electron/main/index.js"], check=True)
    subprocess.run(["node", "-e", harness], check=True, timeout=10)


if __name__ == "__main__":
    main()
