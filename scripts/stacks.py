import json
import os
import re
import sys

SOURCE = re.compile(r'source\s*=\s*"(\.{1,2}/[^"]+)"')


def local_modules(d, seen=None):
    """Directories of local modules used by the .tf files in d (recursive)."""
    seen = set() if seen is None else seen
    for f in os.listdir(d):
        if f.endswith(".tf"):
            for src in SOURCE.findall(open(os.path.join(d, f)).read()):
                m = os.path.normpath(os.path.join(d, src))
                if m not in seen and os.path.isdir(m):
                    seen.add(m)
                    local_modules(m, seen)
    return seen


stacks = {}  # name (directory name) -> {"dir", "depends_on", "paths"}
for d, dirs, files in os.walk("terraform"):
    dirs[:] = [x for x in dirs if not x.startswith(".")]  # skip .terraform
    if "backend.tf" in files:
        deps = []
        if "tf_info" in files:
            for line in open(os.path.join(d, "tf_info")):
                key, _, value = line.partition(":")
                if key.strip() == "depends_on":
                    items = value.split("#")[0].strip().strip("[]").split(",")
                    deps = [v.strip(" '\"") for v in items if v.strip(" '\"") not in ("", "null", "~")]
        stacks[os.path.basename(d)] = {"dir": d, "depends_on": deps, "paths": [d, *local_modules(d)]}

# Execution order (dependencies first).
order, done = [], set()
while len(done) < len(stacks):
    ready = sorted(n for n, s in stacks.items() if n not in done and set(s["depends_on"]) <= done)
    if not ready:  # unknown dependency or a cycle
        stuck = {n: stacks[n]["depends_on"] for n in sorted(set(stacks) - done)}
        sys.exit(f"cannot order stacks (unknown dependency or cycle): {stuck}; known stacks: {sorted(stacks)}")
    order += ready
    done.update(ready)

if "--changed" in sys.argv:
    changed = [os.path.normpath(f) for f in sys.stdin.read().split()]
    selected = {n for n, s in stacks.items()
                if any(f == p or f.startswith(p + os.sep) for f in changed for p in s["paths"])}
    for n in order:  # dependents of an affected stack are affected too (order = parents first)
        if selected & set(stacks[n]["depends_on"]):
            selected.add(n)
    order = [n for n in order if n in selected]

print(json.dumps([stacks[n]["dir"] for n in order]))