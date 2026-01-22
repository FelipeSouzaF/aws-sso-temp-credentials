# aws-sso-temp-credentials

Script para obter credenciais temporárias do AWS SSO e atualizar automaticamente seu arquivo `.env`.

## Prerequisites

Antes de usar este script, certifique-se de ter instalado:

- **AWS CLI v2** - [Download](https://aws.amazon.com/cli/)
- **jq** - JSON processor

  ```shell
  # Ubuntu/Debian
  sudo apt-get install jq
  
  # macOS
  brew install jq

  # Fedora/RHEL
  sudo dnf install jq
  ```

- **Bash 4.0+** (geralmente já disponível em sistemas Linux/macOS)

## Install

```shell
    git clone git@github.com:FelipeSouzaF/aws-sso-temp-credentials.git && \
    cd aws-sso-temp-credentials && \
    sudo cp aws-temp-credential.sh /usr/local/bin/ && \
    sudo chmod +x /usr/local/bin/aws-temp-credential.sh
```

Para verificar a instalação:

```shell
    which aws-temp-credential.sh
    # Should output: /usr/local/bin/aws-temp-credential.sh
```

## Usage

### 1. Configure seu perfil AWS SSO

Configure o arquivo `$HOME/.aws/config` com seu perfil:

```shell
    cat <<EOF >> $HOME/.aws/config
[profile my-awesome-profile]
sso_start_url = https://your-aws-sso-domain.awsapps.com/start#/
sso_region = us-east-1
sso_account_id = 000000000001
sso_role_name = AdministratorAccess
region = us-east-1
output = json
EOF
```

### 2. Crie o arquivo .env

O script atualiza um arquivo `.env` existente. Crie-o com as chaves necessárias:

```shell
    cat <<EOF > .env
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_SESSION_TOKEN=
EOF
```

### 3. Configure a variável de ambiente AWS_PROFILE

```shell
    export AWS_PROFILE="my-awesome-profile"
```

### 4. Faça login no AWS SSO

```shell
    aws sso login
```

### 5. Execute o script

```shell
    aws-temp-credential.sh
```

O script irá:

- Validar dependências e configurações
- Recuperar credenciais temporárias do AWS SSO
- Atualizar o arquivo `.env` (criando backup como `.env.backup`)
- Exibir mensagem de sucesso

## Troubleshooting

### Error: 'jq' is required but not installed

Instale o `jq` seguindo as instruções na seção [Prerequisites](#prerequisites).

### Error: AWS_PROFILE environment variable is not set

Execute: `export AWS_PROFILE='your-profile-name'`

### Error: Could not retrieve all required values from AWS config

Verifique se seu perfil em `~/.aws/config` contém todos os campos obrigatórios:

- `sso_start_url`
- `sso_region`
- `sso_account_id`
- `sso_role_name`

### Error: No matching SSO cache file found

Execute o login SSO novamente: `aws sso login --profile $AWS_PROFILE`

### Error: Failed to retrieve AWS credentials

Suas credenciais SSO podem ter expirado. Execute: `aws sso login --profile $AWS_PROFILE`

### Error: .env file does not exist

Crie o arquivo `.env` conforme mostrado na seção [Usage](#usage), passo 2.

## Security Notes

- O script cria backups automáticos do arquivo `.env` antes de modificá-lo
- Credenciais sensíveis são mostradas parcialmente no terminal (apenas primeiros 20 caracteres)
- Certifique-se de que o arquivo `.env` tenha permissões apropriadas:

  ```shell
  chmod 600 .env
  ```

- Adicione `.env` e `.env.backup` ao seu `.gitignore` para evitar commit acidental de credenciais

## How It Works

1. O script lê a configuração do perfil AWS SSO do arquivo `~/.aws/config`
2. Localiza o arquivo de cache do AWS SSO mais recente em `~/.aws/sso/cache/`
3. Extrai o access token do cache
4. Usa o AWS CLI para obter credenciais temporárias via `aws sso get-role-credentials`
5. Atualiza o arquivo `.env` com as novas credenciais
6. Cria um backup do `.env` antes de modificá-lo

## Credential Expiration

As credenciais temporárias do AWS SSO geralmente expiram após:

- **Access token**: ~8 horas (requer novo `aws sso login`)
- **Temporary credentials**: ~1 hora (requer executar o script novamente)

Quando as credenciais expirarem, você receberá erros da AWS. Execute `aws sso login` novamente e depois o script.

## License

Ver arquivo [LICENSE](LICENSE) para detalhes.
