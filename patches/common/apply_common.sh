#!/usr/bin/env bash
# Mesa fixes every leg ships - Android, Wayland, Linux, perf - because they are KGSL bugs, not
# platform ones. Run from the Mesa tree: apply_common.sh <mesa-dir>. Any patch that does not apply,
# or whose result is not in the tree afterwards, fails the build: a driver without the fix must
# not be zipped. When Mesa upstream carries a fix, delete the patch here (see SOURCE).
set -eu
cd "${1:?usage: apply_common.sh <mesa-dir>}"
here="$(cd "$(dirname "$0")" && pwd)"

for p in "$here/kgsl-syncobj-merge-ts-fd.patch"; do
	echo "[common] applying $(basename "$p")"
	rc=0
	out="$(patch -p1 -N --fuzz=3 --no-backup-if-mismatch < "$p" 2>&1)" || rc=$?
	echo "$out" | sed 's/^/    /'
	[ "$rc" = 0 ] || { echo "[common] $(basename "$p") did not apply cleanly (patch exit $rc) - rebase it onto this Mesa, or drop it if upstream has the fix" >&2; exit 1; }
done

# Assert the result rather than trust the patch.
[ "$(grep -c "int ret_fd = kgsl_syncobj_ts_to_fd(&ret)" src/freedreno/vulkan/tu_knl_kgsl.cc)" = 2 ] \
	|| { echo "[common] kgsl-syncobj-merge-ts-fd did not reach tu_knl_kgsl.cc" >&2; exit 1; }
