#!/usr/bin/env bash
# Optional: run/reference M0 with baselines and perfect CSI.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export UPAIR_VARIANTS="${UPAIR_VARIANTS:-main_full_d256_b4_r2}"
export UPAIR_PIPELINE_RECEIVERS="${UPAIR_PIPELINE_RECEIVERS:-baseline_ls_lmmse,baseline_ls_2dlmmse_lmmse,upair5g_lmmse,perfect_csi_lmmse}"
exec bash "${ROOT}/upair_submit_7variant_pipeline.sh"
