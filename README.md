## 📁 必要なファイル

以下のファイルを同じディレクトリに配置してください：

1. `main.tf` - メインのTerraform設定
2. `variables.tf` - 変数定義
3. `terraform.tfvars.sample` - 設定値のサンプル
4. `README.md` - このマニュアル

**# Claude Code開発環境構築マニュアル

## 📋 概要

このマニュアルでは、TerraformとAWSを使用してClaude Code開発環境を構築する手順を説明します。構築される環境には以下が含まれます：

- **セキュアなEC2インスタンス**（カスタムSSHポート、UFW、fail2ban）
- **開発ツール**（mise、Node.js、Python、Claude Code）
- **SSH認証**（keychain、GitHub連携）
- **日本語環境**（ja_JP.UTF-8ロケール、uim日本語入力）

## 🛠️ 前提条件

- AWS CLIがインストール・設定済み
- Terraformがインストール済み（v1.0以上）
- ローカルマシンにSSHクライアント

## 📁 必要なファイル

以下の4つのファイルを同じディレクトリに配置してください：

1. `main.tf` - メインのTerraform設定
2. `variables.tf` - 変数定義
3. `terraform.tfvars` - 環境固有の設定値
4. `README.md` - このマニュアル

## 🔐 STEP 1: AWSキーペアの作成

### 1.1 AWS CLIでキーペア作成

```bash
# キーペアを作成
aws ec2 create-key-pair \
  --key-name claude-dev-key \
  --region ap-northeast-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/claude-dev-key.pem

# 権限設定
chmod 600 ~/.ssh/claude-dev-key.pem
```

### 1.2 AWS Management Consoleでの作成（代替方法）

1. [EC2コンソール](https://console.aws.amazon.com/ec2/) にアクセス
2. 左メニューの「キーペア」をクリック
3. 「キーペアを作成」をクリック
4. 名前：`claude-dev-key`
5. キータイプ：`RSA`
6. プライベートキーファイル形式：`.pem`
7. 「キーペアを作成」をクリック
8. ダウンロードされたファイルを `~/.ssh/claude-dev-key.pem` に配置
9. 権限設定：`chmod 600 ~/.ssh/claude-dev-key.pem`

### 1.3 キーペア確認

```bash
# キーペアが存在することを確認
aws ec2 describe-key-pairs --key-names claude-dev-key --region ap-northeast-1
```

## 📝 STEP 2: 設定ファイルの準備

### 2.1 terraform.tfvars の作成

サンプルファイルをコピーして設定ファイルを作成します：

```bash
# サンプルファイルをコピー
cp terraform.tfvars.sample terraform.tfvars

# 設定ファイルを編集
vim terraform.tfvars
```

以下の項目を**必ず**あなたの情報に変更してください：

```hcl
# 必須変更項目
key_name = "claude-dev-key"        # 作成したキーペア名
github_username = "your-username"  # あなたのGitHubユーザー名
github_email = "your@email.com"    # あなたのメールアドレス
```

その他の設定はお好みで調整してください。

### 2.2 設定値の説明

`terraform.tfvars.sample` に記載されている設定項目の説明：

| 設定項目 | 説明 | 推奨値 |
|---------|------|--------|
| `aws_region` | AWSリージョン | `ap-northeast-1` (東京) |
| `instance_type` | EC2インスタンスタイプ | `t3.medium` (開発用途) |
| `ssh_port` | カスタムSSHポート | `10022` (セキュリティ向上) |
| `node_versions` | インストールするNode.jsバージョン | お好みで選択 |
| `python_versions` | インストールするPythonバージョン | お好みで選択 |

## 🚀 STEP 3: インフラストラクチャのデプロイ

### 3.1 Terraformの初期化

```bash
# プロジェクトディレクトリに移動
cd /path/to/your/terraform/project

# Terraformを初期化
terraform init
```

### 3.2 設定の確認

```bash
# デプロイ内容を確認
terraform plan
```

出力内容を確認し、想定通りのリソースが作成されることを確認してください。

### 3.3 デプロイ実行

```bash
# インフラストラクチャをデプロイ
terraform apply

# "yes" と入力して実行確認
```

### 3.4 出力値の確認

デプロイ完了後、以下の情報が出力されます：

```bash
instance_public_ip = "xxx.xxx.xxx.xxx"
ssh_command = "ssh -i ~/.ssh/claude-dev-key.pem -p 10022 ubuntu@xxx.xxx.xxx.xxx"
setup_status = "Check setup status: ssh -i ~/.ssh/claude-dev-key.pem -p 10022 ubuntu@xxx.xxx.xxx.xxx 'cat setup_complete.txt'"
github_ssh_setup = "Run GitHub SSH setup: ssh -i ~/.ssh/claude-dev-key.pem -p 10022 ubuntu@xxx.xxx.xxx.xxx './setup-github-ssh.sh'"
```

## 🔗 STEP 4: EC2インスタンスへの接続

### 4.1 SSH接続

```bash
# 出力されたSSHコマンドを使用
ssh -i ~/.ssh/claude-dev-key.pem -p 10022 ubuntu@xxx.xxx.xxx.xxx
```

### 4.2 セットアップ状況の確認

```bash
# セットアップ完了を確認
cat setup_complete.txt
```

以下のような出力が表示されれば成功です：

```
Setup completed successfully at [日時]
Service status check:
- UFW: Status: active
- SSH: active
- SSH Port: 10022
- fail2ban: active
```

## 🔑 STEP 5: GitHub SSH認証の設定

### 5.1 GitHub SSH設定スクリプトの実行

```bash
# GitHub SSH設定を実行
./setup-github-ssh.sh
```

### 5.2 パスフレーズの入力

```bash
Enter passphrase (empty for no passphrase): [強固なパスフレーズを入力]
Enter same passphrase again: [同じパスフレーズを再入力]
```

### 5.3 公開鍵のコピー

スクリプト実行後、以下のような公開鍵が表示されます：

```
=== GitHub SSH Public Key ===
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx your-email@example.com

📋 Copy the above public key to GitHub SSH settings:
   https://github.com/settings/ssh/new
```

### 5.4 GitHubへの公開鍵登録

1. [GitHub SSH設定ページ](https://github.com/settings/ssh/new) にアクセス
2. **Title**: `Claude Dev Environment - [日付]`
3. **Key**: 上記で表示された公開鍵をコピー&ペースト
4. 「Add SSH key」をクリック

### 5.5 SSH接続テスト

```bash
# GitHub SSH接続をテスト
ssh -T git@github.com
```

成功すると以下のメッセージが表示されます：

```
Hi [your-username]! You've successfully authenticated, but GitHub does not provide shell access.
```

## 🧪 STEP 6: 動作確認

### 6.1 開発環境の確認

```bash
# Node.js バージョン確認
node --version

# Python バージョン確認
python --version

# Claude Code確認
claude-code --version

# mise確認
mise list
```

### 6.2 Git操作テスト

```bash
# テスト用のディレクトリ作成
cd ~/workspace
mkdir test-repo
cd test-repo

# Gitリポジトリ初期化
git init
echo "# Test Repository" > README.md
git add README.md
git commit -m "Initial commit"

# GitHubに新しいリポジトリを作成してプッシュテスト
# (事前にGitHubでリポジトリを作成しておく)
git remote add origin git@github.com:your-username/test-repo.git
git push -u origin main
```

**⚠️ 重要**: リポジトリURLは**SSH形式**（`git@github.com:`）を使用してください。HTTPS形式だとSSH認証が働きません。

## 🔧 STEP 7: 開発作業の開始

### 7.1 プロジェクトのクローン

```bash
# SSH形式でクローン（推奨）
git clone git@github.com:username/repository.git

# プロジェクトディレクトリに移動
cd repository
```

### 7.2 Claude Codeの使用

```bash
# Claude Codeを起動
claude-code

# または特定のファイルで起動
claude-code filename.js
```

### 7.3 日本語入力の使用

```bash
# 日本語入力モードを開始
uim-fep

# または短縮コマンド
jp
japanese

# 日本語入力モード中
# Ctrl+Space で 日本語⇔英語 切り替え
```

### 7.4 Node.jsバージョン切り替え

```bash
# 利用可能なバージョン一覧
mise list node

# バージョン切り替え
mise use node@20.16.0

# プロジェクト固有の設定
echo "node 20.16.0" > .tool-versions
```

## 🛡️ セキュリティ設定

### 設定済みの環境機能

- **ロケール**: ja_JP.UTF-8（日本語環境）
- **タイムゾーン**: Asia/Tokyo（日本時間）
- **日本語入力**: uim + Anthy（Ctrl+Spaceで切り替え）
- **セキュリティ**: カスタムSSHポート、UFW、fail2ban
- **開発環境**: mise + Node.js + Python + Claude Code

### 追加セキュリティ対策（推奨）

```bash
# SSH接続ログの確認
sudo tail -f /var/log/auth.log

# fail2ban状況確認
sudo fail2ban-client status sshd

# UFW設定確認
sudo ufw status verbose
```

## 🔄 メンテナンス

### アップデート

```bash
# システムアップデート
sudo apt update && sudo apt upgrade -y

# Node.jsの新バージョンインストール
mise install node@latest

# Pythonの新バージョンインストール
mise install python@latest
```

### バックアップ

重要なデータは定期的にGitリポジトリにコミットしてください：

```bash
# 定期的なコミット
git add .
git commit -m "Work in progress"
git push
```

## 🧹 環境の削除

作業完了後、環境を削除する場合：

```bash
# Terraformで作成したリソースを削除
terraform destroy

# "yes" と入力して削除確認
```

## ❗ トラブルシューティング

### よくある問題と解決法

#### 1. SSH接続できない

```bash
# セキュリティグループの確認
aws ec2 describe-security-groups --filters "Name=group-name,Values=claude-code-*"

# SSHポートが正しく開いているか確認
# 10022番ポートが許可されていることを確認
```

#### 2. git pushでパスワードを求められる

```bash
# リモートURLを確認
git remote -v

# SSH形式に変更
git remote set-url origin git@github.com:username/repository.git
```

#### 3. セットアップスクリプトが完了しない

```bash
# user-dataログを確認
sudo cat /var/log/user-data.log

# 手動でスクリプトを再実行
sudo bash /var/lib/cloud/instances/*/user-data.txt
```

#### 5. keychainが動作しない

```bash
# bashrcの再読み込み
source ~/.bashrc

# keychainを手動実行
keychain ~/.ssh/github_ed25519
source ~/.keychain/$(hostname)-sh
```

## 📚 参考資料

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [mise Documentation](https://mise.jdx.dev/)
- [GitHub SSH Authentication](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)

---
