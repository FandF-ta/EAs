//+------------------------------------------------------------------+
//|                                           RSIOMA_RangeRetest.mq5 |
//|                                         F&F Trading Applications |
//|                                       https://www.francperez.com |
//+------------------------------------------------------------------+
#property copyright "F&F Trading Applications"
#property link      "https://www.francperez.com"
#property version   "1.00"

#include <Trade\Trade.mqh>;
CTrade trade;

input int   LOTAJE = 1;
// Flags
//int direction = 0;
double current_range_high = 0;
double current_range_low = 0;
//bool isRageDefined = false;
// Handlers
int handlerRSIOMA;
// Buffers
double rsioma[];
// Variables
int current_order_direction = 0;
datetime previous_candle_open_time = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   ArraySetAsSeries(rsioma, true);

   handlerRSIOMA = iCustom(_Symbol,PERIOD_CURRENT,"Custom/RSIOMA");
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
// Configuración de entrada


// calculo del rango de RSIOMA
   ArrayResize(rsioma,5);
   CopyBuffer(handlerRSIOMA, 0, 0, 5, rsioma);

   double now_close = iClose(_Symbol,PERIOD_CURRENT,0);
   double now_high = iHigh(_Symbol,PERIOD_CURRENT,1);
   double now_low = iLow(_Symbol,PERIOD_CURRENT,1);

   if(rsioma[1] < 80 && rsioma[1] > 20)
     {
      if(current_range_high < now_high)
        {
         current_range_high = now_high; // Definimos el nuevo alto del rango, si es mayor que el existente.
        }
      if(current_range_low != 0 && current_range_low > now_low)
        {
         current_range_low = now_low; // Definimos el nuevo bajo del rango, si es menor que el existente.
        }
     }
   if(now_close < current_range_high && rsioma[0] > 80 && current_range_high != 0 && current_range_low != 0)
     {
      trade.Buy(LOTAJE,_Symbol,now_close,current_range_low,current_range_high,"BUY Order");
      current_range_high = 0;
      current_range_low = 0;
     }
   if(now_close > current_range_low && rsioma[0] < 20 && current_range_high != 0 && current_range_low != 0)
     {
      trade.Sell(LOTAJE,_Symbol,now_close,current_range_high,current_range_low,"SELL Order");
      current_range_high = 0;
      current_range_low = 0;
     }


  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

  }
//+------------------------------------------------------------------+
