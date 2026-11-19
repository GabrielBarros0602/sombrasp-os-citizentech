#!/usr/bin/env bash
# Agente SombraSP (CitizenTech): a cada INTERVAL segundos mede CPU, memória e disco do nó,
# grava o estado em /srv/citizentech/data/status.txt (equipe, usuário executor, hostname)
# e emite ALERTA quando algum recurso passa do limite.
# Executado pelo systemd como o aluno executor (User= da unit), nunca como root.
# Falha de gravação => ERRO no stderr e exit 1, para o systemd perceber e reiniciar.
set -u
umask 007

PROJECT="SombraSP"
TEAM="RM556309"
DATA_DIR="${DATA_DIR:-/srv/citizentech/data}"
LOG_DIR="${LOG_DIR:-/srv/citizentech/logs}"
STATUS_FILE="$DATA_DIR/status.txt"
INTERVAL="${INTERVAL:-30}"
CPU_MAX="${CPU_MAX:-80}"     # limites em %; ajustáveis por Environment= na unit
MEM_MAX="${MEM_MAX:-80}"
DISK_MAX="${DISK_MAX:-80}"
# Sob o systemd, o prefixo <4> grava a linha no journal com prioridade warning.
WARN=""; [[ -n ${INVOCATION_ID:-} ]] && WARN="<4>"

falha() { printf 'ERRO: nao foi possivel gravar %s\n' "$1" >&2; exit 1; }

cpu_ticks() {  # total e ocioso (idle+iowait) desde o boot, de /proc/stat
  local _ u n s i w q sq st
  read -r _ u n s i w q sq st _ < /proc/stat
  echo "$((u + n + s + i + w + q + sq + st)) $((i + w))"
}

cpu_pct() {    # uso de CPU medido numa janela de 1 segundo
  local t0 i0 t1 i1
  read -r t0 i0 < <(cpu_ticks); sleep 1; read -r t1 i1 < <(cpu_ticks)
  local dt=$((t1 - t0)); (( dt > 0 )) || dt=1
  echo $(( (dt - (i1 - i0)) * 100 / dt ))
}

mem_pct() { awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {printf "%d\n", (t - a) * 100 / t}' /proc/meminfo; }

disk_pct() { df --output=pcent "$DATA_DIR" | tail -n 1 | tr -dc '0-9'; }

while true; do
  cpu="$(cpu_pct)"; mem="$(mem_pct)"; disk="$(disk_pct)"
  alertas=()
  (( cpu  >= CPU_MAX ))  && alertas+=("CPU ${cpu}%>=${CPU_MAX}%")
  (( mem  >= MEM_MAX ))  && alertas+=("MEMORIA ${mem}%>=${MEM_MAX}%")
  (( disk >= DISK_MAX )) && alertas+=("DISCO ${disk}%>=${DISK_MAX}%")
  resumo="nenhum"; (( ${#alertas[@]} )) && resumo="$(IFS=';'; echo "${alertas[*]}")"

  STATUS="$(date --iso-8601=seconds) | project=${PROJECT} | equipe=${TEAM} | usuario=$(id -un) | node=$(hostname)"
  STATUS+=" | cpu=${cpu}% | mem=${mem}% | disco=${disk}% | alerta=${resumo} | status=OK"

  # status=OK só é exibido depois que o estado foi gravado no volume de dados.
  printf '%s\n' "$STATUS" > "$STATUS_FILE" || falha "$STATUS_FILE"
  printf '%s\n' "$STATUS" >> "$LOG_DIR/agent.log" || falha "$LOG_DIR/agent.log"
  printf '%s\n' "$STATUS"

  for a in "${alertas[@]}"; do
    linha="$(date --iso-8601=seconds) | ALERTA ${a} | node=$(hostname) | equipe=${TEAM}"
    printf '%s\n' "$linha" >> "$LOG_DIR/alertas.log" || falha "$LOG_DIR/alertas.log"
    printf '%sALERTA: %s\n' "$WARN" "$a"
  done

  sleep "$INTERVAL"
done
