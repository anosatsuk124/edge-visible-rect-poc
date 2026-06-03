#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE="docker.io/jrottenberg/ffmpeg@sha256:4641478865a2387bb1d180dd9263e7226dab887c0789e02fa077fe919ef543df"
PLATFORM="linux/amd64"
OUTPUT_NAME="edge-visible-rect-poc.h265"
OUTPUT_PATH="${SCRIPT_DIR}/${OUTPUT_NAME}"
BUILD_LOG="${SCRIPT_DIR}/video-build.log"
BUILD_INFO="${SCRIPT_DIR}/video-build-info.txt"
PROBE_LOG="${SCRIPT_DIR}/video-ffprobe.log"
TRACE_LOG="${SCRIPT_DIR}/video-trace-headers.log"
SHA_FILE="${OUTPUT_PATH}.sha256"

run_ffmpeg() {
	docker run --platform "${PLATFORM}" --rm \
		--entrypoint ffmpeg \
		-v "${SCRIPT_DIR}:/work" \
		"${IMAGE}" "$@"
}

run_ffprobe() {
	docker run --platform "${PLATFORM}" --rm \
		--entrypoint ffprobe \
		-v "${SCRIPT_DIR}:/work" \
		"${IMAGE}" "$@"
}

require_line() {
	local pattern="$1"
	local file="$2"
	if ! grep -Eq "${pattern}" "${file}"; then
		echo "Expected pattern not found in ${file}: ${pattern}" >&2
		exit 1
	fi
}

cd "${SCRIPT_DIR}"

{
	echo "Image: ${IMAGE}"
	echo "Platform: ${PLATFORM}"
	echo
	echo "Expected tool versions:"
	echo "  ffmpeg version 6.1"
	echo "  x265 HEVC encoder version 3.6+1-aa7f602f7"
	echo
	echo "Actual ffmpeg -version:"
} > "${BUILD_INFO}"

run_ffmpeg -version >> "${BUILD_INFO}" 2>&1

echo "Generating ${OUTPUT_NAME}..."
run_ffmpeg \
	-y \
	-f lavfi \
	-i "testsrc2=size=1952x1088:rate=10:duration=1" \
	-vf "drawbox=x=0:y=720:w=1952:h=2:color=red:t=fill,drawbox=x=0:y=1080:w=1952:h=8:color=lime:t=fill" \
	-c:v libx265 \
	-profile:v main \
	-preset ultrafast \
	-x265-params "pools=none:frame-threads=1:wpp=0:bframes=0:keyint=10:min-keyint=10:repeat-headers=1:info=0:open-gop=0:aud=1" \
	-an \
	-bsf:v hevc_metadata=crop_right=24 \
	-f hevc \
	"/work/${OUTPUT_NAME}" \
	2>&1 | tee "${BUILD_LOG}"

echo "Validating stream dimensions..."
run_ffprobe \
	-hide_banner \
	-show_streams \
	-select_streams v:0 \
	"/work/${OUTPUT_NAME}" \
	> "${PROBE_LOG}" 2>&1

require_line '^width=1928$' "${PROBE_LOG}"
require_line '^height=1088$' "${PROBE_LOG}"
require_line '^coded_width=1952$' "${PROBE_LOG}"
require_line '^coded_height=1088$' "${PROBE_LOG}"
require_line '^has_b_frames=0$' "${PROBE_LOG}"

echo "Validating SPS conformance crop..."
run_ffmpeg \
	-hide_banner \
	-i "/work/${OUTPUT_NAME}" \
	-c copy \
	-bsf:v trace_headers \
	-f null - \
	> "${TRACE_LOG}" 2>&1

require_line 'pic_width_in_luma_samples.*= 1952' "${TRACE_LOG}"
require_line 'pic_height_in_luma_samples.*= 1088' "${TRACE_LOG}"
require_line 'conf_win_right_offset.*= 12' "${TRACE_LOG}"

if command -v shasum >/dev/null 2>&1; then
	shasum -a 256 "${OUTPUT_PATH}" > "${SHA_FILE}"
else
	sha256sum "${OUTPUT_PATH}" > "${SHA_FILE}"
fi

{
	echo
	echo "Output:"
	cat "${SHA_FILE}"
	echo
	echo "Validation:"
	echo "  ${PROBE_LOG}"
	echo "  ${TRACE_LOG}"
} >> "${BUILD_INFO}"

echo "Done."
cat "${SHA_FILE}"
