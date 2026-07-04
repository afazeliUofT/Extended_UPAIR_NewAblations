#!/usr/bin/env bash
# Submit the trainable mechanism-ablation arms.
# By default this evaluates only upair5g_lmmse to avoid re-running unchanged baselines
# for every ablation arm. Override UPAIR_PIPELINE_RECEIVERS if needed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export UPAIR_PIPELINE_RECEIVERS="${UPAIR_PIPELINE_RECEIVERS:-upair5g_lmmse}"
exec bash "${ROOT}/upair_submit_7variant_pipeline.sh"
