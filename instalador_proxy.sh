#!/bin/bash
# Script Automático para Configuração de Proxy Rotativo com DuckDNS
# Criado por [Seu Nome] - Compatível com Ubuntu 20.04

# Cores para melhor visualização
VERDE="\e[32m"
VERMELHO="\e[31m"
RESET="\e[0m"

echo -e "${VERDE}
██╗   ██╗███████╗██████╗ ██╗   ██╗ █████╗ ████████╗
██║   ██║██╔════╝██╔══██╗╚██╗ ██╔╝██╔══██╗╚══██╔══╝
██║   ██║█████╗  ██████╔╝ ╚████╔╝ ███████║   ██║   
╚██╗ ██╔╝██╔══╝  ██╔══██╗  ╚██╔╝  ██╔══██║   ██║   
 ╚████╔╝ ███████╗██║  ██║   ██║   ██║  ██║   ██║   
  ╚═══╝  ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝   ╚═╝   
${RESET}"

# Variáveis do sistema
DOMINIO="seu-iptv.duckdns.org"  # <<<< ALTERE ISSO PARA SEU DOMÍNIO
TOKEN_DUCKDNS="seu_token_aqui"  # <<<< ALTERE ISSO PARA SEU TOKEN
PORTA_PROXY=3128
DIR_TEMP="/tmp/proxy_rotativo"

# Atualização do sistema
echo -e "${VERDE}[+] Atualizando sistema...${RESET}"
apt update && apt upgrade -y &> /dev/null

# Instalação de pacotes necessários
echo -e "${VERDE}[+] Instalando dependências...${RESET}"
apt install squid apache2-utils curl jq cron ufw -y &> /dev/null

# Configuração do DuckDNS
echo -e "${VERDE}[+] Configurando DuckDNS...${RESET}"
echo "protocol=duckdns" > /etc/ddclient.conf
echo "use=web" >> /etc/ddclient.conf
echo "server=www.duckdns.org" >> /etc/ddclient.conf
echo "login=$TOKEN_DUCKDNS" >> /etc/ddclient.conf
echo "password='senha_qualquer'" >> /etc/ddclient.conf
echo "$DOMINIO" >> /etc/ddclient.conf

systemctl enable ddclient &> /dev/null
systemctl restart ddclient &> /dev/null

# Configuração do Squid (Proxy)
echo -e "${VERDE}[+] Configurando servidor proxy...${RESET}"
cat > /etc/squid/squid.conf <<EOF
http_port $PORTA_PROXY
cache_peer PROXY_EXTERNO parent 80 0 no-query
never_direct allow all

# Segurança
acl allowed_clients src $(curl -s ifconfig.me)
http_access allow allowed_clients
http_access deny all

# Anti-DNS Leak
dns_v4_first on
dns_nameservers 8.8.8.8 8.8.4.4
EOF

# Criação do script de rotação
echo -e "${VERDE}[+] Criando sistema de rotação automática...${RESET}"
cat > /opt/rotacionar_proxy.sh <<EOF
#!/bin/bash
# Buscar proxies anônimos testados
curl -s "https://api.proxyscrape.com/v2/?request=displayproxies&protocol=http&timeout=5000&country=all&ssl=all&anonymity=elite" > \$DIR_TEMP

# Validar proxies
while read proxy; do
  if curl -x http://\$proxy -m 5 -s http://ifconfig.me 2>/dev/null | grep -v "\$(curl -s ifconfig.me)"; then
    echo \$proxy >> \${DIR_TEMP}_validos
  fi
done < \$DIR_TEMP

# Selecionar proxy aleatório
proxy_valido=\$(shuf -n 1 \${DIR_TEMP}_validos)

# Atualizar configuração
sed -i "s|cache_peer .*|cache_peer \$proxy_valido parent 80 0 no-query|g" /etc/squid/squid.conf
systemctl restart squid
EOF

chmod +x /opt/rotacionar_proxy.sh &> /dev/null

# Agendamento da rotação
echo "*/10 * * * * root /opt/rotacionar_proxy.sh" > /etc/cron.d/rotacionar_proxy

# Configuração do firewall
echo -e "${VERDE}[+] Configurando firewall...${RESET}"
ufw allow $PORTA_PROXY/tcp &> /dev/null
ufw deny out 80/tcp &> /dev/null
ufw deny out 8080/tcp &> /dev/null
ufw enable &> /dev/null

# Finalização
echo -e "${VERDE}
[+] Instalação concluída com sucesso!
- Domínio: $DOMINIO
- Porta: $PORTA_PROXY
- Tipo: HTTP

Instruções de uso:
1. Configure seu IPTV com os dados acima
2. Teste com: curl -x http://localhost:$PORTA_PROXY http://ifconfig.me
${RESET}"
