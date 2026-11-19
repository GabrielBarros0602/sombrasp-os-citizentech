#!/usr/bin/env bash
# Provisionamento da APLICAÇÃO SombraSP no CT-NODE: dependências, agente/monitor, web app
# e orquestração pelo systemd (units com Restart=always, habilitadas no boot).
#
# Uso (depois do provision-infra.sh node):  sudo bash scripts/provision-app.sh
set -euo pipefail
source "$(dirname "$0")/comum.sh"
exige_root "$@"
inicia_auditoria "$@"

[[ $(hostname) == "$NODE_HOST" ]] || passo "AVISO: hostname atual não é $NODE_HOST; rode provision-infra.sh node antes"
id "$EXECUTOR" >/dev/null || { passo "ERRO: conta executora $EXECUTOR não existe; rode provision-infra.sh node antes"; exit 1; }
[[ -d $BASE/data ]] || { passo "ERRO: $BASE/data não existe; rode provision-infra.sh node antes"; exit 1; }
findmnt -n "$BASE/data" >/dev/null || passo "AVISO: $BASE/data não está no 2º disco (rode provision-infra.sh com DISK=)"

passo "1/4 Dependências (python3 serve a web app; procps/coreutils para o monitor)"
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y -q python3 procps coreutils curl e2fsprogs

passo "2/4 Agente/monitor -> /usr/local/bin/citizentech-agent.sh"
install -o root -g root -m 0755 "$ROOT_DIR/scripts/citizentech-agent.sh" /usr/local/bin/citizentech-agent.sh
# Um teste manual anterior pode ter criado arquivos com outro dono: devolve ao executor.
for f in "$BASE/data/status.txt" "$BASE/logs/agent.log" "$BASE/logs/alertas.log"; do
  if [[ -e $f ]]; then chown "$EXECUTOR:$GROUP" "$f"; fi
done

passo "3/4 Web app -> $BASE/app (porta 8080)"
install -o root -g "$GROUP" -m 0640 "$ROOT_DIR/app/index.html" "$BASE/app/index.html"
ln -sfn "$BASE/data/status.txt" "$BASE/app/status.txt"   # o painel mostra o estado gravado pelo agente

passo "4/4 Units systemd (configs/*.service)"
install -o root -g root -m 0644 "$ROOT_DIR/configs/citizentech-agent.service" "$ROOT_DIR/configs/sombrasp-web.service" /etc/systemd/system/
grep -q "^User=$EXECUTOR$" /etc/systemd/system/citizentech-agent.service \
  || passo "AVISO: User= da unit difere de $EXECUTOR (comum.sh); corrija configs/*.service"
systemctl daemon-reload
systemctl enable citizentech-agent sombrasp-web
systemctl restart citizentech-agent sombrasp-web
sleep 3

systemctl --no-pager status citizentech-agent sombrasp-web || true
systemctl show -p User -p Group -p MainPID -p Restart citizentech-agent
ps -p "$(systemctl show -p MainPID --value citizentech-agent)" -o user:32,group:20,pid,ppid,args
cat "$BASE/data/status.txt"
curl -fsS "http://127.0.0.1:8080/status.txt"
passo "Aplicação no ar: http://$NODE_IP:8080 (abra no navegador do CT-CLIENT)"
