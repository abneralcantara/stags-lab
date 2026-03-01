# stags-lab — Prompt Injection + Docker Escape + Azure MSI Lab

CTF-style security lab demonstrating a chain of real-world vulnerabilities in AI-powered cloud applications running on Azure.

## Attack Chain

```
Prompt Injection → Shell Execution → Docker Socket Escape → Azure IMDS → Managed Identity Token
```

## Difficulty Levels

| Level | Folder | Name | Description |
|-------|--------|------|-------------|
| 2 — Moderada   | `medium/` | AzureAssist  | Hidden system prompt, JSON function-call injection, enumeration required |
| 3 — Desafiadora | `hard/`  | CloudGuard AI | Input/output filters, context-note injection bypass, Docker API via UNIX socket |

## Quick Start

```bash
# Level 2 — Moderada
cd medium/
docker compose up --build

# Level 3 — Desafiadora
cd hard/
docker compose up --build
```

App runs at **http://localhost:5000**

## Objectives (both levels)

1. **Prompt Injection** — manipulate the AI chatbot to execute internal tools
2. **Shell Access** — run arbitrary commands inside the app container
3. **Docker Escape** — use the mounted Docker socket to create a privileged container
4. **Azure Metadata** — read VM metadata from the Instance Metadata Service (IMDS)
5. **Managed Identity** — obtain a managed identity token via IMDS
6. **Sensitive Data** — read credentials, environment variables, and flags

## Flags (3 per level)

| Flag | Location | How to obtain |
|------|----------|---------------|
| `FLAG_1` | Environment variable `FLAG` | Prompt injection → `env` or `printenv` |
| `FLAG_2` | Host filesystem (Docker escape) | Create privileged container → mount host `/` → read `/root/FLAG_2.txt` |
| `FLAG_3` | Azure IMDS metadata response | Query IMDS `/metadata/instance` → look in `compute.ctfFlag` |

> **Note for FLAG_2**: After escaping, place the flag file on the Docker host before starting the lab:
> ```bash
> sudo mkdir -p /root && echo "FLAG_2{d0ck3r_s0ck3t_3sc4p3_succ3ss}" | sudo tee /root/FLAG_2.txt
> ```

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│  Docker Host  (simulates Azure VM with Managed Identity)       │
│                                                                │
│  ┌──────────────────────────┐   ┌──────────────────────────┐  │
│  │  lab-app container       │   │  mock-imds container      │  │
│  │  Flask chatbot (port 5000)│◄─►│  Azure IMDS simulator    │  │
│  │                          │   │  169.254.169.254 → :80   │  │
│  │  /var/run/docker.sock ───┼──►│  (172.28.0.254)          │  │
│  │  (mounted from host!)    │   └──────────────────────────┘  │
│  └──────────┬───────────────┘                                  │
│             │ Docker socket (escape vector)                    │
│  ┌──────────▼───────────────┐                                  │
│  │  Escaped container       │                                  │
│  │  --privileged -v /:/mnt  │                                  │
│  │  (accesses host FS)      │                                  │
│  └──────────────────────────┘                                  │
└────────────────────────────────────────────────────────────────┘
```

## Key Technical Details

### Mock Azure IMDS
- The `mock-imds` container runs Flask on port 80 at `172.28.0.254`
- The app container's `/etc/hosts` maps `169.254.169.254 → 172.28.0.254` via `extra_hosts`
- On a **real Azure VM**, `169.254.169.254` is provided natively by the hypervisor — no mock needed
- All IMDS API responses are realistic and include the flag in `compute.ctfFlag`

### Docker Socket
- Mounted at `/var/run/docker.sock` inside the app container
- Allows creating new Docker containers from within the app
- The escape technique: `docker run --rm -it --privileged -v /:/mnt alpine sh`
- From inside the escaped container: `chroot /mnt` → full host access

### Managed Identity (Simulated)
```bash
# From inside app container (after shell injection):
curl -s -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/"

# On a real Azure VM, this returns a real Bearer token usable with:
az login --identity
az account show
az keyvault secret list --vault-name kv-stags-lab
```

## Writeups

- `medium/writeup/SOLUTION.md` — Step-by-step solution for Level 2
- `hard/writeup/SOLUTION.md` — Step-by-step solution for Level 3

## Environment Variables (Sensitive Data)

Both levels expose these secrets via environment variables (readable via shell injection):

| Variable | Description |
|----------|-------------|
| `FLAG` | Primary CTF flag |
| `DB_PASSWORD` | Database password |
| `INTERNAL_API_KEY` | Internal API key |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_CLIENT_ID` | Managed identity client ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
