# Script para remover bloco comentado do EA
$file = "d:\EA_Projetos\Nexus_Confluence_MT5\Nexus_Confluence_MT5\Experts\NexusConfluenceEA\NexusConfluenceEA.mq5"

# Ler todas as linhas
$lines = Get-Content $file

# Encontrar índices das seções
$startComment = -1
$endComment = -1

for ($i = 0; $i < $lines.Count; $i++) {
    if ($lines[$i] -match "FUNÇÕES DO CICLO DE VIDA DO EA" -and $startComment -eq -1) {
        $startComment = $i + 2  # Linha após o comentário
    }
    if ($lines[$i] -match "int OnInit\(\)") {
        if ($endComment -eq -1) {
            $endComment = $i - 5  # 5 linhas antes do segundo OnInit
        }
    }
}

Write-Host "Início do bloco comentado: linha $startComment"
Write-Host "Fim do bloco comentado: linha $endComment"

# Criar novo arquivo sem o bloco comentado
$newLines = @()
$newLines += $lines[0..($startComment-1)]  # Até o início
$newLines += $lines[($endComment+1)..($lines.Count-1)]  # Depois do bloco

# Salvar
$newLines | Set-Content $file -Encoding UTF8

Write-Host "Arquivo limpo! Removidas $(($endComment-$startComment+1)) linhas."
