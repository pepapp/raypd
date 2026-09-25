import shutil
import sys
import os

import yaml


def merge(base, override):
    out = dict(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = merge(out[key], value)
        else:
            out[key] = value
    return out


def load(path):
    with open(path) as f:
        return yaml.safe_load(f) or {}


def dump(data, path):
    with open(path, "w") as f:
        yaml.safe_dump(data, f, sort_keys=False)


service, image, tag = sys.argv[1:4]
defaults = load(f"services/{service}/infra/defaults.yaml")
chart_dir = f"helms/{defaults['type']}"
out = f"build/{service}"

shutil.rmtree(out, ignore_errors=True)
shutil.copytree(chart_dir, out)

values = merge(load(f"{chart_dir}/values.yaml"), defaults)
if os.path.exists(f"services/{service}/infra/Dockerfile"):
    values = merge(values, {"name": service, "image": {"repository": image, "tag": tag}})

dump(values, f"{out}/values.yaml")

chart = load(f"{chart_dir}/Chart.yaml")
chart["name"] = service
dump(chart, f"{out}/Chart.yaml")

print(yaml.safe_dump(values, sort_keys=False))