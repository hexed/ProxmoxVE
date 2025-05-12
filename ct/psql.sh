#!/usr/bin/env bash

# Combined MariaDB + PostgreSQL Installer for Proxmox LXC
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# --- MariaDB Installation ---
msg_info "Installing MariaDB"
$STD apt-get install -y mariadb-server
sed -i 's/^# *\(port *=.*\)/\1/' /etc/mysql/my.cnf
sed -i 's/^bind-address/#bind-address/g' /etc/mysql/mariadb.conf.d/50-server.cnf
msg_ok "Installed MariaDB"

# --- PostgreSQL Installation ---
msg_info "Installing PostgreSQL Dependencies"
$STD apt-get install -y gnupg
msg_ok "Installed PostgreSQL Dependencies"

msg_info "Setting up PostgreSQL Repository"
VERSION="$(awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release)"
echo "deb http://apt.postgresql.org/pub/repos/apt ${VERSION}-pgdg main" >/etc/apt/sources.list.d/pgdg.list
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor --output /etc/apt/trusted.gpg.d/postgresql.gpg
msg_ok "Setup PostgreSQL Repository"

msg_info "Installing PostgreSQL"
$STD apt-get update
$STD apt-get install -y postgresql

cat <<EOF >/etc/postgresql/17/main/pg_hba.conf
local   all             postgres                                peer
local   all             all                                     md5
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             0.0.0.0/24              md5
host    all             all             ::1/128                 scram-sha-256
host    all             all             0.0.0.0/0               md5
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256
EOF

cat <<EOF >/etc/postgresql/17/main/postgresql.conf
data_directory = '/var/lib/postgresql/17/main'
hba_file = '/etc/postgresql/17/main/pg_hba.conf'
ident_file = '/etc/postgresql/17/main/pg_ident.conf'
external_pid_file = '/var/run/postgresql/17-main.pid'
listen_addresses = '*'
port = 5432
max_connections = 100
unix_socket_directories = '/var/run/postgresql'
ssl = on
ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'
shared_buffers = 128MB
dynamic_shared_memory_type = posix
max_wal_size = 1GB
min_wal_size = 80MB
log_line_prefix = '%m [%p] %q%u@%d '
log_timezone = 'Etc/UTC'
cluster_name = '17/main'
datestyle = 'iso, mdy'
timezone = 'Etc/UTC'
lc_messages = 'C'
lc_monetary = 'C'
lc_numeric = 'C'
lc_time = 'C'
default_text_search_config = 'pg_catalog.english'
include_dir = 'conf.d'
EOF

systemctl restart postgresql
msg_ok "Installed PostgreSQL"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
