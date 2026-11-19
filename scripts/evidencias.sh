#!/usr/bin/env bash
# Roda os comandos de uma categoria de evidência (E01..E09) com data, hostname e usuário no topo,
# para tirar o print direto do terminal. Rode logado com a conta NomeAluno_RM que deve aparecer.
# Uso: bash scripts/evidencias.sh E05 [parte]
#   Categorias longas têm partes (E02, E05, E06: 1 e 2) para caber numa tela; sem parte, roda tudo.
#   E07, E08 e E09 mudam conforme a VM (node ou client).
set -u
source "$(dirname "$0")/comum.sh"

cmd() { printf '\033[1;33m$ %s\033[0m\n' "$*"; bash -c "$*"; }
parte() { [[ -z ${PARTE} || ${PARTE} == "$1" ]]; }
PARTE="${2:-}"
CLIENTE=0; [[ $(hostname) == "$CLIENT_HOST" ]] && CLIENTE=1

clear
cmd 'date --iso-8601=seconds; hostname; whoami'
case "${1:-}" in
  E01) cmd hostnamectl; cmd 'grep PRETTY_NAME /etc/os-release' ;;
  E02) if parte 1; then for L in "${ALUNOS[@]}"; do cmd "id $L"; cmd "getent passwd $L"; done; fi
       if parte 2; then cmd "getent group $GROUP"; cmd "sudo -l -U $ADMIN"; cmd "sudo -l -U $EXECUTOR"; fi ;;
  E03) cmd "ls -ld $BASE $BASE/*"; cmd "namei -l $BASE/data/status.txt" ;;
  E04) cmd 'lsblk -e7'; cmd 'sudo blkid -L CITIZENDATA; lsblk -f -e7 | grep -i citizendata'
       cmd "findmnt $BASE/data"; cmd "grep -n $BASE/data /etc/fstab"; cmd "df -hT $BASE/data" ;;
  E05) if parte 1; then
         cmd 'sudo systemctl status citizentech-agent --no-pager -n 3'
         cmd 'systemctl is-enabled citizentech-agent sombrasp-web'
       fi
       if parte 2; then
         cmd 'systemctl show -p User -p Group -p MainPID -p Restart citizentech-agent'
         cmd 'ps -p "$(systemctl show -p MainPID --value citizentech-agent)" -o user:32,group:20,pid,ppid,args'
         cmd "sudo cat $BASE/data/status.txt"; cmd "ls -l $BASE/data/status.txt"
       fi ;;
  E06) if parte 1; then
         cmd 'sudo journalctl -u citizentech-agent -n 8 --no-pager'
         cmd 'sudo journalctl -u citizentech-agent -p warning -n 5 --no-pager'
       fi
       if parte 2; then
         cmd "tail -n 3 $BASE/logs/agent.log"; cmd "tail -n 4 $BASE/logs/alertas.log"
         cmd "sudo ls -l $AUDIT_DIR"; cmd 'sudo journalctl -t sombrasp-audit --no-pager | tail -n 5'
       fi ;;
  E07) cmd 'ip -br a'; cmd 'ip a show enp0s8'; cmd 'ip route'
       if (( CLIENTE )); then cmd "ping -c 4 $NODE_IP"; else cmd "ping -c 4 $CLIENT_IP"; fi ;;
  E08) if (( CLIENTE )); then
         echo "Agora rode:  ssh $EXECUTOR@$NODE_IP"
         echo "e, já dentro do CT-NODE:  date --iso-8601=seconds; hostname; whoami; id; ls -l $BASE; exit"
       else
         cmd 'systemctl status ssh --no-pager -n 0'; cmd "ss -lntH 'sport = :22'"
       fi ;;
  E09) if (( CLIENTE )); then
         for n in node dados monitor; do cmd "dig @$NODE_IP $n.$DOMAIN +short"; done
         cmd "nslookup app.$DOMAIN $NODE_IP"
         cmd "curl -s http://\$(dig @$NODE_IP app.$DOMAIN +short):8080/status.txt"
       else
         cmd 'sudo named-checkconf && echo named-checkconf OK'
         cmd "sudo named-checkzone $DOMAIN /etc/bind/db.$DOMAIN"
         cmd 'systemctl status named --no-pager -n 0'
         cmd "ss -lntuH src $NODE_IP:53"
       fi ;;
  *) echo "Uso: bash $0 E01|E02|...|E09 [parte]" >&2; exit 2 ;;
esac
