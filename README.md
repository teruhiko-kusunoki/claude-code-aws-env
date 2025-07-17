# Claude Code AWS Environment

このプロジェクトは、TerraformでAWS環境を構築するためのコードです。

## 必要なもの

- Terraform (v1.0以上)
- AWS CLIが設定済みであること
- 適切なAWSアクセス権限

## 使い方

1. `terraform.tfvars.sample`をコピーして`terraform.tfvars`を作成
   ```bash
   cp terraform.tfvars.sample terraform.tfvars
   ```

2. `terraform.tfvars`を編集して、必要な変数を設定

3. Terraformを初期化
   ```bash
   terraform init
   ```

4. 変更内容を確認
   ```bash
   terraform plan
   ```

5. インフラストラクチャを構築
   ```bash
   terraform apply
   ```

## ファイル構成

- `main.tf` - メインのTerraform設定
- `variables.tf` - 変数定義
- `terraform.tfvars.sample` - 変数値のサンプル

## クリーンアップ

作成したリソースを削除する場合：
```bash
terraform destroy
```