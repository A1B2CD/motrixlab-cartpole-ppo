"""Print a hardware / software report for a MotrixLab training node.

Works on Windows and Linux. Run it with the project virtual environment:

    uv run --no-sync python tools/check_env.py

The same script can be copied to the cloud GPU instance (巧工平台) and run
there to compare the server configuration with the local machine.
"""

from __future__ import annotations

import json
import platform
import shutil
import subprocess
import sys
from pathlib import Path


def run(cmd: list[str]) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        return (out.stdout or out.stderr).strip()
    except Exception as exc:  # noqa: BLE001
        return f"<unavailable: {exc}>"


def cpu_info() -> dict:
    if sys.platform == "win32":
        name = run(["powershell", "-NoProfile", "-Command", "(Get-CimInstance Win32_Processor).Name"])
        cores = run(["powershell", "-NoProfile", "-Command", "(Get-CimInstance Win32_Processor).NumberOfCores"])
        threads = run(
            ["powershell", "-NoProfile", "-Command", "(Get-CimInstance Win32_Processor).NumberOfLogicalProcessors"]
        )
        return {"model": name, "physical_cores": cores, "logical_cores": threads}
    model = ""
    for line in Path("/proc/cpuinfo").read_text().splitlines():
        if line.startswith("model name"):
            model = line.split(":", 1)[1].strip()
            break
    return {"model": model, "logical_cores": os_cpu_count()}


def os_cpu_count() -> int:
    import os

    return os.cpu_count() or 0


def memory_gb() -> float | None:
    try:
        import psutil  # type: ignore

        return round(psutil.virtual_memory().total / 1024**3, 1)
    except Exception:  # noqa: BLE001
        pass
    if sys.platform == "win32":
        value = run(
            [
                "powershell",
                "-NoProfile",
                "-Command",
                "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory",
            ]
        )
        try:
            return round(int(value) / 1024**3, 1)
        except ValueError:
            return None
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            if line.startswith("MemTotal"):
                return round(int(line.split()[1]) / 1024**2, 1)
    except Exception:  # noqa: BLE001
        pass
    return None


def gpu_info() -> list[dict]:
    if not shutil.which("nvidia-smi"):
        return []
    query = run(
        [
            "nvidia-smi",
            "--query-gpu=name,memory.total,driver_version,compute_cap",
            "--format=csv,noheader,nounits",
        ]
    )
    gpus = []
    for line in query.splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) >= 4:
            gpus.append(
                {
                    "name": parts[0],
                    "memory_mb": parts[1],
                    "driver": parts[2],
                    "compute_capability": parts[3],
                }
            )
    return gpus


def packages() -> dict:
    from importlib.metadata import version

    result = {}
    for mod, dist in [
        ("torch", "torch"),
        ("motrixsim", "motrixsim"),
        ("skrl", "skrl"),
        ("numpy", "numpy"),
        ("gymnasium", "gymnasium"),
        ("tensorboard", "tensorboard"),
    ]:
        try:
            __import__(mod)
            result[mod] = version(dist)
        except Exception as exc:  # noqa: BLE001
            result[mod] = f"missing ({exc})"
    try:
        import torch

        result["torch_cuda_available"] = torch.cuda.is_available()
        result["torch_cuda_device_count"] = torch.cuda.device_count()
        if torch.cuda.is_available():
            result["torch_cuda_device"] = torch.cuda.get_device_name(0)
    except Exception:  # noqa: BLE001
        pass
    return result


def main() -> None:
    report = {
        "hostname": platform.node(),
        "os": f"{platform.system()} {platform.release()} ({platform.machine()})",
        "python": sys.version.split()[0],
        "python_executable": sys.executable,
        "cpu": cpu_info(),
        "memory_gb": memory_gb(),
        "gpu": gpu_info(),
        "disk_free_gb": {
            str(p): round(shutil.disk_usage(p).free / 1024**3, 1)
            for p in (
                [Path(f"{letter}:/") for letter in "CDEFGH"]
                if sys.platform == "win32"
                else [Path("/")]
            )
            if p.exists()
        },
        "packages": packages(),
        "nvidia_smi": run(["nvidia-smi"]) if shutil.which("nvidia-smi") else "nvidia-smi not found",
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
