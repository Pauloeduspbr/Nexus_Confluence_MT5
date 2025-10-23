#!/bin/bash
# Instalação de dependências para análise de produção

echo "🔧 Instalando dependências para Nexus Confluence Production Analyzer..."

# Verificar se pip está disponível
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 não encontrado. Instale Python 3.7+ primeiro."
    exit 1
fi

# Instalar dependências
pip3 install --upgrade pip
pip3 install numpy pandas scipy scikit-learn tqdm

echo ""
echo "✅ Dependências instaladas com sucesso!"
echo ""
echo "Para executar a análise:"
echo "  python3 Tools/master_analyzer.py"
echo ""
