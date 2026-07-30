# Porta la Tua Rete

Passa `vpc_id`, `subnet_id` e `security_group_id` per riutilizzare risorse di rete pre-esistenti. L'action provisionerà il server al loro interno senza creare né eliminare il livello di rete.

## Quando usare questa modalità

- Hai una **VPC condivisa** usata da più repository o pipeline.
- Hai bisogno di **regole di sicurezza specifiche** (SSH in ingresso, accesso a servizi interni) configurate in anticipo.
- Vuoi evitare l'overhead di ~30–60 secondi per la creazione di VPC e subnet ad ogni esecuzione.
- Le tue risorse di rete sono **gestite da Terraform** o un altro strumento IaC.

## Prerequisiti

Crea le seguenti risorse nel portale Aruba Cloud o tramite `acloud-cli` prima di usare questa modalità:

1. **VPC** nella regione target.
2. **Subnet** nella VPC (DHCP abilitato, CIDR a scelta).
3. **Security group** nella VPC con almeno una regola **egress allow-all** in modo che il runner possa scaricare pacchetti e raggiungere GitHub.
4. (Opzionale) **Coppia di chiavi SSH** — necessaria solo per accedere via SSH al server per il debug.

Annota gli ID esadecimali di 24 caratteri di ciascuna risorsa.

## Esempio di workflow completo

```yaml
name: CI — rete pre-esistente

on: [push]

jobs:
  start-runner:
    name: Avvia runner effimero
    runs-on: ubuntu-latest
    timeout-minutes: 20
    outputs:
      label:        ${{ steps.runner.outputs.label }}
      server_id:    ${{ steps.runner.outputs.server_id }}
      project_id:   ${{ steps.runner.outputs.project_id }}
      boot_disk_id: ${{ steps.runner.outputs.boot_disk_id }}
      # Nota: auto_vpc_id / auto_subnet_id / auto_security_group_id NON sono
      # dichiarati qui — la rete è pre-esistente e NON deve essere eliminata.
    steps:
      - uses: Arubacloud/acloud-github-runner@v1
        id: runner
        with:
          mode:                 create
          github_token:         ${{ secrets.GH_PAT }}
          acloud_client_id:     ${{ secrets.ACLOUD_CLIENT_ID }}
          acloud_client_secret: ${{ secrets.ACLOUD_CLIENT_SECRET }}
          acloud_project_id:    ${{ secrets.ACLOUD_PROJECT_ID }}
          # Risorse di rete pre-esistenti:
          vpc_id:               ${{ secrets.ACLOUD_VPC_ID }}
          subnet_id:            ${{ secrets.ACLOUD_SUBNET_ID }}
          security_group_id:    ${{ secrets.ACLOUD_SECURITY_GROUP_ID }}
          # Coppia di chiavi SSH opzionale:
          keypair_id:           ${{ secrets.ACLOUD_KEYPAIR_ID }}
          flavor:               CSO4A8
          image:                LU22-001

  build:
    name: Build
    needs: start-runner
    runs-on: ${{ needs.start-runner.outputs.label }}
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v7
      - run: make build

  stop-runner:
    name: Ferma runner effimero
    needs: [start-runner, build]
    runs-on: ubuntu-latest
    timeout-minutes: 15
    if: always()
    steps:
      - uses: Arubacloud/acloud-github-runner@v1
        with:
          mode:          delete
          github_token:  ${{ secrets.GH_PAT }}
          acloud_client_id:     ${{ secrets.ACLOUD_CLIENT_ID }}
          acloud_client_secret: ${{ secrets.ACLOUD_CLIENT_SECRET }}
          acloud_project_id:    ${{ needs.start-runner.outputs.project_id }}
          server_id:     ${{ needs.start-runner.outputs.server_id }}
          boot_disk_id:  ${{ needs.start-runner.outputs.boot_disk_id }}
          name:          ${{ needs.start-runner.outputs.label }}
          # auto_vpc_id, auto_subnet_id, auto_security_group_id sono intenzionalmente
          # omessi — le risorse pre-esistenti non devono essere eliminate.
```

## Segreti GitHub da configurare

| Segreto | Valore |
|---------|--------|
| `ACLOUD_CLIENT_ID` | Client ID API Aruba Cloud |
| `ACLOUD_CLIENT_SECRET` | Client secret API Aruba Cloud |
| `ACLOUD_PROJECT_ID` | Project ID Aruba Cloud |
| `GH_PAT` | GitHub PAT con Administration read/write |
| `ACLOUD_VPC_ID` | ID VPC pre-esistente |
| `ACLOUD_SUBNET_ID` | ID subnet pre-esistente |
| `ACLOUD_SECURITY_GROUP_ID` | ID security group pre-esistente |
| `ACLOUD_KEYPAIR_ID` | (Opzionale) ID coppia di chiavi SSH |

## Crea le risorse con acloud-cli

Puoi creare le risorse condivise una sola volta con `acloud-cli`:

```bash
# Autenticazione
ACLOUD_CLIENT_SECRET="$ACLOUD_CLIENT_SECRET" acloud config set --client-id "$ACLOUD_CLIENT_ID"
acloud context set default --project-id "$ACLOUD_PROJECT_ID"

# Crea VPC
acloud network vpc create \
  --name "ci-vpc" \
  --region "ITBG-Bergamo" \
  --project-id "$ACLOUD_PROJECT_ID"

# Crea Subnet (sostituisci <VPC_ID> con l'ID restituito sopra)
acloud network subnet create <VPC_ID> \
  --name "ci-subnet" \
  --region "ITBG-Bergamo" \
  --cidr "10.0.0.0/24" \
  --dhcp-enabled \
  --project-id "$ACLOUD_PROJECT_ID"

# Crea Security Group
acloud network securitygroup create <VPC_ID> \
  --name "ci-sg" \
  --region "ITBG-Bergamo" \
  --project-id "$ACLOUD_PROJECT_ID"

# Aggiungi regola egress allow-all
acloud network securityrule create <VPC_ID> <SG_ID> \
  --name "allow-all-egress" \
  --region "ITBG-Bergamo" \
  --direction Egress \
  --protocol ANY \
  --target-kind Ip \
  --target-value "0.0.0.0/0" \
  --project-id "$ACLOUD_PROJECT_ID"
```

## Misto: risorse auto e manuali

Puoi fornire parzialmente le risorse di rete. Ad esempio, passa `vpc_id` e `subnet_id` (pre-esistenti) ma ometti `security_group_id` (creato automaticamente):

```yaml
- uses: Arubacloud/acloud-github-runner@v1
  with:
    vpc_id:    ${{ secrets.ACLOUD_VPC_ID }}
    subnet_id: ${{ secrets.ACLOUD_SUBNET_ID }}
    # security_group_id omesso — verrà creato automaticamente
```

In questo caso solo `auto_security_group_id` sarà valorizzato negli output; `auto_vpc_id` e `auto_subnet_id` saranno vuoti.

:::warning
Il security group creato automaticamente viene creato nella VPC che hai fornito. Verrà eliminato dal passo stop. Assicurati che la tua VPC pre-esistente consenta la creazione di security group.
:::
