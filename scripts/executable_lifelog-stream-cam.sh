#!/bin/bash
# Stream Mac webcam → RTSP on lifelog GPU host (nazarf-cachyos:8554/cam).
# capture-svc on the host reads from rtsp://127.0.0.1:8554/cam and runs tier1/tier2.
#
# Camera index: 0=FaceTime HD, 1=Nazarf Camera (iPhone Continuity), 2=Desk View, 3/4=screens.
# Override with: CAM=1 ~/scripts/lifelog-stream-cam.sh
#
# Stop: Ctrl+C. MediaMTX path stays "no publisher" until something else pushes.

set -euo pipefail

CAM="${CAM:-0}"
HOST="${HOST:-nazarf-cachyos}"
PORT="${PORT:-8554}"
PATH_NAME="${PATH_NAME:-cam}"
PUB_USER="${PUB_USER:-publisher}"
PUB_PASS="${PUB_PASS:?set PUB_PASS to the mediamtx publish password from /etc/mediamtx.yml on the host}"

WIDTH="${WIDTH:-1280}"
HEIGHT="${HEIGHT:-720}"
FPS_OUT="${FPS_OUT:-15}"
FPS_IN="${FPS_IN:-30}"

RTSP_URL="rtsp://${PUB_USER}:${PUB_PASS}@${HOST}:${PORT}/${PATH_NAME}"

echo "Streaming AVFoundation camera ${CAM} → ${RTSP_URL}"
echo "  in:  ${WIDTH}x${HEIGHT} @ ${FPS_IN}fps  →  out: ${WIDTH}x${HEIGHT} @ ${FPS_OUT}fps  (H.264 zerolatency, no audio)"
echo

exec ffmpeg -hide_banner -loglevel warning \
  -f avfoundation -framerate "${FPS_IN}" -video_size "${WIDTH}x${HEIGHT}" -i "${CAM}" \
  -vf "fps=${FPS_OUT}" \
  -c:v libx264 -preset veryfast -tune zerolatency -pix_fmt yuv420p -g "$((FPS_OUT * 2))" \
  -an \
  -f rtsp -rtsp_transport tcp \
  "${RTSP_URL}"
