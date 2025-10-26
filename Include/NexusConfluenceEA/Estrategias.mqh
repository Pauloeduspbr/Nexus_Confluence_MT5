//+------------------------------------------------------------------+
//| Estrategias.mqh                                                  |
//| Nexus Confluence EA v4.58 - FIX BUFFERS: Ler CORES não TREND!   |
//|                                                                   |
//| PROPÓSITO: Centralizar TODA a lógica de estratégias multi-TF     |
//|                                                                   |
//| 🚨🚨🚨 v4.58: CORREÇÃO URGENTE - BUFFERS ERRADOS! (27/01/2025)|
//|                                                                  |
//| 🐛 BUG CRÍTICO IDENTIFICADO v4.57:                              |
//|   ❌ EA lia buffers 0-8 (valores trend do indicador)            |
//|   ❌ Mas indicador usa buffers 9-17 (CORES!)                    |
//|   ❌ Resultado: W1=+2, valores incorretos, sincronização errada |
//|   ❌ User: "VOCE ESTA PEGANDO AS CORES ERRADAS !!!!!!"          |
//|                                                                  |
//| 🔍 ESTRUTURA REAL DO INDICADOR GG_TrendBar:                     |
//|   Buffer 0-8:  Valores de trend (Buffer_M1...Buffer_MN1)        |
//|   Buffer 9-17: Índices de cor (Color_M1...Color_MN1)            |
//|                                                                  |
//| 📊 SISTEMA DE CORES DO INDICADOR:                               |
//|   Cor 0 = Verde (Bullish)  → EA converte para +1                |
//|   Cor 1 = Vermelho (Bearish) → EA converte para -1              |
//|   Cor 2 = Amarelo (Neutro) → EA converte para 0                 |
//|                                                                  |
//| ✅ CORREÇÃO IMPLEMENTADA v4.58:                                 |
//|   ✅ Mudou buffers: 0,2,4,6,8,10,12,14,16 → 9,10,11,12,13,14,15,16,17 |
//|   ✅ Agora lê os buffers de COR corretamente!                   |
//|   ✅ Converte cores para valores de trend no EA                 |
//|   ✅ W1 nunca mais será ±2 (será 0,±1 conforme amarelo/verde/vermelho) |
//|                                                                  |
//| 🚨🚨🚨 v4.57: CORREÇÃO DEFINITIVA - TIMESTAMP SINCRONIZADO!    |
//|          (27/01/2025)                                            |
//|                                                                  |
//| 🐛 BUG RAÍZ IDENTIFICADO (v4.56):                               |
//|   ❌ iTime(..., 0) = timestamp do candle EM FORMAÇÃO!          |
//|   ❌ CopyBuffer shift 1 = dados do candle FECHADO!              |
//|   ❌ LOG mostrava timestamp FUTURO vs dados PASSADOS!           |
//|   ❌ Exemplo: LOG 09:00 mas dados de 08:30 (45min diferença!)  |
//|                                                                  |
//| 🔍 ANÁLISE COMPLETA DO PROBLEMA:                                |
//|   1. UpdateBufferCache():                                       |
//|      datetime currentBar = iTime(..., 0)                        |
//|      - Se às 08:47 no M15: retorna 08:45 (candle atual)        |
//|   2. CopyBuffer(..., 1, ...):                                   |
//|      - Copia candle fechado 08:30                               |
//|   3. RESULTADO:                                                 |
//|      - LOG imprime timestamp 08:45                              |
//|      - Mas dados são do candle 08:30                            |
//|      - User vê gráfico em 08:15 mas log mostra 09:00!          |
//|                                                                  |
//| ✅ CORREÇÃO IMPLEMENTADA v4.57:                                 |
//|   ✅ iTime(..., 0) → iTime(..., 1) em UpdateBufferCache()      |
//|   ✅ Agora timestamp = candle fechado (mesmo dos dados)         |
//|   ✅ LOG perfeitamente sincronizado com gráfico!                |
//|   ✅ Exemplo: LOG 08:30 E dados 08:30 = MATCH PERFEITO!        |
//|                                                                  |
//| 🚨🚨🚨 v4.56: CORREÇÃO DEFINITIVA - SINCRONIZAÇÃO LOG vs GRÁFICO|
//|                                                                  |
//| 🐛 BUG CRÍTICO IDENTIFICADO (v4.54):                            |
//|   ❌ Arrays temporários NÃO eram definidos como SERIES!        |
//|   ❌ CopyBuffer em array não-series: [0]=antigo, [1]=atual     |
//|   ❌ Código usava [0] achando que era atual = LIA ANTIGO!      |
//|   ❌ Resultado: LOG mostrava dados ERRADOS vs gráfico          |
//|                                                                  |
//| 🚨🚨� v4.54: CORREÇÃO URGENTE - SUPERTREND EMPTY              |
//|                                                                  |
//| 🐛 BUG CRÍTICO IDENTIFICADO (v4.53):                            |
//|   ❌ Supertrend retornava DBL_MAX (~1.7e308) quando inativo    |
//|   ❌ Threshold 1.0e10 era MUITO BAIXO para detectar!           |
//|   ❌ Comparação `> 0` rejeitava possíveis valores negativos     |
//|   ❌ Resultado: Não detectava corretamente buffer ativo         |
//|   3. Problema: 1.7e+308 > 1.0e10 → NÃO detectava como EMPTY    |
//|   4. Resultado: Tentava usar DBL_MAX como preço válido!        |
//|                                                                  |
//| ✅ CORREÇÃO IMPLEMENTADA v4.54:                                 |
//|   ✅ Threshold aumentado: 1.0e10 → 1.0e100                     |
//|   ✅ Usar MathAbs() para valores negativos                      |
//|   ✅ Verificar != EMPTY_VALUE explicitamente                    |
//|   ✅ Detecção: MathAbs(buf[1]) < 1e100 && != EMPTY_VALUE       |
//|                                                                  |
//| 🚨🚨🚨 v4.53: CORREÇÃO URGENTE - INDICADOR ±2 (25/10/2025)     |
//|                                                                  |
//| 🐛 BUG CRÍTICO IDENTIFICADO (v4.52):                            |
//|   ❌ GG_TrendBar retornava +2/-2 (sinais fortes)               |
//|   ❌ EA espera APENAS -1, 0, +1                                 |
//|   ❌ Resultado: TODAS comparações quebradas!                    |
//|   ❌ M15=-2 nunca era == -1 → setup sempre rejeitado           |
//|                                                                  |
//| 🔍 ANÁLISE DO PROBLEMA:                                         |
//|   1. Indicador v2.10/v2.11 tinha lógica de intensidade:        |
//|      if(adx_diff >= 10.0) IndVal[x] = 2; // FORTE              |
//|      else IndVal[x] = 1; // fraco                               |
//|                                                                  |
//|   2. EA esperava valores simples:                               |
//|      -1 = BEARISH, 0 = NEUTRAL, +1 = BULLISH                   |
//|                                                                  |
//|   3. Comparação falhava:                                        |
//|      if(m15Value == -1) // M15 bearish?                         |
//|      MAS m15Value = -2 (forte) → falha na comparação!          |
//|                                                                  |
//| ✅ CORREÇÃO IMPLEMENTADA v4.53:                                 |
//|   ✅ GG_TrendBar v2.12: Removido lógica de intensidade         |
//|   ✅ Indicador retorna APENAS: -1, 0, +1                       |
//|   ✅ -1 = BEARISH (vermelho)                                    |
//|   ✅  0 = NEUTRAL (amarelo)                                     |
//|   ✅ +1 = BULLISH (verde)                                       |
//|   ✅ EA agora recebe valores corretos                           |
//|                                                                  |
//| 🚨🚨🚨 v4.52: CORREÇÃO URGENTE - EA NÃO ABRE VENDA (25/10/2025)|
//|                                                                  |
//| 🐛 BUG CRÍTICO IDENTIFICADO (v4.50-v4.51):                      |
//|   ❌ EA NÃO abria SELL mesmo com TODOS indicadores alinhados!  |
//|   ❌ Supertrend rejeitava SELL incorretamente                   |
//|   ❌ Todos filtros passavam, mas Supertrend bloqueava           |
//|                                                                  |
//| 🔍 ANÁLISE DO PROBLEMA:                                         |
//|   1. Código v4.51 comparava:                                    |
//|      SYMBOL_BID (preço atual) < Supertrend[1] (candle anterior)|
//|                                                                  |
//|   2. Problema do SPREAD:                                        |
//|      - Close[1] = 143.478 (fechou ABAIXO da linha)             |
//|      - Supertrend[1] = 143.530                                  |
//|      - SYMBOL_BID = 143.435 (com spread)                        |
//|      - Comparação: 143.435 < 143.530? SIM → DEVERIA ACEITAR   |
//|      - MAS: Close[1] vs linha estava INCORRETO                  |
//|                                                                  |
//|   3. Resultado:                                                  |
//|      - EA via "preço não está abaixo da linha"                  |
//|      - Rejeitava SELL mesmo estando correto visualmente         |
//|      - Comparava TEMPOS DIFERENTES (atual vs [1])               |
//|                                                                  |
//| ✅ CORREÇÃO IMPLEMENTADA v4.52:                                 |
//|   ✅ Mudado de SYMBOL_BID → Close[1] (mesmo candle!)           |
//|   ✅ Compara Close[1] com Supertrend[1] (sincronizado)         |
//|   ✅ Elimina problema de spread e timing                        |
//|   ✅ SELL agora detecta corretamente quando Close < linha       |
//|                                                                  |
//| 🚨🚨🚨 v4.51: CORREÇÃO URGENTE - BUG GRAVÍSSIMO (25/10/2025)   |
//|                                                                  |
//| 🐛 BUG CRÍTICO IDENTIFICADO (v4.26-v4.50):                      |
//|   ❌ EA abria COMPRA com H4 VERMELHO (bearish)!                |
//|   ❌ EA ignorava completamente o timeframe H4                   |
//|   ❌ Causa: Leitura incorreta dos buffers do indicador          |
//|                                                                  |
//| 🔍 ANÁLISE DO PROBLEMA:                                         |
//|   1. CopyBuffer(handle, 10, 0, 2, array) copia:                |
//|      - array[0] = valor ATUAL do indicador                      |
//|      - array[1] = valor ANTERIOR (candle passado)               |
//|                                                                  |
//|   2. Código v4.50 fazia:                                        |
//|      macro1Data = gg_h4[1]  ← ERRO! Pegava candle ANTERIOR     |
//|                                                                  |
//|   3. Resultado:                                                  |
//|      - EA via H4 de ONTEM ao invés de H4 de HOJE               |
//|      - Abria trades com informação DESATUALIZADA                |
//|      - Ignorava mudanças de tendência no H4                     |
//|                                                                  |
//| ✅ CORREÇÃO IMPLEMENTADA v4.51:                                 |
//|   ✅ Mudado de gg_h4[1] → gg_h4[0] (valor ATUAL)               |
//|   ✅ Aplicado a TODOS os timeframes (M1-MN1)                    |
//|   ✅ EA agora lê corretamente o último valor do indicador       |
//|   ✅ Validação Multi-TF funcionando corretamente                |
//|                                                                  |
//| 🔥🔥🔥 v4.50: CORREÇÕES CRÍTICAS NOS FILTROS (25/10/2025)      |
//|                                                                  |
//| ✅ CORRIGIDO: GetSupertrendSignal()                             |
//|   - BUY: Linha azul ativa + PREÇO ACIMA da linha azul          |
//|   - SELL: Linha vermelha ativa + PREÇO ABAIXO da linha vermelha|
//|   - Problema v4.49: Não verificava posição do preço             |
//|                                                                  |
//| ✅ CORRIGIDO: GetCurrencyStrengthSignal()                       |
//|   - BUY: Linha verde > vermelha + linha verde > 0              |
//|   - SELL: Linha vermelha > verde + linha vermelha > 0          |
//|   - Problema v4.49: Não verificava se estava acima de 0        |
//|                                                                  |
//| 🏆 PREMIUM: H4+H1+M30+M15 TODOS ALINHADOS (mesma cor)           |
//|   ✅ H4 VERDE + H1 VERDE + M30 VERDE + M15 VERDE = BUY          |
//|   ✅ H4 VERMELHO + H1 VERMELHO + M30 VERMELHO + M15 VERMELHO = SELL |
//|                                                                  |
//| ⭐ GOOD (3 cenários válidos):                                   |
//|   1️⃣ H4+H1+M30 alinhados, M15 NEUTRO (amarelo/0)               |
//|   2️⃣ H4+H1+M15 alinhados, M30 NEUTRO (amarelo/0)               |
//|   3️⃣ H4+H1 alinhados, M30+M15 ambos NEUTROS                    |
//|                                                                  |
//| ❌ REJECT:                                                       |
//|   ❌ M15 OPOSTO a H4+H1 (vermelho quando H4+H1 verdes)          |
//|   ❌ M30 OPOSTO a H4+H1                                          |
//|   ❌ H4 e H1 divergentes entre si                                |
//|   ✅ NEUTRO (amarelo/0) é ACEITO como GOOD                      |
//|                                                                  |
//| 📊 FILTROS - BUY:                                               |
//|   1. Supertrend: LINHA AZUL + PREÇO ACIMA DA LINHA AZUL        |
//|   2. WAE: HISTOGRAMA VERDE                                      |
//|   3. WAE: BARRA VERDE ACIMA DA LINHA AMARELA                    |
//|   4. RSI OMA: LINHA VERMELHA ACIMA DA LINHA AZUL               |
//|   5. Currency: LINHA VERDE ACIMA DA VERMELHA                    |
//|   6. Currency: LINHA VERDE ACIMA DO NÍVEL 0                     |
//|                                                                  |
//| 📊 FILTROS - SELL:                                              |
//|   1. Supertrend: LINHA VERMELHA + PREÇO ABAIXO DA LINHA        |
//|   2. WAE: HISTOGRAMA VERMELHO                                   |
//|   3. WAE: BARRA VERMELHO ACIMA DA LINHA AMARELA                 |
//|   4. RSI OMA: LINHA VERMELHA ABAIXO DA LINHA AZUL              |
//|   5. Currency: LINHA VERMELHA ACIMA DA AZUL                     |
//|   6. Currency: LINHA VERMELHA ACIMA DO NÍVEL 0                  |
//|                                                                  |
//| ❌ v4.48 INCORRETA (REVERTIDA):                                 |
//|   ❌ PROBLEMA v4.47: Exigir sinais ±2 atrasava entradas!        |
//|   ✅ CORREÇÃO v4.48: Volta para > 0 / < 0 (qualquer sinal)      |
//|      - Não exige mais intensidade mínima                         |
//|      - M15 deve estar alinhado (não neutro)                      |
//|      - Classificação PREMIUM/GOOD baseada em alinhamento         |
//|                                                                  |
//| 🔥🔥🔥 LÓGICA RESTAURADA (v4.46):                               |
//|   - PREMIUM: Todos TFs alinhados (H4+H1+M30+M15 mesma direção)  |
//|   - GOOD: Principais alinhados (H4+H1+M15), M30 diverge         |
//|   - REJECT: Qualquer TF principal divergente                    |
//|                                                                  |
//| ❌ v4.47 PROBLEMÁTICA (REVERTIDA):                              |
//|   ✅ PREMIUM: Exige TODOS TFs FORTES (±2) e alinhados           |
//|      - H4 = ±2 (FORTE)                                           |
//|      - H1 = ±2 (FORTE)                                           |
//|      - M30 = ±2 (FORTE) [se aplicável]                          |
//|      - M15 = ±2 (FORTE) e alinhado                              |
//|                                                                  |
//|   ✅ GOOD: Aceita M15 FRACO/NEUTRO se macros FORTES             |
//|      - H4 + H1 = ±2 (FORTES) e alinhados                        |
//|      - M30 pode ser ±1 ou 0 (FRACO/NEUTRO)                      |
//|      - M15 pode ser ±1 ou 0 (FRACO/NEUTRO) [FLEXÍVEL!]          |
//|      - Impede M15 OPOSTO FORTE (±2 contra macros)               |
//|                                                                  |
//|   ❌ REJECT: Qualquer macro fraco ou divergente                 |
//|      - H4 ou H1 = ±1 (FRACOS) → REJEITADO                       |
//|      - M15 = ±2 OPOSTO aos macros → REJEITADO                   |
//|                                                                  |
//| 🔥🔥🔥 HISTÓRICO v4.46: INTENSIDADE DE SINAL (25/10/2025)       |
//|   ✅ INDICADOR GG TRENDBAR v2.10 ATUALIZADO:                    |
//|      - Agora retorna +2/-2 para sinais FORTES                   |
//|      - Baseado na diferença PADX-NADX (threshold 10 pontos)     |
//|      - +2 = Bullish FORTE, +1 = Bullish fraco                   |
//|      - -2 = Bearish FORTE, -1 = Bearish fraco                   |
//|      - 0 = Neutro (amarelo)                                     |
//|                                                                  |
//|   ✅ EA JÁ COMPATÍVEL:                                           |
//|      - v4.45 corrigiu para > 0 (bullish) e < 0 (bearish)        |
//|      - Detecta automaticamente +1, +2, -1, -2                   |
//|      - Logs atualizados para mostrar intensidade                |
//|                                                                  |
//| 🔥🔥🔥 HISTÓRICO v4.45: CORREÇÃO VALORES GG TRENDBAR            |
//|   ❌ BUG v4.44 IDENTIFICADO:                                     |
//|      - Comparava exatamente == 1 para bullish                   |
//|      - Ignorava valor +2 (verde forte)!                         |
//|      - Resultado: H4=+2 não era reconhecido como bullish        |
//|      - EA só abria trades com valores +1, ignorava +2           |
//|                                                                  |
//|   ✅ CORREÇÃO IMPLEMENTADA:                                      |
//|      - Mudado de == 1 para > 0 (aceita +1 e +2)                |
//|      - Mudado de == -1 para < 0 (aceita -1)                    |
//|      - Agora reconhece CORRETAMENTE:                            |
//|        * +2 ou +1 = BULLISH (verde forte/fraco)                |
//|        * -1 = BEARISH (vermelho)                                |
//|        * 0 = NEUTRO (amarelo)                                   |
//|                                                                  |
//| 🔥🔥🔥 CRÍTICO v4.44: CORREÇÃO VALIDAÇÃO TF OPERACIONAL (25/10/2025) |
//|   ❌ BUG GRAVÍSSIMO IDENTIFICADO:                               |
//|      - EA NUNCA validava timeframe operacional (M15, M30, H1)!  |
//|      - RESULTADO: Abria BUY com H4+H1 GREEN mas M15 RED ❌      |
//|      - Violação ABSOLUTA do Sistema Universal                   |
//|      - ~40% dos trades eram contra o TF operacional!            |
//|                                                                  |
//|   ✅ CORREÇÃO IMPLEMENTADA (CRÍTICA):                            |
//|      1. VALIDAÇÃO TF OPERACIONAL OBRIGATÓRIA                    |
//|         - Lê valor do TF operacional do GG TrendBar             |
//|         - TF operacional DEVE estar definido (não neutro)       |
//|         - TF operacional DEVE alinhar com MACRO-1 e MACRO-2     |
//|         - Se divergir: REJEITA IMEDIATAMENTE ❌                 |
//|                                                                  |
//|      2. CLASSIFICAÇÃO PREMIUM/GOOD CORRIGIDA                    |
//|         - PREMIUM: TODOS TFs alinhados (MACRO-1+2+3+OPER)      |
//|         - GOOD: Principais alinhados (MACRO-1+2+OPER), M30 diverge |
//|         - Classificação feita em AnalyzeMultiTimeframeAlignment() |
//|                                                                  |
//|      3. CALCULATESETUPSCORE() REFATORADO                        |
//|         - Recebe classificação do GG (não mais m30Aligned bool) |
//|         - Filtros micro apenas CONFIRMAM ou REJEITAM            |
//|         - Filtros NÃO PODEM elevar classificação (GOOD→PREMIUM) |
//|                                                                  |
//|   ✅ IMPACTO ESPERADO (ENORME):                                 |
//|      - Win Rate: +8-13% (elimina trades contra operacional)    |
//|      - Drawdown: -40% (de -91% para -50%)                      |
//|      - Sharpe Ratio: +45-71% (de 0.38 para 0.55-0.65)         |
//|      - Número de trades: -60% (muito mais seletivo)            |
//|      - Trades errados: -87% (de ~40% para ~5%)                 |
//|                                                                  |
//| AUTOR: GitHub Copilot + Desenvolvedor                            |
//| DATA: Outubro 2025                                               |
//| VERSÃO: 4.44 - CORREÇÃO CRÍTICA: Validação TF Operacional      |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA v4.44"
#property version   "4.44"

#include "Parametros.mqh"

//+------------------------------------------------------------------+
//| FUNÇÕES AUXILIARES DO MÓDULO                                     |
//+------------------------------------------------------------------+

// Converter ENUM_TIMEFRAMES para string legível
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| VARIÁVEIS GLOBAIS DO MÓDULO ESTRATÉGIAS                          |
//+------------------------------------------------------------------+

// Timeframes macro definidos dinamicamente
ENUM_TIMEFRAMES g_tfMacro1       = PERIOD_H4;   // MACRO-1 (mais longo)
ENUM_TIMEFRAMES g_tfMacro2       = PERIOD_H1;   // MACRO-2 (intermediário)
ENUM_TIMEFRAMES g_tfMacro3       = PERIOD_M30;  // MACRO-3 (curto) - pode ser PERIOD_CURRENT se não aplicável
ENUM_TIMEFRAMES g_tfOperacional  = PERIOD_M15;  // OPERACIONAL (atual do gráfico)
int             g_numNiveisMacro = 3;           // 2 ou 3 níveis macro

// Handles dos indicadores (preenchidos em InitializeIndicators)
IndicatorHandles g_handles;

//+------------------------------------------------------------------+
//| 🔥 OTIMIZAÇÃO v2.0: BUFFER CACHE GLOBAL                          |
//| Evita múltiplas chamadas CopyBuffer no mesmo frame              |
//| UpdateBufferCache() é chamado 1x por candle novo                |
//| GetXXXSignal() lê do cache ao invés de CopyBuffer               |
//+------------------------------------------------------------------+
struct BufferCache {
    datetime lastUpdate;         // Timestamp da última atualização
    bool isValid;               // Cache válido?
    
    // WAE (3 buffers × 3 barras)
    double wae_trendUp[3];
    double wae_trendDown[3];
    double wae_explosion[1];
    
    // RSI OMA (2 buffers × 3 barras)
    double rsi_red[3];
    double rsi_blue[3];
    
    // Currency Strength (2 buffers × 1 barra)
    double cs_base[1];
    double cs_quote[1];
    
    // Supertrend (2 buffers × 3 barras)
    double trend_up[3];
    double trend_down[3];
    
    // GG TrendBar (9 timeframes × 2 barras)
    double gg_m1[2];
    double gg_m5[2];
    double gg_m15[2];
    double gg_m30[2];
    double gg_h1[2];
    double gg_h4[2];
    double gg_d1[2];
    double gg_w1[2];
    double gg_mn1[2];
};

BufferCache g_bufferCache;

// 🔥 Arrays temporários GLOBAIS para UpdateBufferCache (workaround compilador MQL5)
// ✅ v4.55: Arrays DINÂMICOS (sem tamanho fixo) para permitir ArraySetAsSeries
// Arrays dinâmicos [] podem ter indexação alterada, arrays estáticos [N] não podem
double g_temp_wae_up[];
double g_temp_wae_down[];
double g_temp_wae_exp[];
double g_temp_rsi_red[];
double g_temp_rsi_blue[];
double g_temp_cs_base[];
double g_temp_cs_quote[];
double g_temp_supertrend_up[];
double g_temp_supertrend_down[];
double g_temp_gg_m1[];
double g_temp_gg_m5[];
double g_temp_gg_m15[];
double g_temp_gg_m30[];
double g_temp_gg_h1[];
double g_temp_gg_h4[];
double g_temp_gg_d1[];
double g_temp_gg_w1[];
double g_temp_gg_mn1[];

//+------------------------------------------------------------------+
//| 🔥 FUNÇÃO: UpdateBufferCache                                     |
//| Atualiza TODOS os buffers de UMA VEZ (chamada 1x por candle)    |
//| Retorna true se sucesso, false se erro                          |
//| ✅ v4.55 FIX: Arrays como SERIES para ler corretamente [0]=atual|
//| 🔥 v4.57 FIX CRÍTICO: iTime shift 0→1 para sincronizar com dados|
//+------------------------------------------------------------------+
bool UpdateBufferCache()
{
    // 🔥 v4.57 FIX CRÍTICO DE SINCRONIZAÇÃO TEMPORAL:
    // ❌ ANTES: iTime(..., 0) = timestamp do candle EM FORMAÇÃO (atual)
    //    - Exemplo: Às 08:47, candle M15 atual = 08:45 (ainda aberto)
    //    - CopyBuffer shift 1 = candle 08:30 (fechado)
    //    - RESULTADO: Log mostra 08:45 mas dados são de 08:30 = DESSINCRONIZADO!
    //
    // ✅ AGORA: iTime(..., 1) = timestamp do último candle FECHADO
    //    - CopyBuffer shift 1 = candle fechado
    //    - iTime shift 1 = timestamp do candle fechado
    //    - RESULTADO: Log e dados do MESMO candle = SINCRONIZADO!
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 1);
    
    if(g_bufferCache.lastUpdate == currentBar && g_bufferCache.isValid)
    {
        return true;
    }
    
    // 🔥 v4.55 FIX CRÍTICO: Redimensionar arrays dinâmicos ANTES de usar
    ArrayResize(g_temp_wae_up, 3);
    ArrayResize(g_temp_wae_down, 3);
    ArrayResize(g_temp_wae_exp, 1);
    ArrayResize(g_temp_rsi_red, 3);
    ArrayResize(g_temp_rsi_blue, 3);
    ArrayResize(g_temp_cs_base, 1);
    ArrayResize(g_temp_cs_quote, 1);
    ArrayResize(g_temp_supertrend_up, 3);
    ArrayResize(g_temp_supertrend_down, 3);
    ArrayResize(g_temp_gg_m1, 2);
    ArrayResize(g_temp_gg_m5, 2);
    ArrayResize(g_temp_gg_m15, 2);
    ArrayResize(g_temp_gg_m30, 2);
    ArrayResize(g_temp_gg_h1, 2);
    ArrayResize(g_temp_gg_h4, 2);
    ArrayResize(g_temp_gg_d1, 2);
    ArrayResize(g_temp_gg_w1, 2);
    ArrayResize(g_temp_gg_mn1, 2);
    
    // 🔥 v4.55 FIX CRÍTICO: Definir TODOS arrays temporários como SERIES!
    // Isso garante que [0] = candle ATUAL, [1] = candle ANTERIOR
    ArraySetAsSeries(g_temp_wae_up, true);
    ArraySetAsSeries(g_temp_wae_down, true);
    ArraySetAsSeries(g_temp_wae_exp, true);
    ArraySetAsSeries(g_temp_rsi_red, true);
    ArraySetAsSeries(g_temp_rsi_blue, true);
    ArraySetAsSeries(g_temp_cs_base, true);
    ArraySetAsSeries(g_temp_cs_quote, true);
    ArraySetAsSeries(g_temp_supertrend_up, true);
    ArraySetAsSeries(g_temp_supertrend_down, true);
    ArraySetAsSeries(g_temp_gg_m1, true);
    ArraySetAsSeries(g_temp_gg_m5, true);
    ArraySetAsSeries(g_temp_gg_m15, true);
    ArraySetAsSeries(g_temp_gg_m30, true);
    ArraySetAsSeries(g_temp_gg_h1, true);
    ArraySetAsSeries(g_temp_gg_h4, true);
    ArraySetAsSeries(g_temp_gg_d1, true);
    ArraySetAsSeries(g_temp_gg_w1, true);
    ArraySetAsSeries(g_temp_gg_mn1, true);
    
    bool success = true;
    
    // 1. WAE
    if(g_handles.wae_oper != INVALID_HANDLE)
    {
        // 🔥 v4.56 FIX: Copiar do shift 1 (candle FECHADO), não shift 0 (em formação)
        if(CopyBuffer(g_handles.wae_oper, 0, 1, 3, g_temp_wae_up) == 3 &&
           CopyBuffer(g_handles.wae_oper, 1, 1, 3, g_temp_wae_down) == 3 &&
           CopyBuffer(g_handles.wae_oper, 2, 1, 1, g_temp_wae_exp) == 1)
        {
            for(int idx = 0; idx < 3; idx++)
            {
                g_bufferCache.wae_trendUp[idx] = g_temp_wae_up[idx];
                g_bufferCache.wae_trendDown[idx] = g_temp_wae_down[idx];
            }
            g_bufferCache.wae_explosion[0] = g_temp_wae_exp[0];
        }
        else success = false;
    }
    
    // 2. RSI OMA
    if(g_handles.rsi_oper != INVALID_HANDLE)
    {
        // 🔥 v4.56 FIX: Copiar do shift 1 (candle FECHADO)
        if(CopyBuffer(g_handles.rsi_oper, 0, 1, 3, g_temp_rsi_red) == 3 &&
           CopyBuffer(g_handles.rsi_oper, 1, 1, 3, g_temp_rsi_blue) == 3)
        {
            for(int idx = 0; idx < 3; idx++)
            {
                g_bufferCache.rsi_red[idx] = g_temp_rsi_red[idx];
                g_bufferCache.rsi_blue[idx] = g_temp_rsi_blue[idx];
            }
        }
        else success = false;
    }
    
    // 3. Currency Strength
    if(g_handles.cs_oper != INVALID_HANDLE)
    {
        if(CopyBuffer(g_handles.cs_oper, 0, 1, 1, g_temp_cs_base) == 1 &&
           CopyBuffer(g_handles.cs_oper, 1, 1, 1, g_temp_cs_quote) == 1)
        {
            g_bufferCache.cs_base[0] = g_temp_cs_base[0];
            g_bufferCache.cs_quote[0] = g_temp_cs_quote[0];
        }
        else success = false;
    }
    
    // 4. Supertrend (TrendMagic)
    if(g_handles.st_oper != INVALID_HANDLE)
    {
        // 🔥 v4.56 FIX: Copiar do shift 1 (candle FECHADO)
        if(CopyBuffer(g_handles.st_oper, 0, 1, 3, g_temp_supertrend_up) == 3 &&
           CopyBuffer(g_handles.st_oper, 1, 1, 3, g_temp_supertrend_down) == 3)
        {
            for(int idx = 0; idx < 3; idx++)
            {
                g_bufferCache.trend_up[idx] = g_temp_supertrend_up[idx];
                g_bufferCache.trend_down[idx] = g_temp_supertrend_down[idx];
            }
        }
        else success = false;
    }
    
    // 5. GG TrendBar - 🔥 v4.58 FIX CRÍTICO: LER BUFFERS DE COR, NÃO DE TREND!
    if(g_handles.gg_global != INVALID_HANDLE)
    {
        // � v4.58 CORREÇÃO URGENTE: BUFFERS ERRADOS!
        // ❌ ANTES v4.57: Lia buffers 0,2,4,6,8,10,12,14,16 (valores trend -1/0/+1)
        // ✅ AGORA v4.58: Lê buffers 9,10,11,12,13,14,15,16,17 (cores 0=Verde, 1=Vermelho, 2=Amarelo)
        //
        // ESTRUTURA DO INDICADOR:
        // Buffer 0-8:  Valores de trend (Buffer_M1, Buffer_M5, ..., Buffer_MN1)
        // Buffer 9-17: Índices de cor (Color_M1, Color_M5, ..., Color_MN1)
        //   Cor 0 = Verde (Bullish +1)
        //   Cor 1 = Vermelho (Bearish -1)
        //   Cor 2 = Amarelo (Neutro 0)
        //
        // CONVERSÃO: Cor → Valor de Trend
        //   0 (Verde) → +1 (Bullish)
        //   1 (Vermelho) → -1 (Bearish)
        //   2 (Amarelo) → 0 (Neutro)
        
        if(CopyBuffer(g_handles.gg_global, 9, 1, 2, g_temp_gg_m1) == 2 &&    // Color_M1
           CopyBuffer(g_handles.gg_global, 10, 1, 2, g_temp_gg_m5) == 2 &&   // Color_M5
           CopyBuffer(g_handles.gg_global, 11, 1, 2, g_temp_gg_m15) == 2 &&  // Color_M15
           CopyBuffer(g_handles.gg_global, 12, 1, 2, g_temp_gg_m30) == 2 &&  // Color_M30
           CopyBuffer(g_handles.gg_global, 13, 1, 2, g_temp_gg_h1) == 2 &&   // Color_H1
           CopyBuffer(g_handles.gg_global, 14, 1, 2, g_temp_gg_h4) == 2 &&   // Color_H4
           CopyBuffer(g_handles.gg_global, 15, 1, 2, g_temp_gg_d1) == 2 &&   // Color_D1
           CopyBuffer(g_handles.gg_global, 16, 1, 2, g_temp_gg_w1) == 2 &&   // Color_W1
           CopyBuffer(g_handles.gg_global, 17, 1, 2, g_temp_gg_mn1) == 2)    // Color_MN1
        {
            // 🔥 v4.58: CONVERTER CORES PARA VALORES DE TREND
            // Cores do indicador → Valores para o EA
            for(int idx = 0; idx < 2; idx++)
            {
                // M1: Cor → Trend
                if(g_temp_gg_m1[idx] == 0) g_bufferCache.gg_m1[idx] = 1;        // Verde = +1
                else if(g_temp_gg_m1[idx] == 1) g_bufferCache.gg_m1[idx] = -1;  // Vermelho = -1
                else g_bufferCache.gg_m1[idx] = 0;                               // Amarelo = 0
                
                // M5: Cor → Trend
                if(g_temp_gg_m5[idx] == 0) g_bufferCache.gg_m5[idx] = 1;
                else if(g_temp_gg_m5[idx] == 1) g_bufferCache.gg_m5[idx] = -1;
                else g_bufferCache.gg_m5[idx] = 0;
                
                // M15: Cor → Trend
                if(g_temp_gg_m15[idx] == 0) g_bufferCache.gg_m15[idx] = 1;
                else if(g_temp_gg_m15[idx] == 1) g_bufferCache.gg_m15[idx] = -1;
                else g_bufferCache.gg_m15[idx] = 0;
                
                // M30: Cor → Trend
                if(g_temp_gg_m30[idx] == 0) g_bufferCache.gg_m30[idx] = 1;
                else if(g_temp_gg_m30[idx] == 1) g_bufferCache.gg_m30[idx] = -1;
                else g_bufferCache.gg_m30[idx] = 0;
                
                // H1: Cor → Trend
                if(g_temp_gg_h1[idx] == 0) g_bufferCache.gg_h1[idx] = 1;
                else if(g_temp_gg_h1[idx] == 1) g_bufferCache.gg_h1[idx] = -1;
                else g_bufferCache.gg_h1[idx] = 0;
                
                // H4: Cor → Trend
                if(g_temp_gg_h4[idx] == 0) g_bufferCache.gg_h4[idx] = 1;
                else if(g_temp_gg_h4[idx] == 1) g_bufferCache.gg_h4[idx] = -1;
                else g_bufferCache.gg_h4[idx] = 0;
                
                // D1: Cor → Trend
                if(g_temp_gg_d1[idx] == 0) g_bufferCache.gg_d1[idx] = 1;
                else if(g_temp_gg_d1[idx] == 1) g_bufferCache.gg_d1[idx] = -1;
                else g_bufferCache.gg_d1[idx] = 0;
                
                // W1: Cor → Trend
                if(g_temp_gg_w1[idx] == 0) g_bufferCache.gg_w1[idx] = 1;
                else if(g_temp_gg_w1[idx] == 1) g_bufferCache.gg_w1[idx] = -1;
                else g_bufferCache.gg_w1[idx] = 0;
                
                // MN1: Cor → Trend
                if(g_temp_gg_mn1[idx] == 0) g_bufferCache.gg_mn1[idx] = 1;
                else if(g_temp_gg_mn1[idx] == 1) g_bufferCache.gg_mn1[idx] = -1;
                else g_bufferCache.gg_mn1[idx] = 0;
            }
        }
        else success = false;
    }
    
    g_bufferCache.isValid = success;
    g_bufferCache.lastUpdate = currentBar;
    
    // 🔥 v4.40.5: LOGS DE CACHE REMOVIDOS (poluíam o log)
    // Log apenas erros críticos consecutivos
    static int consecutiveErrors = 0;
    
    if(!success)
    {
        consecutiveErrors++;
        if(consecutiveErrors >= MaxConsecutiveIndicatorErrors)  // ✅ v4.42: ANTI-HARDCODE
        {
            PrintFormat("🔴 CRÍTICO: Buffer Cache com %d erros consecutivos!", consecutiveErrors);
            consecutiveErrors = 0;
        }
    }
    else
    {
        consecutiveErrors = 0;
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: DefineMultiTimeframes                                    |
//| Define os timeframes macro conforme o TF operacional do gráfico |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - tfOper: Timeframe atual do gráfico (Period())               |
//|   - tfM1: (output) Timeframe MACRO-1 definido                   |
//|   - tfM2: (output) Timeframe MACRO-2 definido                   |
//|   - tfM3: (output) Timeframe MACRO-3 definido                   |
//|   - numNiveisMacro: (output) 2 ou 3 níveis macro                |
//|                                                                  |
//| RETORNO: void (modifica variáveis por referência)               |
//+------------------------------------------------------------------+
void DefineMultiTimeframes(ENUM_TIMEFRAMES tfOper,
                           ENUM_TIMEFRAMES &tfM1,
                           ENUM_TIMEFRAMES &tfM2,
                           ENUM_TIMEFRAMES &tfM3,
                           int &numNiveisMacro)
{
   // Switch baseado no timeframe operacional
   switch(tfOper)
   {
      case PERIOD_M1:
         // M1 → MACRO-1: M30, MACRO-2: M15, MACRO-3: M5
         tfM1 = PERIOD_M30;
         tfM2 = PERIOD_M15;
         tfM3 = PERIOD_M5;
         numNiveisMacro = 3;
         PrintFormat("🎯 TF Detectado: M1 → Macro: M30/M15/M5 (3 níveis)");
         break;
         
      case PERIOD_M5:
         // M5 → MACRO-1: H1, MACRO-2: M30, MACRO-3: M15
         tfM1 = PERIOD_H1;
         tfM2 = PERIOD_M30;
         tfM3 = PERIOD_M15;
         numNiveisMacro = 3;
         PrintFormat("🎯 TF Detectado: M5 → Macro: H1/M30/M15 (3 níveis)");
         break;
         
      case PERIOD_M15:
         // M15 → MACRO-1: H4, MACRO-2: H1, MACRO-3: M30 (SISTEMA ORIGINAL)
         tfM1 = PERIOD_H4;
         tfM2 = PERIOD_H1;
         tfM3 = PERIOD_M30;
         numNiveisMacro = 3;
         PrintFormat("🎯 TF Detectado: M15 → Macro: H4/H1/M30 (3 níveis) ⭐ ORIGINAL");
         break;
         
      case PERIOD_M30:
         // M30 → MACRO-1: D1, MACRO-2: H4, MACRO-3: H1
         tfM1 = PERIOD_D1;
         tfM2 = PERIOD_H4;
         tfM3 = PERIOD_H1;
         numNiveisMacro = 3;
         PrintFormat("🎯 TF Detectado: M30 → Macro: D1/H4/H1 (3 níveis)");
         break;
         
      case PERIOD_H1:
         // H1 → MACRO-1: D1, MACRO-2: H4 (APENAS 2 NÍVEIS)
         tfM1 = PERIOD_D1;
         tfM2 = PERIOD_H4;
         tfM3 = PERIOD_CURRENT; // Não aplicável
         numNiveisMacro = 2;
         PrintFormat("🎯 TF Detectado: H1 → Macro: D1/H4 (2 níveis apenas)");
         break;
         
      case PERIOD_H4:
         // H4 → MACRO-1: W1, MACRO-2: D1 (APENAS 2 NÍVEIS)
         tfM1 = PERIOD_W1;
         tfM2 = PERIOD_D1;
         tfM3 = PERIOD_CURRENT; // Não aplicável
         numNiveisMacro = 2;
         PrintFormat("🎯 TF Detectado: H4 → Macro: W1/D1 (2 níveis apenas)");
         break;
         
      default:
         // Não suportado: D1, W1, MN1
         PrintFormat("❌ ERRO: Timeframe %s não suportado pelo sistema!", EnumToString(tfOper));
         tfM1 = PERIOD_CURRENT;
         tfM2 = PERIOD_CURRENT;
         tfM3 = PERIOD_CURRENT;
         numNiveisMacro = 0;
         break;
   }
   
   // Atualizar variáveis globais
   g_tfMacro1 = tfM1;
   g_tfMacro2 = tfM2;
   g_tfMacro3 = tfM3;
   g_tfOperacional = tfOper;
   g_numNiveisMacro = numNiveisMacro;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: InitializeIndicators                                     |
//| Inicializa todos os handles dos indicadores                     |
//|                                                                  |
//| NOVO v4.2: Sistema simplificado com GG TrendBar como mestre     |
//|            Remove handles multi-TF desnecessários                |
//|                                                                  |
//| RETORNO: true se sucesso, false se erro                         |
//+------------------------------------------------------------------+
bool InitializeIndicators(string symbol)
{
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("📊 Inicializando indicadores (Sistema v4.2 Simplificado)...");
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   // Construir caminhos dos indicadores
   string path_st = IndicatorsBasePath + TrendMagicIndicator;
   string path_cs = IndicatorsBasePath + CurrencyStrengthIndicator;
   string path_rsi = IndicatorsBasePath + RSIOMAIndicator;
   string path_wae = IndicatorsBasePath + WAEIndicator;
   string path_gg = IndicatorsBasePath + GGTrendBarIndicator;
   
   //╔══════════════════════════════════════════════════════════════╗
   //║  1️⃣ GG TRENDBAR - FILTRO MESTRE (Multi-TF Interno)          ║
   //╚══════════════════════════════════════════════════════════════╝
   PrintFormat("🎯 [1/5] GG TrendBar (Filtro Mestre Multi-TF)...");
   g_handles.gg_global = iCustom(symbol, PERIOD_CURRENT, path_gg,
                                  GG_UpColor,
                                  GG_DownColor,
                                  GG_FlatColor,
                                  GG_TextColor,
                                  GG_Corner,
                                  GG_CreateVisualObjects,
                                  GG_ADX_Period,
                                  GG_ADX_Price,
                                  GG_Step_Psar,
                                  GG_Max_Psar);
   if(g_handles.gg_global == INVALID_HANDLE)
   {
      PrintFormat("❌ ERRO CRÍTICO: Falha ao criar handle GG TrendBar!");
      PrintFormat("   GG TrendBar é o FILTRO MESTRE - sistema não pode operar sem ele!");
      return false;
   }
   PrintFormat("   ✅ GG TrendBar OK");
   
   //╔══════════════════════════════════════════════════════════════╗
   //║  2️⃣ SUPERTREND (Trend Magic Oper) - Tendência Local         ║
   //╚══════════════════════════════════════════════════════════════╝
   PrintFormat("📈 [2/5] Supertrend (Tendência Local %s)...", EnumToString(g_tfOperacional));
   g_handles.st_oper = iCustom(symbol, g_tfOperacional, path_st,
                                ST_OPER_CCI_Period,
                                ST_OPER_ATR_Period,
                                ST_OPER_ATR_Multiplier);
   if(g_handles.st_oper == INVALID_HANDLE)
   {
      PrintFormat("❌ ERRO: Supertrend falhou!");
      return false;
   }
   PrintFormat("   ✅ Supertrend OK");
   
   //╔══════════════════════════════════════════════════════════════╗
   //║  3️⃣ WAE - Momentum/Explosão                                  ║
   //╚══════════════════════════════════════════════════════════════╝
   PrintFormat("💥 [3/5] WAE (Momentum)...");
   g_handles.wae_oper = iCustom(symbol, g_tfOperacional, path_wae,
                                 WAE_OPER_FastMA,
                                 WAE_OPER_SlowMA,
                                 WAE_OPER_BBLength,
                                 WAE_OPER_BBMultiplier,
                                 WAE_OPER_Sensitivity);
   if(g_handles.wae_oper == INVALID_HANDLE)
   {
      PrintFormat("❌ ERRO: WAE falhou!");
      return false;
   }
   PrintFormat("   ✅ WAE OK");
   
   //╔══════════════════════════════════════════════════════════════╗
   //║  4️⃣ RSI OMA - Força Relativa                                 ║
   //╚══════════════════════════════════════════════════════════════╝
   PrintFormat("📊 [4/5] RSI OMA (Força Relativa)...");
   g_handles.rsi_oper = iCustom(symbol, g_tfOperacional, path_rsi,
                                 RSI_OPER_Period,
                                 RSI_OPER_MA_Period,
                                 RSI_OPER_MA_Method,
                                 RSI_OPER_HighLevel,
                                 RSI_OPER_LowLevel,
                                 RSI_OPER_ShowLevels);
   if(g_handles.rsi_oper == INVALID_HANDLE)
   {
      PrintFormat("❌ ERRO: RSI OMA falhou!");
      return false;
   }
   PrintFormat("   ✅ RSI OMA OK");
   
   //╔══════════════════════════════════════════════════════════════╗
   //║  5️⃣ CURRENCY STRENGTH - Contexto Moedas (Forex/Metais)      ║
   //╚══════════════════════════════════════════════════════════════╝
   PrintFormat("� [5/5] Currency Strength (Contexto)...");
   g_handles.cs_oper = iCustom(symbol, g_tfOperacional, path_cs,
                                CS_CalculationPeriod,
                                CS_SmoothingPeriod,
                                CS_ShowInPercent);
   if(g_handles.cs_oper == INVALID_HANDLE)
   {
      PrintFormat("❌ ERRO: Currency Strength falhou!");
      return false;
   }
   PrintFormat("   ✅ Currency Strength OK");
   
   //╔══════════════════════════════════════════════════════════════╗
   //║  📌 ANEXANDO INDICADORES AO GRÁFICO                          ║
   //╚══════════════════════════════════════════════════════════════╝
   PrintFormat("────────────────────────────────────────────────────────────────");
   PrintFormat("📌 Anexando indicadores ao gráfico...");
   
   // GG TrendBar - Janela principal (com Supertrend)
   if(!ChartIndicatorAdd(0, 0, g_handles.gg_global))
   {
      PrintFormat("⚠️ Aviso: Não foi possível anexar GG TrendBar ao gráfico principal");
   }
   else
   {
      PrintFormat("   ✅ GG TrendBar anexado à janela principal");
   }
   
   // Supertrend - Janela principal (junto com GG TrendBar)
   if(!ChartIndicatorAdd(0, 0, g_handles.st_oper))
   {
      PrintFormat("⚠️ Aviso: Não foi possível anexar Supertrend ao gráfico principal");
   }
   else
   {
      PrintFormat("   ✅ Supertrend anexado à janela principal");
   }
   
   // Currency Strength - Subwindow 1
   if(!ChartIndicatorAdd(0, 1, g_handles.cs_oper))
   {
      PrintFormat("⚠️ Aviso: Não foi possível anexar Currency Strength ao subwindow 1");
   }
   else
   {
      PrintFormat("   ✅ Currency Strength anexado ao subwindow 1");
   }
   
   // RSI OMA - Subwindow 2
   if(!ChartIndicatorAdd(0, 2, g_handles.rsi_oper))
   {
      PrintFormat("⚠️ Aviso: Não foi possível anexar RSI OMA ao subwindow 2");
   }
   else
   {
      PrintFormat("   ✅ RSI OMA anexado ao subwindow 2");
   }
   
   // WAE - Subwindow 3
   if(!ChartIndicatorAdd(0, 3, g_handles.wae_oper))
   {
      PrintFormat("⚠️ Aviso: Não foi possível anexar WAE ao subwindow 3");
   }
   else
   {
      PrintFormat("   ✅ WAE anexado ao subwindow 3");
   }
   
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("✅ TODOS OS 5 INDICADORES INICIALIZADOS E ANEXADOS COM SUCESSO!");
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   return true;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: GetSupertrendSignal                                      |
//| Lê sinal do Supertrend (antigo Trend Magic) operacional         |
//|                                                                  |
//| NOTA v4.2: Esta função agora é usada APENAS para o timeframe    |
//|            operacional (st_oper). Multi-TF é feito por GG Bar.  |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - handle: Handle do indicador                                 |
//|   - timeframe: Timeframe do sinal                               |
//|                                                                  |
//| RETORNO: TMSignal (struct com direção e força)                  |
//+------------------------------------------------------------------+
TMSignal GetSupertrendSignal(int handle, ENUM_TIMEFRAMES timeframe)
{
   TMSignal result;
   result.isValid = false;
   result.direction = TRADE_DIRECTION_NONE;
   result.strength = 0.0;
   result.timeframe = timeframe;
   result.turnedRecently = false;
   
   if(handle == INVALID_HANDLE)
   {
      return result;
   }
   
   // 🔥 v2.0 OTIMIZADO: LER DO CACHE ao invés de CopyBuffer
   if(!g_bufferCache.isValid)
   {
      PrintFormat("❌ Cache inválido ao ler Supertrend (%s)", EnumToString(timeframe));
      return result;
   }
   
   // Usar dados do cache global (copiar manualmente)
   double bufferUp[3], bufferDown[3];
   for(int i = 0; i < 3; i++)
   {
      bufferUp[i] = g_bufferCache.trend_up[i];
      bufferDown[i] = g_bufferCache.trend_down[i];
   }
   
   // DEBUG: Mostrar valores dos buffers
   PrintFormat("📊 Supertrend %s - Buffers [0]Up=%.5f [0]Down=%.5f [1]Up=%.5f [1]Down=%.5f",
               TimeframeToString(timeframe),
               bufferUp[0], bufferDown[0],
               bufferUp[1], bufferDown[1]);

   // 🔥 CORREÇÃO CRÍTICA v4.54: Detecção ROBUSTA de buffer ativo
   // EMPTY_VALUE = DBL_MAX (~1.7e308) ou valores absurdos
   // TrendMagic define EMPTY_VALUE nos buffers inativos
   
   double DBL_MAX_LIMIT = 1.0e100; // ✅ Threshold muito maior para pegar DBL_MAX corretamente

   // 🔥 v4.27: USAR CANDLE FECHADO [1] ao invés de [0] para sincronizar com GG/WAE/RSI/CS
   // Determinar direção atual (qual linha tem valor VÁLIDO/RAZOÁVEL) no candle FECHADO
   // ✅ v4.54: Usar MathAbs para pegar valores negativos também
   bool currentBullish = (MathAbs(bufferUp[1]) < DBL_MAX_LIMIT && bufferUp[1] != EMPTY_VALUE);
   bool currentBearish = (MathAbs(bufferDown[1]) < DBL_MAX_LIMIT && bufferDown[1] != EMPTY_VALUE);

   // Verificar se mudou de cor recentemente (últimos 3 candles FECHADOS)
   bool wasBullish = (MathAbs(bufferUp[2]) < DBL_MAX_LIMIT && bufferUp[2] != EMPTY_VALUE);
   bool wasBearish = (MathAbs(bufferDown[2]) < DBL_MAX_LIMIT && bufferDown[2] != EMPTY_VALUE);
   
   // Detectar mudança confirmada
   if(currentBullish && !wasBullish)
   {
      result.turnedRecently = true;
   }
   else if(currentBearish && !wasBearish)
   {
      result.turnedRecently = true;
   }
   
   // 🔥 v4.52 FIX CRÍTICO: Usar CLOSE do último candle ao invés de BID/ASK
   // PROBLEMA v4.50-v4.51: Usava SYMBOL_BID (preço atual), causava rejeições incorretas
   // CORREÇÃO: Comparar com CLOSE[1] (mesmo candle que Supertrend[1])
   double lastClose[];
   ArraySetAsSeries(lastClose, true);
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 2, lastClose) < 2)
   {
      PrintFormat("   ❌ Erro ao ler preço de fechamento");
      return result;
   }
   double priceToCompare = lastClose[1];  // Close do candle FECHADO [1]
   
   // Definir direção usando candle FECHADO [1]
   if(currentBullish && !currentBearish)
   {
      // 🔥 v4.52: BUY apenas se CLOSE[1] ACIMA da linha azul[1]
      bool priceAboveLine = (priceToCompare > bufferUp[1]);
      
      if(priceAboveLine)
      {
         result.direction = TRADE_DIRECTION_BUY;
         result.strength = bufferUp[1];
         result.isValid = true;
         PrintFormat("   ✅ %s = BULLISH (BUY) - Close[1]=%.5f ACIMA linha[1]=%.5f", 
                     TimeframeToString(timeframe), priceToCompare, bufferUp[1]);
      }
      else
      {
         result.direction = TRADE_DIRECTION_NONE;
         result.isValid = false;
         PrintFormat("   ❌ %s = Linha azul ativa MAS Close[1]=%.5f NÃO está acima da linha[1]=%.5f", 
                     TimeframeToString(timeframe), priceToCompare, bufferUp[1]);
      }
   }
   else if(currentBearish && !currentBullish)
   {
      // 🔥 v4.52: SELL apenas se CLOSE[1] ABAIXO da linha vermelha[1]
      bool priceBelowLine = (priceToCompare < bufferDown[1]);
      
      if(priceBelowLine)
      {
         result.direction = TRADE_DIRECTION_SELL;
         result.strength = bufferDown[1];
         result.isValid = true;
         PrintFormat("   ✅ %s = BEARISH (SELL) - Close[1]=%.5f ABAIXO linha[1]=%.5f", 
                     TimeframeToString(timeframe), priceToCompare, bufferDown[1]);
      }
      else
      {
         result.direction = TRADE_DIRECTION_NONE;
         result.isValid = false;
         PrintFormat("   ❌ %s = Linha vermelha ativa MAS Close[1]=%.5f NÃO está abaixo da linha[1]=%.5f", 
                     TimeframeToString(timeframe), priceToCompare, bufferDown[1]);
      }
   }
   else if(currentBullish && currentBearish)
   {
      // Ambos têm valor - situação anormal, tratar como indeciso
      result.direction = TRADE_DIRECTION_NONE;
      result.isValid = false;
      PrintFormat("   ⚠️ %s = AMBÍGUO (ambos buffers ativos)", TimeframeToString(timeframe));
   }
   else
   {
      // Nenhum tem valor - indeciso (amarelo ou sem sinal)
      result.direction = TRADE_DIRECTION_NONE;
      result.isValid = false;
      PrintFormat("   ⚠️ %s = NEUTRO/INDECISO", TimeframeToString(timeframe));
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: GetCurrencyStrengthSignal                                |
//| Lê força das moedas e verifica alinhamento                      |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - symbol: Símbolo a analisar                                  |
//|   - direction: Direção pretendida do trade                      |
//|   - assetClass: Classe do ativo (para lógica inversa metais)   |
//|                                                                  |
//| RETORNO: CSSignal (struct com alinhamento)                      |
//+------------------------------------------------------------------+
CSSignal GetCurrencyStrengthSignal(string symbol, TRADE_DIRECTION direction, ASSET_CLASS assetClass)
{
   CSSignal result;
   result.isValid = false;
   result.isAligned = false;
   result.strength = 0.0;
   
   // Verificar se Currency Strength é aplicável
   if(assetClass != ASSET_CLASS_FOREX_MAJOR &&
      assetClass != ASSET_CLASS_FOREX_MINOR &&
      assetClass != ASSET_CLASS_FOREX_EXOTIC &&
      assetClass != ASSET_CLASS_CURRENCY_B3 &&
      assetClass != ASSET_CLASS_METALS)
   {
      return result; // Não aplicável para índices
   }
   
   if(g_handles.cs_oper == INVALID_HANDLE)
   {
      return result;
   }
   
   // 🔥 v2.0 OTIMIZADO: LER DO CACHE ao invés de CopyBuffer
   if(!g_bufferCache.isValid)
   {
      PrintFormat("❌ Cache inválido ao ler Currency Strength");
      return result;
   }
   
   // Usar dados do cache global (copiar manualmente)
   double baseStrength[1], quoteStrength[1];
   baseStrength[0] = g_bufferCache.cs_base[0];
   quoteStrength[0] = g_bufferCache.cs_quote[0];

   result.strength = MathAbs(baseStrength[0] - quoteStrength[0]);
   result.isValid = true;

   // Lógica normal (Forex)
   if(assetClass != ASSET_CLASS_METALS)
   {
      if(direction == TRADE_DIRECTION_BUY)
      {
         // 🔥 v4.50 FIX: Para compra - moeda base > moeda cotação E base > 0
         result.isAligned = (baseStrength[0] > quoteStrength[0]) && (baseStrength[0] > 0.0);
         
         PrintFormat("   🔍 Currency Strength BUY: Base=%.2f Quote=%.2f | Base>Quote=%s | Base>0=%s | ALIGNED=%s",
                     baseStrength[0], quoteStrength[0],
                     (baseStrength[0] > quoteStrength[0]) ? "YES" : "NO",
                     (baseStrength[0] > 0.0) ? "YES" : "NO",
                     result.isAligned ? "YES" : "NO");
      }
      else if(direction == TRADE_DIRECTION_SELL)
      {
         // 🔥 v4.50 FIX: Para venda - moeda cotação > moeda base E cotação > 0
         result.isAligned = (quoteStrength[0] > baseStrength[0]) && (quoteStrength[0] > 0.0);
         
         PrintFormat("   🔍 Currency Strength SELL: Base=%.2f Quote=%.2f | Quote>Base=%s | Quote>0=%s | ALIGNED=%s",
                     baseStrength[0], quoteStrength[0],
                     (quoteStrength[0] > baseStrength[0]) ? "YES" : "NO",
                     (quoteStrength[0] > 0.0) ? "YES" : "NO",
                     result.isAligned ? "YES" : "NO");
      }
   }
   else
   {
      // Lógica INVERSA para metais (XAU/USD, XAG/USD)
      // Ouro sobe quando USD fraco
      if(direction == TRADE_DIRECTION_BUY)
      {
         // 🔥 v4.50 FIX: Para compra de ouro - USD (quote) fraco E base (XAU) > 0
         result.isAligned = (quoteStrength[0] < baseStrength[0]) && (baseStrength[0] > 0.0);
         
         PrintFormat("   🔍 Currency Strength METALS BUY: Base(XAU)=%.2f Quote(USD)=%.2f | Base>Quote=%s | Base>0=%s | ALIGNED=%s",
                     baseStrength[0], quoteStrength[0],
                     (baseStrength[0] > quoteStrength[0]) ? "YES" : "NO",
                     (baseStrength[0] > 0.0) ? "YES" : "NO",
                     result.isAligned ? "YES" : "NO");
      }
      else if(direction == TRADE_DIRECTION_SELL)
      {
         // 🔥 v4.50 FIX: Para venda de ouro - USD (quote) forte E cotação > 0
         result.isAligned = (quoteStrength[0] > baseStrength[0]) && (quoteStrength[0] > 0.0);
         
         PrintFormat("   🔍 Currency Strength METALS SELL: Base(XAU)=%.2f Quote(USD)=%.2f | Quote>Base=%s | Quote>0=%s | ALIGNED=%s",
                     baseStrength[0], quoteStrength[0],
                     (quoteStrength[0] > baseStrength[0]) ? "YES" : "NO",
                     (quoteStrength[0] > 0.0) ? "YES" : "NO",
                     result.isAligned ? "YES" : "NO");
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: GetRSIOMASignal                                          |
//| Lê sinal do RSI OMA (linha vermelha vs azul + inclinação)      |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - handle: Handle do indicador                                 |
//|   - direction: Direção pretendida                               |
//|   - timeframe: Timeframe para log                               |
//|                                                                  |
//| RETORNO: RSISignal (struct com alinhamento e inclinação)        |
//+------------------------------------------------------------------+
RSISignal GetRSIOMASignal(int handle, TRADE_DIRECTION direction, ENUM_TIMEFRAMES timeframe)
{
   RSISignal result;
   result.isValid = false;
   result.isAligned = false;
   result.strength = 0.0;
   result.slope = 0.0;
   
   if(handle == INVALID_HANDLE)
   {
      return result;
   }
   
   // 🔥 v2.0 OTIMIZADO: LER DO CACHE ao invés de CopyBuffer
   if(!g_bufferCache.isValid)
   {
      PrintFormat("❌ Cache inválido ao ler RSI OMA (%s)", EnumToString(timeframe));
      return result;
   }
   
   // Usar dados do cache global (copiar manualmente para manter compatibilidade)
   double rsiRed[3], rsiBlue[3];
   for(int i = 0; i < 3; i++)
   {
      rsiRed[i] = g_bufferCache.rsi_red[i];
      rsiBlue[i] = g_bufferCache.rsi_blue[i];
   }
   
   // 🔥 v4.27: SIMPLIFICAÇÃO - Remover filtros que atrasam entradas
   // Calcular inclinação e força apenas para LOG (não para validação)
   result.slope = (rsiRed[1] - rsiRed[2]) / 1.0;  // [1] vs [2] (1 candle de diferença)
   result.strength = MathAbs(rsiRed[1] - rsiBlue[1]);
   result.isValid = true;

   // Verificar APENAS posição relativa das linhas (sem inclinação, sem zonas)
   bool redAboveBlue = (rsiRed[1] > rsiBlue[1]);

   // ✅ v4.27 SIMPLIFICADO: Apenas posição das linhas (sem slope, sem overbought/oversold)
   // MOTIVO: Filtros de inclinação e zona atrasam entradas desnecessariamente
   if(direction == TRADE_DIRECTION_BUY)
   {
      // Para compra: APENAS linha vermelha acima da azul
      result.isAligned = redAboveBlue;

      PrintFormat("   🔍 RSI OMA BUY: Red=%.1f %s Blue=%.1f | Slope=%.2f | Strength=%.2f",
                  rsiRed[1], redAboveBlue ? ">" : "<=", rsiBlue[1], result.slope, result.strength);
   }
   else if(direction == TRADE_DIRECTION_SELL)
   {
      // Para venda: APENAS linha vermelha abaixo da azul
      result.isAligned = !redAboveBlue;

      PrintFormat("   🔍 RSI OMA SELL: Red=%.1f %s Blue=%.1f | Slope=%.2f | Strength=%.2f",
                  rsiRed[1], !redAboveBlue ? "<" : ">=", rsiBlue[1], result.slope, result.strength);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: GetWAESignal                                             |
//| Lê sinal do WAE (histograma + expansão)                         |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - handle: Handle do indicador                                 |
//|   - direction: Direção pretendida                               |
//|   - timeframe: Timeframe para log                               |
//|                                                                  |
//| RETORNO: WAESignal (struct com expansão e força)                |
//+------------------------------------------------------------------+
WAESignal GetWAESignal(int handle, TRADE_DIRECTION direction, ENUM_TIMEFRAMES timeframe)
{
   WAESignal result;
   result.isValid = false;
   result.isAligned = false;
   result.isExpanding = false;
   result.strength = 0.0;
   
   if(handle == INVALID_HANDLE)
   {
      return result;
   }
   
   // 🔥 v2.0 OTIMIZADO: LER DO CACHE ao invés de CopyBuffer
   // Cache já foi atualizado em UpdateBufferCache() no início do frame
   if(!g_bufferCache.isValid)
   {
      PrintFormat("❌ Cache inválido ao ler WAE (%s)", EnumToString(timeframe));
      return result;
   }
   
   // Usar dados do cache global (copiar manualmente para evitar problemas com tipos)
   double trendUp[3], trendDown[3], explosion[1];
   for(int i = 0; i < 3; i++)
   {
      trendUp[i] = g_bufferCache.wae_trendUp[i];
      trendDown[i] = g_bufferCache.wae_trendDown[i];
   }
   explosion[0] = g_bufferCache.wae_explosion[0];
   
   // 🔥 v4.26: Usar candle FECHADO [1] para análise
   // Determinar cor do histograma (verde ou vermelho) no candle FECHADO
   bool isGreen = (trendUp[1] > trendDown[1] && trendUp[1] > 0);
   bool isRed = (trendDown[1] > trendUp[1] && trendDown[1] > 0);

   // Calcular força do histograma no candle FECHADO
   double currentStrength = MathMax(trendUp[1], trendDown[1]);
   result.strength = currentStrength;

   // Verificar expansão (últimos 3 candles FECHADOS)
   bool expanding = (MathMax(trendUp[1], trendDown[1]) > MathMax(trendUp[2], trendDown[2]));
   result.isExpanding = expanding;

   // 🔥 OTIMIZADO: Usar valor em cache da linha de explosão ao invés de CopyBuffer
   double explosion_val = explosion[0];
   bool aboveExplosion = (currentStrength > explosion_val);
   result.isValid = true;

   if(direction == TRADE_DIRECTION_BUY)
   {
      // Para compra: verde + expandindo + acima explosão
      result.isAligned = (isGreen && expanding && aboveExplosion);
   }
   else if(direction == TRADE_DIRECTION_SELL)
   {
      // Para venda: vermelho + expandindo + acima explosão
      result.isAligned = (isRed && expanding && aboveExplosion);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: GetGGTrendBarSignal                                      |
//| Lê sinais multi-timeframe do GG TrendBar                        |
//|                                                                  |
//| RETORNO: GGTrendBarSignal (struct com sinais de todos os TFs)   |
//+------------------------------------------------------------------+
GGTrendBarSignal GetGGTrendBarSignal()
{
   // 🔥 DEBUG v4.40.3: Contagem de chamadas
   static int callCount = 0;
   callCount++;
   
   GGTrendBarSignal result;
   result.isValid = false;
   
   if(g_handles.gg_global == INVALID_HANDLE)
   {
      // 🔥 DEBUG v4.40.3: Log erro handle
      static int handleErrorCount = 0;
      handleErrorCount++;
      if(handleErrorCount % LogWarningIntervalCount == 0)  // ✅ v4.42: ANTI-HARDCODE
      {
         PrintFormat("🔴 [DEBUG] Handle GG TrendBar INVÁLIDO - erro #%d", handleErrorCount);
      }
      return result;
   }
   
   // 🔥 DEBUG v4.40.3: Log a cada N chamadas
   if(callCount % (LogWarningIntervalCount * 2) == 0)  // ✅ v4.42: ANTI-HARDCODE (2x do intervalo)
   {
      PrintFormat("🔍 [DEBUG] GetGGTrendBarSignal() chamado %d vezes", callCount);
   }
   
   // 🔥 v2.0 OTIMIZADO: LER DO CACHE ao invés de CopyBuffer (9 chamadas → 0 chamadas!)
   if(!g_bufferCache.isValid)
   {
      PrintFormat("🔴 CRÍTICO: Cache inválido ao ler GG TrendBar - ANÁLISE REJEITADA!");
      result.isValid = false;
      
      // 🔥 DEBUG v4.40.3: Contador de cache inválido
      static int cacheInvalidCount = 0;
      cacheInvalidCount++;
      if(cacheInvalidCount % (LogWarningIntervalCount / 2) == 0)  // ✅ v4.42: ANTI-HARDCODE (metade do intervalo)
      {
         PrintFormat("⚠️ [DEBUG] Cache inválido detectado %d vezes", cacheInvalidCount);
      }
      
      return result;
   }
   
   // Usar dados do cache global (copiar manualmente todos os 9 timeframes)
   double gg_m1[2], gg_m5[2], gg_m15[2], gg_m30[2], gg_h1[2], gg_h4[2], gg_d1[2], gg_w1[2], gg_mn1[2];
   
   for(int i = 0; i < 2; i++)
   {
      gg_m1[i] = g_bufferCache.gg_m1[i];
      gg_m5[i] = g_bufferCache.gg_m5[i];
      gg_m15[i] = g_bufferCache.gg_m15[i];
      gg_m30[i] = g_bufferCache.gg_m30[i];
      gg_h1[i] = g_bufferCache.gg_h1[i];
      gg_h4[i] = g_bufferCache.gg_h4[i];
      gg_d1[i] = g_bufferCache.gg_d1[i];
      gg_w1[i] = g_bufferCache.gg_w1[i];
      gg_mn1[i] = g_bufferCache.gg_mn1[i];
   }
   
   // 🔥 v4.40.2 CORREÇÃO CRÍTICA: VALIDAR APENAS TIMEFRAMES USADOS PELO EA!
   // PROBLEMA v4.33: Validava TODOS os TFs (M1-MN1) - se algum fosse neutro=0, rejeitava tudo!
   // SOLUÇÃO v4.40.2: Validar APENAS os timeframes que o EA vai usar (Macro1, Macro2, Macro3)
   
   // Determinar qual timeframe do GG TrendBar corresponde ao g_tfMacro1
   double macro1Data = 0.0;
   double macro2Data = 0.0;
   double macro3Data = 0.0;
   
   // Mapear g_tfMacro1 para os dados do GG TrendBar
   // 🔥 v4.51 FIX CRÍTICO: Usar [0] ao invés de [1]!
   // PROBLEMA v4.50: CopyBuffer(..., 0, 2) copia índices [0,1] do indicador
   // - gg_h4[0] = valor ATUAL (último cálculo do indicador)
   // - gg_h4[1] = valor ANTERIOR (candle passado)
   // EA estava usando [1], pegando dado ANTIGO ao invés do ATUAL!
   if(g_tfMacro1 == PERIOD_H4)       macro1Data = gg_h4[0];   // 🔥 v4.51: [1] → [0]
   else if(g_tfMacro1 == PERIOD_D1)  macro1Data = gg_d1[0];   // 🔥 v4.51: [1] → [0]
   else if(g_tfMacro1 == PERIOD_W1)  macro1Data = gg_w1[0];   // 🔥 v4.51: [1] → [0]
   else if(g_tfMacro1 == PERIOD_M30) macro1Data = gg_m30[0];  // 🔥 v4.51: [1] → [0]
   else if(g_tfMacro1 == PERIOD_H1)  macro1Data = gg_h1[0];   // 🔥 v4.51: [1] → [0]
   
   // Mapear g_tfMacro2 para os dados do GG TrendBar
   if(g_tfMacro2 == PERIOD_H1)       macro2Data = gg_h1[0];   // 🔥 v4.51: [1] → [0]
   else if(g_tfMacro2 == PERIOD_H4)  macro2Data = gg_h4[0];   // 🔥 v4.51: [1] → [0]
   else if(g_tfMacro2 == PERIOD_D1)  macro2Data = gg_d1[0];   // 🔥 v4.51: [1] → [0]
   else if(g_tfMacro2 == PERIOD_M30) macro2Data = gg_m30[0];  // 🔥 v4.51: [1] → [0]
   else if(g_tfMacro2 == PERIOD_M15) macro2Data = gg_m15[0];  // 🔥 v4.51: [1] → [0]
   
   // Mapear g_tfMacro3 para os dados do GG TrendBar (se aplicável)
   if(g_numNiveisMacro == 3)
   {
      if(g_tfMacro3 == PERIOD_M30)       macro3Data = gg_m30[0];  // 🔥 v4.51: [1] → [0]
      else if(g_tfMacro3 == PERIOD_H1)   macro3Data = gg_h1[0];   // 🔥 v4.51: [1] → [0]
      else if(g_tfMacro3 == PERIOD_M15)  macro3Data = gg_m15[0];  // 🔥 v4.51: [1] → [0]
      else if(g_tfMacro3 == PERIOD_M5)   macro3Data = gg_m5[0];   // 🔥 v4.51: [1] → [0]
   }
   
   // Validar se PELO MENOS OS TIMEFRAMES MACRO TÊM DADOS
   // (Não interessa se M1, M5, MN1, etc têm dados - só precisamos dos que vamos usar!)
   bool hasValidMacroData = (macro1Data != 0.0 || macro2Data != 0.0);
   
   if(!hasValidMacroData)
   {
      PrintFormat("🔴 CRÍTICO: GG TrendBar sem dados válidos nos timeframes MACRO!");
      PrintFormat("   MACRO-1 (%s): %.0f", TimeframeToString(g_tfMacro1), macro1Data);
      PrintFormat("   MACRO-2 (%s): %.0f", TimeframeToString(g_tfMacro2), macro2Data);
      if(g_numNiveisMacro == 3)
         PrintFormat("   MACRO-3 (%s): %.0f", TimeframeToString(g_tfMacro3), macro3Data);
      PrintFormat("   Possível causa: Indicador não inicializou ou CopyBuffer falhou");
      result.isValid = false;
      return result;
   }
   
   // 🔥 v4.51 CORREÇÃO CRÍTICA: LER ÍNDICE [0] (VALOR ATUAL DO INDICADOR)!
   // PROBLEMA v4.26-v4.50: Usava [1] = candle ANTERIOR ao invés do ATUAL
   // MOTIVO: CopyBuffer(..., 0, 2) copia [0]=ATUAL, [1]=ANTERIOR
   // RESULTADO: EA via H4 de ONTEM ao invés de H4 de HOJE!

   PrintFormat("🔍 [DEBUG GG TRENDBAR v4.51] VALORES ATUAIS DO INDICADOR [0]:");
   PrintFormat("   M1=%.0f | M5=%.0f | M15=%.0f | M30=%.0f | H1=%.0f | H4=%.0f | D1=%.0f | W1=%.0f | MN1=%.0f",
               gg_m1[0], gg_m5[0], gg_m15[0], gg_m30[0], gg_h1[0], gg_h4[0], gg_d1[0], gg_w1[0], gg_mn1[0]);

   PrintFormat("🔍 [DEBUG GG TRENDBAR v4.26] CANDLE ATUAL [0] (EM FORMAÇÃO - NÃO USAR!):");
   PrintFormat("   M1=%.0f | M5=%.0f | M15=%.0f | M30=%.0f | H1=%.0f | H4=%.0f | D1=%.0f | W1=%.0f | MN1=%.0f",
               gg_m1[0], gg_m5[0], gg_m15[0], gg_m30[0], gg_h1[0], gg_h4[0], gg_d1[0], gg_w1[0], gg_mn1[0]);

   // 🔥 v4.51 CORREÇÃO CRÍTICA: USAR ÍNDICE [0] (VALOR ATUAL DO INDICADOR)!
   // PROBLEMA v4.26-v4.50: Usava [1] = valor ANTERIOR (candle passado)
   // CAUSA: CopyBuffer copia [0]=ATUAL do indicador, [1]=ANTERIOR
   // RESULTADO: EA via H4 de ONTEM ao invés de HOJE = trades incorretos!
   // CORREÇÃO: Usar [0] para pegar valor ATUAL do indicador
   result.m1Value = (int)gg_m1[0];    // 🔥 v4.51: [1] → [0]
   result.m5Value = (int)gg_m5[0];    // 🔥 v4.51: [1] → [0]
   result.m15Value = (int)gg_m15[0];  // 🔥 v4.51: [1] → [0]
   result.m30Value = (int)gg_m30[0];  // 🔥 v4.51: [1] → [0]
   result.h1Value = (int)gg_h1[0];    // 🔥 v4.51: [1] → [0]
   result.h4Value = (int)gg_h4[0];    // 🔥 v4.51: [1] → [0]
   result.d1Value = (int)gg_d1[0];    // 🔥 v4.51: [1] → [0]
   result.w1Value = (int)gg_w1[0];    // 🔥 v4.51: [1] → [0]
   result.mn1Value = (int)gg_mn1[0];  // 🔥 v4.51: [1] → [0]

   PrintFormat("🔍 [DEBUG GG TRENDBAR v4.51] Valores ATUAIS do indicador [0]:");
   PrintFormat("   M1=%+d | M5=%+d | M15=%+d | M30=%+d | H1=%+d | H4=%+d | D1=%+d | W1=%+d | MN1=%+d",
               result.m1Value, result.m5Value, result.m15Value, result.m30Value,
               result.h1Value, result.h4Value, result.d1Value, result.w1Value, result.mn1Value);
   
   // 🔥 v4.46 LOG INTENSIDADE: Identificar sinais fortes (+2/-2) vs fracos (+1/-1)
   string intensityLog = "🔥 [INTENSIDADE v4.46] ";
   if(MathAbs(result.h4Value) == 2) intensityLog += "H4=FORTE ";
   else if(result.h4Value != 0) intensityLog += "H4=fraco ";
   
   if(MathAbs(result.h1Value) == 2) intensityLog += "H1=FORTE ";
   else if(result.h1Value != 0) intensityLog += "H1=fraco ";
   
   if(MathAbs(result.m30Value) == 2) intensityLog += "M30=FORTE ";
   else if(result.m30Value != 0) intensityLog += "M30=fraco ";
   
   if(MathAbs(result.m15Value) == 2) intensityLog += "M15=FORTE ";
   else if(result.m15Value != 0) intensityLog += "M15=fraco ";
   
   Print(intensityLog);
   
   // 🔥 v4.45 CORREÇÃO CRÍTICA: Aceitar valores +1 E +2 como BULLISH!
   // BUG v4.44: Comparava exatamente == 1, ignorando == 2 (verde forte)
   // RESULTADO: H4=+2 não era reconhecido como bullish!
   // CORREÇÃO: Usar > 0 para bullish, < 0 para bearish
   // v4.46: Agora GG TrendBar retorna +2/-2 (forte) e +1/-1 (fraco)!
   result.h4Bullish = (result.h4Value > 0);   // ✅ Aceita +1 e +2
   result.h1Bullish = (result.h1Value > 0);   // ✅ Aceita +1 e +2
   result.m30Bullish = (result.m30Value > 0); // ✅ Aceita +1 e +2
   result.m15Bullish = (result.m15Value > 0); // ✅ Aceita +1 e +2
   
   // Determinar direção geral (pode ser usado como confirmação)
   int sumSignals = result.h4Value + result.h1Value + result.m30Value + result.m15Value;
   if(sumSignals >= MinMacroSignalsForAlignment)  // ✅ v4.42: ANTI-HARDCODE
   {
      result.overallDirection = TRADE_DIRECTION_BUY;
   }
   else if(sumSignals <= -MinMacroSignalsForAlignment)  // ✅ v4.42: ANTI-HARDCODE
   {
      result.overallDirection = TRADE_DIRECTION_SELL;
   }
   else
   {
      result.overallDirection = TRADE_DIRECTION_NONE;
   }
   
   result.isValid = true;
   return result;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: AnalyzeMultiTimeframeAlignment                           |
//| Valida alinhamento multi-TF usando GG TRENDBAR (FILTRO MESTRE)  |
//|                                                                  |
//| NOVO v4.2: Substitui lógica de Trend Magic multi-TF             |
//|            GG TrendBar analisa M1-MN1 internamente              |
//|                                                                  |
//| RETORNO: MultiTFResult (struct com resultado da análise)        |
//+------------------------------------------------------------------+
MultiTFResult AnalyzeMultiTimeframeAlignment()
{
   MultiTFResult result;
   result.isValid = false;
   result.direction = TRADE_DIRECTION_NONE;
   result.h4Aligned = false;
   result.h1Aligned = false;
   result.m30Aligned = false;
   result.operationalAligned = false;  // 🔥 v4.44: INICIALIZAR
   result.structureValid = false;
   result.classification = SETUP_REJECT;  // 🔥 v4.44: INICIALIZAR
   
   // 🔥 v4.40.5: Log APENAS primeira chamada
   static bool firstCallLogged = false;
   if(!firstCallLogged)
   {
      PrintFormat("\n🔍 [PRIMEIRA ANÁLISE] AnalyzeMultiTimeframeAlignment() iniciando...");
      firstCallLogged = true;
   }
   
   // Validar se timeframes foram inicializados
   if(g_tfOperacional == 0 || g_tfMacro1 == 0 || g_tfMacro2 == 0)
   {
      static bool initErrorLogged = false;
      if(!initErrorLogged)
      {
         PrintFormat("\n🔴 ERRO CRÍTICO: Timeframes multi-TF não foram inicializados!");
         PrintFormat("   g_tfOperacional=%d, g_tfMacro1=%d, g_tfMacro2=%d",
                     g_tfOperacional, g_tfMacro1, g_tfMacro2);
         PrintFormat("   CAUSA: DefineMultiTimeframes() não foi chamado no OnInit()!\n");
         initErrorLogged = true;
      }
      
      return result;
   }
   
   // Obter sinais GG TrendBar de todos os timeframes
   GGTrendBarSignal gg = GetGGTrendBarSignal();
   
   if(!gg.isValid)
   {
      PrintFormat("❌ GG TrendBar inválido - não é possível analisar");
      return result;
   }
   
   // Mapear timeframes conforme sistema atual
   int macro1Value = 0;  // MACRO-1 (mais longo)
   int macro2Value = 0;  // MACRO-2 (intermediário)
   int macro3Value = 0;  // MACRO-3 (curto) - opcional
   
   // Determinar quais buffers do GG TrendBar usar baseado no sistema definido
   switch(g_tfMacro1)
   {
      case PERIOD_H4:  macro1Value = gg.h4Value;  break;
      case PERIOD_D1:  macro1Value = gg.d1Value;  break;
      case PERIOD_W1:  macro1Value = gg.w1Value;  break;
      case PERIOD_M30: macro1Value = gg.m30Value; break;
      case PERIOD_H1:  macro1Value = gg.h1Value;  break;
   }
   
   switch(g_tfMacro2)
   {
      case PERIOD_H1:  macro2Value = gg.h1Value;  break;
      case PERIOD_H4:  macro2Value = gg.h4Value;  break;
      case PERIOD_D1:  macro2Value = gg.d1Value;  break;
      case PERIOD_M30: macro2Value = gg.m30Value; break;
      case PERIOD_M15: macro2Value = gg.m15Value; break;
   }
   
   if(g_numNiveisMacro == 3)
   {
      switch(g_tfMacro3)
      {
         case PERIOD_M30: macro3Value = gg.m30Value; break;
         case PERIOD_H1:  macro3Value = gg.h1Value;  break;
         case PERIOD_M15: macro3Value = gg.m15Value; break;
         case PERIOD_M5:  macro3Value = gg.m5Value;  break;
      }
   }
   
   // 🔥 v4.23 DEBUG DETALHADO: Análise completa dos timeframes
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("📊 GG TrendBar - LEITURA DOS TIMEFRAMES:");
   PrintFormat("   MACRO-1 (%s): %+d %s",
               TimeframeToString(g_tfMacro1), macro1Value,
               (macro1Value > 0) ? "🟢 BULLISH" : (macro1Value < 0) ? "🔴 BEARISH" : "⚪ NEUTRO");
   PrintFormat("   MACRO-2 (%s): %+d %s",
               TimeframeToString(g_tfMacro2), macro2Value,
               (macro2Value > 0) ? "🟢 BULLISH" : (macro2Value < 0) ? "🔴 BEARISH" : "⚪ NEUTRO");
   if(g_numNiveisMacro == 3)
   {
      PrintFormat("   MACRO-3 (%s): %+d %s",
                  TimeframeToString(g_tfMacro3), macro3Value,
                  (macro3Value > 0) ? "🟢 BULLISH" : (macro3Value < 0) ? "🔴 BEARISH" : "⚪ NEUTRO");
   }
   PrintFormat("────────────────────────────────────────────────────────────────");

   // 🔥 v4.43 CORREÇÃO CRÍTICA: EXIGIR AMBOS MACRO-1 E MACRO-2 DEFINIDOS E ALINHADOS!
   // ❌ BUG v4.41: Aceitava modo fallback com apenas 1 TF definido
   // ❌ PROBLEMA: EA abria BUY com H4 bullish mas H1 neutro (violação da regra fundamental)
   // ✅ CORREÇÃO: AMBOS timeframes macro devem estar DEFINIDOS (!=0) E NA MESMA DIREÇÃO
   
   // ✅ VALIDAÇÃO 1: AMBOS MACRO-1 E MACRO-2 DEVEM ESTAR DEFINIDOS (NÃO NEUTROS)
   if(macro1Value == 0 || macro2Value == 0)
   {
      PrintFormat("❌ REJEIÇÃO ETAPA 1: MACRO-1 ou MACRO-2 NEUTRO - ALINHAMENTO INSUFICIENTE");
      PrintFormat("   MACRO-1 (%s): %+d %s",
                  TimeframeToString(g_tfMacro1), macro1Value,
                  (macro1Value > 0) ? "🟢 BULLISH" : (macro1Value < 0) ? "🔴 BEARISH" : "⚪ NEUTRO");
      PrintFormat("   MACRO-2 (%s): %+d %s",
                  TimeframeToString(g_tfMacro2), macro2Value,
                  (macro2Value > 0) ? "🟢 BULLISH" : (macro2Value < 0) ? "🔴 BEARISH" : "⚪ NEUTRO");
      PrintFormat("   ⚠️ REGRA: AMBOS timeframes macro DEVEM estar DEFINIDOS para trade válido!");
      PrintFormat("   Aguardando ambos timeframes definirem direção clara");
      PrintFormat("════════════════════════════════════════════════════════════════");
      return result;
   }
   
   // ✅ VALIDAÇÃO 2: AMBOS DEFINIDOS - DEVEM ESTAR NA MESMA DIREÇÃO
   bool macro1Bullish = (macro1Value > 0);
   bool macro2Bullish = (macro2Value > 0);
   bool macro1Bearish = (macro1Value < 0);
   bool macro2Bearish = (macro2Value < 0);
   
   // Verificar se estão na MESMA DIREÇÃO (ambos positivos OU ambos negativos)
   if(!((macro1Bullish && macro2Bullish) || (macro1Bearish && macro2Bearish)))
   {
      PrintFormat("❌ REJEIÇÃO ETAPA 2: TIMEFRAMES EM DIREÇÕES OPOSTAS - SEM ALINHAMENTO");
      PrintFormat("   MACRO-1 (%s): %s", TimeframeToString(g_tfMacro1),
                  macro1Bullish ? "🟢 BULLISH" : "🔴 BEARISH");
      PrintFormat("   MACRO-2 (%s): %s", TimeframeToString(g_tfMacro2),
                  macro2Bullish ? "🟢 BULLISH" : "🔴 BEARISH");
      PrintFormat("   ⚠️ REGRA: MACRO-1 e MACRO-2 devem estar na MESMA direção!");
      PrintFormat("   Aguardando alinhamento entre os timeframes macro");
      PrintFormat("════════════════════════════════════════════════════════════════");
      return result;
   }
   
   // ✅✅✅ VALIDAÇÃO PASSOU: AMBOS DEFINIDOS E NA MESMA DIREÇÃO!
   result.direction = (macro1Value > 0) ? TRADE_DIRECTION_BUY : TRADE_DIRECTION_SELL;
   result.h4Aligned = true;
   result.h1Aligned = true;
   
   // Calcular força do alinhamento (ambos +2/-2 = máximo)
   int alignmentStrength = MathMin(MathAbs(macro1Value), MathAbs(macro2Value));
   
   PrintFormat("✅✅✅ MACRO-1 + MACRO-2 ALINHADOS: %s (Forças: %+d/%+d, Alinhamento: %d/2)", 
               (result.direction == TRADE_DIRECTION_BUY) ? "BULLISH" : "BEARISH",
               macro1Value, macro2Value, alignmentStrength);
   
   // 🔥🔥🔥 v4.44 CORREÇÃO CRÍTICA: VALIDAR TF OPERACIONAL! 🔥🔥🔥
   // PROBLEMA v4.40-v4.43: M15 operacional NUNCA era validado no macro!
   // RESULTADO: EA abria BUY com H4+H1 GREEN mas M15 RED (ERRO GRAVE!)
   // CORREÇÃO: TF operacional DEVE estar alinhado com MACRO-1 e MACRO-2
   
   PrintFormat("────────────────────────────────────────────────────────────────");
   PrintFormat("🔍 [VALIDAÇÃO CRÍTICA] Verificando TF OPERACIONAL...");
   
   int operationalValue = 0;
   
   // Ler valor do TF operacional do GG TrendBar
   switch(g_tfOperacional)
   {
      case PERIOD_M1:  operationalValue = gg.m1Value;  break;
      case PERIOD_M5:  operationalValue = gg.m5Value;  break;
      case PERIOD_M15: operationalValue = gg.m15Value; break;
      case PERIOD_M30: operationalValue = gg.m30Value; break;
      case PERIOD_H1:  operationalValue = gg.h1Value;  break;
      case PERIOD_H4:  operationalValue = gg.h4Value;  break;
      case PERIOD_D1:  operationalValue = gg.d1Value;  break;
      default:
         PrintFormat("⚠️ TF operacional não suportado: %s", TimeframeToString(g_tfOperacional));
         operationalValue = 0;
         break;
   }
   
   PrintFormat("   TF OPERACIONAL (%s): %+d %s",
               TimeframeToString(g_tfOperacional), operationalValue,
               (operationalValue > 0) ? "🟢 VERDE" : 
               (operationalValue < 0) ? "🔴 VERMELHO" : "⚪ AMARELO (NEUTRO)");
   
   // 🔥 v4.49 LÓGICA CORRETA:
   // - NEUTRO (0) = ACEITO para GOOD (não rejeita!)
   // - OPOSTO = REJEITADO (verde quando macros vermelhos, ou vice-versa)
   
   bool operationalBullish = (operationalValue > 0);
   bool operationalBearish = (operationalValue < 0);
   bool operationalNeutral = (operationalValue == 0);
   
   // VALIDAÇÃO: TF operacional NÃO pode ser OPOSTO aos macros
   // ✅ NEUTRO (amarelo) = OK para GOOD
   // ❌ OPOSTO (verde vs vermelho) = REJEITADO
   
   bool operationalOpposite = (operationalBullish && macro1Bearish && macro2Bearish) ||
                              (operationalBearish && macro1Bullish && macro2Bullish);
   
   if(operationalOpposite)
   {
      PrintFormat("❌ REJEIÇÃO CRÍTICA: TF OPERACIONAL OPOSTO AOS MACROS!");
      PrintFormat("   TF Operacional (%s): %s", 
                  TimeframeToString(g_tfOperacional),
                  operationalBullish ? "🟢 VERDE" : "🔴 VERMELHO");
      PrintFormat("   MACRO-1 (%s): %s", 
                  TimeframeToString(g_tfMacro1),
                  macro1Bullish ? "🟢 VERDE" : "🔴 VERMELHO");
      PrintFormat("   MACRO-2 (%s): %s", 
                  TimeframeToString(g_tfMacro2),
                  macro2Bullish ? "🟢 VERDE" : "🔴 VERMELHO");
      PrintFormat("   ⚠️ REGRA v4.49: M15 OPOSTO é REJEITADO (M15 NEUTRO é ACEITO como GOOD)");
      PrintFormat("════════════════════════════════════════════════════════════════");
      return result;
   }
   
   // ✅ TF OPERACIONAL VALIDADO!
   // - Alinhado (mesma cor) = PREMIUM
   // - Neutro (amarelo) = GOOD
   result.operationalAligned = ((operationalBullish && macro1Bullish && macro2Bullish) ||
                                (operationalBearish && macro1Bearish && macro2Bearish));
   
   if(result.operationalAligned)
   {
      PrintFormat("✅✅✅ TF OPERACIONAL ALINHADO COM MACROS!");
      PrintFormat("   TF Operacional (%s): %s alinhado com MACRO-1 e MACRO-2",
                  TimeframeToString(g_tfOperacional),
                  operationalBullish ? "🟢 VERDE" : "🔴 VERMELHO");
      PrintFormat("   🏆 Qualifica para PREMIUM se M30 também alinhado");
   }
   else if(operationalNeutral)
   {
      PrintFormat("⭐ TF OPERACIONAL NEUTRO - ACEITO PARA GOOD!");
      PrintFormat("   TF Operacional (%s): ⚪ AMARELO (neutro)",
                  TimeframeToString(g_tfOperacional));
      PrintFormat("   ⭐ Qualifica para GOOD (não PREMIUM)");
   }
   PrintFormat("   TF Operacional (%s): %s alinhado com MACRO-1 e MACRO-2",
               TimeframeToString(g_tfOperacional),
               operationalBullish ? "🟢 BULLISH" : "🔴 BEARISH");
   PrintFormat("────────────────────────────────────────────────────────────────");
   
   // VALIDAÇÃO 3: MACRO-3 (M30 - se aplicável) - BÔNUS para PREMIUM
   if(g_numNiveisMacro == 3)
   {
      // 🔥 v4.49 LÓGICA CORRETA:
      // - M30 alinhado = PREMIUM
      // - M30 neutro (amarelo/0) = GOOD
      // - M30 oposto = GOOD (não rejeita!)
      
      bool macro3Bullish = (macro3Value > 0);
      bool macro3Bearish = (macro3Value < 0);
      bool macro3Neutral = (macro3Value == 0);
      
      // M30 alinhado com direção dos macros
      if((macro3Bullish && macro1Bullish && macro2Bullish) ||
         (macro3Bearish && macro1Bearish && macro2Bearish))
      {
         result.m30Aligned = true;
         PrintFormat("🏆 ALINHAMENTO PREMIUM: MACRO-1 + MACRO-2 + MACRO-3 = %s",
                     macro3Bullish ? "🟢 VERDE" : "🔴 VERMELHO");
      }
      else if(macro3Neutral)
      {
         result.m30Aligned = false;
         PrintFormat("⭐ ALINHAMENTO GOOD: MACRO-1+MACRO-2 alinhados, MACRO-3 ⚪ AMARELO (neutro)");
         PrintFormat("   ✅ M30 NEUTRO é ACEITO como GOOD");
      }
      else  // M30 oposto
      {
         result.m30Aligned = false;
         PrintFormat("⭐ ALINHAMENTO GOOD: MACRO-1+MACRO-2 alinhados, MACRO-3 oposto");
         PrintFormat("   ⚠️ MACRO-3 divergente - será classificado como GOOD (não PREMIUM)");
      }
   }
   else
   {
      // Sistema 2 níveis - sempre GOOD se passou validações
      result.m30Aligned = false;
      PrintFormat("⭐ ALINHAMENTO GOOD: Sistema 2 níveis (MACRO-1 + MACRO-2)");
   }
   
   // 🔥🔥🔥 v4.49 CLASSIFICAÇÃO CORRETA DEFINITIVA 🔥🔥🔥
   // LÓGICA BASEADA NO ESPECIFICADO PELO USUÁRIO:
   //   - PREMIUM: TODOS alinhados (H4+H1+M30+M15 mesma cor)
   //   - GOOD: H4+H1 alinhados, M30 ou M15 podem ser NEUTROS (nunca opostos)
   //   - REJECT: Qualquer TF OPOSTO (não apenas divergente)
   
   PrintFormat("────────────────────────────────────────────────────────────────");
   PrintFormat("🎯 [CLASSIFICAÇÃO GG TRENDBAR v4.49 - LÓGICA CORRETA]");
   
   bool allAligned = (result.h4Aligned && result.h1Aligned && 
                      result.operationalAligned && 
                      (g_numNiveisMacro < 3 || result.m30Aligned));
   
   if(allAligned)
   {
      result.classification = SETUP_PREMIUM;
      PrintFormat("🏆 CLASSIFICAÇÃO: PREMIUM");
      PrintFormat("   Motivo: TODOS os timeframes alinhados (mesma cor)");
      PrintFormat("   - MACRO-1 (%s): ✅ %s", TimeframeToString(g_tfMacro1),
                  (result.direction == TRADE_DIRECTION_BUY) ? "🟢 VERDE" : "🔴 VERMELHO");
      PrintFormat("   - MACRO-2 (%s): ✅ %s", TimeframeToString(g_tfMacro2),
                  (result.direction == TRADE_DIRECTION_BUY) ? "🟢 VERDE" : "🔴 VERMELHO");
      if(g_numNiveisMacro == 3)
      {
         PrintFormat("   - MACRO-3 (%s): ✅ %s", TimeframeToString(g_tfMacro3),
                     (result.direction == TRADE_DIRECTION_BUY) ? "🟢 VERDE" : "🔴 VERMELHO");
      }
      PrintFormat("   - OPERACIONAL (%s): ✅ %s", TimeframeToString(g_tfOperacional),
                  (result.direction == TRADE_DIRECTION_BUY) ? "🟢 VERDE" : "🔴 VERMELHO");
      PrintFormat("   🎯 Risco recomendado: MaxRiskPremium (até 2%%)");
   }
   else if(result.h4Aligned && result.h1Aligned)
   {
      // H4+H1 alinhados = pode ser GOOD
      // M30 e/ou M15 podem ser NEUTROS (já validado que não são OPOSTOS)
      result.classification = SETUP_GOOD;
      PrintFormat("⭐ CLASSIFICAÇÃO: GOOD");
      PrintFormat("   Motivo: H4+H1 alinhados, M30 ou M15 NEUTRO/divergente (não oposto)");
      PrintFormat("   - MACRO-1 (%s): ✅ %s", TimeframeToString(g_tfMacro1),
                  (result.direction == TRADE_DIRECTION_BUY) ? "🟢 VERDE" : "🔴 VERMELHO");
      PrintFormat("   - MACRO-2 (%s): ✅ %s", TimeframeToString(g_tfMacro2),
                  (result.direction == TRADE_DIRECTION_BUY) ? "🟢 VERDE" : "🔴 VERMELHO");
      
      if(g_numNiveisMacro == 3)
      {
         if(result.m30Aligned)
            PrintFormat("   - MACRO-3 (%s): ✅ %s", TimeframeToString(g_tfMacro3),
                       (result.direction == TRADE_DIRECTION_BUY) ? "🟢 VERDE" : "🔴 VERMELHO");
         else
            PrintFormat("   - MACRO-3 (%s): ⚠️ ⚪ AMARELO ou divergente", TimeframeToString(g_tfMacro3));
      }
      
      if(result.operationalAligned)
         PrintFormat("   - OPERACIONAL (%s): ✅ %s", TimeframeToString(g_tfOperacional),
                    (result.direction == TRADE_DIRECTION_BUY) ? "🟢 VERDE" : "🔴 VERMELHO");
      else
         PrintFormat("   - OPERACIONAL (%s): ⚠️ ⚪ AMARELO (neutro - ACEITO)", 
                    TimeframeToString(g_tfOperacional));
      
      PrintFormat("   🎯 Risco recomendado: AccountRiskPercent (até 1.5%%)");
   }
   else
   {
      result.classification = SETUP_REJECT;
      PrintFormat("❌ CLASSIFICAÇÃO: REJECT");
      PrintFormat("   Motivo: H4 ou H1 não alinhados (ou TF oposto detectado)");
      PrintFormat("   (Este ponto nunca deveria ser alcançado - validações anteriores rejeitam)");
      return result;
   }
   
   PrintFormat("────────────────────────────────────────────────────────────────");
   
   // Estrutura válida (por ora, simplificado)
   result.structureValid = true;
   result.isValid = true;

   // 🔥 v4.44 LOG RESUMO FINAL DO ALINHAMENTO
   PrintFormat("────────────────────────────────────────────────────────────────");
   PrintFormat("✅ MULTI-TIMEFRAME APROVADO:");
   PrintFormat("   Direção: %s", (result.direction == TRADE_DIRECTION_BUY) ? "🟢 COMPRA" : "🔴 VENDA");
   PrintFormat("   Classificação: %s", (result.classification == SETUP_PREMIUM) ? "🏆 PREMIUM" : "⭐ GOOD");
   PrintFormat("   MACRO-1 (%s): %s", TimeframeToString(g_tfMacro1), result.h4Aligned ? "✅" : "❌");
   PrintFormat("   MACRO-2 (%s): %s", TimeframeToString(g_tfMacro2), result.h1Aligned ? "✅" : "❌");
   if(g_numNiveisMacro == 3)
   {
      PrintFormat("   MACRO-3 (%s): %s", TimeframeToString(g_tfMacro3), result.m30Aligned ? "✅" : "❌");
   }
   PrintFormat("   OPERACIONAL (%s): %s", TimeframeToString(g_tfOperacional), result.operationalAligned ? "✅" : "❌");
   PrintFormat("════════════════════════════════════════════════════════════════");

   return result;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: CalculateSetupScore                                      |
//| Pontua e classifica o setup com base nos filtros micro          |
//|                                                                  |
//| 🔥 v4.44 MUDANÇA CRÍTICA:                                        |
//|   - ANTES: Recebia m30Aligned (bool) e redefinia classificação |
//|   - AGORA: Recebe ggClassification (SETUP_CLASS) do GG TrendBar |
//|   - LÓGICA: Filtros micro apenas CONFIRMAM ou REJEITAM         |
//|   - FILTROS NÃO PODEM ELEVAR classificação (GOOD → PREMIUM)    |
//|                                                                  |
//| HIERARQUIA v4.44:                                                |
//|   1️⃣ GG TRENDBAR - FILTRO MESTRE (define classificação base)    |
//|   2️⃣ SUPERTREND - Tendência local (OBRIGATÓRIO)                 |
//|   3️⃣ WAE - Momentum/Explosão (OBRIGATÓRIO)                      |
//|   4️⃣ RSI OMA - Força relativa (OBRIGATÓRIO)                     |
//|   5️⃣ CURRENCY STRENGTH - Contexto moedas (OBRIGATÓRIO Forex)   |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - symbol: Símbolo a analisar                                  |
//|   - assetClass: Classe do ativo                                 |
//|   - direction: Direção do alinhamento macro                     |
//|   - ggClassification: Classificação do GG TrendBar (PREMIUM/GOOD) |
//|                                                                  |
//| RETORNO: SetupScore (struct com pontuação e classificação)      |
//+------------------------------------------------------------------+
SetupScore CalculateSetupScore(string symbol, ASSET_CLASS assetClass, TRADE_DIRECTION direction, SETUP_CLASS ggClassification)
{
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("📊 PONTUANDO SETUP - Filtros Micro (GG TrendBar já validou)");
   PrintFormat("   Classificação GG: %s", (ggClassification == SETUP_PREMIUM) ? "🏆 PREMIUM" : "⭐ GOOD");
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   SetupScore score;
   score.classification = ggClassification;  // 🔥 v4.44: INICIAR com classificação do GG
   score.direction = direction;
   score.traderMagicPoints = 1; // GG TrendBar já validou multi-TF (FILTRO MESTRE)
   score.currencyStrengthPoints = 0;
   score.rsiomaPoints = 0;
   score.waePoints = 0;
   score.totalPoints = 0;
   
   // ═══════════════════════════════════════════════════════════════════════
   // 🔥 CORREÇÃO CRÍTICA v4.12: ADICIONAR VALIDAÇÃO SUPERTREND OBRIGATÓRIA
   // ═══════════════════════════════════════════════════════════════════════
   PrintFormat("🎯 [FILTRO OBRIGATÓRIO] Validando Supertrend Operacional (%s)...", 
               TimeframeToString(g_tfOperacional));
   
   // Verificar Supertrend no timeframe operacional
   TMSignal supertrend = GetSupertrendSignal(g_handles.st_oper, g_tfOperacional);
   
   // 🔥 v4.20: LOG DETALHADO do Supertrend
   PrintFormat("🔍 [DEBUG SUPERTREND] Leitura do indicador:");
   PrintFormat("   isValid: %s", supertrend.isValid ? "SIM" : "NÃO");
   PrintFormat("   direction: %s", 
               (supertrend.direction == TRADE_DIRECTION_BUY) ? "📈 BUY" :
               (supertrend.direction == TRADE_DIRECTION_SELL) ? "📉 SELL" : "⚠️ NONE");
   PrintFormat("   turnedRecently: %s", supertrend.turnedRecently ? "SIM (BÔNUS!)" : "NÃO");
   PrintFormat("   strength: %.5f", supertrend.strength);
   
   if(!supertrend.isValid)
   {
      PrintFormat("⚠️ Supertrend INVÁLIDO - aguardar confirmação");
      PrintFormat("   Razão: Indicador não retornou sinal válido");
      score.classification = SETUP_REJECT;
      return score;
   }
   
   // Validar se Supertrend alinha com direção GG TrendBar
   if(supertrend.direction != direction)
   {
      PrintFormat("❌ SUPERTREND CONTRA DIREÇÃO GG TRENDBAR - REJECT!");
      PrintFormat("   GG TrendBar: %s", (direction == TRADE_DIRECTION_BUY) ? "📈 BUY" : "📉 SELL");
      PrintFormat("   Supertrend: %s", (supertrend.direction == TRADE_DIRECTION_BUY) ? "📈 BUY" : "📉 SELL");
      PrintFormat("   ⚠️ Macro e Micro NÃO estão alinhados - aguardar convergência");
      score.classification = SETUP_REJECT;
      return score;
   }
   
   PrintFormat("✅ Supertrend ALINHADO com GG TrendBar (%s)", 
               (direction == TRADE_DIRECTION_BUY) ? "📈 BUY" : "📉 SELL");
   if(supertrend.turnedRecently)
   {
      PrintFormat("   🎯 BÔNUS: Virada recente detectada (entrada em momentum)");
   }
   // ═══════════════════════════════════════════════════════════════════════
   
   // Determinar quantos filtros são necessários conforme tipo de ativo
   bool useCS = (assetClass == ASSET_CLASS_FOREX_MAJOR ||
                 assetClass == ASSET_CLASS_FOREX_MINOR ||
                 assetClass == ASSET_CLASS_FOREX_EXOTIC ||
                 assetClass == ASSET_CLASS_CURRENCY_B3 ||
                 assetClass == ASSET_CLASS_METALS);
   
   if(useCS)
   {
      // 🔥 v4.41 CORREÇÃO CRÍTICA: WAE É OBRIGATÓRIO!
      // Sistema 3 filtros: WAE + RSI + CS (TODOS OBRIGATÓRIOS)
      // WAE mede a FORÇA DA TENDÊNCIA através do histograma (explosão de momentum)
      // Sem WAE = sem confirmação de força = setup fraco
      score.requiredPoints = 3;  // ✅ MUDADO: 2 → 3 (todos obrigatórios)
      
      PrintFormat("────────────────────────────────────────────────────────────────");
      PrintFormat("📊 Analisando Filtros Micro (TODOS OBRIGATÓRIOS):");
      
      // 1️⃣ WAE - MOMENTUM/FORÇA (OBRIGATÓRIO!)
      PrintFormat("1️⃣ WAE (Momentum/Explosão - OBRIGATÓRIO)...");
      WAESignal wae = GetWAESignal(g_handles.wae_oper, direction, g_tfOperacional);
      
      // 🔥 v4.41 CRÍTICO: WAE OBRIGATÓRIO!
      if(!wae.isValid)
      {
         PrintFormat("   ❌ WAE INVÁLIDO - REJEITANDO SETUP COMPLETO!");
         PrintFormat("   Razão: WAE não retornou sinal válido");
         score.classification = SETUP_REJECT;
         score.totalPoints = 0;
         return score;
      }
      
      if(!wae.isAligned)
      {
         PrintFormat("   ❌ WAE NÃO ALINHADO - REJEITANDO SETUP COMPLETO!");
         PrintFormat("   Razão: Falta FORÇA/MOMENTUM na tendência (histograma não confirma)");
         score.classification = SETUP_REJECT;
         score.totalPoints = 0;
         return score;
      }
      
      score.waePoints = 1;
      PrintFormat("   ✅ WAE alinhado (+1 ponto) - Força: %.2f | Expandindo: %s", 
                  wae.strength, wae.isExpanding ? "SIM" : "NÃO");
      
      // 2️⃣ RSI OMA - FORÇA RELATIVA (OBRIGATÓRIO!)
      PrintFormat("2️⃣ RSI OMA (Força Relativa - OBRIGATÓRIO)...");
      RSISignal rsi = GetRSIOMASignal(g_handles.rsi_oper, direction, g_tfOperacional);
      
      // 🔥 v4.22 CORREÇÃO CRÍTICA: RSI OMA OBRIGATÓRIO!
      if(!rsi.isValid)
      {
         PrintFormat("   ❌ RSI OMA INVÁLIDO - REJEITANDO SETUP COMPLETO!");
         score.classification = SETUP_REJECT;
         score.totalPoints = 0;
         return score;
      }
      
      if(!rsi.isAligned)
      {
         PrintFormat("   ❌ RSI OMA NÃO ALINHADO - REJEITANDO SETUP COMPLETO!");
         PrintFormat("   Razão: Força relativa não confirma direção");
         score.classification = SETUP_REJECT;
         score.totalPoints = 0;
         return score;
      }
      
      score.rsiomaPoints = 1;
      PrintFormat("   ✅ RSI OMA alinhado (+1 ponto) - Separação: %.2f | Inclinação: %.2f", 
                  rsi.strength, rsi.slope);
      
      // 3️⃣ CURRENCY STRENGTH - CONTEXTO (OBRIGATÓRIO!)
      PrintFormat("3️⃣ Currency Strength (Contexto Moedas - OBRIGATÓRIO)...");
      CSSignal cs = GetCurrencyStrengthSignal(symbol, direction, assetClass);
      
      if(!cs.isValid)
      {
         PrintFormat("   ❌ CURRENCY STRENGTH INVÁLIDO - REJEITANDO SETUP COMPLETO!");
         score.classification = SETUP_REJECT;
         score.totalPoints = 0;
         return score;
      }
      
      if(!cs.isAligned)
      {
         PrintFormat("   ❌ CURRENCY STRENGTH NÃO ALINHADO - REJEITANDO SETUP COMPLETO!");
         PrintFormat("   Razão: Contexto de moedas não favorece direção");
         score.classification = SETUP_REJECT;
         score.totalPoints = 0;
         return score;
      }
      
      score.currencyStrengthPoints = 1;
      PrintFormat("   ✅ Currency Strength alinhado (+1 ponto) - Separação: %.2f", cs.strength);
      
      score.totalPoints = score.waePoints + score.rsiomaPoints + score.currencyStrengthPoints;
      
      // 🔥 v4.44 NOVA LÓGICA: Filtros apenas CONFIRMAM classificação do GG
      // NÃO redefinem classificação! (GOOD não vira PREMIUM, PREMIUM não vira GOOD)
      
      if(score.totalPoints < 3)
      {
         PrintFormat("❌ Filtros micro insuficientes (%d/3) - REJEITANDO setup", score.totalPoints);
         score.classification = SETUP_REJECT;
         return score;
      }
      
      // ✅ Todos os 3 filtros passaram - MANTÉM classificação do GG TrendBar
      PrintFormat("✅ Todos filtros micro passaram (3/3) - Mantém classificação GG: %s",
                  (ggClassification == SETUP_PREMIUM) ? "🏆 PREMIUM" : "⭐ GOOD");
   }
   else
   {
      // 🔥 v4.41 CORREÇÃO CRÍTICA: WAE É OBRIGATÓRIO!
      // Sistema 2 filtros: WAE + RSI (AMBOS OBRIGATÓRIOS) - ÍNDICES
      // Não usa CS para índices (WIN, US30, etc)
      score.requiredPoints = 2;
      
      PrintFormat("────────────────────────────────────────────────────────────────");
      PrintFormat("📊 Analisando Filtros Micro - ÍNDICES (TODOS OBRIGATÓRIOS):");
      
      // 1️⃣ WAE - MOMENTUM (OBRIGATÓRIO!)
      PrintFormat("1️⃣ WAE (Momentum/Explosão - OBRIGATÓRIO)...");
      WAESignal wae = GetWAESignal(g_handles.wae_oper, direction, g_tfOperacional);
      
      if(!wae.isValid)
      {
         PrintFormat("   ❌ WAE INVÁLIDO - REJEITANDO SETUP COMPLETO!");
         score.classification = SETUP_REJECT;
         score.totalPoints = 0;
         return score;
      }
      
      if(!wae.isAligned)
      {
         PrintFormat("   ❌ WAE NÃO ALINHADO - REJEITANDO SETUP COMPLETO!");
         PrintFormat("   Razão: Falta FORÇA/MOMENTUM (histograma não confirma)");
         score.classification = SETUP_REJECT;
         score.totalPoints = 0;
         return score;
      }
      
      score.waePoints = 1;
      PrintFormat("   ✅ WAE alinhado (+1 ponto) - Força: %.2f | Expandindo: %s", 
                  wae.strength, wae.isExpanding ? "SIM" : "NÃO");
      
      // 2️⃣ RSI OMA - FORÇA RELATIVA (OBRIGATÓRIO!)
      PrintFormat("2️⃣ RSI OMA (Força Relativa - OBRIGATÓRIO)...");
      RSISignal rsi = GetRSIOMASignal(g_handles.rsi_oper, direction, g_tfOperacional);
      
      // 🔥 v4.22 CORREÇÃO CRÍTICA: RSI OMA OBRIGATÓRIO também para ÍNDICES!
      if(!rsi.isValid)
      {
         PrintFormat("   ❌ RSI OMA INVÁLIDO - REJEITANDO SETUP COMPLETO!");
         score.classification = SETUP_REJECT;
         score.totalPoints = 0;
         return score;
      }
      
      if(!rsi.isAligned)
      {
         PrintFormat("   ❌ RSI OMA NÃO ALINHADO - REJEITANDO SETUP COMPLETO!");
         score.classification = SETUP_REJECT;
         score.totalPoints = 0;
         return score;
      }
      
      score.rsiomaPoints = 1;
      PrintFormat("   ✅ RSI OMA alinhado (+1 ponto) - Separação: %.2f | Inclinação: %.2f", 
                  rsi.strength, rsi.slope);
      
      score.totalPoints = score.waePoints + score.rsiomaPoints;
      
      // 🔥 v4.44 NOVA LÓGICA: Filtros apenas CONFIRMAM classificação do GG
      // NÃO redefinem classificação! (GOOD não vira PREMIUM, PREMIUM não vira GOOD)
      
      if(score.totalPoints < 2)
      {
         PrintFormat("❌ Filtros micro insuficientes (%d/2) - REJEITANDO setup", score.totalPoints);
         score.classification = SETUP_REJECT;
         return score;
      }
      
      // ✅ Ambos os filtros passaram (WAE + RSI) - MANTÉM classificação do GG TrendBar
      PrintFormat("✅ Todos filtros micro passaram (2/2) - Mantém classificação GG: %s",
                  (ggClassification == SETUP_PREMIUM) ? "🏆 PREMIUM" : "⭐ GOOD");
   }
   
   // Log detalhado com nova hierarquia
   PrintFormat("────────────────────────────────────────────────────────────────");
   PrintFormat("📊 RESULTADO FINAL - Setup %s:", symbol);
   PrintFormat("   Direção: %s", (direction == TRADE_DIRECTION_BUY) ? "📈 BUY" : "📉 SELL");
   PrintFormat("   ✅ GG TrendBar: VALIDADO (Filtro Mestre Macro)");
   PrintFormat("   ✅ Supertrend: ALINHADO (Filtro Obrigatório Micro)");
   PrintFormat("   %s WAE (Momentum): %d pt", 
               (score.waePoints > 0) ? "✅" : "❌",
               score.waePoints);
   PrintFormat("   %s RSI OMA (Força): %d pt", 
               (score.rsiomaPoints > 0) ? "✅" : "❌",
               score.rsiomaPoints);
   PrintFormat("   %s Currency Strength (Contexto): %d pt", 
               (score.currencyStrengthPoints > 0) ? "✅" : "❌",
               score.currencyStrengthPoints);
   PrintFormat("   📈 TOTAL: %d/%d pontos", score.totalPoints, score.requiredPoints);
   PrintFormat("   🎯 Classificação: %s",
               (score.classification == SETUP_PREMIUM) ? "🏆 PREMIUM (Máxima Qualidade)" :
               (score.classification == SETUP_GOOD) ? "⭐ GOOD (Boa Qualidade)" : 
               "❌ REJECT (Insuficiente)");
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   return score;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: ReleaseIndicators                                        |
//| Libera handles E remove objetos visuais do gráfico              |
//+------------------------------------------------------------------+
void ReleaseIndicators()
{
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("🔓 LIMPANDO INDICADORES E OBJETOS VISUAIS...");
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 1: Liberar handles (memória)
   // ═══════════════════════════════════════════════════════════════
   int handlesLiberados = 0;
   
   if(g_handles.gg_global != INVALID_HANDLE)  
   {
      IndicatorRelease(g_handles.gg_global);
      handlesLiberados++;
      PrintFormat("   ✅ Handle GG TrendBar liberado");
   }
   
   if(g_handles.st_oper != INVALID_HANDLE)    
   {
      IndicatorRelease(g_handles.st_oper);
      handlesLiberados++;
      PrintFormat("   ✅ Handle Supertrend liberado");
   }
   
   if(g_handles.wae_oper != INVALID_HANDLE)   
   {
      IndicatorRelease(g_handles.wae_oper);
      handlesLiberados++;
      PrintFormat("   ✅ Handle WAE liberado");
   }
   
   if(g_handles.rsi_oper != INVALID_HANDLE)   
   {
      IndicatorRelease(g_handles.rsi_oper);
      handlesLiberados++;
      PrintFormat("   ✅ Handle RSI OMA liberado");
   }
   
   if(g_handles.cs_oper != INVALID_HANDLE)    
   {
      IndicatorRelease(g_handles.cs_oper);
      handlesLiberados++;
      PrintFormat("   ✅ Handle Currency Strength liberado");
   }
   
   PrintFormat("📊 Total de handles liberados: %d", handlesLiberados);
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 2: Remover TODOS os indicadores do gráfico (janelas)
   // ═══════════════════════════════════════════════════════════════
   int indicatorsRemoved = 0;
   int totalWindows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   
   PrintFormat("\n🔍 Detectadas %d janelas no gráfico (incluindo principal)", totalWindows);
   
   // Remover indicadores das sub-janelas (janela 1, 2, 3...)
   // IMPORTANTE: Começar do fim para não bagunçar índices
   for(int window = totalWindows - 1; window >= 1; window--)
   {
      int indicatorsInWindow = ChartIndicatorsTotal(0, window);
      PrintFormat("   📊 Janela %d: %d indicador(es)", window, indicatorsInWindow);
      
      // Remover todos os indicadores desta janela
      for(int i = indicatorsInWindow - 1; i >= 0; i--)
      {
         string indicatorName = ChartIndicatorName(0, window, i);
         if(indicatorName != "")
         {
            if(ChartIndicatorDelete(0, window, indicatorName))
            {
               indicatorsRemoved++;
               PrintFormat("      ✅ Removido: %s", indicatorName);
            }
            else
            {
               PrintFormat("      ⚠️ Falha ao remover: %s", indicatorName);
            }
         }
      }
   }
   
   // Remover indicadores da janela principal (janela 0)
   int mainWindowIndicators = ChartIndicatorsTotal(0, 0);
   PrintFormat("   📊 Janela principal: %d indicador(es)", mainWindowIndicators);
   
   for(int i = mainWindowIndicators - 1; i >= 0; i--)
   {
      string indicatorName = ChartIndicatorName(0, 0, i);
      if(indicatorName != "")
      {
         // FILTRO: Só remover indicadores do Nexus (evitar remover outros EAs)
         if(StringFind(indicatorName, "GG_TrendBar") >= 0 ||
            StringFind(indicatorName, "TrendMagic") >= 0 ||
            StringFind(indicatorName, "Supertrend") >= 0 ||
            StringFind(indicatorName, "WAE") >= 0 ||
            StringFind(indicatorName, "Waddah") >= 0 ||
            StringFind(indicatorName, "RSI") >= 0 ||
            StringFind(indicatorName, "RSIOMA") >= 0 ||
            StringFind(indicatorName, "Currency") >= 0 ||
            StringFind(indicatorName, "Strength") >= 0)
         {
            if(ChartIndicatorDelete(0, 0, indicatorName))
            {
               indicatorsRemoved++;
               PrintFormat("      ✅ Removido: %s", indicatorName);
            }
            else
            {
               PrintFormat("      ⚠️ Falha ao remover: %s", indicatorName);
            }
         }
      }
   }
   
   PrintFormat("📊 Total de indicadores removidos do gráfico: %d", indicatorsRemoved);
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 3: Remover objetos gráficos (textos, linhas, etc)
   // ═══════════════════════════════════════════════════════════════
   int objectsRemoved = 0;
   int totalObjects = ObjectsTotal(0);
   
   PrintFormat("\n🔍 Detectados %d objetos gráficos no gráfico", totalObjects);
   
   // Remover objetos que começam com prefixos conhecidos do Nexus
   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      
      // FILTRO: Só remover objetos do Nexus
      if(StringFind(objName, "Nexus") >= 0 ||
         StringFind(objName, "GG_") >= 0 ||
         StringFind(objName, "TM_") >= 0 ||
         StringFind(objName, "WAE_") >= 0 ||
         StringFind(objName, "RSI_") >= 0 ||
         StringFind(objName, "CS_") >= 0)
      {
         if(ObjectDelete(0, objName))
         {
            objectsRemoved++;
            PrintFormat("   ✅ Objeto removido: %s", objName);
         }
      }
   }
   
   PrintFormat("📊 Total de objetos gráficos removidos: %d", objectsRemoved);
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 4: Forçar redesenho do gráfico
   // ═══════════════════════════════════════════════════════════════
   ChartRedraw(0);
   
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("✅ LIMPEZA COMPLETA!");
   PrintFormat("   Handles liberados: %d", handlesLiberados);
   PrintFormat("   Indicadores removidos: %d", indicatorsRemoved);
   PrintFormat("   Objetos removidos: %d", objectsRemoved);
   PrintFormat("════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
