# 🚀 Nexus Confluence EA v2.03

**Expert Advisor de Trading Profissional para MetaTrader 5**  
Sistema de Confluência Multi-Timeframe com Validação de 6 Gates

> **⚙️ v2.03 Update (04/11/2025):**
> - Visualização: novo input InpAttachIndicatorsToChart para anexar indicadores ao gráfico automaticamente
>   - Supertrend no gráfico principal; WAE, RSI OMA e Currency Strength em sub-janelas 1/2/3
>   - Remoção automática ao desligar o EA (limpeza garantida)
> - Trailing Stop: robustez e logs limpos
>   - Checks de broker: FREEZE_LEVEL/STOPS_LEVEL antes de modificar SL
>   - Deduplicação por vela: evita spam de erros repetidos (ex.: retcode 4014)
> - Execução: centralizada em RiskExecution (retry + normalização de preços/lotes)
> - Gate 3: reforçada a exigência (alinhamento estrito para PREMIUM, tolerância apenas onde documentado)
> - MarketAccess: warm-up de spread e melhorias de horário (sem “realtime momentum guard”)

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Arquitetura do Sistema](#arquitetura-do-sistema)
- [Sistema de 6 Gates](#sistema-de-6-gates)
- [Indicadores Customizados](#indicadores-customizados)
- [Gestão de Risco Assimétrica](#gestão-de-risco-assimétrica)
- [Instalação](#instalação)
- [Configuração](#configuração)
- [Visualização no Gráfico](#visualização-no-gráfico)
- [Otimização](#otimização)
- [Backtest e Validação](#backtest-e-validação)
- [Resolução de Problemas](#resolução-de-problemas)

---

## 🎯 Visão Geral

O **Nexus Confluence EA v2.02** é um Expert Advisor profissional desenvolvido para trading em **contas reais** no MetaTrader 5. Utiliza análise de confluência multi-timeframe com validação rigorosa através de 6 gates sequenciais.

### ✨ Características Principais

- ✅ **6 Gates de Validação** sequencial (zero tolerância para sinais fracos)
- ✅ **Análise Multi-Timeframe** hierárquica (H4 → H1 → M30 → M15)
- ✅ **Gestão Assimétrica de Risco** (parâmetros diferentes para BUY/SELL)
- ✅ **Break Even Inteligente** com trigger e step configuráveis
- ✅ **Trailing Stop Dinâmico** por direção
- ✅ **Proteção contra Drawdown** (circuit breaker automático)
- ✅ **Zero Repaint** (sempre `shift=1` - barra fechada)
- ✅ **State Machine** (previne ordens duplicadas)
- ✅ **Filtro de Spread Dinâmico** (mediana-based)
- ✅ **Fallback para Índices** (opera sem Currency Strength)

### 📊 Mercados Suportados

| Mercado | Currency Strength | Horário Especial | Skip Monday |
|---------|-------------------|------------------|-------------|
| **Forex** | ✅ Obrigatório | 24h | ✅ Sim |
| **B3 (WIN/WDO)** | ❌ Não usado | 09:00-17:55 | ❌ Não |
| **Índices (US30/NAS)** | ❌ Fallback automático | Varia | ✅ Sim |
| **Metais (XAU/XAG)** | ✅ Obrigatório | ~24h | ✅ Sim |
| **Crypto (BTC/ETH)** | ⚠️ Opcional | 24/7 | ❌ Não |

---

## 🏗️ Arquitetura do Sistema

### Estrutura de Diretórios

```
📁 MQL5/
├── 📁 Experts/
│   └── 📁 NexusConfluenceEA/
│       └── NexusConfluenceEA.mq5          ← EA Principal
├── 📁 Include/
│   └── 📁 NexusConfluenceEA/
│       └── 📁 Modules/
│           ├── Core.mqh                    ← Gate 0: Sincronização
│           ├── MarketAccess.mqh            ← Gate 1: Filtros de Mercado
│           ├── IndicatorHub.mqh            ← Gerencia 5 indicadores
│           ├── SignalEngine.mqh            ← Gates 2-5: Análise
│           ├── RiskExecution.mqh           ← Execução de ordens
│           ├── AsymmetricRisk.mqh          ← Risco diferenciado BUY/SELL
│           ├── BreakEvenManager.mqh        ← Gestão de Break Even
│           ├── TrailingStopManager.mqh     ← Trailing Stop dinâmico
│           └── DrawdownProtection.mqh      ← Circuit Breaker
└── 📁 Indicators/
    └── 📁 NexusConfluenceEA/
        ├── GG_TrendBar_Indicator.mq5       ← MTF Trend Analysis
        ├── TrendMagic_MT5.mq5              ← Supertrend
        ├── WaddahAttarExplosion_Professional.mq5  ← WAE Momentum
        ├── RSIOMA_v2HHLSX_MT5.mq5          ← RSI OMA
        └── CurrencyStrengthMeter_MT5.mq5   ← Currency Strength
```

### Módulos Principais

#### 1. **Core.mqh** (Gate 0 - Sincronização)
- Detecção de nova vela (`shift=1` enforcement)
- State Machine (IDLE → SIGNAL_DETECTED → ORDER_SENT → WAITING_CLOSE)
- Sistema de logs em 3 níveis (Executivo, Operacional, Debug)
- Validação de timestamp dos buffers

#### 2. **MarketAccess.mqh** (Gate 1 - Filtros)
- Spread dinâmico (mediana-based)
- Horários de trading por mercado
- Filtro semanal (dias permitidos)
- Skip Monday Open para Forex

#### 3. **IndicatorHub.mqh** (Gerenciador)
- Cache de buffers uma vez por vela
- Gerencia handles dos 5 indicadores
- Fallback automático para índices
- Validação de sincronização
- Anexo visual opcional dos indicadores ao gráfico (InpAttachIndicatorsToChart)

#### 4. **SignalEngine.mqh** (Gates 2-5 - Análise)
- Implementa toda lógica de validação
- Sistema de score MTF (-4 a +4)
- Classificação (PREMIUM/GOOD/REJECT)
- Processamento sequencial dos gates

#### 5. **RiskExecution.mqh** (Execução)
- CTrade + CPositionInfo
- Retry logic para erros recuperáveis
- Normalização de preços e lotes
- Anti-duplicação por vela

#### 6. **AsymmetricRisk.mqh** (v2.00)
- SL/TP diferenciados por direção
- Score mínimo independente
- Controle BUY/SELL separado
- Estatísticas de aceitação

#### 7. **BreakEvenManager.mqh** (v2.00)
- Trigger e Step individuais
- Validação de distância mínima
- Log de ativações
- Previne múltiplas modificações

#### 8. **TrailingStopManager.mqh** (v2.00)
- Trailing após trigger específico
- Step configurável por direção
- Proteção de lucros
- v2.03: valida FREEZE_LEVEL/STOPS_LEVEL e deduplica logs por vela

#### 9. **DrawdownProtection.mqh** (v2.00)
- Circuit Breaker por DD% diário
- Contador de perdas consecutivas
- Redução automática de lote
- Reset diário automático

---

## 🔐 Sistema de 6 Gates

O EA **APENAS ABRE POSIÇÕES** quando os 6 gates são aprovados sequencialmente. Se qualquer gate rejeitar, o sinal é descartado.

### Gate 0: Sincronização ⏱️

**Objetivo:** Garantir que trabalhamos sempre com barras fechadas (`shift=1`).

**Validações:**
- ✅ Nova vela detectada (timestamp diferente)
- ✅ Buffers de indicadores atualizados
- ✅ Timestamp de sincronização válido

**Rejeita:**
- ❌ Mesma vela já processada
- ❌ Buffers desatualizados

---

### Gate 1: Acesso ao Mercado 🚦

**Objetivo:** Filtrar condições de mercado desfavoráveis.

**Validações:**
- ✅ Spread dentro do limite (mediana × multiplier)
- ✅ Spread abaixo do máximo absoluto
- ✅ Horário de trading permitido
- ✅ Dia da semana permitido

**Rejeita:**
- ❌ Spread excessivo (spike)
- ❌ Fora do horário configurado
- ❌ Monday Open (Forex) - proteção gap

**Configuração por Mercado:**

| Mercado | Max Spread | Multiplier | Skip Monday |
|---------|-----------|------------|-------------|
| Forex | 20 pts | 1.5x | Sim |
| B3 (WIN) | 10 pts | 1.5x | Não |
| Índices | 15 pts | 1.5x | Sim |
| Metais | 30 pts | 2.0x | Sim |
| Crypto | 50 pts | 2.5x | Não |

---

### Gate 2: Multi-Timeframe (MTF) 📊

**Objetivo:** Confirmar tendência macro e micro alinhadas.

#### Lógica Hierárquica (CRÍTICA)

```
H4 (Macro 1) ─┐
              ├─► MANDANTES (devem estar alinhados)
H1 (Macro 2) ─┘

M30 (Macro 3) ─┐
               ├─► CLASSIFICADORES (definem PREMIUM vs GOOD)
M15 (Operacional)─┘
```

#### Regras de Validação:

1. **H4 e H1 são MANDANTES** - Se não estiverem alinhados, REJECT imediato
2. **M30/M15 não podem estar OPOSTOS** aos macros - REJECT se opostos
3. **Classificação:**
   - **PREMIUM** (Score ±4): 4/4 timeframes alinhados (H4+H1+M30+M15)
   - **GOOD** (Score ±2/±3): H4+H1 alinhados + pelo menos 1 operacional
   - **REJECT**: H4/H1 desalinhados OU operacional oposto

#### Exemplos:

| H4 | H1 | M30 | M15 | Score | Resultado |
|----|----|----|-----|-------|-----------|
| +1 | +1 | +1 | +1 | +4 | ✅ PREMIUM BUY |
| +1 | +1 | +1 | 0 | +3 | ✅ GOOD BUY |
| +1 | +1 | 0 | 0 | +2 | ✅ GOOD BUY |
| +1 | -1 | +1 | +1 | +2 | ❌ REJECT (H4/H1 desalinhados) |
| +1 | +1 | -1 | +1 | +2 | ❌ REJECT (M30 oposto) |
| -1 | -1 | -1 | -1 | -4 | ✅ PREMIUM SELL |

**Valores GG TrendBar:**
- `+1` = Verde (Bullish)
- `0` = Amarelo (Neutro)
- `-1` = Vermelho (Bearish)

---

### Gate 3: Supertrend (Confirmação Local) 🎯

**Objetivo:** Validar tendência no timeframe operacional.

**Validações:**
- ✅ Supertrend alinhado com direção MTF
- ✅ **Tolerância diferenciada por classificação**

**⚙️ LÓGICA ATUALIZADA (v2.02):**

| Classe Signal | ST Alinhado | ST Neutro | ST Oposto |
|---------------|-------------|-----------|-----------|
| **PREMIUM** | ✅ PASS | ❌ REJECT | ❌ REJECT |
| **GOOD** | ✅ PASS | ✅ PASS | ❌ REJECT |

**Filosofia:**
- **PREMIUM (Score ±4):** exige **alinhamento PERFEITO** do Supertrend (mais rigoroso).
- **GOOD (Score ±2/±3):** aceita **neutro (0)** como transição, mas **não aceita oposto**. A tolerância de 1 vela é contemplada via processamento na barra fechada (shift=1) e transições neutras.

**Exemplos:**

**PREMIUM BUY (Score +4):**
```
✅ ST=+1 (bullish) → PASS (alinhamento perfeito)
❌ ST=0 (neutro) → REJECT (PREMIUM exige confirmação forte)
❌ ST=-1 (bearish) → REJECT (PREMIUM não aceita oposto)
```

**GOOD BUY (Score +2 ou +3):**
```
✅ ST=+1 (bullish) → PASS (alinhamento)
✅ ST=0 (neutro) → PASS (transição)
❌ ST=-1 (bearish) → REJECT (oposto não aceito)
```

**Buffers:**
- Buffer 0: Upper Band (linha azul - zona bearish)
- Buffer 1: Lower Band (linha vermelha - zona bullish)

**Interpretação:**
- Preço > Lower Band → Bullish (+1)
- Preço < Upper Band → Bearish (-1)
- Entre bandas ou indefinido → Neutro (0)

---

### Gate 4: Momentum (Filtro Lateral + Direção) 💥

**Objetivo:** Confirmar expansão de momentum E direção.

#### ⚠️ ORDEM CRÍTICA: WAE PRIMEIRO → RSI SEGUNDO

1. **WAE (Waddah Attar Explosion)** - Filtro de Expansão
   - ✅ Trend Bar (verde OU vermelho) > Explosion Line
   - ❌ Mercado lateral (ambos < Explosion Line) → REJECT

2. **RSI OMA** - Confirmação de Direção
   - BUY: Red Line > Blue Line
   - SELL: Red Line < Blue Line

**Validações:**
- ✅ WAE expandindo (não lateral)
- ✅ WAE direcionado para o lado do MTF
- ✅ RSI OMA confirmando direção

**Buffers WAE:**
- Buffer 0: Trend Up (barras verdes)
- Buffer 1: Trend Down (barras vermelhas)
- Buffer 2: Explosion Line (linha limite)

**Buffers RSI OMA:**
- Buffer 0: Red Line (RSI)
- Buffer 1: Blue Line (RSI MA)

---

### Gate 5: Currency Strength (Contexto Fundamental) 🌍

**Objetivo:** Validar força relativa das moedas.

**Aplicação:**
- ✅ **Forex**: Obrigatório (Base vs Quote)
- ✅ **Metais**: Obrigatório (XAU vs USD)
- ⚠️ **Crypto**: Opcional
- ❌ **Índices**: Skip automático (fallback)

**Validações:**
- **BUY**: Base Currency > Quote Currency
- **SELL**: Quote Currency > Base Currency

**Fallback:**
- Se indicador não disponível → PASS automático
- Log informa skip do gate

---

## 📈 Indicadores Customizados

### 1. GG TrendBar Indicator

**Função:** Análise de tendência em 9 timeframes simultaneamente.

**Buffers:** 9 (um por timeframe)
- 0: M1 | 1: M5 | 2: M15 | 3: M30 | 4: H1
- 5: H4 | 6: D1 | 7: W1 | 8: MN1

**Retorno:** `-1` (bearish) / `0` (neutro) / `+1` (bullish)

**Lógica Interna:**
- ADX + Parabolic SAR
- Detecta força e direção da tendência

**Inputs Principais:**
- `ADX_Period` (14): Período do ADX
- `PSAR_Step` (0.02): Step do Parabolic SAR
- `PSAR_Max` (0.2): Máximo do Parabolic SAR

---

### 2. TrendMagic (Supertrend)

**Função:** Supertrend adaptativo com CCI e ATR.

**Buffers:**
- 0: Upper Band (linha azul - zona bearish)
- 1: Lower Band (linha vermelha - zona bullish)

**Lógica:**
- Baseado em CCI e ATR
- Bandas dinâmicas de suporte/resistência

**Inputs Principais:**
- `CCI_Period` (50): Período do CCI
- `ATR_Period` (5): Período do ATR
- `ATR_Multiplier` (1.0): Multiplicador da volatilidade

---

### 3. Waddah Attar Explosion (WAE)

**Função:** Detecta explosão de momentum e força direcional.

**Buffers:**
- 0: Trend Up (barras verdes - momentum bullish)
- 1: Trend Down (barras vermelhas - momentum bearish)
- 2: Explosion Line (threshold de ativação)

**Lógica:**
- MACD Histogram vs Bollinger Bands
- Filtra mercados laterais (compressão)

**Inputs Principais:**
- `FastMA` (20): MA rápida
- `SlowMA` (40): MA lenta
- `BBLength` (20): Período das Bollinger Bands
- `BBMultiplier` (2.0): Desvio padrão BB
- `Sensitivity` (150): Sensibilidade do threshold

---

### 4. RSI OMA

**Função:** RSI com média móvel sobreposta.

**Buffers:**
- 0: Red Line (RSI calculado)
- 1: Blue Line (MA do RSI)

**Sinal:**
- BUY: Red > Blue (RSI subindo)
- SELL: Red < Blue (RSI descendo)

**Inputs Principais:**
- `RSI_Period` (14): Período do RSI
- `MA_Period` (9): Período da MA
- `MA_Method` (0): Método (SMA=0, EMA=1, etc)
- `HighLevel` (70.0): Nível de sobrecompra
- `LowLevel` (30.0): Nível de sobrevenda

---

### 5. Currency Strength Meter

**Função:** Calcula força individual de 8 moedas (USD, EUR, GBP, JPY, AUD, CAD, CHF, NZD).

**Buffers:**
- 0: Base Currency Strength
- 1: Quote Currency Strength

**Lógica:**
- Analisa múltiplos pares para cada moeda
- Normaliza força relativa

**Inputs Principais:**
- `CalcPeriod` (24): Período de cálculo
- `Smoothing` (5): Suavização
- `ShowPercent` (true): Exibir em %

---

## ⚖️ Gestão de Risco Assimétrica

### Conceito

A versão 2.00 permite configurar **parâmetros independentes** para BUY e SELL, reconhecendo que mercados têm comportamentos assimétricos.

### Parâmetros Assimétricos

| Parâmetro | BUY | SELL |
|-----------|-----|------|
| **Habilitação** | `InpEnableBuy` | `InpEnableSell` |
| **Stop Loss** | `InpStopLossBuy` | `InpStopLossSell` |
| **Take Profit** | `InpTakeProfitBuy` | `InpTakeProfitSell` |
| **Score Mínimo** | `InpMinScoreBuy` | `InpMinScoreSell` |
| **Break Even Trigger** | `InpBE_Buy_Trigger` | `InpBE_Sell_Trigger` |
| **Break Even Step** | `InpBE_Buy_Step` | `InpBE_Sell_Step` |
| **Trailing Trigger** | `InpTS_Buy_Trigger` | `InpTS_Sell_Trigger` |
| **Trailing Step** | `InpTS_Buy_Step` | `InpTS_Sell_Step` |

### Perfis de Entrada (v2.00)

Controla quais classificações de sinal são permitidas:

```
InpBuyPremiumEnable   → Permite BUY PREMIUM (score +4)
InpBuyGoodEnable      → Permite BUY GOOD (score +2/+3)
InpSellPremiumEnable  → Permite SELL PREMIUM (score -4)
InpSellGoodEnable     → Permite SELL GOOD (score -2/-3)
```

**Exemplo de Configuração Conservadora:**
```
InpBuyPremiumEnable = true   // Aceita BUY PREMIUM
InpBuyGoodEnable = false     // Rejeita BUY GOOD
InpSellPremiumEnable = true  // Aceita SELL PREMIUM
InpSellGoodEnable = false    // Rejeita SELL GOOD
```

---

## 🛡️ Break Even Manager

### Funcionamento

1. **Trigger Atingido:** Quando lucro em pontos/pips atinge o valor configurado
2. **Aplicação:** Move SL para `Entry + Step`
3. **Proteção:** Garante lucro mínimo mesmo se mercado reverter

### Configuração Recomendada

| Mercado | Trigger BUY | Step BUY | Trigger SELL | Step SELL |
|---------|-------------|----------|--------------|-----------|
| **Forex (M15)** | 150-300 | 30-80 | 150-300 | 30-80 |
| **WIN (M5)** | 300-500 | 50-100 | 300-500 | 50-100 |
| **US30 (M15)** | 20-40 | 5-15 | 20-40 | 5-15 |
| **XAU (M15)** | 300-500 | 50-150 | 300-500 | 50-150 |

### Validações Automáticas

- ✅ SL não ultrapassa TP
- ✅ Distância mínima respeitada (STOPS_LEVEL)
- ✅ Só ativa uma vez por posição
- ✅ Log detalhado de ativação

---

## 🚀 Trailing Stop Manager

### Funcionamento

1. **Trigger:** Aguarda lucro específico para iniciar trailing
2. **Acompanhamento:** Move SL a cada `Step` pontos de lucro adicional
3. **Proteção:** Nunca move SL contra a posição

### Configuração Recomendada

| Mercado | Trigger | Step | Observação |
|---------|---------|------|------------|
| **Forex (M15)** | 400 | 200 | Conservador |
| **WIN (M5)** | 600 | 300 | Volatilidade alta |
| **US30 (M15)** | 50 | 20 | Ajustar ao tick |
| **XAU (M15)** | 500 | 250 | Ouro volátil |

### ⚠️ Importante

- Trailing **complementa** Break Even (não substitui)
- Recomendado desabilitar em backtests iniciais
- Ajustar Step baseado em ATR médio do ativo

---

## 🔴 Drawdown Protection (Circuit Breaker)

### Mecanismo

Sistema de proteção que **pausa trading automaticamente** quando limites de risco são atingidos.

### Gatilhos de Ativação

1. **Drawdown Diário:** Perda acumulada no dia > `InpDD_DailyMax` (%)
2. **Perdas Consecutivas:** Número de losses seguidos ≥ `InpDD_ConsecLoss`

### Ações ao Ativar

- 🔴 **Circuit Breaker ATIVO**
- ❌ Trading pausado até reset
- 📉 Redução de lote: `LotAtual × InpDD_LotReduce`
- 📊 Log detalhado do evento

### Reset Automático

- ✅ Novo dia (00:00 server time)
- ✅ Trade vencedor (reset contador perdas)

### Configuração Recomendada

| Perfil | DailyMax (%) | ConsecLoss | LotReduce |
|--------|--------------|------------|-----------|
| **Conservador** | 3-5% | 3-5 | 0.5 (50%) |
| **Moderado** | 5-8% | 5-7 | 0.7 (30%) |
| **Agressivo** | 8-12% | 7-10 | 0.8 (20%) |

---

## 📥 Instalação

### Pré-requisitos

- ✅ MetaTrader 5 Build 4000+
- ✅ Conta de trading configurada
- ✅ Permissão para AutoTrading
- ✅ DLL permitido (se usar notificações)

### Passo 1: Compilar Indicadores

1. Copie todos os arquivos `.mq5` de `Indicators/NexusConfluenceEA/` para:
   ```
   [MT5_DATA]/MQL5/Indicators/NexusConfluenceEA/
   ```

2. Abra MetaEditor (F4 no MT5)

3. Compile cada indicador:
   - `GG_TrendBar_Indicator.mq5`
   - `TrendMagic_MT5.mq5`
   - `WaddahAttarExplosion_Professional.mq5`
   - `RSIOMA_v2HHLSX_MT5.mq5`
   - `CurrencyStrengthMeter_MT5.mq5`

4. Verifique os arquivos `.ex5` gerados

### Passo 2: Instalar Módulos

1. Copie todos os `.mqh` de `Include/NexusConfluenceEA/Modules/` para:
   ```
   [MT5_DATA]/MQL5/Include/NexusConfluenceEA/Modules/
   ```

2. Verifique a estrutura:
   ```
   Include/
   └── NexusConfluenceEA/
       └── Modules/
           ├── Core.mqh
           ├── MarketAccess.mqh
           ├── IndicatorHub.mqh
           ├── SignalEngine.mqh
           ├── RiskExecution.mqh
           ├── AsymmetricRisk.mqh
           ├── BreakEvenManager.mqh
           ├── TrailingStopManager.mqh
           └── DrawdownProtection.mqh
   ```

### Passo 3: Compilar EA

1. Copie `NexusConfluenceEA.mq5` para:
   ```
   [MT5_DATA]/MQL5/Experts/NexusConfluenceEA/
   ```

2. Compile no MetaEditor

3. Verifique `NexusConfluenceEA.ex5` em `Experts/NexusConfluenceEA/`

### Passo 4: Verificação

1. Abra MT5
2. Navigator → Expert Advisors
3. Localize `NexusConfluenceEA`
4. Se não aparecer, pressione F5 (refresh)

---

## ⚙️ Configuração

### Configuração Inicial (Forex EURUSD M15)

```
═══════════ 💰 GESTÃO DE RISCO ═══════════
InpLotSize = 0.01               // Lote inicial
InpMaxSlippage = 10             // Slippage máximo

═══════════ 📈 BUY ═══════════
InpStopLossBuy = 300            // SL em pontos
InpTakeProfitBuy = 900          // TP em pontos (R:R 1:3)
InpMinScoreBuy = 2              // Score mínimo (GOOD+)

═══════════ 📉 SELL ═══════════
InpStopLossSell = 300           // SL em pontos
InpTakeProfitSell = 900         // TP em pontos (R:R 1:3)
InpMinScoreSell = 2             // Score mínimo (GOOD+)

═══════════ 🎯 BREAK EVEN ═══════════
InpBE_Buy_Enable = true
InpBE_Buy_Trigger = 200         // Ativa após +200 pts
InpBE_Buy_Step = 50             // Move SL para Entry+50

InpBE_Sell_Enable = true
InpBE_Sell_Trigger = 200
InpBE_Sell_Step = 50

═══════════ 🚀 TRAILING STOP ═══════════
InpTS_Buy_Enable = false        // Desabilitar inicialmente
InpTS_Sell_Enable = false       // Testar BE primeiro

═══════════ 🛡️ DRAWDOWN ═══════════
InpDD_Enable = true
InpDD_DailyMax = 5.0            // 5% DD máximo diário
InpDD_ConsecLoss = 5            // 5 perdas consecutivas
InpDD_LotReduce = 0.5           // Reduz lote pela metade

═══════════ 🔍 FILTROS ═══════════
InpMaxSpread = 20               // 20 pontos máximo
InpSpreadMulti = 1.5            // 1.5x mediana
InpUseTimeFilter = false        // Sem filtro de horário
InpTradeOnMonday = false        // Skip Monday (Forex)

═══════════ ⏰ TIMEFRAMES ═══════════
InpMacro1TF = PERIOD_H4         // H4
InpMacro2TF = PERIOD_H1         // H1
InpMacro3TF = PERIOD_M30        // M30
InpOperationalTF = PERIOD_M15   // M15 (gráfico atual)

═══════════ 🧭 PERFIS ═══════════
InpBuyPremiumEnable = true      // Aceita BUY PREMIUM
InpBuyGoodEnable = true         // Aceita BUY GOOD
InpSellPremiumEnable = true     // Aceita SELL PREMIUM
InpSellGoodEnable = true        // Aceita SELL GOOD

═══════════ ↕️ DIREÇÃO ═══════════
InpEnableBuy = true             // Habilita BUY
InpEnableSell = true            // Habilita SELL

═══════════ 📝 LOGS ═══════════
InpLogLevel = 2                 // 1=Exec, 2=Oper, 3=Debug
```

### Configuração WIN (B3 M5)

```
InpLotSize = 1                  // 1 contrato
InpStopLossBuy = 400            // 400 pontos (~R$200)
InpTakeProfitBuy = 1200         // 1200 pontos (~R$600)
InpBE_Buy_Trigger = 300
InpBE_Buy_Step = 100

InpMaxSpread = 10               // WIN spread típico 5-10
InpUseTimeFilter = true
InpStartTime = 09:15            // Evitar abertura
InpEndTime = 17:45              // Evitar fechamento
InpTradeOnMonday = true         // B3 não tem Monday gap
```

### Configuração US30 (M15)

```
InpLotSize = 0.10
InpStopLossBuy = 30             // 30 pontos = ~$30
InpTakeProfitBuy = 90           // 90 pontos = ~$90
InpBE_Buy_Trigger = 20
InpBE_Buy_Step = 10

InpMaxSpread = 15
InpTradeOnMonday = false        // Skip Monday gap
```

---

## 🎨 Visualização no Gráfico

A partir da v2.03, o EA pode anexar os indicadores visualmente no gráfico automaticamente.

### Toggle

```
InpAttachIndicatorsToChart = true  // ON por padrão
```

### Layout

- Supertrend (TrendMagic) → janela principal (overlay)
- WAE (Waddah Attar Explosion) → Sub-janela #1
- RSI OMA → Sub-janela #2
- Currency Strength → Sub-janela #3 (se disponível; índices fazem fallback)

Ao remover o EA do gráfico, os indicadores anexados por ele são limpos automaticamente.

---

## 🧪 Otimização

### Arquivo .set Otimizado

Salvei um arquivo `.set` otimizado em `Presets/NexusConfluenceEA_Optimized.set`.

### Parâmetros CRÍTICOS para Otimizar (Y)

#### 1. Gestão de Risco
```
InpLotSize = 0.01||0.01||0.01||0.10||Y
InpStopLossBuy = 200||100||50||600||Y
InpTakeProfitBuy = 600||300||100||1800||Y
InpStopLossSell = 200||100||50||600||Y
InpTakeProfitSell = 600||300||100||1800||Y
```

#### 2. Break Even
```
InpBE_Buy_Enable = true||false||0||true||Y
InpBE_Buy_Trigger = 150||50||50||500||Y
InpBE_Buy_Step = 30||10||10||100||Y

InpBE_Sell_Enable = true||false||0||true||Y
InpBE_Sell_Trigger = 150||50||50||500||Y
InpBE_Sell_Step = 30||10||10||100||Y
```

#### 3. Scores Mínimos
```
InpMinScoreBuy = 2||2||1||4||Y
InpMinScoreSell = 2||2||1||4||Y
```

#### 4. Drawdown Protection
```
InpDD_Enable = true||false||0||true||Y
InpDD_DailyMax = 5.0||3||1||10||Y
InpDD_ConsecLoss = 5||3||1||8||Y
InpDD_LotReduce = 0.5||0.3||0.1||0.9||Y
```

### Parâmetros para NÃO Otimizar (N)

#### Estruturais
```
InpMagicNumber = 20241024||20241024||1||202410240||N
InpLogLevel = 2||2||1||3||N
InpOperationalTF = PERIOD_M15||0||0||49153||N
InpEnableBuy = true||false||0||true||N
InpEnableSell = true||false||0||true||N
```

#### Perfis (ajustar manualmente)
```
InpBuyPremiumEnable = true||false||0||true||N
InpBuyGoodEnable = true||false||0||true||N
InpSellPremiumEnable = true||false||0||true||N
InpSellGoodEnable = true||false||0||true||N
```

#### Indicadores (usar defaults testados)
```
InpGG_CreateObjects = false||false||0||true||N
InpGG_ADX_Period = 14||14||1||50||N
InpST_CCI_Period = 50||50||10||100||N
InpWAE_FastMA = 20||20||5||40||N
InpRSI_Period = 14||14||5||30||N
InpCS_CalcPeriod = 24||24||5||50||N
```

### Processo de Otimização

#### 1. Preparação
- ✅ Dados históricos: 2+ anos (tick data quality)
- ✅ Modo: Complete Algorithm
- ✅ Critério: Balance + Drawdown (Custom Max)
- ✅ Trailing Stop: DESABILITADO (otimizar depois)

#### 2. Fase 1 - SL/TP Base
```
Variar: InpStopLossBuy/Sell, InpTakeProfitBuy/Sell
Fixar: Tudo mais em defaults
Objetivo: Encontrar R:R ótimo
Tempo: ~30-60 min
```

#### 3. Fase 2 - Break Even
```
Variar: InpBE_*_Trigger, InpBE_*_Step
Fixar: SL/TP da Fase 1
Objetivo: Proteger lucros sem cortar winners
Tempo: ~20-40 min
```

#### 4. Fase 3 - Scores
```
Variar: InpMinScoreBuy, InpMinScoreSell
Fixar: Fase 1 + Fase 2
Objetivo: Balance entre frequência e qualidade
Tempo: ~10-20 min
```

#### 5. Fase 4 - Drawdown
```
Variar: InpDD_DailyMax, InpDD_ConsecLoss
Fixar: Fase 1 + 2 + 3
Objetivo: Proteger conta em drawdowns
Tempo: ~15-30 min
```

#### 6. Validação Final
- ✅ Forward test: 20-30% dos dados
- ✅ Different market conditions (trending/ranging)
- ✅ Monte Carlo simulation
- ✅ Walk-Forward Analysis

---

## 📊 Backtest e Validação

### Requisitos Mínimos

| Critério | Mínimo Aceitável | Ideal |
|----------|------------------|-------|
| **Win Rate** | 45% | 55%+ |
| **Profit Factor** | 1.3 | 1.8+ |
| **Max DD** | <20% | <10% |
| **Sharpe Ratio** | 0.5 | 1.0+ |
| **Recovery Factor** | 2.0 | 3.0+ |
| **Trades (1 ano)** | 100+ | 200+ |

### KPIs por Perfil

#### PREMIUM (Score ±4)
- **Win Rate Esperado:** 60-70%
- **Frequência:** Baixa (10-15% dos sinais)
- **Profit Factor:** 2.0+

#### GOOD (Score ±2/±3)
- **Win Rate Esperado:** 50-60%
- **Frequência:** Média (40-50% dos sinais)
- **Profit Factor:** 1.5+

### Validação Visual (Strategy Tester)

1. **Modo Visual:** Ativar
2. **Observar:**
   - ✅ Entries em confluência de cores (GG TrendBar)
   - ✅ Supertrend alinhado
   - ✅ WAE expandindo
   - ✅ Sem entries em lateralização
   - ✅ Break Even ativando corretamente

3. **Logs:**
```
[OPERACIONAL] ✅ Gates: G0✓ G1✓ G2✓ G3✓ G4✓ G5✓ | PREMIUM SIGNAL_DIR_BUY | Score:+4
[EXECUTIVO] ✅ TRADE EXECUTED SUCCESSFULLY
[EXECUTIVO] 📋 Ticket: 123456
[EXECUTIVO] 📈 Direction: POSITION_TYPE_BUY
[EXECUTIVO] 💰 Lot: 0.01
[EXECUTIVO] 📊 Score: +4
[EXECUTIVO] 🎯 SL: 1.08000 (300 points)
[EXECUTIVO] 🎯 TP: 1.08900 (900 points)
[EXECUTIVO] 📐 R:R: 1:3.00
```

---

## 🐛 Resolução de Problemas

### EA Não Aparece na Lista

**Causa:** Indicadores não compilados ou ausentes.

**Solução:**
1. Verificar logs ao inicializar EA:
   ```
   ❌ ERROR: Failed to load GG_TrendBar_Indicator from any path
   ```
2. Recompilar indicadores
3. Verificar pasta `Indicators/NexusConfluenceEA/`
4. Reiniciar MT5

---

### Indicadores não aparecem no gráfico (apenas GG_TrendBar)

**Causa:** Indicadores não estavam sendo anexados visualmente pelo EA.

**v2.03 Solução:**
- Ative `InpAttachIndicatorsToChart = true` nos inputs do EA
- O EA usará ChartIndicatorAdd para anexar Supertrend (principal), WAE (#1), RSI OMA (#2) e Currency Strength (#3)
- Na remoção do EA, executa limpeza com ChartIndicatorDelete

Se ainda não aparecer:
1. Verifique se os indicadores foram compilados (.ex5 presentes)
2. Veja logs de inicialização: “✅ <Indicador> loaded from: …”
3. Confirme que o símbolo/timeframe suporta o indicador

---

### Spam de erro 4014/retcode 0 no Trailing Stop

**Sintoma:** Logs repetidos como “❌ [TS] Falha ao modificar … Retcode: 0 | Erro: 4014”.

**v2.03 Mitigação:**
- Validação de `SYMBOL_TRADE_FREEZE_LEVEL` e `SYMBOL_TRADE_STOPS_LEVEL` antes de modificar SL
- Deduplicação por vela e por ticket/SL/retcode/erro: no máximo um log por combinação por vela

**O que você deve ver:**
- Um único aviso por vela quando em FREEZE ou quando a distância mínima impede a modificação
- Assim que a restrição do broker expirar/afrouxar, a próxima modificação válida será tentada

**Dicas:**
- Em horários de abertura, FREEZE_LEVEL pode bloquear alterações de SL por alguns segundos
- Evite steps muito pequenos em ativos com STOPS_LEVEL alto

---

### "Indicator not available" no Log

**Causa:** Handle inválido ao carregar indicador.

**Solução:**
1. Verificar nome do arquivo (case-sensitive em alguns sistemas)
2. Testar indicador standalone no gráfico
3. Verificar parâmetros de inicialização
4. Logs detalhados em `InpLogLevel = 3`

---

### EA Não Abre Posições

**Diagnósticos:**

#### 1. Verificar Gates
```
[OPERACIONAL] ❌ Gate 1 REJECTED: Spread too high
[OPERACIONAL] ❌ Gate 2 REJECTED: H4/H1 não alinhados
[OPERACIONAL] ❌ Gate 4 REJECTED: WAE not expanding
```

#### 2. Verificar Perfis
```
[EXECUTIVO] ⏭️ Perfil DESATIVADO: SIGNAL_GOOD SIGNAL_DIR_BUY não permitido pelos inputs de perfil
```

**Solução:** Habilitar perfis correspondentes:
```
InpBuyGoodEnable = true
InpSellGoodEnable = true
```

#### 3. Verificar Drawdown Protection
```
[EXECUTIVO] 🔴 Circuit Breaker ACTIVE - Trading paused
```

**Solução:** Reset manual ou aguardar novo dia.

#### 4. Verificar State Machine
```
[DEBUG] ⏸️ State machine blocks new signal processing
```

**Solução:** Aguardar fechamento de posição ou reiniciar EA.

---

### Break Even Não Ativa

**Diagnósticos:**

#### 1. Lucro Insuficiente
```
[BE] Lucro atual: +120 pontos (Trigger: 200)
```

**Solução:** Aguardar lucro atingir trigger.

#### 2. SL Ultrapassaria TP
```
❌ [BE] BUY #123456: BE Step levaria SL acima do TP. Ajustando...
```

**Solução:** Reduzir `InpBE_*_Step` ou aumentar TP.

#### 3. STOPS_LEVEL
```
⚠️ [BE] BUY #123456: SL muito próximo do preço (stops_level=10)
```

**Solução:** Broker não permite SL tão próximo (aumentar Step).

---

### Spread Sempre Alto (Gate 1 Falha)

**Causa:** Parâmetros de spread muito restritivos.

**Solução:**
```
InpMaxSpread = 30              // Aumentar limite
InpSpreadMulti = 2.0           // Aumentar multiplier
InpSpreadPeriod = 50           // Aumentar período mediana
```

**Verificar:**
- Horários de baixa liquidez (noite)
- Broker com spread variável alto
- Considerar conta ECN/Raw Spread

---

### "Position already exists" (Duplicação)

**Causa:** State Machine não atualizou corretamente.

**Solução:**
1. Verificar `InpMagicNumber` único
2. Logs mostrarão:
   ```
   [DEBUG] ⏸️ Trade already executed on this candle
   ```
3. Sistema previne por design (não é erro)

---

### Backtest Muito Lento

**Causas:**
1. `InpGG_CreateObjects = true` (desenha objetos no gráfico)
2. Otimização de muitos parâmetros simultâneos
3. Tick data quality (modo "Every tick")

**Soluções:**
```
// Em .set para otimização
InpGG_CreateObjects = false||false||0||true||N
InpLogLevel = 1||1||1||2||N  // Menos logs
```

**Otimizar em fases** (não tudo junto):
- Fase 1: SL/TP (4 parâmetros)
- Fase 2: Break Even (6 parâmetros)
- Fase 3: Scores (2 parâmetros)

---

## 📚 Glossário

| Termo | Significado |
|-------|-------------|
| **MTF** | Multi-Timeframe (análise em múltiplos timeframes) |
| **Gate** | Filtro de validação sequencial |
| **Score** | Soma algébrica dos GG TrendBar (H4+H1+M30+M15) |
| **PREMIUM** | Sinal com 4/4 timeframes alinhados (score ±4) |
| **GOOD** | Sinal com H4+H1 alinhados + operacional(is) (score ±2/±3) |
| **REJECT** | Sinal rejeitado por desalinhamento crítico |
| **shift=1** | Uso de barra fechada (previne repaint) |
| **Repaint** | Alteração retroativa de sinais (proibido neste EA) |
| **State Machine** | Sistema de estados (IDLE/SIGNAL/ORDER/WAITING) |
| **Circuit Breaker** | Pausa automática por excesso de perdas |
| **R:R** | Risk:Reward ratio (ex: 1:3 = TP 3x maior que SL) |

---

## 📞 Suporte e Contribuições

### Repositório
- **GitHub:** [https://github.com/Pauloeduspbr/Nexus_Confluence_MT5](https://github.com/Pauloeduspbr/Nexus_Confluence_MT5)

### Logs de Debug

Para reportar problemas, incluir:
1. **Versão:** EA v2.03
2. **Build MT5:** (Help → About)
3. **Símbolo/Timeframe:** Ex: EURUSD M15
4. **Configuração:** Arquivo `.set` usado
5. **Logs:** Com `InpLogLevel = 3`
6. **Screenshot:** Experts tab

### Contribuições

Pull requests são bem-vindos! Por favor:
- Seguir arquitetura modular
- Manter `shift=1` enforcement
- Adicionar logs apropriados
- Testar em backtest + forward test

---

## 📄 Licença

Copyright © 2024 Nexus Confluence EA  
Este software é fornecido "como está", sem garantias.

---

## ⚠️ Aviso Legal

**ATENÇÃO:** Trading em mercados financeiros envolve risco substancial de perda. Este EA:
- ❌ NÃO É "Santo Graal"
- ❌ NÃO GARANTE lucros
- ❌ NÃO substitui gestão de risco adequada
- ✅ É ferramenta para traders experientes
- ✅ Requer testes extensivos antes de conta real
- ✅ Deve ser monitorado regularmente

**Use por sua conta e risco.**

---

## 📈 Histórico de Versões

### v2.03 (04/11/2025)
- ✅ Visualização: novo input `InpAttachIndicatorsToChart` para anexar indicadores ao gráfico
   - Supertrend (main), WAE (#1), RSI OMA (#2), Currency Strength (#3)
   - Limpeza automática ao remover o EA
- ✅ Trailing Stop robusto: checks de `FREEZE_LEVEL`/`STOPS_LEVEL` antes de modificar SL
- ✅ Deduplicação de logs por vela para falhas repetidas (evita spam)
- ✅ Execução centralizada em `RiskExecution` (retry + normalização)
- ✅ MarketAccess: warm-up do spread; remoção de realtime momentum guard
- ♻️ Documentação revisada e seção “Visualização no Gráfico” adicionada

### v2.02 (02/11/2025)
- ✅ Gate 3: PREMIUM estrito (alinhamento perfeito); GOOD aceita alinhado ou neutro (não aceita oposto)
- ✅ Score Premium: Asymmetric Risk exige +1 sobre o score mínimo por direção
- ✅ BE→TS: Trailing Stop somente após Break Even ativo (ordem corrigida)
- ✅ BE perto do TP: distância dinâmica = max(20 pts, 5% entry→TP)
- ✅ TS throttling: atualização com movimento ≥ 75% do step (permite intra-vela quando significativo)
- ✅ Drawdown: circuit breaker progressivo (60 min; 120 min após >2 ativações)

### v2.01 (02/11/2025) - 🔴 CRITICAL FIX
- ✅ **CORREÇÃO CRÍTICA:** Gate 3 (Supertrend) lógica invertida corrigida
  - PREMIUM: Agora exige alinhamento PERFEITO (mais rigoroso)
  - GOOD: Agora aceita 1 vela de atraso (mais flexível)
- ✅ Documentação atualizada com lógica correta
- ✅ Logs aprimorados no Gate 3 (mostra classificação)
- ⚠️ **AÇÃO REQUERIDA:** Re-executar backtests com v2.01

### v2.00 (Base)
- ✅ Risco Assimétrico (BUY/SELL independentes)
- ✅ Break Even Manager (trigger/step configuráveis)
- ✅ Trailing Stop Manager
- ✅ Drawdown Protection (circuit breaker)
- ✅ Controle de Perfis (PREMIUM/GOOD separados)
- ✅ Guard realtime momentum (previne reversões súbitas)

### v1.00 (Original)
- ✅ Sistema de 6 Gates
- ✅ Análise MTF hierárquica
- ✅ 5 indicadores customizados
- ✅ Zero repaint (shift=1)
- ✅ State Machine anti-duplicação
- ✅ Spread dinâmico
- ✅ Fallback para índices

---

**🚀 Bons trades! Que os 6 gates estejam sempre verdes! 🟢**
