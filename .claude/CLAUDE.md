# EA_Projetos — Instrucoes de Desenvolvimento

## REGRA ZERO

**NUNCA pule etapas. NUNCA code sem planejar. NUNCA entregue sem validar.**
**NUNCA avalie um EA apenas por R:R. NUNCA ignore filtros que matam oportunidades.**
A velocidade vem da disciplina, nao do atalho.

---

## 1. PIPELINE DE DESENVOLVIMENTO (5 fases, SEMPRE)

```
FASE 1: ENTENDER    → Decomposicao + perguntas criticas + Definition of Done
FASE 2: PLANEJAR    → Pseudocodigo + contratos + teste de mesa
FASE 3: IMPLEMENTAR → Codigo com observabilidade + sanity checks + fail-fast
FASE 4: VALIDAR     → TDD light + trace + backtest curto com debug
FASE 5: AVALIAR     → Metricas completas + diagnostico de filtros + causa-raiz
```

A Fase 5 NAO e "olhar se deu lucro". E uma analise sistematica com 30+ metricas.

---

## 2. FRAMEWORK DE AVALIACAO DE EA (5 camadas)

### REGRA: R:R sozinho nao diz NADA

Um EA com R:R de 1:3 e 15% win rate PERDE dinheiro.
Um EA com R:R de 1:1 e 65% win rate GANHA dinheiro.
**O que importa e a COMBINACAO de metricas, nao uma isolada.**

### 2.1 CAMADA 1 — Lucratividade Real (O EA ganha dinheiro?)

| Metrica | O que mede | Alvo minimo | Alerta vermelho |
|---------|-----------|-------------|-----------------|
| **Net Profit** | Lucro total apos custos | > 0 | Negativo |
| **Profit Factor** | GrossProfit / GrossLoss | > 1.3 | < 1.0 |
| **Expectancy** | Lucro medio por trade em $ | > 0 | Negativo |
| **Expectancy/Trade (pips)** | Lucro medio por trade em pips | > spread*3 | < spread |
| **ROMAD** | NetProfit / MaxDrawdown | > 2.0 | < 0.5 |

**Formulas criticas:**
```
Expectancy = (WinRate * AvgWin) - (LossRate * AvgLoss)
Profit Factor = GrossProfit / GrossLoss
ROMAD = NetProfit / MaxDrawdown
Payoff Ratio = AvgWin / AvgLoss  (isso e diferente de R:R planejado!)
```

**O Payoff Ratio REAL (pos-trade) importa mais que o R:R planejado (pre-trade).**
- R:R planejado = distancia TP / distancia SL (antes de abrir)
- Payoff Ratio = tamanho medio dos ganhos / tamanho medio das perdas (depois de fechar)
- Se Payoff Real << R:R planejado: o EA esta saindo cedo demais ou sendo stoppado antes do TP

### 2.2 CAMADA 2 — Qualidade do Risco (Vou sobreviver ao drawdown?)

| Metrica | O que mede | Alvo | Alerta |
|---------|-----------|------|--------|
| **Max Drawdown %** | Maior queda do equity peak | < 15% | > 25% |
| **Max Drawdown Duracao** | Tempo para recuperar | < 60 dias | > 120 dias |
| **Recovery Factor** | NetProfit / MaxDD | > 3.0 | < 1.0 |
| **Max Consecutive Losses** | Pior sequencia de perdas | < 8 | > 12 |
| **Avg Drawdown** | Drawdown medio | < 5% | > 10% |
| **Tail Risk (worst 5%)** | Media dos 5% piores trades | < 2x AvgLoss | > 3x AvgLoss |
| **Ulcer Index** | Severidade + duracao dos DDs | < 5 | > 15 |

```
Recovery Factor = NetProfit / MaxDrawdown
Ulcer Index = sqrt(mean(drawdown_pct^2))   // penaliza DDs profundos E longos
Tail Risk = mean(worst 5% of trade results)
```

**Perguntas de sobrevivencia:**
- Se eu tomar o MaxDD logo no inicio, ainda tenho capital para operar?
- Quantas perdas consecutivas antes de atingir daily loss limit?
- O drawdown medio esta crescendo ao longo do tempo? (sinal de degradacao)

### 2.3 CAMADA 3 — Consistencia (Posso confiar neste EA mes a mes?)

| Metrica | O que mede | Alvo | Alerta |
|---------|-----------|------|--------|
| **Sharpe Ratio** | Retorno ajustado ao risco | > 1.5 | < 0.5 |
| **Sortino Ratio** | Retorno ajustado ao downside | > 2.0 | < 0.8 |
| **% Meses Lucrativos** | Consistencia mensal | > 60% | < 40% |
| **Desvio Padrao Mensal** | Volatilidade de retorno | < 5% | > 15% |
| **Equity R²** | Linearidade da curva | > 0.85 | < 0.60 |
| **Win Rate** | % de trades vencedores | contexto | < 30% ou > 85% |

```
Sharpe = (AvgReturn - RiskFreeRate) / StdDev(Returns)     // anualizado
Sortino = (AvgReturn - RiskFreeRate) / StdDev(NegReturns)  // so downside
Equity R² = coeficiente de determinacao da regressao linear no equity
```

**IMPORTANTE sobre Win Rate:**
- Win Rate sozinho nao diz nada. Depende do Payoff Ratio.
- O que importa e o QUADRANTE:

```
                   Payoff Ratio
              Baixo (<1.0)    Alto (>1.5)
         ┌──────────────┬──────────────┐
  Alto   │  BREAKEVEN   │  EXCELENTE   │
  (>55%) │  risco medio │  ideal       │
Win Rate ├──────────────┼──────────────┤
  Baixo  │  PERDE $$$   │  VIAVEL      │
  (<45%) │  pior caso   │  trend-follow│
         └──────────────┴──────────────┘
```

- EA trend-following: tipicamente 30-40% win rate + Payoff > 2.0
- EA mean-reversion: tipicamente 60-70% win rate + Payoff 0.8-1.2
- EA scalper: tipicamente 70-80% win rate + Payoff 0.3-0.7

### 2.4 CAMADA 4 — Robustez (Vai funcionar em mercado real?)

| Teste | O que revela | Como fazer |
|-------|-------------|-----------|
| **Walk-Forward** | Overfitting | Otimizar em 70%, testar em 30% rolling |
| **Walk-Forward Efficiency** | WFE = OOS_perf / IS_perf | > 50% |
| **Sensibilidade de Parametro** | Fragilidade | Variar cada param ±20%, medir impacto |
| **Multi-Symbol** | Universalidade | Rodar em 3+ simbolos similares |
| **Multi-Timeframe** | Timeframe-fitting | Testar em TF adjacentes (M15→M30→H1) |
| **Monte Carlo (95%)** | Confianca estatistica | Reordenar trades 1000x, ver pior cenario |
| **Spread Sensitivity** | Custo de transacao | Rodar com spread 0, normal, 2x |
| **Slippage Test** | Impacto de execucao | Adicionar 1-3 pips de slippage |

**Walk-Forward e OBRIGATORIO antes de ir para live:**
```
WALK-FORWARD PROTOCOL (Pardo Method):
1. Periodo total: 3+ anos
2. Janela de otimizacao (IS): 6 meses
3. Janela de teste (OOS): 2 meses
4. Step: 2 meses (rolling forward)
5. Rodar 10+ ciclos
6. WFE = Media(OOS_return) / Media(IS_return)
7. Se WFE < 50%: OVERFITTED. Simplificar estrategia.
```

**Teste de Sensibilidade (OBRIGATORIO):**
```
Para CADA parametro do EA:
  1. Valor otimizado: X
  2. Testar X-20%, X-10%, X, X+10%, X+20%
  3. Se Profit Factor cai > 40% com variacao de 20%: parametro FRAGIL
  4. Buscar PLATO (regiao onde performance e estavel) nao PICO
  5. Parametro robusto = plato amplo. Parametro fragil = pico estreito.
```

### 2.5 CAMADA 5 — Diagnostico de Estrategia (O que esta quebrado?)

#### 2.5.1 Analise por Regime de Mercado

```
SEGMENTAR trades por regime (obrigatorio):
┌────────────┬──────────┬──────────┬──────────┐
│ Regime     │ Trades   │ WinRate  │ Expect.  │
├────────────┼──────────┼──────────┼──────────┤
│ Uptrend    │ 45       │ 62%      │ +12 pips │
│ Downtrend  │ 38       │ 58%      │ +8 pips  │
│ Range      │ 67       │ 31%      │ -15 pips │ ← PROBLEMA
│ Volatile   │ 20       │ 25%      │ -22 pips │ ← PROBLEMA
└────────────┴──────────┴──────────┴──────────┘
Diagnostico: EA perde em range e volatilidade alta.
Acao: Adicionar filtro ADX > 20 ou ATR-regime.
```

#### 2.5.2 Analise por Sessao/Horario

```
SEGMENTAR por sessao (obrigatorio):
┌────────────┬──────────┬──────────┬──────────┐
│ Sessao     │ Trades   │ WinRate  │ Expect.  │
├────────────┼──────────┼──────────┼──────────┤
│ Asia       │ 30       │ 40%      │ -5 pips  │ ← revisar
│ Londres    │ 55       │ 60%      │ +15 pips │ ← melhor
│ NY         │ 50       │ 55%      │ +10 pips │
│ Overlap    │ 15       │ 70%      │ +25 pips │ ← excelente
└────────────┴──────────┴──────────┴──────────┘
Acao: Considerar desativar durante Asia.
```

#### 2.5.3 Analise de Entry Timing

```
MEDIR qualidade da entrada:
- Max Favorable Excursion (MFE): quanto o trade foi a favor antes de fechar
- Max Adverse Excursion (MAE): quanto o trade foi contra antes de fechar

SE MFE medio >> TP alcancado: saindo CEDO demais (TP muito curto)
SE MAE medio >> SL: SL muito largo (perdas grandes demais)
SE MAE medio proximo do SL na maioria: SL muito apertado (stoppado cedo)

IDEAL: MAE medio < 30% do SL e MFE medio > 80% do TP
```

#### 2.5.4 Analise de Exit Quality

```
MEDIR eficiencia de saida:
Exit Efficiency = (preco_saida - preco_entrada) / (extremo_favoravel - preco_entrada)

Para BUY:  EE = (close - entry) / (highest_after_entry - entry)
Para SELL: EE = (entry - close) / (entry - lowest_after_entry)

EE > 50%: saida boa (captura >50% do movimento)
EE < 20%: saida muito ruim (deixa muito na mesa ou sai em loss)
EE > 90%: sorte ou TP muito curto (investigar)
```

---

## 3. DIAGNOSTICO DE FILTROS (CRITICO)

### PRINCIPIO: Todo filtro tem um CUSTO e um BENEFICIO

```
Um filtro que bloqueia 95% dos sinais mas nao melhora o win rate
e PIOR que nenhum filtro — porque voce perde oportunidades.

REGRA: Para cada filtro, medir:
  1. Pass Rate: % de sinais que passam
  2. Win Rate COM filtro vs SEM filtro
  3. Expectancy COM vs SEM
  4. Numero de trades COM vs SEM
  5. VALOR LIQUIDO = (Expect_COM * N_trades_COM) - (Expect_SEM * N_trades_SEM)
```

### 3.1 Matriz de Eficiencia de Filtros

Rodar backtest com cada filtro ativado/desativado isoladamente:

```
EXEMPLO de analise de filtros:
┌──────────────────┬───────┬────────┬────────┬─────────┬───────────┐
│ Config           │Trades │WinRate │Expect  │NetProfit│ Veredicto │
├──────────────────┼───────┼────────┼────────┼─────────┼───────────┤
│ SEM filtros      │ 500   │ 42%    │ +2 pip │ +1000   │ baseline  │
│ + Trend filter   │ 280   │ 55%    │ +8 pip │ +2240   │ MANTEM    │
│ + Score >= 5     │ 120   │ 58%    │ +10 pip│ +1200   │ MANTEM    │
│ + CCI trigger    │  25   │ 60%    │ +12 pip│ +300    │ REMOVE!   │
│ + Zone check     │ 450   │ 44%    │ +3 pip │ +1350   │ MANTEM    │
│ TODOS filtros    │  15   │ 65%    │ +15 pip│ +225    │ OVERTRADE │
└──────────────────┴───────┴────────┴────────┴─────────┴───────────┘

DIAGNOSTICO:
- Trend filter: +124% netprofit → EXCELENTE, manter
- Score >= 5: reducao para 120 trades mas netprofit > baseline → BOM
- CCI trigger: mata 95% dos trades, netprofit TOTAL cai para $300 → REMOVER
- Zone check: custo minimo (10% rejeicao), melhoria marginal → MANTER
- TODOS juntos: apenas 15 trades em 2 anos → OVERFILTERED
```

### 3.2 Diagnostico: "Por que 0 trades?"

```
PIPELINE DE ELIMINACAO (contar em CADA estagio):
┌─────────────────┬────────┬──────────────────────────────────┐
│ Estagio         │ Pass   │ Se = 0, investigar:              │
├─────────────────┼────────┼──────────────────────────────────┤
│ Total bars      │ 50000  │ Dados carregados?                │
│ New bar gate    │ 50000  │ IsNewBar() funciona?             │
│ Time filter     │ 39500  │ Horario muito restrito?          │
│ Swing detection │ 39000  │ Strength muito alto?             │
│ Fib levels      │ 38500  │ Swings validos suficientes?      │
│ Clusters found  │ 15000  │ Tolerance errada? Min rels alto? │
│ Setups created  │ 14000  │ Score muito alto?                │
│ Trend filter    │  7000  │ Trend undefined demais?          │
│ Price in zone   │  2000  │ Zona muito estreita?             │
│ Entry trigger   │    50  │ CCI muito restritivo?            │
│ Risk check      │    48  │ Max positions/daily limit?       │
│ Trade executed  │    45  │ Margin/spread/erro de ordem?     │
└─────────────────┴────────┴──────────────────────────────────┘

REGRA: Se qualquer estagio reduz > 90% dos sinais, QUESTIONAR esse filtro.
```

### 3.3 Sinais de Problemas Comuns

| Sintoma | Causa provavel | Investigar |
|---------|---------------|-----------|
| 0 trades | Filtros overfit, parametros extremos | Pipeline de eliminacao |
| Muitos trades, perda constante | Falta de filtro ou entrada ruim | Regime analysis |
| Win rate alta mas loss grande | SL muito largo ou trail ruim | MAE analysis |
| Win rate baixa mas gains bons | Normal para trend-following | Verificar Expectancy > 0 |
| Lucrativo in-sample, perde OOS | Overfitting | Walk-forward + simplificar |
| Performance degrada no tempo | Regime shift | Segmentar por periodo |
| Picos de drawdown repentinos | Evento de volatilidade | Filtro de vol + max SL |
| Trades concentrados em poucos dias | Cluster risk | Diversificar timing |
| Payoff Real << R:R planejado | SL hit rate alto ou saida antecipada | MFE/MAE analysis |
| Score alto mas poucos trades | Filtros muito restritivos | Relaxar 1 filtro por vez |

---

## 4. PROTOCOLO DE TESTES (4 niveis)

### Nivel 1: Teste de Mesa (ANTES de compilar)

Trace manual com dados reais:
```
TESTE DE MESA: Pipeline completo
Simbolo: USDJPY M15, periodo: 2024-01-15 a 2024-01-19 (1 semana)
Dados: copiar 20 barras reais do grafico

Passo 1 — DetectSwings(strength=5, bars=20):
  Input: highs/lows reais
  Calculo manual: verificar cada barra se e swing
  Esperado: ~3-5 swings
  Anotar: precos e indices

Passo 2 — AnalyzeStructure:
  Ultimos 2 highs e 2 lows dos swings acima
  Calcular: HH/HL = uptrend? LH/LL = downtrend?
  Anotar: direcao da tendencia

Passo 3 — CalcRetracements:
  Para cada swing LOW: calcular 5 niveis ate HH
  Calcular manualmente: HH - ratio * (HH - swingLow)
  Anotar: lista de niveis com precos

Passo 4 — FindClusters:
  Ordenar niveis por preco
  Agrupar niveis dentro de tolerance
  Verificar: algum grupo tem 3+ niveis?
  Anotar: zonas de cluster

Passo 5 — Setup + Execution:
  Preco atual esta na zona do cluster?
  Trigger de entrada esta ativo?
  Calcular SL/TP e verificar se fazem sentido

SE qualquer passo der resultado inesperado: corrigir ANTES de implementar.
```

### Nivel 2: TDD Light (funcoes matematicas)

Para CADA funcao que calcula algo:
```
// Caso normal
TEST_CalcRetracements_Normal:
  Input: 2 swings (LOW=148.00 bar=5, HIGH=150.00 bar=15), HH=150.0, LL=148.0
  Esperado: 5 niveis entre 148-150
  Assert: level[0] = 150.0 - 0.236*2.0 = 149.528
  Assert: level[2] = 150.0 - 0.500*2.0 = 149.000

// Caso borda
TEST_CalcRetracements_ZeroRange:
  Input: HIGH=150.0, LOW=150.0 (range=0)
  Esperado: retorna 0, sem crash

// Caso adversarial
TEST_CalcRetracements_SingleSwing:
  Input: 1 swing apenas
  Esperado: retorna 0 (need >= 2)

// Caso volumetrico
TEST_CalcRetracements_MaxSwings:
  Input: 100 swings
  Esperado: nao excede MAX_FIB_LEVELS, sem buffer overflow
```

### Nivel 3: Backtest Diagnostico (1 mes, debug ON)

```
PROTOCOLO:
1. Debug=2, periodo=1 mes, simbolo alvo
2. Verificar no journal:
   - Cada estagio tem passagens > 0?
   - Os numeros fazem sentido? (swings~100, levels~500, clusters~50, trades~5-20)
3. Se algum estagio = 0: parar e investigar AQUELE estagio
4. Se trades > 0: verificar se entry/SL/TP fazem sentido visual no grafico
5. So avancar para backtest longo quando 1 mes esta saudavel
```

### Nivel 4: Backtest Completo + Avaliacao (2+ anos)

```
PROTOCOLO:
1. Periodo: minimo 2 anos (cobrir diferentes regimes de mercado)
2. Modelo: Every tick ou OHLC 1 minute (nao Open prices only)
3. Spread: realista (variavel ou fixo baseado no broker)
4. Comissao: incluir se aplicavel
5. Capital inicial: realista ($10,000-$50,000)

APOS o backtest, OBRIGATORIO calcular TODAS as 5 camadas:
  Camada 1: Profit Factor, Expectancy, ROMAD
  Camada 2: Max DD%, Recovery Factor, Max Consec Losses
  Camada 3: Sharpe, Sortino, % meses lucrativos, Equity R²
  Camada 4: Walk-forward (separar IS/OOS), sensibilidade
  Camada 5: Regime, sessao, MFE/MAE, exit efficiency

RELATÓRIO FINAL deve conter:
  a) Tabela com todas metricas e classificacao (verde/amarelo/vermelho)
  b) Equity curve com drawdown overlay
  c) Distribuicao de trades por regime e sessao
  d) Matriz de eficiencia de filtros
  e) Lista de acoes de melhoria priorizadas
```

---

## 5. METODOLOGIA DE IMPLEMENTACAO

### 5.1 Pseudocodigo (OBRIGATORIO para funcoes > 20 linhas)

```
FUNCAO NomeFuncao(params):
  PRE: condicoes que devem ser verdade antes
  POS: o que a funcao garante ao retornar
  INVARIANTE: o que nunca muda durante a execucao

  // logica em linguagem natural com nomes reais
  RETORNA resultado
```

### 5.2 Design by Contract DLL↔MQL5

```
CONTRATO: DLL_NomeFuncao
  C:     tipo f(tipo1 p1, tipo2 p2, ...)     // fonte de verdade
  MQL5:  tipo f(tipo1 p1, tipo2 p2, ...)     // DEVE SER IDENTICO
  PRE:   condicoes de entrada
  POS:   garantias de saida
  SIZEOF: verificar structs em ambos lados
```

**Regras DLL↔MQL5:**
- Assinatura C = UNICA fonte de verdade
- TODA #import MQL5 conferida com header C (param count, tipos, ordem)
- sizeof() de CADA struct verificado em ambos lados
- Structs individuais: array de 1 elemento no MQL5
- Testar com dados triviais antes de dados reais

### 5.3 Observabilidade (OBRIGATORIA em todo EA)

```mql5
// TODO EA deve ter:
input int InpDebugLevel = 0;  // 0=off, 1=resumo, 2=detalhado

// Contadores por estagio do pipeline:
int g_passSwings, g_passFib, g_passClusters, g_passSetups;
int g_passTrend, g_passScore, g_passZone, g_passTrigger;

// OnDeinit: SEMPRE imprimir resumo
void OnDeinit(const int reason) {
   Print("PIPELINE STATS: swings=%d fib=%d clusters=%d setups=%d",
         g_passSwings, g_passFib, g_passClusters, g_passSetups);
   Print("FILTER STATS: trend=%d score=%d zone=%d trigger=%d trades=%d",
         g_passTrend, g_passScore, g_passZone, g_passTrigger, g_trades);
}
```

### 5.4 Fail-Fast com Contexto

```mql5
// BOM: mensagem clara com numeros
if(lots < m_minLots) {
    Print("REJECT: lots=%.4f < min=%.4f | entry=%.5f sl=%.5f dist=%.1f pips",
          lots, m_minLots, entry, sl, MathAbs(entry-sl)/_Point);
    return false;
}
// RUIM: falha silenciosa
if(lots < m_minLots) return false;
```

### 5.5 OODA Loop para Debug

```
OBSERVE: Ler journal. Coletar numeros de cada estagio.
ORIENT:  Qual estagio bloqueia? (primeiro com queda > 90%)
DECIDE:  Qual UNICA hipotese testar? (a mais provavel primeiro)
ACT:     Mudar UMA coisa. Testar. Confirmar ou refutar.
REPETIR ate causa-raiz.

NUNCA shotgun debugging (mudar 5 coisas ao mesmo tempo).
```

### 5.6 Causa-Raiz (5 Whys)

Quando bug encontrado, perguntar 5x "por que?":
```
Bug: EA tem 0 trades em 2 anos
1. Por que? → Nenhum setup passa todos filtros combinados
2. Por que? → CCI trigger rejeita 98% dos setups validos
3. Por que? → CCI crossover acontece em 1 barra especifica
              mas cluster pode estar ativo por 50 barras
4. Por que? → O design exige coincidencia temporal exata
              entre 2 eventos independentes
5. Por que? → Nao foi feito teste de mesa para calcular
              a probabilidade de coincidencia

ACAO: a) Testar sem CCI para ver baseline
      b) Se funciona sem CCI, redesenhar trigger
      c) Adicionar teste de mesa para novos filtros
```

---

## 6. CONVENCOES DE CODIGO MQL5

### Nomenclatura
- `InpRiskPercent` (inputs), `g_isInitialized` (globais), `m_config` (membros)
- `CTradeManager` (classes), `SSwingPoint` (structs), `ENUM_ENTRY_MODE` (enums)

### Estrutura de Arquivo
```
EA_Project/
  DLL/fib_types.h, Module.c, build.bat
  MQL5/Experts/EA_Name.mq5
  MQL5/Include/ProjectName/Config.mqh, DLLBridge.mqh, RiskManager.mqh
```

### Padroes
```mql5
// OnInit: Validar → Inicializar → Flag
// OnTick: Guard → ManagePositions → NewBarGate → Pipeline → Execute
// OnDeinit: Liberar handles → PrintPipelineStats
// Posicoes: for(i=Total-1; i>=0; i--) com magic+symbol filter
// Indicadores: criar OnInit, liberar OnDeinit, NUNCA em OnTick
```

### Indicadores Tecnicos
```mql5
int iMA(sym,tf,period,shift,method,price);   // 1 buffer
int iRSI(sym,tf,period,price);                // 1 buffer
int iMACD(sym,tf,fast,slow,signal,price);     // 2 buffers (main, signal)
int iBands(sym,tf,period,shift,dev,price);    // 3 buffers (base,upper,lower)
int iATR(sym,tf,period);                      // 1 buffer
int iADX(sym,tf,period);                      // 3 buffers (main,+DI,-DI)
int iCCI(sym,tf,period,price);                // 1 buffer
```

---

## 7. ARQUITETURA HIBRIDA (MQL5 + DLL)

```
EA (MQL5): dados, ordens, broker, estados — orquestrador FINO
    ↕ DLL Import (x64 Windows ABI)
DLL (C): calculos, SIMD, deteccao de padroes — TODA logica pesada
```

- ABI x64: params 1-4 em rcx/rdx/r8/r9 (int/ptr) ou xmm0-3 (double)
- Structs NUNCA por valor; sempre ponteiro (array[1] no MQL5)
- `gcc -shared -O2 -msse2 -static-libgcc -static -o Name.dll Name.c`
- Deploy: Terminal/MQL5/Libraries/ E Tester/Agent/MQL5/Libraries/

---

## 8. REFERENCIA DE ESTRATEGIAS

### Localizacao: `Livros/Livros_Extraidos/[NomeLivro]/`

**Fibonacci (Borden):** Clusters (3+ niveis), AB=CD, Two-Step, Symmetry. WITH trend. CCI+EMA34.
**ICT:** Order Blocks, FVG, BOS/CHoCH, OTE (62-79%), Liquidity.
**Mean Reversion:** Z-Score, Bollinger 2σ, RSI extremes.
**Supply/Demand:** Consolidacao pre-move, freshness, role reversal.
**Harmonics:** Gartley/Butterfly/Bat/Crab com ratios especificos.
**Ciclos (Ehlers):** MESA, Hilbert Transform, indicadores adaptativos.
**Design (Pardo):** Walk-forward, anti-overfitting, robustez.

---

## 9. PROJETOS ATIVOS

| Projeto | Estrategia | Status |
|---------|-----------|--------|
| EA_Fibonacci_Hybrid | Fibonacci Borden + DLLs | Ativo |
| EA_Odin | EMA + ADX + MACD | Ativo |
| EA_Neural_Trader | Neural + indicadores | Ativo |
| EA_Price_Action | Price action puro | Ativo |
| EA_Supply_Demand | Zonas S/D + Python | Ativo |
| Enterprise_EA | Multi-estrategia | Ativo |
| Thor_EA | Volatilidade + momentum | Ativo |

---

## 10. PATHS

- **Raiz:** `C:\Users\santospaulo\Documents\EA_Projetos\EA_Projetos\`
- **Livros:** `Livros\Livros_Extraidos\`
- **MQL5 Manual:** `Livros\Livros_Extraidos\MQL5 - Manual de Referencia\`
- **MT5 Terminal:** `C:\Users\santospaulo\AppData\Roaming\MetaQuotes\Terminal\FEC98F1D078C037902D797DB372EA18E\MQL5\`
- **MT5 Tester:** `C:\Users\santospaulo\AppData\Roaming\MetaQuotes\Tester\FEC98F1D078C037902D797DB372EA18E\Agent-127.0.0.1-3000\MQL5\`
- **GCC:** `...WinGet\Packages\BrechtSanders.WinLibs.POSIX.UCRT_Microsoft.Winget.Source_...\mingw64\bin\gcc.exe`

---

## 11. ANTI-PATTERNS

- ❌ Avaliar EA apenas por R:R ou apenas por win rate
- ❌ Considerar backtest in-sample como prova de que funciona
- ❌ Adicionar filtro sem medir custo (trades perdidos) vs beneficio (win rate)
- ❌ Ignorar diagnostico por regime/sessao/timing
- ❌ Implementar sem pseudocodigo para funcoes > 20 linhas
- ❌ Criar #import MQL5 sem conferir assinatura C
- ❌ Deployar sem 0 errors E 0 warnings
- ❌ Rodar backtest longo sem antes rodar curto com debug
- ❌ Shotgun debugging (mudar N coisas ao mesmo tempo)
- ❌ Criar handles de indicador dentro de OnTick
- ❌ Passar struct por referencia simples para DLL
- ❌ Assumir "compila = funciona"
- ❌ Silenciar erros (return false sem Print)
- ❌ Otimizar sem walk-forward validation
- ❌ Ignorar tail risk e max consecutive losses
- ❌ Criar novo script Python para cada analise de backtest (REUSAR ou fazer INLINE)
- ❌ Proliferar arquivos analyze_v*.py / analysis_v*.py no repositorio

---

## 12. ANALISE DE BACKTEST — REGRAS

### PROIBIDO criar novos scripts de analise

**REGRA ABSOLUTA:** NUNCA criar um novo arquivo .py para analisar backtest.

**Como analisar backtest:**
1. **INLINE via Python REPL** — `python3 -c "..."` ou REPL interativo direto no terminal
2. **Reusar script existente** — se existir um `backtest_analyzer.py` canonico, usar ele
3. **Calculos simples** — extrair dados com grep/awk e calcular inline

**Por que:** Ja existiram 17+ scripts duplicados fazendo a mesma coisa.
Cada script novo e desperdicio de tokens, polui o repositorio, e nunca e reusado.

**O que o script canonico deve ter (se necessario):**
- Aceitar path do log como argumento
- Parsear TRADE # lines + deal closures automaticamente
- Calcular TODAS as 5 camadas do CLAUDE.md
- Output formatado ASCII (sem Unicode que quebra no Windows cp1252)
- NUNCA hardcodar dados de trades — sempre parsear do log

---

## 13. CHECKLISTS RAPIDOS

### Pre-Codigo
- [ ] Pseudocodigo para funcoes complexas?
- [ ] Contratos DLL documentados?
- [ ] Teste de mesa com dados reais?
- [ ] Edge cases identificados?

### Pre-Deploy
- [ ] 0 errors, 0 warnings?
- [ ] DLLs em Terminal E Tester?
- [ ] Debug ON para primeiro teste?
- [ ] sizeof() verificado?
- [ ] Backtest 1 mes ok?

### Pre-Live
- [ ] Camadas 1-4 avaliadas?
- [ ] Walk-forward efficiency > 50%?
- [ ] Sensibilidade de parametros testada?
- [ ] Spread/slippage sensitivity ok?
- [ ] Matriz de filtros analisada?
- [ ] Nenhum filtro matando > 95% dos sinais sem beneficio proporcional?
- [ ] Monte Carlo 95% still profitable?
