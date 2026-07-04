#!/usr/bin/env bash
# Worker for A8 dagger: no training; evaluate errvar_eval_swap using M0 checkpoint.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

source "${ROOT}/upair_portable_env.sh"
upair_activate

VARIANT="errvar_eval_swap"
M0_VARIANT="${UPAIR_EVAL_SWAP_M0_VARIANT:-main_full_d256_b4_r2}"
CONFIG="${UPAIR_CONFIG:-${ROOT}/configs/twc_comprehensive_mu32_base.yaml}"
DMRS_CASE="${UPAIR_DMRS_CASE:-1dmrs}"
SEED="${UPAIR_SEED:-7}"
STAGEB_PREFIX="${UPAIR_OPTUNA_STAGEB_PREFIX:-clean_b32_prb8_d256_40k_smart_trueDMRS_u34610_1dmrs_stageB}"
OUT_ROOT="${UPAIR_EVAL_CHUNK_ROOT:-${ROOT}/_isolated_eval_chunks}"

RECEIVERS_RAW="${UPAIR_PIPELINE_RECEIVERS:-upair5g_lmmse}"
USERS_RAW="${UPAIR_PIPELINE_USERS:-1,2,3,4}"
EBNOS_RAW="${UPAIR_PIPELINE_EBNOS:--4,-3,-2,-1,0,1,2,3,4}"
CHUNK_BATCHES="${UPAIR_PIPELINE_CHUNK_BATCHES:-20}"
MICRO="${UPAIR_PIPELINE_MICRO:-8}"

TARGET_BLOCK_ERRORS="${UPAIR_PIPELINE_TARGET_BLOCK_ERRORS:-}"
MAX_BATCHES="${UPAIR_PIPELINE_MAX_BATCHES:-}"
MIN_BATCHES="${UPAIR_PIPELINE_MIN_BATCHES:-}"

mkdir -p "${OUT_ROOT}" logs/pipeline

M0_CKPT="${UPAIR_EVAL_SWAP_M0_CHECKPOINT:-${ROOT}/TWC_plots_comprehensive/runs_rx16/seed${SEED}/${DMRS_CASE}/${M0_VARIANT}/checkpoints/best.weights.h5}"
if [[ ! -s "${M0_CKPT}" && "${M0_VARIANT}" == "main_full_d256_b4_r2" ]]; then
  legacy="${ROOT}/TWC_plots_comprehensive/runs_rx16/seed${SEED}/${DMRS_CASE}/main_d256_b4_r2/checkpoints/best.weights.h5"
  if [[ -s "${legacy}" ]]; then
    M0_CKPT="${legacy}"
  fi
fi

if [[ ! -s "${M0_CKPT}" ]]; then
  echo "[A8DAGGER] Missing M0 checkpoint:" >&2
  echo "  ${M0_CKPT}" >&2
  echo "Train main_full_d256_b4_r2 first, or set UPAIR_EVAL_SWAP_M0_CHECKPOINT." >&2
  exit 2
fi

best_json="${ROOT}/optuna/${STAGEB_PREFIX}_${VARIANT}_best_params.json"
if [[ ! -s "${best_json}" ]]; then
  echo "[A8DAGGER] Missing frozen recipe JSON for ${VARIANT}: ${best_json}" >&2
  exit 3
fi

split_csv() {
  local raw="${1//,/ }"
  # shellcheck disable=SC2206
  local arr=( ${raw} )
  printf '%s
' "${arr[@]}"
}

echo "================================================================================"
echo "[A8DAGGER] variant=${VARIANT}"
echo "[A8DAGGER] M0 checkpoint=${M0_CKPT}"
echo "[A8DAGGER] receivers=${RECEIVERS_RAW}"
echo "[A8DAGGER] users=${USERS_RAW}"
echo "[A8DAGGER] ebnos=${EBNOS_RAW}"
echo "================================================================================"

status_args_base=(--input-root "${OUT_ROOT}" --config "${CONFIG}" --variant "${VARIANT}" --chunk-batches "${CHUNK_BATCHES}")
if [[ -n "${TARGET_BLOCK_ERRORS}" ]]; then
  status_args_base+=(--target-block-errors "${TARGET_BLOCK_ERRORS}")
fi
if [[ -n "${MAX_BATCHES}" ]]; then
  status_args_base+=(--max-batches "${MAX_BATCHES}")
fi
if [[ -n "${MIN_BATCHES}" ]]; then
  status_args_base+=(--min-batches "${MIN_BATCHES}")
fi

while IFS= read -r receiver; do
  [[ -n "${receiver}" ]] || continue
  while IFS= read -r users; do
    [[ -n "${users}" ]] || continue
    while IFS= read -r ebno; do
      [[ -n "${ebno}" ]] || continue

      echo
      echo "--------------------------------------------------------------------------------"
      echo "[A8DAGGER] eval point receiver=${receiver} U=${users} Eb/N0=${ebno}"
      echo "--------------------------------------------------------------------------------"

      while true; do
        status_file="$(mktemp)"
        python "${ROOT}/scripts/isolated_eval_status.py"           "${status_args_base[@]}"           --receiver "${receiver}"           --num-users "${users}"           --ebno-db "${ebno}"           --shell > "${status_file}"
        # shellcheck disable=SC1090
        source "${status_file}"
        rm -f "${status_file}"

        echo "[A8DAGGER] status done=${DONE} reason=${REASON} chunks=${NUM_CHUNKS_DONE} batches=${NUM_BATCHES} block_errors=${BLOCK_ERRORS}/${TARGET_BLOCK_ERRORS} next_chunk=${NEXT_CHUNK}"

        if [[ "${DONE}" == "1" ]]; then
          break
        fi

        python -u "${ROOT}/scripts/run_isolated_eval_chunk.py"           --config "${CONFIG}"           --variant "${VARIANT}"           --dmrs-case "${DMRS_CASE}"           --seed "${SEED}"           --num-users "${users}"           --receiver "${receiver}"           --ebno-db "${ebno}"           --chunk-idx "${NEXT_CHUNK}"           --chunk-batches "${CHUNK_BATCHES}"           --receiver-microbatch-size "${MICRO}"           --stageb-prefix "${STAGEB_PREFIX}"           --optuna-dir "${ROOT}/optuna"           --checkpoint "${M0_CKPT}"           --output-root "${OUT_ROOT}"
      done

      safe_ebno="${ebno//-/m}"
      safe_ebno="${safe_ebno//./p}"
      merged_csv="${OUT_ROOT}/merged_${VARIANT}_u${users}_${receiver}_e${safe_ebno}.csv"
      python "${ROOT}/scripts/merge_isolated_eval_chunks.py"         --input-root "${OUT_ROOT}"         --output-csv "${merged_csv}"         --variant "${VARIANT}"         --receiver "${receiver}"         --num-users "${users}"         --ebno-db "${ebno}"

    done < <(split_csv "${EBNOS_RAW}")
  done < <(split_csv "${USERS_RAW}")
done < <(split_csv "${RECEIVERS_RAW}")

echo "[A8DAGGER] COMPLETE"
