#!/usr/bin/env bash
set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# ✅ 关键1：设置 PYTHONPATH（绝对路径，确保子进程继承）
export PYTHONPATH="${PROJECT_ROOT}/src:${PYTHONPATH}"

# ✅ 关键2：忽略 pkg_resources 警告（消除噪音）
export PYTHONWARNINGS="ignore::UserWarning:pkg_resources"

# ✅ 关键3：验证 ray 可用性（提前报错，避免训练中途失败）
if ! python -c "import ray; ray.init(num_cpus=1, include_dashboard=False); ray.shutdown()" 2>/dev/null; then
  echo "❌ CRITICAL: ray not working! Run:"
  echo "   sudo apt-get install -y build-essential libgl1 libglib2.0-0"
  echo "   pip install 'ray==2.9.3' --force-reinstall --no-cache-dir"
  exit 1
fi

# 参数解析
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <nproc_per_node> [hydra_overrides...]"
  exit 1
fi
nproc_per_node=$1
shift 1

SAVE_DIR="${PROJECT_ROOT}/checkpoints/run${nproc_per_node}gpu"
mkdir -p "${SAVE_DIR}"
LOG_FILE="${SAVE_DIR}/train_$(date "+%Y%m%d_%H%M%S").log"

# ✅ 关键4：用 env 显式传递 PYTHONPATH（防 nohup 重置环境）
nohup env PYTHONPATH="${PYTHONPATH}" \
  torchrun --standalone --nnodes=1 --nproc_per_node="${nproc_per_node}" \
    -m verl.trainer.fsdp_sft_trainer \
    --config-path "${PROJECT_ROOT}/configs" \
    --config-name sft_config \
    trainer.project_name=social-behavior-sft \
    trainer.experiment_name=run${nproc_per_node}gpu \
    "$@" > "${LOG_FILE}" 2>&1 &

echo "✅ Launched on ${nproc_per_node} GPUs"
echo "   Logs: ${LOG_FILE}"