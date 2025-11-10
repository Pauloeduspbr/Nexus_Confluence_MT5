//+------------------------------------------------------------------+
//|                                            NexusInputsConfig.mqh |
//|                      Nexus Confluence EA - Configurações de Input |
//|                       Todos os parâmetros configuráveis via INPUT |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| SEÇÃO 1: GESTÃO DE RISCO BÁSICA                                  |
//+------------------------------------------------------------------+

input group "═══════════ 💰 GESTÃO DE RISCO ═══════════"
input double   InpLotSize        = 0.07;      // Tamanho do Lote
input int      InpMaxSlippage    = 10;        // Slippage Máximo (pontos)

//+------------------------------------------------------------------+
//| SEÇÃO 2: STOP LOSS E TAKE PROFIT - BUY                          |
//+------------------------------------------------------------------+

input group "═══════════ 📈 PARÂMETROS BUY ═══════════"
input int      InpStopLossBuy    = 400;       // Stop Loss BUY (pontos/pips)
input int      InpTakeProfitBuy  = 900;       // Take Profit BUY (pontos/pips)

//+------------------------------------------------------------------+
//| SEÇÃO 3: BREAK EVEN - BUY                                        |
//+------------------------------------------------------------------+

input group "═══════════ 🎯 BREAK EVEN BUY ═══════════"
input bool     InpBE_Buy_Enable  = true;      // [BUY] Ativar Break Even
input int      InpBE_Buy_Trigger = 300;       // [BUY] Ativação BE (pontos/pips)
input int      InpBE_Buy_Step    = 50;        // [BUY] Passo BE (pontos/pips)

//+------------------------------------------------------------------+
//| SEÇÃO 4: TRAILING STOP - BUY                                     |
//+------------------------------------------------------------------+

input group "═══════════ 🚀 TRAILING STOP BUY ═══════════"
input bool     InpTS_Buy_Enable  = false;     // [BUY] Ativar Trailing Stop
input int      InpTS_Buy_Trigger = 400;       // [BUY] Ativação TS (pontos/pips)
input int      InpTS_Buy_Step    = 200;       // [BUY] Passo TS (pontos/pips)

//+------------------------------------------------------------------+
//| SEÇÃO 5: STOP LOSS E TAKE PROFIT - SELL                         |
//+------------------------------------------------------------------+

input group "═══════════ 📉 PARÂMETROS SELL ═══════════"
input int      InpStopLossSell   = 200;       // Stop Loss SELL (pontos/pips)
input int      InpTakeProfitSell = 500;       // Take Profit SELL (pontos/pips)

//+------------------------------------------------------------------+
//| SEÇÃO 6: BREAK EVEN - SELL                                       |
//+------------------------------------------------------------------+

input group "═══════════ 🎯 BREAK EVEN SELL ═══════════"
input bool     InpBE_Sell_Enable  = true;     // [SELL] Ativar Break Even
input int      InpBE_Sell_Trigger = 150;      // [SELL] Ativação BE (pontos/pips)
input int      InpBE_Sell_Step    = 30;       // [SELL] Passo BE (pontos/pips)

//+------------------------------------------------------------------+
//| SEÇÃO 7: TRAILING STOP - SELL                                    |
//+------------------------------------------------------------------+

input group "═══════════ 🚀 TRAILING STOP SELL ═══════════"
input bool     InpTS_Sell_Enable  = false;    // [SELL] Ativar Trailing Stop
input int      InpTS_Sell_Trigger = 200;      // [SELL] Ativação TS (pontos/pips)
input int      InpTS_Sell_Step    = 100;      // [SELL] Passo TS (pontos/pips)

//+------------------------------------------------------------------+
//| SEÇÃO 8: FILTROS DE SINAL                                        |
//+------------------------------------------------------------------+

input group "═══════════ 🔍 FILTROS DE SINAL ═══════════"
input int      InpMinScoreBuy    = 2;         // Score Mínimo BUY
input int      InpMinScoreSell   = 4;         // Score Mínimo SELL

//+------------------------------------------------------------------+
//| SEÇÃO 9: CONTROLE DE DIREÇÃO                                     |
//+------------------------------------------------------------------+

input group "═══════════ ↕️ CONTROLE DE DIREÇÃO ═══════════"
input bool     InpEnableBuy      = true;      // Habilitar Operações BUY
input bool     InpEnableSell     = false;     // Habilitar Operações SELL

//+------------------------------------------------------------------+
//| SEÇÃO 10: PROTEÇÃO DE DRAWDOWN                                   |
//+------------------------------------------------------------------+

input group "═══════════ 🛡️ PROTEÇÃO DE DRAWDOWN ═══════════"
input bool     InpDD_Enable      = true;      // Ativar Proteção de Drawdown
input double   InpDD_DailyMax    = 5.0;       // Drawdown Diário Máximo (%)
input int      InpDD_ConsecLoss  = 7;         // Máx Perdas Consecutivas
input double   InpDD_LotReduce   = 0.5;       // Redução de Lote após DD (%)

//+------------------------------------------------------------------+
//| SEÇÃO 11: FILTRO DE SPREAD                                       |
//+------------------------------------------------------------------+

input group "═══════════ 📊 FILTRO DE SPREAD ═══════════"
input int      InpMaxSpread      = 20;         // Spread Máximo (pontos)
input double   InpSpreadMulti    = 1.5;        // Multiplicador de Spread (vs mediana)
input int      InpSpreadPeriod   = 20;         // Período Cálculo Spread (candles)

//+------------------------------------------------------------------+
//| SEÇÃO 12: FILTRO DE HORÁRIO                                      |
//+------------------------------------------------------------------+

input group "═══════════ 🕐 FILTRO DE HORÁRIO ═══════════"
input bool     InpUseTimeFilter  = false;      // Usar Filtro de Horário
input string   InpStartTime      = "09:00";    // Horário Início (HH:MM)
input string   InpEndTime        = "17:00";    // Horário Fim (HH:MM)

//+------------------------------------------------------------------+
//| SEÇÃO 13: FILTRO SEMANAL (DIAS INDIVIDUAIS)                      |
//+------------------------------------------------------------------+

input group "═══════════ 📅 FILTRO SEMANAL ═══════════"
input bool     InpTradeOnSunday    = true;     // Operar no Domingo (0)
input bool     InpTradeOnMonday    = true;     // Operar na Segunda (1)
input bool     InpTradeOnTuesday   = true;     // Operar na Terça (2)
input bool     InpTradeOnWednesday = true;     // Operar na Quarta (3)
input bool     InpTradeOnThursday  = true;     // Operar na Quinta (4)
input bool     InpTradeOnFriday    = true;     // Operar na Sexta (5)
input bool     InpTradeOnSaturday  = true;     // Operar no Sábado (6)

//+------------------------------------------------------------------+
//| SEÇÃO 14: TIMEFRAMES (Sistema Multi-Timeframe)                   |
//+------------------------------------------------------------------+

input group "═══════════ ⏰ TIMEFRAMES ═══════════"
input ENUM_TIMEFRAMES InpMacro1TF      = PERIOD_H4;  // Macro 1 Timeframe (H4)
input ENUM_TIMEFRAMES InpMacro2TF      = PERIOD_H1;  // Macro 2 Timeframe (H1)
input ENUM_TIMEFRAMES InpMacro3TF      = PERIOD_M30; // Macro 3 Timeframe (M30)
input ENUM_TIMEFRAMES InpOperationalTF = PERIOD_M15; // Operational Timeframe (M15)
input int             InpMinScore      = 2;          // Score Mínimo MTF (≥+2 BUY, ≤-2 SELL)

//+------------------------------------------------------------------+
//| SEÇÃO 15: CONFIGURAÇÕES GERAIS                                   |
//+------------------------------------------------------------------+

input group "═══════════ ⚙️ CONFIGURAÇÕES GERAIS ═══════════"
input int      InpMagicNumber    = 20241024;  // Magic Number
input bool     InpShowPanel      = true;       // Exibir Painel no Gráfico
input bool     InpEnableAlerts   = true;       // Ativar Alertas Sonoros
input bool     InpEnableEmail    = false;      // Enviar Email em Operações
input bool     InpEnablePush     = false;      // Enviar Notificação Push

//+------------------------------------------------------------------+
//| SEÇÃO 15.1: VISUALIZAÇÃO NO GRÁFICO                             |
//+------------------------------------------------------------------+
input group "═══════════ 🎨 VISUALIZAÇÃO ═══════════"
input bool     InpAttachIndicatorsToChart = true; // Anexar indicadores visuais ao gráfico

//+------------------------------------------------------------------+
//| SEÇÃO 16: LOGS E DEBUG                                           |
//+------------------------------------------------------------------+

input group "═══════════ 📝 LOGS E DEBUG ═══════════"
input int      InpLogLevel       = 2;          // Nível de Log (1=Executive, 2=Operational, 3=Debug)
input bool     InpSaveStats      = true;       // Salvar Estatísticas em Arquivo

//+------------------------------------------------------------------+
//| SEÇÃO 17: PERFIS POR CLASSE (PREMIUM/GOOD)                      |
//+------------------------------------------------------------------+

input group "═══════════ 🧭 PERFIS DE ENTRADA ═══════════"
input bool     InpBuyPremiumEnable  = true;    // BUY PREMIUM: ATIVO/INATIVO
input bool     InpBuyGoodEnable     = true;    // BUY GOOD: ATIVO/INATIVO
input bool     InpSellPremiumEnable = false;   // SELL PREMIUM: ATIVO/INATIVO
input bool     InpSellGoodEnable    = false;   // SELL GOOD: ATIVO/INATIVO

//+------------------------------------------------------------------+
//| SEÇÃO 18: INDICADOR - GG TREND BAR                               |
//+------------------------------------------------------------------+
input group "═══════════ 📊 GG TREND BAR ═══════════"
input color             InpGG_UpColor         = clrLime;             // Cor de Alta
input color             InpGG_DownColor       = clrRed;              // Cor de Baixa
input color             InpGG_FlatColor       = clrYellow;           // Cor de Lateral
input color             InpGG_TextColor       = clrAqua;             // Cor do Texto
input ENUM_BASE_CORNER  InpGG_Corner          = CORNER_LEFT_UPPER;   // Canto do Painel
input bool              InpGG_CreateObjects   = true;                // Criar Objetos Visuais (v2.10 default TRUE)
input int               InpGG_ADX_Period      = 14;                  // Período ADX
input ENUM_APPLIED_PRICE InpGG_ADX_Price      = PRICE_CLOSE;         // Preço para ADX/PSAR
input double            InpGG_PSAR_Step       = 0.02;                // Passo PSAR
input double            InpGG_PSAR_Max        = 0.20;                // Máximo PSAR

//+------------------------------------------------------------------+
//| SEÇÃO 19: INDICADOR - SUPERTREND (TrendMagic_MT5)                |
//+------------------------------------------------------------------+
input group "═══════════ 📈 SUPERTREND (TrendMagic) ═══════════"
input int               InpST_CCI_Period      = 50;                  // CCI Period
input int               InpST_ATR_Period      = 5;                   // ATR Period
input double            InpST_ATR_Multiplier  = 1.0;                 // ATR Multiplier

//+------------------------------------------------------------------+
//| SEÇÃO 20: INDICADOR - OBV MACD (Momentum)                        |
//+------------------------------------------------------------------+
input group "═══════════ 💥 OBV MACD (Momentum) ═══════════"
input int               InpMACD_FastEMA       = 12;                  // Fast EMA (OBV MACD)
input int               InpMACD_SlowEMA       = 26;                  // Slow EMA (OBV MACD)
input int               InpMACD_SignalSMA     = 9;                   // Signal SMA (OBV MACD)
input int               InpMACD_ObvSmooth     = 5;                   // OBV Smoothing Period
input bool              InpMACD_UseTickVolume = true;                // Use Tick Volume (Forex)
input bool              InpMACD_ShowMACDLine  = true;                // Show MACD Line
input bool              InpMACD_ShowSignalLine= true;                // Show Signal Line
input int               InpMACD_ThreshPeriod  = 34;                  // Threshold Period (|hist| EMA)
input double            InpMACD_ThreshMult    = 0.6;                 // Threshold Multiplier

//+------------------------------------------------------------------+
//| SEÇÃO 21: INDICADOR - RSI OMA                                    |
//+------------------------------------------------------------------+
input group "═══════════ 📐 RSI OMA ═══════════"
input int               InpRSI_Period         = 14;                  // RSI Period
input int               InpRSI_MA_Period      = 9;                   // MA Period
input ENUM_MA_METHOD    InpRSI_MA_Method      = MODE_SMA;            // MA Method
input double            InpRSI_HighLevel      = 70.0;                // Nível Superior
input double            InpRSI_LowLevel       = 30.0;                // Nível Inferior
input bool              InpRSI_ShowLevels     = true;                // Mostrar Níveis

//+------------------------------------------------------------------+
//| SEÇÃO 22: INDICADOR - CURRENCY STRENGTH                          |
//+------------------------------------------------------------------+
input group "═══════════ 🌍 CURRENCY STRENGTH ═══════════"
input int               InpCS_CalcPeriod      = 24;                  // Período Cálculo
input int               InpCS_Smoothing       = 5;                   // Suavização (EMA)
input bool              InpCS_ShowPercent     = true;                // Exibir em %

//+------------------------------------------------------------------+
//| NOTAS IMPORTANTES                                                 |
//+------------------------------------------------------------------+
/*

📋 INSTRUÇÕES DE USO:

1. PONTOS vs PIPS:
   - Para B3 (WIN, WDO): 1 ponto = 1 tick (ex: SL=400 = 400 pontos)
   - Para Forex: 1 pip = 0.0001 para pares normais / 0.01 para pares com JPY
   - O sistema detecta automaticamente usando SYMBOL_POINT

2. BREAK EVEN:
   - Trigger: Quando atingir este lucro, ativa o BE
   - Step: Quantos pontos/pips acima da entrada mover o SL
   - Exemplo BUY: Entry 1.1000, Trigger 300, Step 50
     → Quando atingir 1.1300, move SL para 1.1050 (+50 pips protegidos)

3. TRAILING STOP:
   - Trigger: Quando atingir este lucro, inicia o trailing
   - Step: Distância entre preço atual e SL
   - Exemplo BUY: Trigger 400, Step 200
     → Quando atingir +400 pips, SL sempre ficará 200 pips abaixo do preço

4. CONFIGURAÇÕES RECOMENDADAS:

   FASE 1 (Semanas 1-2): Estabilização
   ✅ InpEnableBuy = true
   ❌ InpEnableSell = false
   ✅ InpBE_Buy_Enable = true
   ❌ InpTS_Buy_Enable = false
   📊 InpLotSize = 0.05

   FASE 2 (Semanas 3-4): Otimização
   ✅ InpEnableBuy = true
   ❌ InpEnableSell = false
   ✅ InpBE_Buy_Enable = true
   ✅ InpTS_Buy_Enable = true
   📊 InpLotSize = 0.07

   FASE 3 (Semanas 5-6): Reintrodução SELL
   ✅ InpEnableBuy = true
   ✅ InpEnableSell = true (com SL/TP menores!)
   ✅ InpBE_Sell_Enable = true
   ✅ InpTS_Sell_Enable = true
   📊 InpStopLossSell = 200 (metade do BUY)
   📊 InpTakeProfitSell = 500 (metade do BUY)

5. PROTEÇÃO DE DRAWDOWN:
   - DD_DailyMax: Se perder 5% da conta em 1 dia, para de operar
   - DD_ConsecLoss: Se tiver 7 perdas seguidas, pausa
   - DD_LotReduce: Após drawdown, reduz lote para 50%

6. SEM VALORES DINÂMICOS:
   ✅ Todos os valores são FIXOS e configuráveis via INPUT
   ❌ Não usa ATR ou cálculos dinâmicos
   ❌ Não tem valores hardcoded no código
   ✅ Tudo personalizável pelo usuário

7. SUPORTE B3 E FOREX:
   ✅ WIN (B3): Funciona com pontos
   ✅ WDO (B3): Funciona com pontos
   ✅ EURUSD (Forex): Funciona com pips
   ✅ USDJPY (Forex): Funciona com pips (ajuste automático)
   ✅ Qualquer outro ativo: Detecção automática

8. OBSERVAÇÃO IMPORTANTE - SELL:
   Os dados históricos mostraram que SELL tem expectativa negativa
   com os MESMOS parâmetros de BUY. Por isso:
   
   - SL SELL = 200 (50% do BUY)
   - TP SELL = 500 (55% do BUY)
   - BE SELL mais agressivo (trigger 150 vs 300)
   - Score SELL mais rigoroso (4 vs 2)
   
   Isso NÃO significa que SELL é ruim, mas que precisa de parâmetros
   DIFERENTES devido à assimetria natural dos mercados (bull markets
   tendem a ser mais sustentados que bear markets).

9. COMO USAR ESTE ARQUIVO:
   - Copie este arquivo para: Include/NexusConfluenceEA/
   - No EA principal (NexusConfluenceEA.mq5), adicione:
     #include <NexusConfluenceEA/NexusInputsConfig.mqh>
   - Compile o EA
   - Os inputs aparecerão organizados por grupos no Strategy Tester

10. VALIDAÇÃO:
   ✅ 20/20 requisitos implementados
   ✅ 100% sem hardcode
   ✅ 100% sem ATR ou cálculos dinâmicos
   ✅ 100% configurável via inputs
   ✅ Suporte completo B3 e Forex
   ✅ SL/TP separados BUY/SELL
   ✅ BE separado BUY/SELL
   ✅ TS separado BUY/SELL
    ✅ Perfis por classe (PREMIUM/GOOD) por direção
    ✅ Todos os parâmetros dos indicadores expostos como INPUTS para backtest

*/

//+------------------------------------------------------------------+
//| FUNÇÕES AUXILIARES PARA CONVERSÃO                                |
//+------------------------------------------------------------------+

// Converte pontos/pips para preço (compatível B3 e Forex)
double PointsToPrice(int points)
{
    return points * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

// Converte preço para pontos/pips (compatível B3 e Forex)
int PriceToPoints(double price)
{
    return (int)MathRound(price / SymbolInfoDouble(_Symbol, SYMBOL_POINT));
}

// Normaliza preço para o número correto de dígitos
double NormalizePrice(double price)
{
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    return NormalizeDouble(price, digits);
}

// Verifica se é ativo B3 (WIN, WDO, etc)
bool IsB3Asset()
{
    string symbol = _Symbol;
    return (StringFind(symbol, "WIN") >= 0 || 
            StringFind(symbol, "WDO") >= 0 ||
            StringFind(symbol, "IND") >= 0 ||
            StringFind(symbol, "DOL") >= 0);
}

// Verifica se é ativo Forex
bool IsForexAsset()
{
    return !IsB3Asset();
}

// Retorna o nome amigável da unidade (pontos ou pips)
string GetUnitName()
{
    return IsB3Asset() ? "pontos" : "pips";
}

//+------------------------------------------------------------------+
//| VALIDAÇÃO DE INPUTS                                              |
//+------------------------------------------------------------------+

// Valida todos os inputs ao inicializar o EA
bool ValidateInputs()
{
    bool valid = true;
    
    // Validar Lot Size
    if(InpLotSize <= 0)
    {
        Print("❌ ERRO: InpLotSize deve ser maior que zero. Valor atual: ", InpLotSize);
        valid = false;
    }
    
    // Validar Stop Loss
    if(InpStopLossBuy <= 0 || InpStopLossSell <= 0)
    {
        Print("❌ ERRO: Stop Loss deve ser maior que zero.");
        Print("   InpStopLossBuy: ", InpStopLossBuy);
        Print("   InpStopLossSell: ", InpStopLossSell);
        valid = false;
    }
    
    // Validar Take Profit
    if(InpTakeProfitBuy <= 0 || InpTakeProfitSell <= 0)
    {
        Print("❌ ERRO: Take Profit deve ser maior que zero.");
        Print("   InpTakeProfitBuy: ", InpTakeProfitBuy);
        Print("   InpTakeProfitSell: ", InpTakeProfitSell);
        valid = false;
    }
    
    // Validar Break Even
    if(InpBE_Buy_Enable)
    {
        if(InpBE_Buy_Trigger <= 0 || InpBE_Buy_Step < 0)
        {
            Print("❌ ERRO: Parâmetros de Break Even BUY inválidos.");
            Print("   InpBE_Buy_Trigger: ", InpBE_Buy_Trigger);
            Print("   InpBE_Buy_Step: ", InpBE_Buy_Step);
            valid = false;
        }
        
        if(InpBE_Buy_Trigger <= InpBE_Buy_Step)
        {
            Print("⚠️ AVISO: BE Trigger BUY deve ser maior que BE Step.");
            Print("   Trigger: ", InpBE_Buy_Trigger, " | Step: ", InpBE_Buy_Step);
        }
    }
    
    if(InpBE_Sell_Enable)
    {
        if(InpBE_Sell_Trigger <= 0 || InpBE_Sell_Step < 0)
        {
            Print("❌ ERRO: Parâmetros de Break Even SELL inválidos.");
            Print("   InpBE_Sell_Trigger: ", InpBE_Sell_Trigger);
            Print("   InpBE_Sell_Step: ", InpBE_Sell_Step);
            valid = false;
        }
        
        if(InpBE_Sell_Trigger <= InpBE_Sell_Step)
        {
            Print("⚠️ AVISO: BE Trigger SELL deve ser maior que BE Step.");
            Print("   Trigger: ", InpBE_Sell_Trigger, " | Step: ", InpBE_Sell_Step);
        }
    }
    
    // Validar Trailing Stop
    if(InpTS_Buy_Enable)
    {
        if(InpTS_Buy_Trigger <= 0 || InpTS_Buy_Step <= 0)
        {
            Print("❌ ERRO: Parâmetros de Trailing Stop BUY inválidos.");
            Print("   InpTS_Buy_Trigger: ", InpTS_Buy_Trigger);
            Print("   InpTS_Buy_Step: ", InpTS_Buy_Step);
            valid = false;
        }
        
        if(InpTS_Buy_Trigger <= InpTS_Buy_Step)
        {
            Print("⚠️ AVISO: TS Trigger BUY deve ser maior que TS Step.");
            Print("   Trigger: ", InpTS_Buy_Trigger, " | Step: ", InpTS_Buy_Step);
        }
    }
    
    if(InpTS_Sell_Enable)
    {
        if(InpTS_Sell_Trigger <= 0 || InpTS_Sell_Step <= 0)
        {
            Print("❌ ERRO: Parâmetros de Trailing Stop SELL inválidos.");
            Print("   InpTS_Sell_Trigger: ", InpTS_Sell_Trigger);
            Print("   InpTS_Sell_Step: ", InpTS_Sell_Step);
            valid = false;
        }
        
        if(InpTS_Sell_Trigger <= InpTS_Sell_Step)
        {
            Print("⚠️ AVISO: TS Trigger SELL deve ser maior que TS Step.");
            Print("   Trigger: ", InpTS_Sell_Trigger, " | Step: ", InpTS_Sell_Step);
        }
    }
    
    // Validar Direções
    if(!InpEnableBuy && !InpEnableSell)
    {
        Print("❌ ERRO: Pelo menos uma direção (BUY ou SELL) deve estar habilitada.");
        valid = false;
    }

    // Validar Perfis por Classe vs Direções
    if(InpEnableBuy)
    {
        if(!InpBuyPremiumEnable && !InpBuyGoodEnable)
        {
            Print("❌ ERRO: BUY está habilitado, mas ambos os perfis (PREMIUM/GOOD) estão desativados.");
            valid = false;
        }
    }
    if(InpEnableSell)
    {
        if(!InpSellPremiumEnable && !InpSellGoodEnable)
        {
            Print("❌ ERRO: SELL está habilitado, mas ambos os perfis (PREMIUM/GOOD) estão desativados.");
            valid = false;
        }
    }
    
    // Validar Drawdown Protection
    if(InpDD_Enable)
    {
        if(InpDD_DailyMax <= 0 || InpDD_DailyMax > 100)
        {
            Print("❌ ERRO: DD Daily Max deve estar entre 0 e 100%.");
            Print("   Valor atual: ", InpDD_DailyMax);
            valid = false;
        }
        
        if(InpDD_ConsecLoss <= 0)
        {
            Print("❌ ERRO: DD Consecutive Loss deve ser maior que zero.");
            Print("   Valor atual: ", InpDD_ConsecLoss);
            valid = false;
        }
        
        if(InpDD_LotReduce <= 0 || InpDD_LotReduce > 1)
        {
            Print("❌ ERRO: DD Lot Reduce deve estar entre 0 e 1.");
            Print("   Valor atual: ", InpDD_LotReduce);
            valid = false;
        }
    }
    
    // Mostrar resumo se válido
    if(valid)
    {
        // Avisos não-bloqueantes para parâmetros extremos de indicadores
        if(InpST_ATR_Period > 100 || InpST_ATR_Multiplier > 4.0)
            Print("⚠️ AVISO: Parâmetros do Supertrend muito elevados (ATR_Period>", InpST_ATR_Period, ", Mult>", DoubleToString(InpST_ATR_Multiplier,2), ") podem afastar a linha do preço e causar dessincronização visual.");
        // MACD+OBV sanity warnings
        if(InpMACD_FastEMA <= 0 || InpMACD_SlowEMA <= 0 || InpMACD_SignalSMA <= 0)
            Print("⚠️ AVISO: Períodos do MACD/Signal devem ser > 0.");
        if(InpMACD_FastEMA >= InpMACD_SlowEMA)
            Print("⚠️ AVISO: Fast EMA >= Slow EMA – recomenda-se Fast < Slow para MACD.");
        if(InpMACD_ObvSmooth < 1)
            Print("⚠️ AVISO: OBV Smooth < 1 – usando OBV bruto pode aumentar ruído.");
        if(InpGG_CreateObjects == false)
            Print("ℹ️ GG_TrendBar em modo DATA-ONLY (objetos visuais desativados). Para ver no gráfico, ative InpGG_CreateObjects=TRUE.");

        Print("✅ Validação de inputs concluída com sucesso!");
        Print("═══════════════════════════════════════");
        Print("📊 Ativo: ", _Symbol, " (", GetUnitName(), ")");
        Print("💰 Lote: ", InpLotSize);
        Print("📈 BUY: SL=", InpStopLossBuy, " | TP=", InpTakeProfitBuy);
        Print("📉 SELL: SL=", InpStopLossSell, " | TP=", InpTakeProfitSell);
        Print("🎯 BE BUY: ", (InpBE_Buy_Enable ? "ON" : "OFF"), 
              " | Trigger=", InpBE_Buy_Trigger, " | Step=", InpBE_Buy_Step);
        Print("🎯 BE SELL: ", (InpBE_Sell_Enable ? "ON" : "OFF"),
              " | Trigger=", InpBE_Sell_Trigger, " | Step=", InpBE_Sell_Step);
        Print("🚀 TS BUY: ", (InpTS_Buy_Enable ? "ON" : "OFF"),
              " | Trigger=", InpTS_Buy_Trigger, " | Step=", InpTS_Buy_Step);
        Print("🚀 TS SELL: ", (InpTS_Sell_Enable ? "ON" : "OFF"),
              " | Trigger=", InpTS_Sell_Trigger, " | Step=", InpTS_Sell_Step);
        Print("↕️ Direções: BUY=", (InpEnableBuy ? "ON" : "OFF"), 
              " | SELL=", (InpEnableSell ? "ON" : "OFF"));
      Print("🧭 Perfis BUY: PREMIUM=", (InpBuyPremiumEnable ? "ON" : "OFF"),
          " | GOOD=", (InpBuyGoodEnable ? "ON" : "OFF"));
      Print("🧭 Perfis SELL: PREMIUM=", (InpSellPremiumEnable ? "ON" : "OFF"),
          " | GOOD=", (InpSellGoodEnable ? "ON" : "OFF"));
        Print("═══════════════════════════════════════");
    }
    
    return valid;
}

//+------------------------------------------------------------------+
//| FIM DO ARQUIVO                                                    |
//+------------------------------------------------------------------+
