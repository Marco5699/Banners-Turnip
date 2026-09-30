#!/usr/bin/env bash
# Mesa fixes every leg ships - Android, Wayland, Linux, perf - because they are KGSL bugs, not
# platform ones. Run from the Mesa tree: apply_common.sh <mesa-dir>. Any patch that does not apply,
# or whose result is not in the tree afterwards, fails the build: a driver without the fix must
# not be zipped. When Mesa upstream carries a fix, delete the patch here (see SOURCE).
set -eu
cd "${1:?usage: apply_common.sh <mesa-dir>}"
here="$(cd "$(dirname "$0")" && pwd)"

# Order: our syncobj fix, Max's WinNative series in its own number order (winnative/0001-0006,
# which build on each other), then our poll fix.
for p in "$here/kgsl-syncobj-merge-ts-fd.patch" "$here"/winnative/0*.patch \
         "$here/kgsl-zero-timeout-poll.patch"; do
	echo "[common] applying $(basename "$p")"
	rc=0
	out="$(patch -p1 -N --fuzz=3 --no-backup-if-mismatch < "$p" 2>&1)" || rc=$?
	echo "$out" | sed 's/^/    /'
	[ "$rc" = 0 ] || { echo "[common] $(basename "$p") did not apply cleanly (patch exit $rc) - rebase it onto this Mesa, or drop it if upstream has the fix" >&2; exit 1; }
done
[ "$(ls "$here"/winnative/0*.patch | wc -l)" = 6 ] || { echo "[common] expected 6 patches in winnative/" >&2; exit 1; }

# Assert the result rather than trust the patch.
[ "$(grep -c "int ret_fd = kgsl_syncobj_ts_to_fd(&ret)" src/freedreno/vulkan/tu_knl_kgsl.cc)" = 2 ] \
	|| { echo "[common] kgsl-syncobj-merge-ts-fd did not reach tu_knl_kgsl.cc" >&2; exit 1; }
[ -f src/freedreno/vulkan/tu_mesh.cc ] && grep -q "EXT_mesh_shader = tu_has_mesh_shader(device)" src/freedreno/vulkan/tu_device.cc \
	|| { echo "[common] winnative/0001 (mesh shaders) did not reach tu_mesh.cc / tu_device.cc" >&2; exit 1; }
grep -q "tu_mesh.cc" src/freedreno/vulkan/meson.build \
	|| { echo "[common] winnative/0001 (mesh shaders) did not reach meson.build" >&2; exit 1; }
grep -q "HALF_SUBGROUP_SIZE 32" src/freedreno/ir3/ir3_lower_subgroups.c \
	|| { echo "[common] winnative/0002 (wave32 subgroups) did not reach ir3_lower_subgroups.c" >&2; exit 1; }
grep -q "cube_coord_hang_quirk = True" src/freedreno/common/freedreno_devices.py \
	|| { echo "[common] winnative/0003 (cube-coord sanitize) did not reach freedreno_devices.py" >&2; exit 1; }
grep -q "SP_GFX_BINDLESS_INVALIDATE" src/freedreno/vulkan/tu_cmd_buffer.h \
	|| { echo "[common] winnative/0004 (bindless invalidate) did not reach tu_cmd_buffer.h" >&2; exit 1; }
grep -q "KGSL_MEMFLAGS_VBO" src/freedreno/vulkan/tu_knl_kgsl.cc \
	|| { echo "[common] winnative/0005 (IB VBO alias) did not reach tu_knl_kgsl.cc" >&2; exit 1; }
grep -q "KGSL_IB_CACHE_MAX_BYTES" src/freedreno/vulkan/tu_knl_kgsl.cc \
	|| { echo "[common] winnative/0006 (IB cache) did not reach tu_knl_kgsl.cc" >&2; exit 1; }
grep -q "kgsl_timestamp_retired(fd, context_id, timestamp) ? VK_SUCCESS : VK_TIMEOUT" src/freedreno/vulkan/tu_knl_kgsl.cc \
	|| { echo "[common] kgsl-zero-timeout-poll did not reach tu_knl_kgsl.cc" >&2; exit 1; }
