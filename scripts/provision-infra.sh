#!/usr/bin/env bash
# Provisionamento da INFRAESTRUTURA SombraSP: pacotes, hostname, IP fixo da rede privada,
# contas dos alunos e grupo, diretórios/permissões, 2º disco + fstab, SSH e DNS/BIND9.
#
# Uso (com a conta inicial que tem sudo, na pasta da entrega):
#   CT-NODE:   sudo DISK=/dev/sdb bash scripts/provision-infra.sh node [interface-host-only]
#   CT-CLIENT: sudo bash scripts/provision-infra.sh client [interface-host-only]
# Sem DISK=, a etapa de disco é pulada. Pode ser executado de novo: cada etapa confere o que já existe.
set -euo pipefail
source "$(dirname "$0")/comum.sh"

ROLE="${1:-}"
IFACE="${2:-}"
[[ $ROLE == node || $ROLE == client ]] || { echo "Uso: sudo [DISK=/dev/sdX] bash $0 node|client [interface]" >&2; exit 2; }
exige_root "$@"
inicia_auditoria "$@"

if [[ $ROLE == node ]]; then
  HOST="$NODE_HOST"; IP="$NODE_IP"
  PKGS=(openssh-server bind9 bind9-utils dnsutils parted curl)
else
  HOST="$CLIENT_HOST"; IP="$CLIENT_IP"
  PKGS=(openssh-client dnsutils curl)
fi

# ---------------------------------------------------------------- 1. pacotes
passo "1/7 Instalando dependências: ${PKGS[*]}"
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y -q "${PKGS[@]}"

# ---------------------------------------------------------------- 2. hostname
passo "2/7 Hostname -> $HOST"
hostnamectl set-hostname "$HOST"
# 127.0.1.1 precisa apontar para o nome novo, senão o sudo avisa "unable to resolve host".
if grep -q '^127\.0\.1\.1' /etc/hosts; then
  sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$HOST/" /etc/hosts
else
  printf '127.0.1.1\t%s\n' "$HOST" >> /etc/hosts
fi
hostnamectl

# ---------------------------------------------------------------- 3. rede privada
passo "3/7 Rede privada: $IP/$PREFIX"
# Placa 1 = NAT (internet, rota padrão). Placa 2 = Host-Only (rede entre as VMs, sem gateway).
IFACE="${IFACE:-$(ip -o link show | awk -F': ' '$2 != "lo" {print $2}' | sed -n 2p)}"
if ! command -v nmcli >/dev/null; then
  passo "AVISO: nmcli ausente; configure $IP/$PREFIX pela interface gráfica (Configurações > Rede)"
elif [[ -z $IFACE ]] || ! ip link show "$IFACE" >/dev/null 2>&1; then
  passo "ERRO: placa host-only não encontrada. Veja 'ip -br link' e informe-a como 2º argumento"
  exit 1
else
  nmcli con delete citizentech-priv >/dev/null 2>&1 || true
  nmcli con add type ethernet ifname "$IFACE" con-name citizentech-priv \
    ipv4.method manual ipv4.addresses "$IP/$PREFIX" ipv4.never-default yes \
    ipv6.method disabled connection.autoconnect-priority 10
  nmcli con up citizentech-priv
fi
ip -br addr
ip route

# ---------------------------------------------------------------- 4. usuários e grupo
passo "4/7 Grupo $GROUP e contas dos alunos: ${ALUNOS[*]}"
getent group "$GROUP" >/dev/null || groupadd "$GROUP"
for L in "${ALUNOS[@]}"; do
  id "$L" >/dev/null 2>&1 || adduser --allow-bad-names --disabled-password --gecos "" "$L"
  usermod -aG "$GROUP" "$L"
  # Senha local definida pelo próprio aluno na hora; nunca vai para arquivo ou log.
  if [[ -t 0 && $(passwd -S "$L" | awk '{print $2}') != P ]]; then
    passo "Defina a senha local de $L"
    passwd "$L"
  fi
done
usermod -aG sudo "$ADMIN"
for L in "${ALUNOS[@]}"; do id "$L"; done
getent group "$GROUP"
if id -nG "$EXECUTOR" | grep -qw sudo; then passo "AVISO: executor $EXECUTOR tem sudo; o enunciado prefere sem"; fi

if [[ $ROLE == client ]]; then
  passo "CT-CLIENT pronto. Testando o CT-NODE:"
  ping -c 3 "$NODE_IP" || passo "AVISO: CT-NODE ($NODE_IP) não respondeu ainda"
  dig @"$NODE_IP" "node.$DOMAIN" +short || true
  exit 0
fi

# ---------------------------------------------------------------- 5. diretórios
passo "5/7 Estrutura $BASE (data/logs 2770, config/app 2750, dono root:$GROUP)"
install -d -o root -g "$GROUP" -m 0750 "$BASE"
install -d -o root -g "$GROUP" -m 2770 "$BASE/data" "$BASE/logs"
install -d -o root -g "$GROUP" -m 2750 "$BASE/config" "$BASE/app"

# ---------------------------------------------------------------- 6. segundo disco
passo "6/7 Armazenamento dedicado em $BASE/data"
if findmnt -n "$BASE/data" >/dev/null; then
  passo "Volume já montado"
elif grep -q "[[:space:]]$BASE/data[[:space:]]" /etc/fstab; then
  passo "Linha já existe no fstab; montando com mount -a"
  mount -a
elif [[ -z ${DISK:-} ]]; then
  passo "AVISO: DISK não informado, etapa pulada. Confira o disco novo com lsblk e rode: sudo DISK=/dev/sdb bash $0 node"
else
  lsblk "$DISK"
  [[ $(lsblk -dno TYPE "$DISK") == disk ]] || { passo "ERRO: $DISK não é um disco"; exit 1; }
  [[ $(lsblk -no NAME "$DISK" | wc -l) -eq 1 ]] || { passo "ERRO: $DISK já tem partições; confira o dispositivo"; exit 1; }
  read -rp "Isto APAGA todo o conteúdo de $DISK. Digite SIM para continuar: " ok
  [[ $ok == SIM ]] || { passo "Cancelado pelo operador"; exit 1; }
  parted -s "$DISK" mklabel gpt mkpart primary ext4 0% 100%
  udevadm settle
  PART="$(lsblk -lnpo NAME,TYPE "$DISK" | awk '$2 == "part" {print $1; exit}')"
  mkfs.ext4 -F -L CITIZENDATA "$PART"
  UUID="$(blkid -s UUID -o value "$PART")"
  printf 'UUID=%s  %s/data  ext4  defaults  0  2\n' "$UUID" "$BASE" >> /etc/fstab
  systemctl daemon-reload
  mount -a    # monta pelo fstab: prova que a linha persistente está correta
fi
if findmnt -n "$BASE/data" >/dev/null; then
  # A montagem esconde as permissões do diretório original: reaplicar depois de montar.
  chown root:"$GROUP" "$BASE/data"
  chmod 2770 "$BASE/data"
  grep "[[:space:]]$BASE/data[[:space:]]" /etc/fstab | tee "$BASE/config/fstab-citizentech.txt"
  findmnt "$BASE/data"
  df -hT "$BASE/data"
fi
ls -ld "$BASE" "$BASE"/*

# ---------------------------------------------------------------- 7. SSH e BIND9
passo "7/7 SSH e zona DNS $DOMAIN"
systemctl enable --now ssh
grep -q "zone \"$DOMAIN\"" /etc/bind/named.conf.local || cat "$ROOT_DIR/configs/named.conf.local" >> /etc/bind/named.conf.local
install -o root -g bind -m 0644 "$ROOT_DIR/configs/db.$DOMAIN" "/etc/bind/db.$DOMAIN"
named-checkconf
named-checkzone "$DOMAIN" "/etc/bind/db.$DOMAIN"
systemctl enable named
systemctl restart named
ss -lntuH 'sport = :22 or sport = :53' | awk '{print $1, $5}' | sort -u   # SSH e DNS escutando
for n in ns1 node dados monitor app; do printf '%-8s -> %s\n' "$n" "$(dig @"$NODE_IP" "$n.$DOMAIN" +short +time=2 +tries=1 | head -n 1)"; done

passo "CT-NODE provisionado. Próximo passo: sudo bash scripts/provision-app.sh"
