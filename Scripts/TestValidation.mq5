//+------------------------------------------------------------------+
//| Script para testar validação de parâmetros                      |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

// Simular parâmetros do EA
input double AccountRiskPercent = 1.5;
input double MaxRiskPremium = 2.0;
input double MaxDrawdownPercent = 15.0;
input int MaxSimultaneousTrades = 3;

input double SL_BufferPoints = 5.0;
input double SL_FallbackPercent = 0.3;
input double SL_MinDistancePoints = 20.0;
input double SL_MaxDistancePoints = 500.0;
input bool SL_UseStructure = true;

input bool EnablePartialTP = true;
input double TP1_RR = 1.0;
input double TP2_RR = 2.0;
input double TP3_RR = 3.0;
input bool UseTP3 = false;
input double TP1_ClosePercent = 50.0;
input double TP2_ClosePercent = 30.0;
input double TP3_ClosePercent = 20.0;

input bool UseCustomTradingHours = true;
input int CustomStartHour = 0;
input int CustomStartMinute = 0;
input int CustomEndHour = 23;
input int CustomEndMinute = 59;

//+------------------------------------------------------------------+
void OnStart()
{
   Print("════════════════════════════════════════════");
   Print("🧪 TESTE DE VALIDAÇÃO DE PARÂMETROS");
   Print("════════════════════════════════════════════");
   
   bool allValid = true;
   
   // Teste 1: Riscos básicos
   Print("\n📊 Teste 1: Riscos básicos");
   if(AccountRiskPercent <= 0 || AccountRiskPercent > 10)
   {
      PrintFormat("❌ AccountRiskPercent inválido: %.2f", AccountRiskPercent);
      allValid = false;
   }
   else
      PrintFormat("✅ AccountRiskPercent: %.2f", AccountRiskPercent);
   
   if(MaxRiskPremium <= 0 || MaxRiskPremium > 10)
   {
      PrintFormat("❌ MaxRiskPremium inválido: %.2f", MaxRiskPremium);
      allValid = false;
   }
   else
      PrintFormat("✅ MaxRiskPremium: %.2f", MaxRiskPremium);
   
   // Teste 2: Stop Loss
   Print("\n🛑 Teste 2: Stop Loss");
   if(SL_BufferPoints < 0 || SL_BufferPoints > 1000)
   {
      PrintFormat("❌ SL_BufferPoints inválido: %.1f", SL_BufferPoints);
      allValid = false;
   }
   else
      PrintFormat("✅ SL_BufferPoints: %.1f", SL_BufferPoints);
   
   if(SL_MinDistancePoints < 0 || SL_MinDistancePoints > 10000)
   {
      PrintFormat("❌ SL_MinDistancePoints inválido: %.1f", SL_MinDistancePoints);
      allValid = false;
   }
   else
      PrintFormat("✅ SL_MinDistancePoints: %.1f", SL_MinDistancePoints);
   
   if(SL_MaxDistancePoints < SL_MinDistancePoints || SL_MaxDistancePoints > 50000)
   {
      PrintFormat("❌ SL_MaxDistancePoints inválido: %.1f (Min: %.1f)", SL_MaxDistancePoints, SL_MinDistancePoints);
      allValid = false;
   }
   else
      PrintFormat("✅ SL_MaxDistancePoints: %.1f", SL_MaxDistancePoints);
   
   // Teste 3: Take Profit
   Print("\n🎯 Teste 3: Take Profit");
   if(TP1_RR < 0.1 || TP1_RR > 20)
   {
      PrintFormat("❌ TP1_RR inválido: %.2f", TP1_RR);
      allValid = false;
   }
   else
      PrintFormat("✅ TP1_RR: %.2f", TP1_RR);
   
   if(TP2_RR < TP1_RR || TP2_RR > 20)
   {
      PrintFormat("❌ TP2_RR inválido: %.2f (TP1: %.2f)", TP2_RR, TP1_RR);
      allValid = false;
   }
   else
      PrintFormat("✅ TP2_RR: %.2f", TP2_RR);
   
   if(UseTP3)
   {
      if(TP3_RR < TP2_RR || TP3_RR > 20)
      {
         PrintFormat("❌ TP3_RR inválido: %.2f (TP2: %.2f)", TP3_RR, TP2_RR);
         allValid = false;
      }
      else
         PrintFormat("✅ TP3_RR: %.2f", TP3_RR);
   }
   
   // Teste 4: CRÍTICO - Percentuais
   Print("\n📊 Teste 4: Percentuais de fechamento");
   if(EnablePartialTP)
   {
      double totalClosePercent = TP1_ClosePercent + TP2_ClosePercent;
      if(UseTP3)
         totalClosePercent += TP3_ClosePercent;
      
      PrintFormat("   TP1: %.1f%%", TP1_ClosePercent);
      PrintFormat("   TP2: %.1f%%", TP2_ClosePercent);
      if(UseTP3)
         PrintFormat("   TP3: %.1f%%", TP3_ClosePercent);
      PrintFormat("   TOTAL: %.1f%%", totalClosePercent);
      
      if(totalClosePercent < 90 || totalClosePercent > 110)
      {
         PrintFormat("❌ Soma inválida: %.1f%% (deve ser 90-110%%)", totalClosePercent);
         allValid = false;
      }
      else
         PrintFormat("✅ Soma válida: %.1f%%", totalClosePercent);
   }
   
   // Teste 5: Horários
   Print("\n⏰ Teste 5: Horários");
   if(UseCustomTradingHours)
   {
      if(CustomStartHour < 0 || CustomStartHour > 23)
      {
         PrintFormat("❌ CustomStartHour inválido: %d", CustomStartHour);
         allValid = false;
      }
      else
         PrintFormat("✅ CustomStartHour: %d", CustomStartHour);
      
      if(CustomEndHour < 0 || CustomEndHour > 23)
      {
         PrintFormat("❌ CustomEndHour inválido: %d", CustomEndHour);
         allValid = false;
      }
      else
         PrintFormat("✅ CustomEndHour: %d", CustomEndHour);
      
      if(CustomStartMinute < 0 || CustomStartMinute > 59)
      {
         PrintFormat("❌ CustomStartMinute inválido: %d", CustomStartMinute);
         allValid = false;
      }
      else
         PrintFormat("✅ CustomStartMinute: %d", CustomStartMinute);
      
      if(CustomEndMinute < 0 || CustomEndMinute > 59)
      {
         PrintFormat("❌ CustomEndMinute inválido: %d", CustomEndMinute);
         allValid = false;
      }
      else
         PrintFormat("✅ CustomEndMinute: %d", CustomEndMinute);
   }
   
   Print("\n════════════════════════════════════════════");
   if(allValid)
      Print("✅✅✅ TODOS OS PARÂMETROS VÁLIDOS! ✅✅✅");
   else
      Print("❌❌❌ ALGUNS PARÂMETROS INVÁLIDOS! ❌❌❌");
   Print("════════════════════════════════════════════");
}
