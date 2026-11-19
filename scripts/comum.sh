# shellcheck shell=bash
# Dados da equipe e funções de auditoria usados por todos os scripts (carregado com "source").
# Altere SOMENTE este bloco se mudar integrante, RM, domínio ou IP.

PROJECT="SombraSP"
TEAM_RM="RM556309"                       # RM do líder (vai no hostname e no agente)
DOMAIN="sombrasp.test"
ADMIN="GabrielCisoto_RM556309"           # aluno administrador (sudo)
EXECUTOR="FelipeOliveira_RM556319"       # aluno executor do agente (sem sudo, User= das units)
ALUNOS=("$ADMIN" "$EXECUTOR")
GROUP="citizenops"
NODE_HOST="ct-node-rm556309"
CLIENT_HOST="ct-client-rm556309"
NODE_IP="192.168.56.10"
CLIENT_IP="192.168.56.20"
PREFIX="24"
BASE="/srv/citizentech"
AUDIT_DIR="/var/log/citizentech"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_NAME="$(basename "$0" .sh)"

# Uma linha de auditoria: quando, quem (aluno real por trás do sudo), onde e o quê.
passo() {
  printf '[%s] [%s@%s] %s\n' "$(date --iso-8601=seconds)" "${SUDO_USER:-$(id -un)}" "$(hostname)" "$*"
}

exige_root() {
  [[ $EUID -eq 0 ]] || { echo "Execute com sudo: sudo bash $0 $*" >&2; exit 1; }
}

# Copia toda a saída do script para /var/log/citizentech/<script>.log e registra início/fim/erro.
# Se o script definir a função "limpeza", ela roda na saída (inclusive em erro).
inicia_auditoria() {
  install -d -o root -g adm -m 2750 "$AUDIT_DIR"
  AUDIT_LOG="$AUDIT_DIR/$SCRIPT_NAME.log"
  exec > >(tee -a "$AUDIT_LOG") 2>&1
  passo "INICIO $SCRIPT_NAME $* | projeto=$PROJECT | equipe=$TEAM_RM"
  trap 'passo "ERRO na linha $LINENO: $BASH_COMMAND"' ERR
  trap 'rc=$?; declare -F limpeza >/dev/null && limpeza; passo "FIM $SCRIPT_NAME rc=$rc"; logger -t sombrasp-audit "$SCRIPT_NAME rc=$rc por ${SUDO_USER:-root} em $(hostname)"' EXIT
}
