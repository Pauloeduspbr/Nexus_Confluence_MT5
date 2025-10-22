//+------------------------------------------------------------------+
//| WaddahAttarExplosion_Professional.mq5 v2.2 ROBUSTO              |
//| WAE usando iMACD + iBands nativos - SEM ERROS                   |
//| CORREÇÃO: Retry logic + validação inteligente de buffers        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Adaptive Flow Systems"
#property link      "https://adaptiveflow.systems"
#property version   "2.20"
#property strict

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots 4
#property indicator_minimum 0
#property indicator_maximum 10

#property indicator_label1  "Trend Up"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrLime
#property indicator_width1  2

#property indicator_label2  "Trend Down"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrRed
#property indicator_width2  2

#property indicator_label3  "Explosion Line"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_width3  2
#property indicator_style3  STYLE_SOLID

#property indicator_label4  "Dead Zone"
#property indicator_type4   DRAW_NONE

// Níveis de referência - Zero Line
#property indicator_level1  0.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT
#property indicator_levelwidth 1

input int InpFastMA = 20;
input int InpSlowMA = 40;
input int InpBBLength = 20;
input double InpBBMultiplier = 2.0;
input int InpSensitivity = 150;

double g_buf_trend_up[];
double g_buf_trend_down[];
double g_buf_explosion_line[];
double g_buf_dead_zone[];

int g_handle_macd = INVALID_HANDLE;
int g_handle_bb = INVALID_HANDLE;

int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("WAE [Fast:%d | Slow:%d | Sens:%d]", 
                                                        InpFastMA, InpSlowMA, InpSensitivity));

   SetIndexBuffer(0, g_buf_trend_up, INDICATOR_DATA);
   SetIndexBuffer(1, g_buf_trend_down, INDICATOR_DATA);
   SetIndexBuffer(2, g_buf_explosion_line, INDICATOR_DATA);
   SetIndexBuffer(3, g_buf_dead_zone, INDICATOR_DATA);

   ArraySetAsSeries(g_buf_trend_up, true);
   ArraySetAsSeries(g_buf_trend_down, true);
   ArraySetAsSeries(g_buf_explosion_line, true);
   ArraySetAsSeries(g_buf_dead_zone, true);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // Criar handles nativos
   g_handle_macd = iMACD(_Symbol, PERIOD_CURRENT, InpFastMA, InpSlowMA, 9, PRICE_CLOSE);
   g_handle_bb = iBands(_Symbol, PERIOD_CURRENT, InpBBLength, 0, InpBBMultiplier, PRICE_CLOSE);

   if(g_handle_macd == INVALID_HANDLE || g_handle_bb == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create WAE indicator handles");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(g_handle_macd != INVALID_HANDLE) IndicatorRelease(g_handle_macd);
   if(g_handle_bb != INVALID_HANDLE) IndicatorRelease(g_handle_bb);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if(rates_total < InpSlowMA)
        return 0;

    //--- 🔥 v2.1: Determinar quantas barras calcular
    int limit;
    if(prev_calculated == 0)
    {
        // Primeira execução: calcular todas as barras
        limit = rates_total - InpSlowMA;  // Começar de onde temos dados suficientes
        // Inicializar buffers
        ArrayInitialize(g_buf_trend_up, 0.0);
        ArrayInitialize(g_buf_trend_down, 0.0);
        ArrayInitialize(g_buf_explosion_line, EMPTY_VALUE);
        ArrayInitialize(g_buf_dead_zone, 0.0);
    }
    else if(prev_calculated == rates_total)
    {
        // Tick no candle atual: recalcular apenas [0]
        limit = 0;
    }
    else
    {
        // Novo candle: calcular desde a última barra calculada
        limit = rates_total - prev_calculated;
    }
    
    //--- 🔥 Calcular barras necessárias para CopyBuffer
    // Precisamos de dados suficientes para calcular os indicadores base
    int bars_to_copy = limit + InpSlowMA + 10;  // +10 segurança extra
    if(bars_to_copy > rates_total) bars_to_copy = rates_total;
    if(bars_to_copy < InpSlowMA) bars_to_copy = InpSlowMA;
    
    //--- Arrays temporários
    double macd_main[], macd_signal[], bb_upper[], bb_lower[];
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    ArraySetAsSeries(bb_upper, true);
    ArraySetAsSeries(bb_lower, true);

    //--- 🔥 Copiar buffers com retry (indicadores podem não estar prontos)
    int copy_result = 0;
    int max_attempts = 3;
    
    for(int attempt = 0; attempt < max_attempts; attempt++)
    {
        copy_result = CopyBuffer(g_handle_macd, 0, 0, bars_to_copy, macd_main);
        if(copy_result > 0) break;
        Sleep(10);  // Aguardar indicador ficar pronto
    }
    if(copy_result <= 0)
        return prev_calculated;  // Retornar prev para tentar novamente no próximo tick
    
    for(int attempt = 0; attempt < max_attempts; attempt++)
    {
        copy_result = CopyBuffer(g_handle_macd, 1, 0, bars_to_copy, macd_signal);
        if(copy_result > 0) break;
        Sleep(10);
    }
    if(copy_result <= 0)
        return prev_calculated;
    
    for(int attempt = 0; attempt < max_attempts; attempt++)
    {
        copy_result = CopyBuffer(g_handle_bb, 1, 0, bars_to_copy, bb_upper);
        if(copy_result > 0) break;
        Sleep(10);
    }
    if(copy_result <= 0)
        return prev_calculated;
    
    for(int attempt = 0; attempt < max_attempts; attempt++)
    {
        copy_result = CopyBuffer(g_handle_bb, 2, 0, bars_to_copy, bb_lower);
        if(copy_result > 0) break;
        Sleep(10);
    }
    if(copy_result <= 0)
        return prev_calculated;

    //--- Validar tamanho mínimo dos arrays copiados
    int min_required = InpSlowMA;
    if(ArraySize(macd_main) < min_required || 
       ArraySize(macd_signal) < min_required ||
       ArraySize(bb_upper) < min_required || 
       ArraySize(bb_lower) < min_required)
    {
        // Dados insuficientes, mas não é erro fatal - aguardar próximo tick
        return prev_calculated;
    }

    //--- 🔥 LOOP CORRETO: De limit até 0 (mais recente para mais antigo)
    for(int i = limit; i >= 0; i--)
    {
        //--- Garantir que índices estão dentro dos limites de TODOS os arrays
        if(i >= ArraySize(macd_main) || 
           i >= ArraySize(macd_signal) ||
           i >= ArraySize(bb_upper) || 
           i >= ArraySize(bb_lower))
        {
            continue;  // Pular esta barra
        }

        //--- MACD Histogram
        double histogram = macd_main[i] - macd_signal[i];

        //--- Trend Power
        double trend_power = histogram * InpSensitivity;

        //--- Preencher buffers Up/Down
        if(trend_power >= 0)
        {
            g_buf_trend_up[i] = trend_power;
            g_buf_trend_down[i] = 0.0;
        }
        else
        {
            g_buf_trend_up[i] = 0.0;
            g_buf_trend_down[i] = MathAbs(trend_power);
        }

        //--- Explosion Line
        double bb_width = bb_upper[i] - bb_lower[i];
        g_buf_explosion_line[i] = (bb_width * InpSensitivity) / 50.0;

        //--- Dead Zone
        if(g_buf_trend_up[i] < g_buf_explosion_line[i] && 
           g_buf_trend_down[i] < g_buf_explosion_line[i])
        {
            g_buf_dead_zone[i] = 1.0;
        }
        else
        {
            g_buf_dead_zone[i] = 0.0;
        }
    }

    return(rates_total);
}