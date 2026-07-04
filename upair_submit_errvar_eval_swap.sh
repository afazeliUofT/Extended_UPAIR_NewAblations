#!/usr/bin/env bash
# Submit A8 dagger: M0 weights, but LS err_var fed to the detector at eval.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

source "${ROOT}/upair_submit_lib.sh"
upair_ensure_venv

mkdir -p "${UPAIR_REPO_ROOT}/logs/pipeline" "${UPAIR_REPO_ROOT}/logs/submit"

TIME_LIMIT="${UPAIR_TIME_PIPELINE:-30:00:00}"
export UPAIR_GRES="${UPAIR_GRES:-gpu:h100:1}"
export UPAIR_MEM="${UPAIR_MEM:-32G}"
export UPAIR_CPUS="${UPAIR_CPUS:-8}"

job="upairA8dagger"
log="${UPAIR_REPO_ROOT}/logs/pipeline/pipeline_errvar_eval_swap_%j.out"
jobfile="${UPAIR_REPO_ROOT}/logs/submit/pipeline_errvar_eval_swap.sbatch"
upair_write_sbatch_header "${jobfile}" "${job}" "${TIME_LIMIT}" "${log}"

cat >> "${jobfile}" <<SBATCH
set -euo pipefail
cd "${UPAIR_REPO_ROOT}"
source "${UPAIR_REPO_ROOT}/upair_portable_env.sh"
upair_activate

export PYTHONUNBUFFERED=1
export PYTHONDONTWRITEBYTECODE=1
export TF_CPP_MIN_LOG_LEVEL="\${TF_CPP_MIN_LOG_LEVEL:-2}"
export TF_CPP_VMODULE="\${TF_CPP_VMODULE:-bfc_allocator=0}"
export TF_FORCE_GPU_ALLOW_GROWTH="\${TF_FORCE_GPU_ALLOW_GROWTH:-true}"
export TF_GPU_ALLOCATOR="\${TF_GPU_ALLOCATOR:-cuda_malloc_async}"

export UPAIR_CONFIG="\${UPAIR_CONFIG:-${UPAIR_REPO_ROOT}/configs/twc_comprehensive_mu32_base.yaml}"
export UPAIR_DMRS_CASE="\${UPAIR_DMRS_CASE:-1dmrs}"
export UPAIR_SEED="\${UPAIR_SEED:-7}"
export UPAIR_OPTUNA_STAGEB_PREFIX="\${UPAIR_OPTUNA_STAGEB_PREFIX:-clean_b32_prb8_d256_40k_smart_trueDMRS_u34610_1dmrs_stageB}"
export UPAIR_PIPELINE_RECEIVERS="\${UPAIR_PIPELINE_RECEIVERS:-upair5g_lmmse}"
export UPAIR_PIPELINE_USERS="\${UPAIR_PIPELINE_USERS:-1,2,3,4}"
export UPAIR_PIPELINE_EBNOS="\${UPAIR_PIPELINE_EBNOS:--4,-3,-2,-1,0,1,2,3,4}"
export UPAIR_PIPELINE_CHUNK_BATCHES="\${UPAIR_PIPELINE_CHUNK_BATCHES:-20}"
export UPAIR_PIPELINE_MICRO="\${UPAIR_PIPELINE_MICRO:-8}"

bash "${UPAIR_REPO_ROOT}/upair_errvar_eval_swap_worker.sh"
SBATCH

echo "[A8DAGGER-SUBMIT] submitting errvar_eval_swap"
upair_submit_job_script "${jobfile}"
