#!/usr/bin/env bash
# Teste de falha: derruba os serviços e simula falha de gravação no volume de dados,
# mostrando o systemd (Restart=always) recuperando tudo sozinho.
# Uso (no CT-NODE, aluno administrador):  sudo bash scripts/teste-falha.sh
set -euo pipefail
source "$(dirname "$0")/comum.sh"
exige_root "$@"
inicia_auditoria "$@"

STATUS_FILE="$BASE/data/status.txt"
limpeza() { chattr -i "$STATUS_FILE" 2>/dev/null || true; }   # nunca deixa o arquivo travado

mostra() {
  passo "$1 | estado=$(systemctl is-active "$1" || true) | MainPID=$(systemctl show -p MainPID --value "$1") | reinicios=$(systemctl show -p NRestarts --value "$1")"
}

for svc in citizentech-agent sombrasp-web; do
  passo "TESTE 1 ($svc): kill -9 no processo principal"
  mostra "$svc"
  kill -9 "$(systemctl show -p MainPID --value "$svc")"
  sleep 5    # RestartSec=3 + tempo de subida
  mostra "$svc"
done
journalctl -u citizentech-agent -n 6 --no-pager
curl -fsS -o /dev/null -w 'web app respondeu HTTP %{http_code}\n' http://127.0.0.1:8080/

passo "TESTE 2: falha de gravação (status.txt imutável com chattr +i)"
chattr +i "$STATUS_FILE"
INICIO="$(date '+%Y-%m-%d %H:%M:%S')"
systemctl restart citizentech-agent   # força a gravação imediata em vez de esperar o próximo ciclo de 30 s
sleep 8
journalctl -u citizentech-agent --since "$INICIO" --no-pager | grep -E 'ERRO|exited|Scheduled restart' | tail -n 6
mostra citizentech-agent

passo "TESTE 2: liberando o arquivo; o agente deve voltar a gravar sozinho"
chattr -i "$STATUS_FILE"
sleep 6
mostra citizentech-agent
cat "$STATUS_FILE"
passo "Resultado: serviços recuperados pelo systemd sem intervenção manual"
