# Edge HEVC visibleRect PoC

Minimal proof of concept for checking a Microsoft Edge for Windows HEVC decoder issue where WebCodecs may expose an unexpectedly small `VideoFrame.visibleRect`.

The repo contains a raw Annex B HEVC sample with:

- Coded size: `1952x1088`
- Expected visible size: `1928x1088`
- SPS conformance crop: right crop of 24 luma pixels

`index.html` decodes the sample with WebCodecs, draws the original decoded `VideoFrame`, then creates a corrected `VideoFrame` with the expected `visibleRect` and draws that next to it.

## Live Repro

https://anosatsuk124.github.io/edge-visible-rect-poc/

## Security Impact

This PoC is **not believed to demonstrate a security vulnerability**. It is intended to show a rendering / decoder correctness issue where Edge may report an unexpectedly small `VideoFrame.visibleRect` for a valid HEVC stream.

The observed behavior is limited to incorrect frame crop / visible rectangle handling. This PoC does not demonstrate memory corruption, sandbox escape, privilege escalation, data disclosure, or arbitrary code execution.

## Screenshots

### Microsoft Edge

<img width="1997" height="948" alt="localhost_8000_" src="https://github.com/user-attachments/assets/40badede-7ad2-46ce-bc34-a3e2ee1677d8" />

### Google Chrome

<img width="2005" height="945" alt="localhost_8000_ (1)" src="https://github.com/user-attachments/assets/3fbe153d-d656-41cd-bc65-2dcca8286b8a" />

## Requirements

- A browser with WebCodecs `VideoDecoder` support.
- HEVC decode support in that browser.
- For the intended reproduction: Microsoft Edge on Windows with HEVC support installed.
- A local HTTP server. Do not open `index.html` directly from `file://`.
- Docker, only if you want to regenerate the sample stream.

Tested browser results:

| Browser | Version | Platform | Result |
| --- | --- | --- | --- |
| Microsoft Edge | `Version 148.0.3967.96 (Official build) (64-bit)` | Windows | Reproduces |
| Microsoft Edge Canary | `Edg/150.0.4071.0` | Windows | Reproduces |
| Google Chrome Stable | `Version 147.0.7727.117 (Official Build) (64-bit)` | Windows | Does not reproduce |

Tested Windows environment:

| Field | Value |
| --- | --- |
| OS Name | Microsoft Windows 11 Pro |
| Version | 10.0.26100 Build 26100 |
| Other OS Description | Not Available |
| OS Manufacturer | Microsoft Corporation |
| System Manufacturer | LENOVO |
| System Model | 21CES2FE0B |
| System Type | x64-based PC |
| System SKU | LENOVO_MT_21CE_BU_Think_FM_ThinkPad X1 Yoga Gen 7 |
| Processor | 12th Gen Intel(R) Core(TM) i7-1270P, 2200 Mhz, 12 Core(s), 16 Logical Processor(s) |

Tested Edge and GPU environment:

| Field | Value |
| --- | --- |
| Edge version | Edg/148.0.3967.96 |
| OS | Windows NT 10.0.26100.6584 |
| GPU | Intel Iris Xe Graphics |
| GPU vendor/device | 0x8086 / 0x46a6 |
| Driver version | 32.0.101.7026 |
| Video Decode | Hardware accelerated |
| Video Encode | Hardware accelerated |
| HEVC installed / activable / version | Not recorded |
| AV1 installed / activable / version | Not recorded |
| Hardware acceleration on/off result | Not recorded |

Tested Edge Canary and GPU environment:

The issue also reproduces on Microsoft Edge Canary. The following data was exported from `edge://gpu` on 2026-06-03.

| Field | Value |
| --- | --- |
| Edge version | Edg/150.0.4071.0 |
| OS | Windows NT 10.0.26100.6584 |
| GPU | Intel Iris Xe Graphics |
| GPU vendor/device | 0x8086 / 0x46a6 |
| Driver version | 32.0.101.7026 |
| Canvas | Hardware accelerated |
| Compositing | Hardware accelerated |
| Rasterization | Hardware accelerated |
| Video Decode | Hardware accelerated |
| Video Encode | Hardware accelerated |
| WebGL | Hardware accelerated |
| WebGPU | Hardware accelerated |
| WebNN | Disabled |

## Run

Serve this directory over localhost:

```sh
python3 -m http.server 8000
```

Then open:

```text
http://localhost:8000/
```

The page starts automatically when loaded over HTTP. You can also press **Run PoC** manually.

## Interpreting Results

Expected healthy behavior:

- `decoded visibleRect` is `{ x: 0, y: 0, width: 1928, height: 1088 }`
- The original and corrected canvases look the same.
- The original badge shows `normal`.

Likely bug reproduction:

- `decoded visibleRect` is much smaller than the expected `1928x1088`.
- The original canvas looks zoomed or cropped.
- The corrected canvas shows the expected `1928x1088` image.
- The original badge shows `Edge bug likely`.

The status panel includes the user agent, selected HEVC codec string, decoded dimensions, and `visibleRect` values.

## Regenerate the HEVC Sample

Run:

```sh
./generate-video.sh
```

The script uses a pinned Docker image:

```text
docker.io/jrottenberg/ffmpeg@sha256:4641478865a2387bb1d180dd9263e7226dab887c0789e02fa077fe919ef543df
```

It generates `edge-visible-rect-poc.h265`, validates the stream, and writes:

- `edge-visible-rect-poc.h265.sha256`
- `video-build.log`
- `video-build-info.txt`
- `video-ffprobe.log`
- `video-trace-headers.log`

Expected validation checks:

- `width=1928`
- `height=1088`
- `coded_width=1952`
- `coded_height=1088`
- `has_b_frames=0`
- `pic_width_in_luma_samples = 1952`
- `pic_height_in_luma_samples = 1088`
- `conf_win_right_offset = 12`

For this 4:2:0 HEVC stream, `conf_win_right_offset = 12` means a 24-pixel right crop, producing the expected visible width of `1928`.

## Files

- `index.html`: Static WebCodecs test page.
- `edge-visible-rect-poc.h265`: Raw HEVC sample used by the page.
- `generate-video.sh`: Reproducible sample generation and validation script.
- `video-*.log`, `video-build-info.txt`: Build and validation outputs for the committed sample.
- `edge-visible-rect-poc.h265.sha256`: SHA-256 checksum for the sample.

## Notes

HEVC browser support depends on the OS, browser, installed codecs, and hardware/software decoder availability. This PoC decodes the first frame of a raw HEVC stream; it is not intended to test MP4 playback behavior.
