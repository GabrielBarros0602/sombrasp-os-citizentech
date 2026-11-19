# SombraSP — CitizenTech Infrastructure Node (Operating Systems)

Global Solution 2026.2 · Engenharia de Software · Operating Systems
Entrega: `GS_OS_GabrielCisoto_RM556309.zip`

## Equipe

| Nome completo | RM | Turma | Login nas duas VMs | Papel |
|---|---|---|---|---|
| Gabriel Barros Cisoto | RM556309 | 3ESPH | `GabrielCisoto_RM556309` | **Líder** e aluno administrador (sudo) |
| Felipe Marques de Oliveira | RM556319 | 3ESPH | `FelipeOliveira_RM556319` | Aluno executor do agente (sem sudo, `User=` das units) |

Os dois alunos estão no grupo `citizenops`. Somente o líder envia o ZIP. A equipe é a mesma nas demais disciplinas da GS.

Checklist de integrantes: ☑ ninguém foi esquecido · ☑ cada aluno está em um único grupo · ☑ logins iguais nas duas VMs.

## Ficha da CitizenTech

| Campo | Valor |
|---|---|
| Nome | SombraSP |
| Cidade e bairro | São Paulo, Centro (Sé / República) |
| Cidadão beneficiado | Idosos e trabalhadores de rua (ambulantes, entregadores, garis) expostos ao sol |
| Problema | Nos dias de calor extremo, quem passa o dia na rua não recebe aviso a tempo nem sabe onde encontrar sombra e água por perto. |
| Como funciona | Sensores (ESP32) e dados públicos do INMET estimam o risco de calor; quando ele sobe, a plataforma emite alertas e mostra pontos de sombra e hidratação próximos. |
| Papel desta disciplina | Infraestrutura Linux que provisiona e hospeda a web app SombraSP, com monitoramento, logs e DNS próprio. |
| Indicador proposto de impacto | Nº de alertas emitidos em dias de risco e nº de consultas a pontos de sombra/hidratação. |
| Domínio de teste | `sombrasp.test` |

### ODS (fonte: <https://brasil.un.org/pt-br/sdgs>)

| ODS | Resumo | Como a SombraSP contribui |
|---|---|---|
| 3. Saúde e Bem-Estar | Vida saudável e bem-estar para todas as pessoas, em todas as idades. | Avisos de calor extremo reduzem desidratação, insolação e agravamento de doenças em idosos. |
| 10. Redução das Desigualdades | Reduzir desigualdades, com atenção a grupos vulneráveis. | Atende quem trabalha na rua, sem ar-condicionado nem acesso fácil a previsões. |
| 11. Cidades e Comunidades Sustentáveis | Cidades inclusivas, seguras, resilientes e sustentáveis. | Mapeia sombra e água no Centro e torna o espaço público mais seguro em ondas de calor. |
| 13. Ação contra a Mudança Global do Clima | Medidas urgentes contra a mudança do clima e seus impactos. | Adaptação a um impacto climático concreto: ondas de calor mais frequentes. |

## Arquitetura

```
 CT-CLIENT  ct-client-rm556309                 CT-NODE  ct-node-rm556309
 192.168.56.20/24  ───── host-only ─────▶      192.168.56.10/24
 ping · ssh · dig · navegador                  contas + citizenops · /srv/citizentech
                                               2º disco ext4 → /srv/citizentech/data (fstab/UUID)
 placa 1: NAT (internet, apt)                  citizentech-agent.service  (estado + monitor CPU/mem/disco)
                                               sombrasp-web.service :8080 · SSH :22 · BIND9 :53
```

| Caminho | Dono / modo | Uso |
|---|---|---|
| `/srv/citizentech` | root:citizenops 0750 | raiz da solução |
| `/srv/citizentech/data` | root:citizenops 2770 | 2º disco; `status.txt` do agente |
| `/srv/citizentech/logs` | root:citizenops 2770 | `agent.log`, `alertas.log` |
| `/srv/citizentech/config` | root:citizenops 2750 | cópia da linha do fstab |
| `/srv/citizentech/app` | root:citizenops 2750 | web app |
| `/var/log/citizentech` | root:adm 2750 | log de auditoria de cada script |

## Conteúdo da entrega

```
GS_OS_GabrielCisoto_RM556309/
├── README.md · relatorio.docx · prompts.md
├── app/index.html                      painel da SombraSP (risco de calor, pontos de sombra, estado do nó)
├── configs/
│   ├── citizentech-agent.service       agente: User=FelipeOliveira_RM556319, Restart=always
│   ├── sombrasp-web.service            web app: python3 http.server :8080, Restart=always
│   ├── fstab-citizentech.txt           linha do fstab (substituir pela gerada na VM)
│   ├── named.conf.local                declaração da zona
│   └── db.sombrasp.test                ns1, node, dados, monitor, app, cliente
├── scripts/
│   ├── comum.sh                        dados da equipe + funções de auditoria (único lugar a editar)
│   ├── provision-infra.sh              pacotes, hostname, IP, usuários, diretórios, disco, SSH, BIND9
│   ├── provision-app.sh                dependências, agente, web app, units systemd
│   ├── citizentech-agent.sh            agente/monitor executado pelo systemd
│   ├── teste-falha.sh                  kill -9 + falha de gravação → systemd recupera
│   └── evidencias.sh                   comandos de cada categoria E01–E09 para os prints
└── evidencias/                         E01_… a E09_… (.png)
```

| Critério (D04) | Onde está |
|---|---|
| 1. Contexto e arquitetura | este README, relatório §1–2 |
| 2. Usuários, grupos e permissões | `provision-infra.sh` etapas 4–5 · E02, E03 |
| 3. Armazenamento | `provision-infra.sh` etapa 6 · `fstab-citizentech.txt` · E04 |
| 4. Processos, serviço e logs | `citizentech-agent.sh`, `*.service`, `provision-app.sh`, `teste-falha.sh` · E05, E06 |
| 5. Rede | `provision-infra.sh` etapa 3 · E07 |
| 6. SSH | `provision-infra.sh` etapa 7 · E08 |
| 7. DNS/BIND9 | `named.conf.local`, `db.sombrasp.test` · E09 |
| 8. Evidências, relatório | `relatorio.docx`, `prompts.md`, `evidencias/` |

Itens do briefing geral também cobertos: provisionamento de infra (rede, DNS, IP, hostname) e da aplicação (dependências, configuração, orquestração) por script; monitor de CPU, memória e disco com alertas; monitoramento como serviço systemd tolerante a falhas; logs de auditoria e de execução.

## Como reproduzir

Pré-requisitos: duas VMs Ubuntu Desktop (24.04 recomendado) no VirtualBox, cada uma com **placa 1 NAT** e **placa 2 Host-Only** (rede 192.168.56.0/24). No CT-NODE, um **segundo disco virtual de 2 GB**. Use a conta inicial com sudo para provisionar.

### 1. Copiar a entrega para as duas VMs

```bash
sudo apt install -y git && git clone <URL-DO-REPOSITORIO> && cd <repositorio>/GS_OS_GabrielCisoto_RM556309
```
(ou copie a pasta por pasta compartilhada/pendrive.)

### 2. CT-NODE

```bash
ip -br link            # placa 2 (host-only), ex.: enp0s8
lsblk                  # disco novo SEM partições, ex.: sdb  (CONFIRME antes!)
sudo DISK=/dev/sdb bash scripts/provision-infra.sh node enp0s8
sudo bash scripts/provision-app.sh
```
O script pede a senha local de cada aluno (não é gravada em log) e pede `SIM` antes de formatar o disco. Depois:
```bash
sudo cp /srv/citizentech/config/fstab-citizentech.txt configs/   # linha real do fstab para a entrega
```

### 3. CT-CLIENT

```bash
sudo bash scripts/provision-infra.sh client enp0s8
```

### 4. Testes

No CT-NODE:
```bash
sudo bash scripts/teste-falha.sh          # kill -9 nos serviços e falha de gravação → recuperação automática
sudo reboot                               # opcional: depois confira findmnt, is-enabled e status.txt atualizado
```
No CT-CLIENT:
```bash
ping -c 4 192.168.56.10
ssh FelipeOliveira_RM556319@192.168.56.10
dig @192.168.56.10 node.sombrasp.test +short
dig @192.168.56.10 dados.sombrasp.test +short
dig @192.168.56.10 monitor.sombrasp.test +short
```
Web app: abra `http://192.168.56.10:8080` no navegador do CT-CLIENT.

Para ver um alerta de CPU acontecendo (CT-NODE): `timeout 70 bash -c 'for i in $(seq $(nproc)); do yes > /dev/null & done; wait'` e depois `sudo journalctl -u citizentech-agent -p warning -n 5`.

### 5. Evidências (prints)

Logado com a conta nominal, rode `bash scripts/evidencias.sh E0X [parte]` e capture o terminal inteiro (data, hostname e usuário aparecem no topo). Os prints desta entrega já estão em `evidencias/`:

| Arquivo | VM | Conta |
|---|---|---|
| `E01_01_sistema_identidade.png`, `E01_02_sistema_client.png` | node e client | GabrielCisoto_RM556309 |
| `E02_01_usuarios_grupos.png`, `E02_02_grupo_sudo.png`, `E02_03_usuarios_client.png` | node e client | GabrielCisoto_RM556309 |
| `E03_01_permissoes.png` | node | GabrielCisoto_RM556309 |
| `E04_01_armazenamento.png` | node | GabrielCisoto_RM556309 |
| `E05_01_servico.png`, `E05_02_usuario_processo.png`, `E05_03_teste_falha.png` | node | GabrielCisoto_RM556309 |
| `E06_01_logs.png`, `E06_02_alertas_auditoria.png` | node | GabrielCisoto_RM556309 |
| `E07_01_rede_node.png`, `E07_02_rede_client.png` | node e client | GabrielCisoto_RM556309 |
| `E08_01_ssh.png`, `E08_02_ssh_cliente.png` | node; client → node | FelipeOliveira_RM556319 na sessão SSH |
| `E09_01_dns_node.png`, `E09_02_dns_client.png`, `E09_03_app_navegador.png`, `E09_04_app_status.png` | node e client | GabrielCisoto_RM556309 |

Os mesmos prints estão embutidos no `relatorio.docx`, seção por seção.

## Mudar integrante, RM ou IP

Edite `scripts/comum.sh`. Se mudar o executor, troque também `User=` em `configs/*.service` e `TEAM` em `scripts/citizentech-agent.sh`; se mudar IP ou domínio, ajuste `configs/db.sombrasp.test` e `configs/named.conf.local`.

## Uso de IA

Registrado em [prompts.md](prompts.md).
