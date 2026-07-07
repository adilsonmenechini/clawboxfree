# Kilo AI Free Login

Script Python para configurar autenticação free do Kilo AI via API key manual.

## Uso

```bash
# Login interativo (salva API key em ~/.kilo.env)
python3 kilo_login.py

# Verificar status do token
python3 kilo_login.py --status
```

## O que o script faz

- Solicita sua Kilo API key
- Salva em `~/.kilo.env`
- Define variáveis de ambiente necessárias
- Permite reutilizar a key em sessões futuras

## Variáveis necessárias

```
LLM_PROVIDER=kilo
KILO_API_URL=https://api.kilo.ai/api/gateway
KILO_API_KEY=sua_key_aqui
LLM_MODEL=kilo-auto/free
```

## Nota

O fluxo oficial `kilo auth login` (CLI própria do Kilo) continua sendo a opção recomendada para device authorization. Este script é uma alternativa simplificada quando você já possui uma API key.
