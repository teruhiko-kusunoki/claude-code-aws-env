# プロバイダー設定
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Ubuntu Minimal AMI ID（リージョン別）
locals {
  ubuntu_ami_ids = {
    "ap-northeast-1" = "ami-0154caaf0c638f431"  # Ubuntu 22.04 LTS Minimal (Tokyo)
    "us-east-1"      = "ami-020f2384205e90013"  # Ubuntu 22.04 LTS Minimal (Virginia)
  }
  
  ubuntu_ami_id = local.ubuntu_ami_ids[var.aws_region]
}

# セキュリティグループ
resource "aws_security_group" "claude_code_sg" {
  name_prefix = "claude-code-"
  description = "Security group for Claude Code development environment"

  # カスタムSSHポート（変数使用）
  ingress {
    description = "SSH Custom Port"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic（必要最小限）
  egress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "ssh"
    from_port   = 22 
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "NTP"
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "claude-code-sg-secure"
  }
}

# Claude Code環境セットアップスクリプト（完成版）
locals {
  user_data = <<-EOF
#!/bin/bash
set -e

# ログ設定
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting secure setup script at $(date)"

# Phase 1: システムアップデートと基本セキュリティ設定
echo "Phase 1: System update and security setup"

apt-get update
apt-get upgrade -y

# 日本語ロケール設定
echo "Setting up Japanese locale..."
apt-get install -y language-pack-ja
locale-gen ja_JP.UTF-8
update-locale LANG=ja_JP.UTF-8

# システム全体のロケール設定
cat > /etc/default/locale << 'LOCALE_EOF'
LANG=ja_JP.UTF-8
LANGUAGE=ja_JP:ja
LC_ALL=ja_JP.UTF-8
LOCALE_EOF

# タイムゾーンを日本時間に設定
timedatectl set-timezone Asia/Tokyo

echo "Locale and timezone configured for Japan"

# 基本ツールとufwのインストール（最優先）
apt-get install -y curl wget git vim build-essential ufw fail2ban keychain

# Phase 2: ファイアウォール設定（アプリインストール前）
echo "Phase 2: Firewall configuration"

# ファイアウォール設定
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ${var.ssh_port}        # カスタムSSHポート
ufw allow out 80/tcp             # HTTP
ufw allow out 443/tcp            # HTTPS
ufw allow out 22/tcp             # SSH 
ufw allow out 53/udp             # DNS
ufw allow out 123/udp            # NTP
ufw --force enable

echo "UFW configured successfully"

# Phase 3: SSH設定の最適化（カスタムポート使用）
echo "Phase 3: SSH configuration"

# SSH設定ファイルのバックアップ
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# 個別の設定を変更する関数
update_ssh_config() {
    local key="$1"
    local value="$2"
    local config_file="/etc/ssh/sshd_config"
    
    # 設定が存在するかチェック
    if grep -q "^$${key}" "$config_file"; then
        # 設定が存在する場合は置換
        sed -i "s/^$${key}.*/$${key} $${value}/" "$config_file"
        echo "Updated: $${key} $${value}"
    elif grep -q "^#$${key}" "$config_file"; then
        # コメントアウトされた設定がある場合は有効化して置換
        sed -i "s/^#$${key}.*/$${key} $${value}/" "$config_file"
        echo "Enabled and updated: $${key} $${value}"
    else
        # 設定が存在しない場合は追加
        echo "$${key} $${value}" >> "$config_file"
        echo "Added: $${key} $${value}"
    fi
}

# セキュリティ強化とカスタムポート設定
update_ssh_config "Port" "${var.ssh_port}"
update_ssh_config "PermitRootLogin" "no"
update_ssh_config "PasswordAuthentication" "no"
update_ssh_config "AllowUsers" "ubuntu"

# SSH設定のテスト
sshd -t
if [ $? -eq 0 ]; then
    systemctl restart sshd
    echo "SSH configuration updated successfully"
else
    echo "SSH configuration test failed, restoring backup"
    cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
    systemctl restart sshd
fi

# Phase 4: fail2ban設定
echo "Phase 4: fail2ban setup"

%{ if var.enable_fail2ban }
cat > /etc/fail2ban/jail.local << 'F2B_EOF'
[DEFAULT]
bantime = 1800
findtime = 3600
maxretry = 10
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ${var.ssh_port}
maxretry = 10
findtime = 3600
bantime = 1800
backend = systemd
filter = sshd
journalmatch = _SYSTEMD_UNIT=ssh.service + _COMM=sshd
action = iptables-multiport[name=SSH, port="${var.ssh_port}", protocol=tcp]
F2B_EOF

systemctl enable --now fail2ban
echo "fail2ban configured successfully"
%{ else }
echo "fail2ban disabled by configuration"
%{ endif }

# Phase 5: 不要なサービスの無効化
echo "Phase 5: Disabling unnecessary services"

systemctl disable --now snapd postfix exim4 sendmail cups avahi-daemon bluetooth 2>/dev/null || true
apt-get remove --purge -y postfix exim4* sendmail* cups* avahi-daemon bluetooth bluez thunderbird* evolution* 2>/dev/null || true
apt-get autoremove -y

# Phase 6: 開発環境セットアップ（ubuntu ユーザーで実行）
echo "Phase 6: Development environment setup"

# ubuntu ユーザーで実行
su - ubuntu << 'SETUP_EOF'
cd /home/ubuntu

# miseのインストール
curl https://mise.run | sh

# bashrcに設定追加
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc

# 日本語ロケール設定をubuntuユーザーに追加
cat >> ~/.bashrc << 'LOCALE_EOF'

# 日本語ロケール設定
export LANG=ja_JP.UTF-8
export LANGUAGE=ja_JP:ja
export LC_ALL=ja_JP.UTF-8
LOCALE_EOF

# keychain設定をヒアドキュメントで追加
cat >> ~/.bashrc << 'KEYCHAIN_EOF'

# keychain設定
if command -v keychain >/dev/null 2>&1; then
    # 既存のSSHキーがあれば自動で追加
    if [ -f ~/.ssh/id_rsa ]; then
        keychain ~/.ssh/id_rsa
    fi
    if [ -f ~/.ssh/id_ed25519 ]; then
        keychain ~/.ssh/id_ed25519
    fi
    if [ -f ~/.ssh/github_ed25519 ]; then
        keychain ~/.ssh/github_ed25519
    fi
    # keychain環境を読み込み
    [ -z "$HOSTNAME" ] && HOSTNAME=`uname -n`
    [ -f $HOME/.keychain/$HOSTNAME-sh ] && . $HOME/.keychain/$HOSTNAME-sh
    [ -f $HOME/.keychain/$HOSTNAME-sh-gpg ] && . $HOME/.keychain/$HOSTNAME-sh-gpg
fi
KEYCHAIN_EOF

# npmの設定をヒアドキュメントで追加
cat >> ~/.bashrc << 'NPM_EOF'
export PATH=~/.npm-global/bin:$PATH
NPM_EOF

# mise環境をアクティベート
export PATH="$HOME/.local/bin:$PATH"
eval "$(~/.local/bin/mise activate bash)"

# Node.jsバージョンのインストール
mise use --global node@${var.default_node_version}
${join("\n", [for version in var.node_versions : "mise install node@${version}" if version != var.default_node_version])}

# Pythonバージョンのインストール
mise use --global python@${var.default_python_version}
${join("\n", [for version in var.python_versions : "mise install python@${version}" if version != var.default_python_version])}

# yarnのインストール
mise install yarn@latest
mise use --global yarn@latest

# mise環境を再度アクティベート（確実にパスを通す）
eval "$(~/.local/bin/mise activate bash)"

# npmの設定
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global

# 環境変数を現在のセッションに適用
export PATH=~/.npm-global/bin:$PATH

# Claude Codeのインストール
npm install -g @anthropic-ai/claude-code

# Git設定
%{ if var.github_username != "" && var.github_email != "" }
git config --global user.name "${var.github_username}"
git config --global user.email "${var.github_email}"
%{ endif }
git config --global init.defaultBranch main

# 基本ディレクトリ作成
mkdir -p ~/projects ~/workspace

# GitHub SSH設定スクリプト（keychain対応版）
%{ if var.github_email != "" }
cat > ~/setup-github-ssh.sh << 'SSH_SCRIPT_EOF'
#!/bin/bash
echo "Setting up GitHub SSH..."

# SSH キーを生成（パスフレーズあり）
ssh-keygen -t ed25519 -C "${var.github_email}" -f ~/.ssh/github_ed25519
chmod 600 ~/.ssh/github_ed25519

# SSH設定ファイルを作成
cat > ~/.ssh/config << 'SSH_CONFIG_INNER_EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_ed25519
SSH_CONFIG_INNER_EOF
chmod 600 ~/.ssh/config

# keychain設定（keychainがあれば）
if command -v keychain >/dev/null 2>&1; then
    echo "Adding key to keychain..."
    keychain ~/.ssh/github_ed25519
    # keychain環境を読み込み
    [ -z "$HOSTNAME" ] && HOSTNAME=`uname -n`
    [ -f $HOME/.keychain/$HOSTNAME-sh ] && . $HOME/.keychain/$HOSTNAME-sh
    echo "Key added to keychain successfully"
fi

echo ""
echo "=== GitHub SSH Public Key ==="
cat ~/.ssh/github_ed25519.pub
echo ""
echo "📋 Copy the above public key to GitHub SSH settings:"
echo "   https://github.com/settings/ssh/new"
echo ""
echo "🧪 After adding the key to GitHub, test with:"
echo "   ssh -T git@github.com"
echo ""
echo "✅ If successful, you should see:"
echo "   Hi ${var.github_username}! You've successfully authenticated..."
SSH_SCRIPT_EOF

chmod +x ~/setup-github-ssh.sh
%{ endif }
SETUP_EOF

# Phase 7: 完了確認
echo "Phase 7: Setup completion"

# 完了通知
echo "Setup completed successfully at $(date)" > /home/ubuntu/setup_complete.txt
chown ubuntu:ubuntu /home/ubuntu/setup_complete.txt

# 各種サービスの状態確認
echo "Service status check:" >> /home/ubuntu/setup_complete.txt
echo "- UFW: $(ufw status | head -1)" >> /home/ubuntu/setup_complete.txt
echo "- SSH: $(systemctl is-active sshd)" >> /home/ubuntu/setup_complete.txt
echo "- SSH Port: ${var.ssh_port}" >> /home/ubuntu/setup_complete.txt
%{ if var.enable_fail2ban }
echo "- fail2ban: $(systemctl is-active fail2ban)" >> /home/ubuntu/setup_complete.txt
%{ endif }

echo "All phases completed successfully!"
EOF
}

# バリデーションチェック
resource "null_resource" "validation" {
  lifecycle {
    precondition {
      condition     = contains(var.node_versions, var.default_node_version)
      error_message = "default_node_version '${var.default_node_version}' must be one of the versions specified in node_versions: [${join(", ", var.node_versions)}]"
    }

    precondition {
      condition     = contains(var.python_versions, var.default_python_version)
      error_message = "default_python_version '${var.default_python_version}' must be one of the versions specified in python_versions: [${join(", ", var.python_versions)}]"
    }

    precondition {
      condition     = contains(keys(local.ubuntu_ami_ids), var.aws_region)
      error_message = "aws_region '${var.aws_region}' is not supported. Supported regions: [${join(", ", keys(local.ubuntu_ami_ids))}]. You can add more regions by finding their Ubuntu Minimal AMI IDs."
    }
  }
}

# EC2インスタンス
resource "aws_instance" "claude_code_dev" {
  ami           = local.ubuntu_ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.claude_code_sg.id]

  user_data                   = base64encode(local.user_data)
  user_data_replace_on_change = true

  # ストレージ設定
  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  tags = {
    Name = "claude-code-dev-environment"
    Type = "development"
  }
}

# Elastic IP
resource "aws_eip" "claude_code_eip" {
  instance = aws_instance.claude_code_dev.id
  domain   = "vpc"

  tags = {
    Name = "claude-code-dev-eip"
  }
}

# 出力値
output "instance_public_ip" {
  description = "Public IP address of the instance"
  value       = aws_eip.claude_code_eip.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.claude_code_dev.private_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem -p ${var.ssh_port} ubuntu@${aws_eip.claude_code_eip.public_ip}"
}

output "setup_status" {
  description = "How to check setup status"
  value       = "Check setup status: ssh -i ~/.ssh/${var.key_name}.pem -p ${var.ssh_port} ubuntu@${aws_eip.claude_code_eip.public_ip} 'cat setup_complete.txt'"
}

output "github_ssh_setup" {
  description = "GitHub SSH setup command"
  value       = var.github_email != "" ? "Run GitHub SSH setup: ssh -i ~/.ssh/${var.key_name}.pem -p ${var.ssh_port} ubuntu@${aws_eip.claude_code_eip.public_ip} './setup-github-ssh.sh'" : "GitHub email not configured"
}