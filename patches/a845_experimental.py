#!/usr/bin/env python3
"""
Experimental Adreno 845 (SM8950) chip-id bring-up for Banners-Turnip.

Observed retail device:
  SoC     : SM8950
  GPU     : Adreno 845
  KGSL ID : 0x44041430

Qualcomm's upstream kernel enablement uses the A845 family/base ID 0x44041400.
Mesa/Turnip does not yet carry a native A845 GPUInfo in this A8xx stack, so this
script deliberately aliases the retail chip ID to the existing A840 GPUInfo.

THIS IS ONLY A BRING-UP PROBE. It is intended to get past
VK_ERROR_INCOMPATIBLE_DRIVER / "device ... is unsupported" so later failures can
be observed. It is not a claim of correct A845 support and may hang the GPU,
render incorrectly, or fail later during initialization.

Safe to run multiple times.
"""

import re
import sys

DEVICES_PY = "src/freedreno/common/freedreno_devices.py"
A845_ID = "44041430"

with open(DEVICES_PY, "r") as f:
    content = f.read()

if re.search(r"chip_id=0x(?:ffff)?44041430", content, re.IGNORECASE):
    print("  A845 experimental chip_id already present, skipping")
    sys.exit(0)

# Attach the A845 retail ID to the same add_gpus() list as A840.
# Prefer Mesa's canonical A840 ID, but accept any A840 entry so the script
# survives small upstream changes and the a840v2.py fixup.
m = re.search(
    r'^(\s*)GPUId\(chip_id=0x(?:ffff)?44050a[0-9a-f]{2}, name="Adreno \(TM\) 840(?:v2)?"\),.*\n',
    content,
    re.IGNORECASE | re.MULTILINE,
)

if not m:
    print("  FATAL: could not find an A840 GPUId entry to use as the bring-up template",
          file=sys.stderr)
    sys.exit(1)

indent = m.group(1)
extra = (
    f'{indent}GPUId(chip_id=0xffff44041430, name="Adreno (TM) 845 EXPERIMENTAL"),\n'
    f'{indent}GPUId(chip_id=0x44041430, name="Adreno (TM) 845 EXPERIMENTAL"), # KGSL retail\n'
)

content = content[:m.end()] + extra + content[m.end():]

try:
    compile(content, DEVICES_PY, "exec")
except SyntaxError as e:
    print(f"  FATAL: syntax error after patching at line {e.lineno}: {e.msg}",
          file=sys.stderr)
    sys.exit(1)

with open(DEVICES_PY, "w") as f:
    f.write(content)

print("  Added experimental Adreno 845 chip_id 0x44041430")
print("  WARNING: this aliases A845 to A840 GPUInfo for bring-up only; not production support")
