# helmfile-reporter-bot (WIP)

Run helmfile in a pipeline and report the diff to a merge request.

## example action (tested on Gitea)

```yaml
---
name: helmfile reporter bot

on: push

jobs:
  build:
    name: helmfile reporter bot
    container:
      image: repo/helmfile-reporter-bot:latest
    steps:
      - name: install nodejs
        run: |
          apt-get update && apt-get install curl -y && \
          curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
          apt-get install nodejs -y

      - uses: actions/checkout@v3

      - name: helmfile reporter bot
        env:
          LOG_LEVEL: debug
          KUBE_CONTEXT: private
          KUBE_CONFIG: ${{ secrets.KUBE_CONFIG }}
        run: |
          /opt/helmfile-reporter-bot/helmfile-reporter-bot.sh

      - name: output
        run: |
          cat helmfile-report/report.txt

```

## env vars

### aws (use serviceaccount if not set) (WIP)

```bash
AWS_ACCESS_KEY_ID (optional)
AWS_SECRET_ACCESS_KEY (optional)
AWS_DEFAULT_REGION or AWS_REGION (optional)
```

### k8s

```bash
KUBE_CONFIG (as base64, or fetch using `aws eks`)
KUBE_CONTEXT
```

### helmfile

```bash
HELMFILE_ENVIRONMENT
HELMFILE_SELECTOR
```

### GITLAB (WIP)

```bash
GITLAB_USERNAME
GITLAB_TOKEN
```

### GITEA (WIP)

```bash
???
```

## GITHUB (WIP)

```bash
???
```
