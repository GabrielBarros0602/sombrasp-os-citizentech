# Uso de IA generativa — GS Operating Systems (SombraSP)

Ferramenta: Claude Code (Anthropic), em 17/11/2026. A IA não digitou nem usou senhas: elas foram definidas e digitadas pela equipe nas VMs. Além de nome, RM e login dos integrantes, nenhum dado pessoal foi informado.

| # | Prompt (resumo) | Finalidade | Como verificamos na prática |
|---|---|---|---|
| 1 | "Leia D00–D06, as instruções do professor, a ficha da SombraSP e os slides 35–37 do briefing geral; liste o que a entrega exige." | Entender requisitos, estrutura do ZIP e evidências E01–E09. | Conferimos a lista com a rubrica D04 e o guia D05; a estrutura de pastas segue o D01. |
| 2 | "Escreva scripts Bash para provisionar o CT-NODE e o CT-CLIENT: hostname, IP fixo na placa host-only, contas NomeAluno_RM, grupo citizenops, /srv/citizentech, 2º disco com fstab por UUID, SSH e BIND9." | Automatizar o tutorial D02 com nossos dados. | `bash -n` e ShellCheck; execução num Ubuntu 24.04 com systemd e numa rede 192.168.56.0/24 (dois containers), depois nas VMs. |
| 3 | "Transforme o agente do tutorial num monitor de CPU, memória e disco com alertas, mantendo status.txt com equipe, usuário e host e exit 1 em falha de gravação." | Atender o agente do D01 e o monitoramento do briefing geral. | Forçamos limites 0% para ver ALERTA no journal (`-p warning`) e em `alertas.log`. |
| 4 | "Crie um script de teste de falha: kill -9 e falha de escrita, mostrando o systemd reiniciando." | Comprovar tolerância a falhas (`Restart=always`). | `teste-falha.sh`: PID mudou, NRestarts subiu, `ERRO` apareceu no journal e o serviço voltou após `chattr -i`. |
| 5 | "Crie uma página mínima da SombraSP servida por python3 http.server, sem nginx." | Ter a aplicação hospedada no nó (o enunciado não exige servidor web). | `curl http://192.168.56.10:8080/status.txt` a partir do cliente devolveu o estado do agente. |
| 6 | "Gere README, relatório no modelo D03 e roteiro do vídeo." | Documentação. | Revisamos o texto, os nomes, RMs, logins e IPs contra as VMs e as evidências. |
| 7 | "Crie as VMs CT-NODE e CT-CLIENT no VirtualBox com instalação automática do Ubuntu 24.04, rode os scripts e tire os prints E01–E09." (18/11/2026) | Montar o laboratório e capturar as evidências. | As senhas das contas foram digitadas por nós, nunca pela IA. Conferimos cada print (data, hostname e conta no topo) antes de colocar no relatório. |

Problemas que a IA ajudou a diagnosticar: no teste, saída repetida do `ss` para a porta 53 (uma linha por thread do named) e `dig` lento para IP inexistente; nas VMs, SSH ausente porque a instalação automática não tinha DNS, fuso em UTC e `systemctl status` sem as linhas do journal quando roda sem sudo. Todos foram corrigidos.

A equipe revisou cada comando e sabe explicar: quem executa o agente e por quê, o que acontece se o fstab estiver errado, como o systemd reage à falha e como a zona DNS é validada.
