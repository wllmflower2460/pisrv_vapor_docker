#!/usr/bin/env python3
"""
Session Worker Script
----------------------

Watches the /home/pi/appdata/sessions directory for new sessions
(video.mp4 exists but results.json does not) and runs hailortcli benchmark
on the detected HEF model.

Writes results.json with:
  - status (ok/error)
  - session name
  - timestamp
  - HEF path + model name
  - duration_sec (benchmark runtime)
  - parsed metrics (FPS, latency)
  - raw_tail (ANSI-stripped output tail)

Now includes atomic writes for results.json to prevent partial files.
"""

import time
import json
import subprocess
import pathlib
import os
import re
import sys
import fcntl

# Path where session directories live
SESSIONS = pathlib.Path(os.environ.get("SESSIONS_DIR", "/home/pi/appdata/sessions"))

# Optional override from environment
HEF_ENV = os.environ.get("HEF_PATH")

# Scan interval in seconds
INTERVAL = 2

# Maximum concurrent processing (to prevent device exhaustion)
MAX_CONCURRENT = 1
LOCK_FILE = SESSIONS / ".worker.lock"

# Regex to strip ANSI escape codes from CLI output
ANSI = re.compile(r'\x1B\[[0-?]*[ -/]*[@-~]')


def find_hef():
    """Locate a .hef model file, checking env override, known paths, then searching."""
    if HEF_ENV and pathlib.Path(HEF_ENV).exists():
        return HEF_ENV

  candidates = [
      "/usr/local/hailo/resources/models/hailo8/yolov8s.hef",      # YOLOv8 
  small
      "/usr/local/hailo/resources/models/hailo8/yolov5m_seg.hef",  # YOLOv5 
  medium seg
      "/usr/local/hailo/resources/models/hailo8/yolov11s.hef",     # YOLOv11 
  small
      "/opt/hailo/models/sample.hef",                              # Fallback
  ]
    for c in candidates:
        if pathlib.Path(c).exists():
            return c

    try:
        out = subprocess.run(
            [
                "bash", "-lc",
                "find /usr/local/hailo/resources/models /opt/hailo "
                "-type f -name '*.hef' 2>/dev/null | head -n1"
            ],
            capture_output=True, text=True, check=False
        ).stdout.strip()
        return out or None
    except Exception:
        return None


def parse_benchmark(text: str):
    """Parse FPS and latency metrics from hailortcli output."""
    r_hw_only = re.search(r"FPS\s*\(hw_only\)\s*=\s*([0-9.]+)", text)
    r_stream  = re.search(r"\(streaming\)\s*=\s*([0-9.]+)", text)
    r_lat     = re.search(r"Latency\s*\(hw\)\s*=\s*([0-9.]+)\s*ms", text)
    return {
        "fps_hw_only": float(r_hw_only.group(1)) if r_hw_only else None,
        "fps_streaming": float(r_stream.group(1)) if r_stream else None,
        "latency_ms": float(r_lat.group(1)) if r_lat else None,
    }


def _tail(text: str, n: int) -> str:
    """Return last n lines of text, or empty string if None."""
    return "\n".join((text or "").strip().splitlines()[-n:])


def _write_json_atomic(path: pathlib.Path, data: dict):
    """
    Write JSON atomically:
      - Write to <path>.tmp
      - Rename to final path
    Ensures partial writes never overwrite a good file.
    """
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    tmp_path.write_text(json.dumps(data, indent=2))
    tmp_path.replace(path)


def run_for_session(sdir: pathlib.Path):
    """Run benchmark for given session directory and write atomic results.json."""
    hef = find_hef()
    result = {
        "status": "starting",
        "session": sdir.name,
        "ts": time.time(),
        "hef": hef
    }

    if not hef:
        result.update(status="error", error="No HEF found", raw_tail="")
        _write_json_atomic(sdir / "results.json", result)
        return

    # Wait for video.mp4 to settle (size check)
    v = sdir / "video.mp4"
    try:
        s1 = v.stat().st_size
        time.sleep(1.0)
        s2 = v.stat().st_size
        if s2 != s1:
            time.sleep(1.0)
    except FileNotFoundError:
        pass

    print(f"Starting benchmark for session {sdir.name}")
    start = time.time()
    try:
        # Add timeout and better error handling for device issues
        bench = subprocess.run(
            ["hailortcli", "benchmark", "-t", "3", hef],  # Reduced from 5 to 3 seconds
            capture_output=True, text=True, check=True, timeout=30
        )
        dur = time.time() - start
        tail = _tail(bench.stdout, 12)
        clean_tail = ANSI.sub("", tail)
        summary = parse_benchmark(bench.stdout)

        result.update(
            status="ok",
            summary=summary,
            raw_tail=clean_tail,
            model=pathlib.Path(hef).stem,
            duration_sec=round(dur, 2),
        )
        print(f"Completed benchmark for session {sdir.name} in {dur:.2f}s")

    except subprocess.TimeoutExpired as e:
        dur = time.time() - start
        result.update(
            status="error",
            error="benchmark timeout",
            raw_tail=f"Benchmark timed out after {dur:.2f}s",
            model=pathlib.Path(hef).stem,
            duration_sec=round(dur, 2),
        )
        print(f"Benchmark timeout for session {sdir.name}")
        
    except subprocess.CalledProcessError as e:
        dur = time.time() - start
        stdout_tail = _tail(e.stdout or "", 20)
        stderr_text = ANSI.sub("", e.stderr or "")
        
        # Check for specific Hailo device issues
        if "HAILO_OUT_OF_PHYSICAL_DEVICES" in stderr_text:
            result.update(
                status="error", 
                error="Hailo device busy - will retry later",
                stderr=stderr_text[:500],  # Truncate long error messages
                raw_tail=ANSI.sub("", stdout_tail),
                model=pathlib.Path(hef).stem,
                duration_sec=round(dur, 2),
            )
            print(f"Hailo device busy for session {sdir.name} - will retry")
            # Don't write results.json yet - let it retry later
            return
        else:
            result.update(
                status="error",
                error="benchmark failed",
                stderr=stderr_text[:500],
                raw_tail=ANSI.sub("", stdout_tail),
                model=pathlib.Path(hef).stem,
                duration_sec=round(dur, 2),
            )
            print(f"Benchmark failed for session {sdir.name}: {e.returncode}")

    except Exception as e:
        dur = time.time() - start
        result.update(
            status="error",
            error=str(e),
            raw_tail="",
            model=pathlib.Path(hef).stem,
            duration_sec=round(dur, 2),
        )
        print(f"Unexpected error for session {sdir.name}: {e}")

    _write_json_atomic(sdir / "results.json", result)


def main():
    """Main loop watching sessions dir for new work."""
    if not SESSIONS.exists():
        print(f"missing {SESSIONS}", file=sys.stderr)
        sys.exit(1)

    print(f"Worker watching: {SESSIONS}")
    print(f"Worker running as user: {os.getuid()}")
    
    while True:
        try:
            # Find sessions that need processing
            pending_sessions = []
            
            for sdir in SESSIONS.iterdir():
                if not sdir.is_dir():
                    continue
                    
                # Check permissions and ownership before processing
                try:
                    stat_info = sdir.stat()
                except PermissionError as e:
                    print(f"Permission denied accessing {sdir.name}: {e}", file=sys.stderr)
                    continue
                except Exception as e:
                    print(f"Error checking {sdir.name}: {e}", file=sys.stderr)
                    continue
                
                video_file = sdir / "video.mp4"
                results_file = sdir / "results.json"
                
                if video_file.exists() and not results_file.exists():
                    pending_sessions.append(sdir)
            
            if pending_sessions:
                print(f"Found {len(pending_sessions)} pending sessions")
                
                # Process only one session at a time to avoid device exhaustion
                session_to_process = pending_sessions[0]  # Process oldest first
                print(f"Processing session: {session_to_process.name}")
                
                try:
                    run_for_session(session_to_process)
                    print(f"Completed session: {session_to_process.name}")
                    
                    # Add a small delay between sessions to let the device recover
                    time.sleep(1)
                    
                except PermissionError as e:
                    print(f"Permission denied processing {session_to_process.name}: {e}", file=sys.stderr)
                    # Write a simple error results.json if we can
                    try:
                        error_result = {
                            "status": "error",
                            "session": session_to_process.name,
                            "ts": time.time(),
                            "error": f"Permission denied: {e}",
                            "raw_tail": ""
                        }
                        _write_json_atomic(session_to_process / "results.json", error_result)
                    except Exception:
                        pass  # Can't even write error file
                        
                except Exception as e:
                    print(f"Error processing {session_to_process.name}: {e}", file=sys.stderr)
            else:
                # No pending sessions - shorter sleep
                time.sleep(INTERVAL)
                continue
                
        except Exception as e:
            print("loop error:", e, file=sys.stderr)

        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
