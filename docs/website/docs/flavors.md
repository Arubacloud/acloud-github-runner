# Flavors & Images

## Server Flavors

Choose the right flavor for your workload. Servers are billed hourly; bigger flavors cost more but complete jobs faster.

| Flavor | vCPU | RAM | Recommended for |
|--------|-----:|----:|-----------------|
| `CSO1A2` | 1 | 2 GB | Lightweight scripts, simple builds |
| `CSO1A4` | 1 | 4 GB | Small Go / Node.js builds |
| `CSO2A4` | 2 | 4 GB | **Default** — most CI workloads |
| `CSO2A8` | 2 | 8 GB | Java / Kotlin builds, Android |
| `CSO4A8` | 4 | 8 GB | Parallel test suites, Docker builds |
| `CSO4A16` | 4 | 16 GB | Large Docker images, JVM with heap |
| `CSO8A16` | 8 | 16 GB | Heavy parallelism, compilation |
| `CSO8A32` | 8 | 32 GB | Large monorepos, iOS builds |
| `CSO16A32` | 16 | 32 GB | Multi-arch cross-compilation |
| `CSO16A64` | 16 | 64 GB | Machine learning preprocessing |
| `CSO32A64` | 32 | 64 GB | Massive parallel workloads |

:::tip
Windows images require at least `CSO1A4`. All Linux flavors ≥ `CSO1A4` are compatible with Windows images.
:::

## OS Images

| Image code | Operating system | Notes |
|------------|-----------------|-------|
| `LU20-001` | Ubuntu 20.04 LTS (64-bit) | End of life April 2025 |
| `LU22-001` | Ubuntu 22.04 LTS (64-bit) | **Recommended** — LTS until 2027 |
| `LU24-001` | Ubuntu 24.04 LTS (64-bit) | Latest Ubuntu LTS |
| `DE11-001` | Debian 11 (Bullseye, 64-bit) | Stable |
| `DE12-001` | Debian 12 (Bookworm, 64-bit) | Current Debian stable |
| `alma8` | AlmaLinux 8 (64-bit) | RHEL 8 compatible |
| `alma9` | AlmaLinux 9 (64-bit) | RHEL 9 compatible |
| `osuse15_2_x64_1_0` | openSUSE Leap 15 (64-bit) | SUSE-based |
| `WS19-001_W2K19_1_0` | Windows Server 2019 | PowerShell runners |
| `WS22-001_W2K22_1_0` | Windows Server 2022 | PowerShell runners |

:::note
The GitHub Actions runner agent supports Linux (x64/arm64) and Windows. Use Linux images for the best compatibility with community Actions.
:::

## Regions and Zones

| Region | Zones | Location |
|--------|-------|---------|
| `ITBG-Bergamo` | `ITBG-1`, `ITBG-2`, `ITBG-3` | Bergamo, Italy |

:::warning
All resources in a single workflow (VPC, subnet, security group, server) must be in the same region. Resources cannot be moved between regions after creation.
:::

## Boot disk types

| Type | Use case |
|------|---------|
| `Performance` | **Default** — SSD-backed, lower latency, better I/O throughput. Recommended for CI workloads |
| `Archive` | HDD-backed, lower cost per GB. Not recommended for active CI workloads |

## Choosing the right flavor

For most CI workloads `CSO2A4` (the default) is a good starting point. Here are common scenarios:

```yaml
# Lightweight: scripts, linting, simple tests
flavor: CSO1A2

# Standard Go / Node.js / Python build
flavor: CSO2A4   # default

# Docker image build
flavor: CSO4A8

# Android / Java build with large heap
flavor: CSO4A16

# Parallel test suites or large compilations
flavor: CSO8A32
```
