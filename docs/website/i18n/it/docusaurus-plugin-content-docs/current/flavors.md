# Flavor e Immagini

## Flavor del Server

Scegli il flavor giusto per il tuo workload. I server vengono fatturati all'ora; i flavor più grandi costano di più ma completano i job più velocemente.

| Flavor | vCPU | RAM | Consigliato per |
|--------|-----:|----:|-----------------|
| `CSO1A2` | 1 | 2 GB | Script leggeri, build semplici |
| `CSO1A4` | 1 | 4 GB | Build Go / Node.js piccole |
| `CSO2A4` | 2 | 4 GB | **Default** — la maggior parte dei workload CI |
| `CSO2A8` | 2 | 8 GB | Build Java / Kotlin, Android |
| `CSO4A8` | 4 | 8 GB | Suite di test parallele, build Docker |
| `CSO4A16` | 4 | 16 GB | Immagini Docker grandi, JVM con heap elevato |
| `CSO8A16` | 8 | 16 GB | Parallelismo intenso, compilazione |
| `CSO8A32` | 8 | 32 GB | Monorepo grandi, build iOS |
| `CSO16A32` | 16 | 32 GB | Cross-compilazione multi-architettura |
| `CSO16A64` | 16 | 64 GB | Preprocessing machine learning |
| `CSO32A64` | 32 | 64 GB | Workload paralleli massivi |

:::tip
Le immagini Windows richiedono almeno `CSO1A4`. Tutti i flavor Linux ≥ `CSO1A4` sono compatibili con le immagini Windows.
:::

## Immagini OS

| Codice immagine | Sistema operativo | Note |
|-----------------|------------------|------|
| `LU20-001` | Ubuntu 20.04 LTS (64-bit) | Fine vita aprile 2025 |
| `LU22-001` | Ubuntu 22.04 LTS (64-bit) | **Consigliata** — LTS fino al 2027 |
| `LU24-001` | Ubuntu 24.04 LTS (64-bit) | Ultima Ubuntu LTS |
| `DE11-001` | Debian 11 (Bullseye, 64-bit) | Stabile |
| `DE12-001` | Debian 12 (Bookworm, 64-bit) | Debian stable corrente |
| `alma8` | AlmaLinux 8 (64-bit) | Compatibile RHEL 8 |
| `alma9` | AlmaLinux 9 (64-bit) | Compatibile RHEL 9 |
| `osuse15_2_x64_1_0` | openSUSE Leap 15 (64-bit) | Basato su SUSE |
| `WS19-001_W2K19_1_0` | Windows Server 2019 | Runner PowerShell |
| `WS22-001_W2K22_1_0` | Windows Server 2022 | Runner PowerShell |

:::note
Il runner GitHub Actions supporta Linux (x64/arm64) e Windows. Usa immagini Linux per la migliore compatibilità con le Actions della community.
:::

## Regioni e Zone

| Regione | Zone | Posizione |
|---------|------|----------|
| `ITBG-Bergamo` | `ITBG-1`, `ITBG-2`, `ITBG-3` | Bergamo, Italia |

:::warning
Tutte le risorse in un singolo workflow (VPC, subnet, security group, server) devono trovarsi nella stessa regione. Le risorse non possono essere spostate tra regioni dopo la creazione.
:::

## Tipi di boot disk

| Tipo | Caso d'uso |
|------|-----------|
| `Performance` | **Default** — basato su SSD, latenza ridotta, migliore throughput I/O. Consigliato per workload CI |
| `Archive` | Basato su HDD, costo inferiore per GB. Non consigliato per workload CI attivi |

## Scegliere il flavor giusto

Per la maggior parte dei workload CI, `CSO2A4` (il default) è un buon punto di partenza. Ecco gli scenari comuni:

```yaml
# Leggero: script, linting, test semplici
flavor: CSO1A2

# Build Go / Node.js / Python standard
flavor: CSO2A4   # default

# Build immagini Docker
flavor: CSO4A8

# Build Android / Java con heap elevato
flavor: CSO4A16

# Suite di test parallele o compilazioni pesanti
flavor: CSO8A32
```
