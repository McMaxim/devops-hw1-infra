#!/usr/bin/env bash
# Поднимает локальную "VM" — Linux-машину OrbStack (Ubuntu 22.04) — и готовит её к Ansible.
# Делает то же, что cloud-init в облаке: ставит sshd и создаёт админа `ubuntu` с SSH-ключом.
# Всё остальное (deployer, Docker, hardening) — зона ответственности Ansible.
set -euo pipefail

VM_NAME="${VM_NAME:-devops-vm}"
VM_IMAGE="${VM_IMAGE:-ubuntu:jammy}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/devops_hw_ed25519}"
ADMIN_USER="${ADMIN_USER:-ubuntu}"

command -v orb >/dev/null || { echo "ERROR: OrbStack CLI (orb) не найден" >&2; exit 1; }

if [[ ! -f "$SSH_KEY" ]]; then
  echo ">> Генерирую SSH-ключ $SSH_KEY"
  ssh-keygen -t ed25519 -N "" -C "devops-hw1" -f "$SSH_KEY" -q
fi

if orb list | awk '{print $1}' | grep -qx "$VM_NAME"; then
  echo ">> VM $VM_NAME уже существует"
else
  echo ">> Создаю VM $VM_NAME ($VM_IMAGE)"
  orb create "$VM_IMAGE" "$VM_NAME"
fi

echo ">> Настраиваю сеть, ставлю openssh-server, создаю пользователя $ADMIN_USER"
orb -m "$VM_NAME" -u root bash -s -- "$ADMIN_USER" "$(cat "$SSH_KEY.pub")" <<'EOF'
set -euo pipefail
admin="$1"; pubkey="$2"
export DEBIAN_FRONTEND=noninteractive

# Выход в интернет по IPv6 в этом окружении не работает (apt и docker pull рвутся),
# поэтому запрещаем IPv6 к внешним адресам — apt, curl и dockerd сразу идут по IPv4.
if [[ ! -f /etc/netplan/60-ipv6-egress.yaml ]]; then
  cat > /etc/netplan/60-ipv6-egress.yaml <<'NETPLAN'
network:
  version: 2
  ethernets:
    eth0:
      routes:
        - to: "2000::/3"
          type: unreachable
NETPLAN
  chmod 0600 /etc/netplan/60-ipv6-egress.yaml
  netplan apply
fi

if ! dpkg -s openssh-server >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq openssh-server python3 >/dev/null
fi
systemctl enable --now ssh >/dev/null

id "$admin" >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo "$admin"
echo "$admin ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$admin"
chmod 0440 "/etc/sudoers.d/90-$admin"

install -d -m 0700 -o "$admin" -g "$admin" "/home/$admin/.ssh"
echo "$pubkey" > "/home/$admin/.ssh/authorized_keys"
chown "$admin:$admin" "/home/$admin/.ssh/authorized_keys"
chmod 0600 "/home/$admin/.ssh/authorized_keys"
EOF

VM_IP="$(orb -m "$VM_NAME" bash -c "ip -4 -o addr show eth0 | awk '{print \$4}' | cut -d/ -f1")"
echo ">> Готово. IP VM: $VM_IP (впишите его в ansible/inventory.ini и terraform vm_host)"
echo "   Проверка: ssh -i $SSH_KEY $ADMIN_USER@$VM_IP hostname"
