# Nexus Confluence EA v3.0.1

**Expert Advisor Profissional para MetaTrader 5**
Sistema de Confluencia Multi-Timeframe com 6 Gates de Validacao | Arquitetura Hibrida MQL5 + C++ DLL

---

## Arquitetura

```
MQL5 (Wrapper fino)          C++ DLL (Toda logica)
  OnTick() ───────────────>  NX_ProcessTick()
  iCustom() indicators       5 indicadores internos
  CTrade orders               6 gates sequenciais
  Chart panel                 Risk management
```

- **DLL**: ~9,700 linhas C++ compiladas em binario nativo x64
- **MQL5 Wrapper**: Orquestra dados, ordens e visualizacao
- **Protecao IP**: Logica em DLL binaria (impossivel decompilar)
- **Shared Memory**: Indicadores visuais leem da DLL via Windows Named Memory-Mapped Files
- **Multi-Instancia**: Ate 20 simbolos simultaneos no mesmo terminal

## Sistema de 6 Gates

Cada trade passa por 6 validacoes sequenciais. Se qualquer gate rejeitar, o sinal e descartado.

| Gate | Nome | Funcao |
|------|------|--------|
| **Gate 1** | Market Access | Spread filter (absoluto + dinamico), time filter, day filter |
| **Gate 2** | MTF Analysis | GG TrendBar em 3 macro TFs + operational. Score -4 a +4 |
| **Gate 3** | Supertrend | TrendMagic (CCI + Kaufman ER) confirma direcao |
| **Gate 4** | Signal Quality | OBV MACD threshold + RSI OMA crossover. RSI OB/OS filter |
| **Gate 5** | Trend Quality | Efficiency Ratio min + momentum ratio + ER decline filter |
| **Gate 6** | Risk Check | Max positions, cooldown anti-churn, macro flip cooldown |

## Gestao de Risco

- **Break Even**: trigger + step configuravel por BUY/SELL separadamente
- **Trailing Stop**: ativacao independente BUY/SELL
- **Drawdown Protection**: daily max %, consecutive loss limit, lot reduction
- **Dynamic SL/TP**: escala automatica baseada no Efficiency Ratio
- **Cooldown Anti-Churn**: bloqueia re-entrada na mesma direcao apos SL

---

## Resultados de Backtest (2024.01 - 2026.03)

Deposito inicial: $83.00 | Alavancagem: 1:200 | Every tick | Walk-Forward 1/3

### XAUUSD H1

| Metrica | Valor | Status |
|---------|-------|--------|
| **Net Profit** | $709.64 (+855%) | VERDE |
| **Profit Factor** | 2.24 | VERDE |
| **Recovery Factor** | 8.90 | VERDE |
| **Sharpe Ratio** | 9.53 | VERDE |
| **Max DD (Balance)** | 13.64% | VERDE |
| **Total Trades** | 214 | OK |
| **Win Rate** | 85.05% | VERDE |
| **Max Consec Wins / Losses** | 32 / 3 | VERDE |

![XAUUSD Equity](Reports/XAUUSD/xauusd.png)

### USDJPY H1

| Metrica | Valor | Status |
|---------|-------|--------|
| **Net Profit** | $481.74 (+580%) | VERDE |
| **Profit Factor** | 1.90 | VERDE |
| **Recovery Factor** | 4.29 | VERDE |
| **Sharpe Ratio** | 6.70 | VERDE |
| **Max DD (Balance)** | 14.68% | VERDE |
| **Total Trades** | 292 | OK |
| **Win Rate** | 86.64% | VERDE |
| **Max Consec Wins / Losses** | 37 / 4 | VERDE |

![USDJPY Equity](Reports/USDJPY/usdjpy.png)

### Comparativo

| Metrica | XAUUSD | USDJPY |
|---------|--------|--------|
| Net Profit | $709.64 | $481.74 |
| Profit Factor | 2.24 | 1.90 |
| Recovery Factor | 8.90 | 4.29 |
| Sharpe | 9.53 | 6.70 |
| Max DD % | 13.64% | 14.68% |
| Win Rate | 85.05% | 86.64% |
| Trades | 214 | 292 |

---

## Instalacao

### Estrutura de arquivos

Copie o conteudo da pasta `dist/MQL5/` para o diretorio `MQL5/` do seu terminal MetaTrader 5:

```
dist/MQL5/
  Libraries/
    NexusConfluence.dll              <-- DLL principal (toda logica)
  Experts/NexusConfluenceV3/
    NexusConfluenceV3.ex5            <-- EA compilado
    set/
      NexusV3_FINAL_USDJPY_H1.set   <-- Preset USDJPY otimizado
      NexusV3_FINAL_XAUUSD_H1.set   <-- Preset XAUUSD otimizado
      NexusV3_FINAL_GBPUSD_H1.set   <-- Preset GBPUSD otimizado
  Indicators/NexusConfluenceEA/
    GG_TrendBar_Indicator.ex5        <-- Visualizacao (*)
    TrendMagic_MT5.ex5               <-- Visualizacao (*)
    OBV_MACD.ex5                     <-- Visualizacao (*)
    RSIOMA_v2HHLSX_MT5.ex5           <-- Visualizacao (*)
    CurrencyStrengthMeter_MT5.ex5    <-- Visualizacao (*)
```

> (*) **IMPORTANTE**: Os indicadores .ex5 sao wrappers visuais da DLL.
> Eles NAO calculam nada — leem os valores diretamente da DLL via shared memory.
> O que voce ve no grafico e EXATAMENTE o que o EA usa para decidir.
> Funciona tanto em live chart quanto no Strategy Tester visual.
> Voce pode operar sem os indicadores visuais — o EA funciona normalmente.

### Passo a passo

1. Localize a pasta de dados do MT5: **File > Open Data Folder**
2. Copie `NexusConfluence.dll` para `MQL5/Libraries/`
3. Copie `NexusConfluenceV3.ex5` para `MQL5/Experts/NexusConfluenceV3/`
4. Copie os `.set` para `MQL5/Experts/NexusConfluenceV3/set/`
5. Copie os indicadores `.ex5` para `MQL5/Indicators/NexusConfluenceEA/`
6. Reinicie o MetaTrader 5
7. Abra o chart desejado (ex: USDJPY H1)
8. Arraste o EA **NexusConfluenceV3** para o chart
9. Na aba **Common**: marque **"Allow DLL imports"**
10. Na aba **Inputs**: clique **Load** e selecione o preset correspondente
11. Preencha o campo **"Chave de Licenca"** com sua key
12. Clique **OK**

## Requisitos

- MetaTrader 5 (build 5660+)
- Windows x64 (DLL requer Windows)
- Broker com hedging mode
- Leverage: 1:200 recomendado
- Licenca valida (adquira em [contato])

## Licenciamento

O EA utiliza sistema de licenciamento integrado na DLL com protecao multinivel:

- **Account Lock**: Licenca vinculada a conta MT5 especifica
- **Expiry Date**: Licencas com data de validade
- **HWID Lock**: Validacao de hardware
- **Checksum**: Deteccao de adulteracao

### Tipos de Licenca

| Tipo | Duracao | Contas | Preco |
|------|---------|--------|-------|
| **TRIAL** | 14 dias | 1 | Gratis |
| **STARTER** | 1 ano | 1 | $497 |
| **PRO** | 1 ano | 3 | $997 |
| **LIFETIME** | Vitalicia | 5 | $1,997 |

### Ativacao

1. Adquira sua licenca informando seu numero de conta MT5
2. No EA, preencha o campo **"Chave de Licenca"** nos Inputs
3. A DLL valida automaticamente na inicializacao
4. Se valida: EA opera normalmente
5. Se invalida/expirada: EA nao inicializa e mostra erro no log

## Otimizacao

O EA foi otimizado usando metodologia de 3 rounds sequenciais:

```
R1 Foundation  -> TFs + GG TrendBar + Supertrend + Scores + State (16 params)
R2 Signal      -> MACD + RSI + Gates 4/5 + Spread (16 params)
R3 Exits       -> SL/TP + BE + TS + DD protection (16 params)
```

- Periodo: 2024.01.02 - 2026.01.19
- Modelagem: Every tick
- Walk-Forward: 1/3 (IS ~66%, OOS ~33%)
- Criterio: Complexo maximo (Genetico)

## Suporte

- Problemas de instalacao: verifique se "Allow DLL imports" esta ativado
- Licenca expirada: entre em contato para renovacao
- Novos ativos: presets adicionais serao disponibilizados periodicamente

---

*Nexus Confluence EA v3.0.1 - Trading algoritmico profissional com arquitetura C++ DLL*

Copyright 2024-2026 Nexus EA. Todos os direitos reservados.
