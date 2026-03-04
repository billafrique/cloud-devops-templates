# cloud-devops-templates

Centralised DevOps templates for the Billafrique platform.
All pipeline templates, infra configs, and docker-compose files live here.

---

## Repo Structure

```
cloud-devops-templates/
├── pipeline-templates/
│   └── dev/
│       ├── infra-deploy.yml              # reusable — deploys MySQL + Redis + Nginx
│       ├── backend-build-deploy.yml      # reusable — builds billafrique-api → DOCR → droplet
│       └── frontend-build-deploy.yml     # reusable — builds frontend → DOCR → droplet
│
├── infra-config/                         # authoritative infra configs deployed to droplet
│   ├── docker-compose.infra.yml
│   ├── .env.example                      # template — copy to .env on droplet, never commit real .env
│   ├── mysql/
│   │   ├── my.cnf
│   │   └── init/01-init.sql
│   ├── redis/
│   │   └── redis.conf
│   └── nginx/
│       ├── nginx.conf
│       └── sites/app.conf
│
└── docker-compose-configs/               # compose files copied to droplet per service
    ├── backend/
    │   ├── docker-compose.prod.yml
    │   └── .env.example
    ├── frontend/
    │   ├── docker-compose.prod.yml
    │   └── .env.example
    └── infra/
        └── docker-compose.infra.yml      # reference copy of infra-config version
```

---

## How Each App Repo Calls These Pipelines

In your `backend-api` or `frontend-app` repo, create `.github/workflows/deploy.yml`:

### Backend (billafrique-api)
```yaml
name: Deploy Backend

on:
  push:
    branches: [dev]

jobs:
  deploy:
    uses: billafrique/cloud-devops-templates/.github/workflows/pipeline-templates/dev/backend-build-deploy.yml@main
    with:
      image_tag: ${{ github.sha }}
    secrets:
      DROPLET_IP: ${{ secrets.DROPLET_IP }}
      SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
      DOCR_TOKEN: ${{ secrets.DOCR_TOKEN }}
      DOCR_ENDPOINT: ${{ secrets.DOCR_ENDPOINT }}
```

### Frontend
```yaml
name: Deploy Frontend

on:
  push:
    branches: [dev]

jobs:
  deploy:
    uses: billafrique/cloud-devops-templates/.github/workflows/pipeline-templates/dev/frontend-build-deploy.yml@main
    with:
      image_tag: ${{ github.sha }}
    secrets:
      DROPLET_IP: ${{ secrets.DROPLET_IP }}
      SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
      DOCR_TOKEN: ${{ secrets.DOCR_TOKEN }}
      DOCR_ENDPOINT: ${{ secrets.DOCR_ENDPOINT }}
```

### Infra (infra-configs repo)
```yaml
name: Deploy Infra

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    uses: billafrique/cloud-devops-templates/.github/workflows/pipeline-templates/dev/infra-deploy.yml@main
    secrets:
      DROPLET_IP: ${{ secrets.DROPLET_IP }}
      SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
```

---

## GitHub Secrets Required Per Repo

| Secret | infra-configs | backend-api | frontend-app |
|---|---|---|---|
| `DROPLET_IP` | ✅ | ✅ | ✅ |
| `SSH_PRIVATE_KEY` | ✅ | ✅ | ✅ |
| `DOCR_TOKEN` | ❌ | ✅ | ✅ |
| `DOCR_ENDPOINT` | ❌ | ✅ | ✅ |
| `MYSQL_ROOT_PASSWORD` | ✅ (.env on droplet) | ❌ | ❌ |
| `REDIS_PASSWORD` | ✅ (.env on droplet) | ❌ | ❌ |

---

## Deployment Order on a Fresh Droplet

```bash
# 1. Infra first — creates billafrique_network, starts MySQL + Redis + Nginx
cd /opt/infra && docker compose -f docker-compose.infra.yml up -d

# 2. Backend — pipeline waits for MySQL + Redis to be healthy
cd /opt/backend && docker compose -f docker-compose.prod.yml up -d

# 3. Frontend — independent, can deploy any time after infra
cd /opt/frontend && docker compose -f docker-compose.prod.yml up -d
```

---

## Droplet Setup (One-Time)

```bash
# Format and mount block storage
mkfs.ext4 /dev/sda
mkdir -p /mnt/volume-data
echo "/dev/sda /mnt/volume-data ext4 defaults,nofail 0 2" >> /etc/fstab
mount -a

# Create data directories with correct ownership
mkdir -p /mnt/volume-data/{mysql,redis}
chown -R 999:999 /mnt/volume-data/mysql
chown -R 999:999 /mnt/volume-data/redis

# Create deploy directories
mkdir -p /opt/{infra,backend,frontend}

# Create .env files from examples (fill in real values)
cp /opt/infra/.env.example /opt/infra/.env
cp /opt/backend/.env.example /opt/backend/.env
cp /opt/frontend/.env.example /opt/frontend/.env
chmod 600 /opt/infra/.env /opt/backend/.env /opt/frontend/.env
```
