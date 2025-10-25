#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
EXTRATOR DE PARÂMETROS REAIS
Extrai configuração REAL usada no backtest do log de debug MT5
"""

import re
import sys
from pathlib import Path

def extract_params_from_log(log_path: str) -> dict:
    """Extrai TODOS os parâmetros reais do log de debug MT5"""
    
    params = {}
    
    try:
        with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # Procurar seção "Tester.*started with inputs:"
        match = re.search(r'started with inputs:(.*?)(?=\n\S|\Z)', content, re.DOTALL)
        
        if match:
            inputs_section = match.group(1)
            
            # Extrair todos os parâmetros (formato: "    Tester    param=value")
            param_matches = re.findall(r'Tester\s+(\w+)=([^\n]+)', inputs_section)
            
            for param_name, param_value in param_matches:
                # Limpar valor (remover espaços e comentários inline)
                param_value = param_value.strip()
                
                # Converter tipos
                if param_value.lower() in ['true', 'false']:
                    params[param_name] = (param_value.lower() == 'true')
                elif '.' in param_value:
                    try:
                        params[param_name] = float(param_value)
                    except:
                        params[param_name] = param_value
                else:
                    try:
                        params[param_name] = int(param_value)
                    except:
                        params[param_name] = param_value
        
        return params
    
    except Exception as e:
        print(f"❌ ERRO ao ler log: {e}")
        return {}


def display_params(params: dict):
    """Exibe parâmetros organizados por categoria"""
    
    print("=" * 80)
    print("📋 PARÂMETROS REAIS DO BACKTEST (Extraídos do Log de Debug)")
    print("=" * 80)
    
    # Categorizar parâmetros
    gestao_risco = {}
    tp_sl = {}
    breakeven_trail = {}
    filtros = {}
    indicadores = {}
    horarios = {}
    outros = {}
    
    for key, value in params.items():
        key_lower = key.lower()
        
        if any(x in key_lower for x in ['risk', 'drawdown', 'consecutive', 'loss', 'pause']):
            gestao_risco[key] = value
        elif any(x in key_lower for x in ['tp_', 'sl_', 'partial', 'takeprofit', 'stoploss']):
            tp_sl[key] = value
        elif any(x in key_lower for x in ['breakeven', 'trailing', 'trail', 'be_']):
            breakeven_trail[key] = value
        elif any(x in key_lower for x in ['filter', 'require', 'strict', 'confluence', 'alignment']):
            filtros[key] = value
        elif any(x in key_lower for x in ['wae_', 'rsi_', 'st_', 'cs_', 'gg_', 'indicator', 'cci', 'atr', 'adx']):
            indicadores[key] = value
        elif any(x in key_lower for x in ['hour', 'minute', 'tradeon', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday']):
            horarios[key] = value
        else:
            outros[key] = value
    
    # Exibir por categoria
    if gestao_risco:
        print("\n💰 GESTÃO DE RISCO:")
        for k, v in sorted(gestao_risco.items()):
            print(f"   {k:45s} = {v}")
    
    if tp_sl:
        print("\n🎯 TAKE PROFIT / STOP LOSS:")
        for k, v in sorted(tp_sl.items()):
            print(f"   {k:45s} = {v}")
            
            # Converter para pips
            if k == 'SL_Points' and isinstance(v, (int, float)):
                pips = v / 10.0
                print(f"   {'':45s}   (= {pips:.1f} pips)")
            elif k == 'TP_Points' and isinstance(v, (int, float)):
                pips = v / 10.0
                print(f"   {'':45s}   (= {pips:.1f} pips)")
    
    if breakeven_trail:
        print("\n📈 BREAKEVEN / TRAILING:")
        for k, v in sorted(breakeven_trail.items()):
            print(f"   {k:45s} = {v}")
    else:
        print("\n⚠️  NENHUM parâmetro de Breakeven/Trailing configurado!")
    
    if filtros:
        print("\n🔍 FILTROS / CONFLUÊNCIA:")
        for k, v in sorted(filtros.items()):
            print(f"   {k:45s} = {v}")
    
    if indicadores:
        print("\n📊 INDICADORES:")
        for k, v in sorted(indicadores.items()):
            # Mostrar apenas indicadores principais (não todos os parâmetros)
            if 'Indicator' in k or k.endswith('_Period') or k.endswith('_Multiplier'):
                print(f"   {k:45s} = {v}")
    
    if horarios:
        print("\n⏰ HORÁRIOS DE OPERAÇÃO:")
        # Mostrar apenas primeiros e últimos
        for k, v in list(sorted(horarios.items()))[:8]:
            print(f"   {k:45s} = {v}")
    
    # Calcular ratio TP:SL
    if 'TP_Points' in tp_sl and 'SL_Points' in tp_sl:
        tp = tp_sl['TP_Points']
        sl = tp_sl['SL_Points']
        ratio = tp / sl if sl > 0 else 0
        
        print("\n" + "=" * 80)
        print(f"📐 RATIO TP:SL = {ratio:.2f}:1")
        print(f"   TP = {tp:.0f} pontos ({tp/10:.1f} pips)")
        print(f"   SL = {sl:.0f} pontos ({sl/10:.1f} pips)")
        print("=" * 80)


def main():
    """Função principal"""
    
    # Verificar argumentos
    if len(sys.argv) < 2:
        print("❌ ERRO: Caminho do log não fornecido!")
        print("\nUSO:")
        print("   python extract_real_params.py <caminho_do_log>")
        print("\nEXEMPLO:")
        print("   python extract_real_params.py log/20251025.log")
        sys.exit(1)
    
    log_path = sys.argv[1]
    
    # Verificar se arquivo existe
    if not Path(log_path).exists():
        print(f"❌ ERRO: Arquivo não encontrado: {log_path}")
        sys.exit(1)
    
    # Extrair parâmetros
    print(f"📂 Lendo log: {log_path}")
    print()
    
    params = extract_params_from_log(log_path)
    
    if not params:
        print("❌ ERRO: Nenhum parâmetro encontrado no log!")
        print("\n💡 DICA: Certifique-se de que o log contém a seção")
        print("   'testing of ... started with inputs:'")
        sys.exit(1)
    
    # Exibir resultados
    display_params(params)
    
    print(f"\n✅ Total de {len(params)} parâmetros extraídos com sucesso!")


if __name__ == '__main__':
    main()
