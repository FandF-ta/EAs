//+------------------------------------------------------------------+
//|                                           Ivan_Scherman_2024.mq5 |
//|                                                      Franc Pérez |
//|                                     https://youtu.be/BrZu7SEuBmk |
//+------------------------------------------------------------------+
#property copyright "Franc Pérez"
#property link      "https://youtu.be/BrZu7SEuBmk"
#property version   "1.00"

#include <Trade\Trade.mqh>;
CTrade trade;

//--- input parameters
input double   LOTAJE=1.0;
input int      TAKEPROFIT=100;
input int      STOPLOSS=100;
input int      FASTEMA=25; //FASTEMA (25 Optimised)
input int      SLOWSMA=228; //SLOWSMA (228 Optimised)
input int      BACK_BARS=3;
input int      ATR_PERIOD=13;
input double   ATR_FACTOR=1.5;

// Handlers
int handlerSLOWSMA;
int handlerFASTEMA;
int handlerATR;
int handlerBB;
int handlerRSI;

// Buffers
double slowsma[10];
double fastema[10];
double atr[10];
double bbhigh[10];
double bblow[10];
double rsi[10];

// Flags
datetime previous_candle_open_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   handlerFASTEMA = iMA(_Symbol,PERIOD_CURRENT,FASTEMA,0,MODE_EMA,PRICE_CLOSE);
   handlerSLOWSMA = iMA(_Symbol,PERIOD_CURRENT,SLOWSMA, 0,MODE_SMA, PRICE_CLOSE);
   handlerATR = iATR(Symbol(), Period(), ATR_PERIOD);
   handlerBB = iBands(_Symbol,PERIOD_CURRENT,20,0,2.718,PRICE_CLOSE);
   handlerRSI = iRSI(_Symbol,PERIOD_CURRENT,2,PRICE_CLOSE);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   CopyBuffer(handlerFASTEMA,0,0,10,fastema);
   CopyBuffer(handlerSLOWSMA,0,0,10,slowsma);
   CopyBuffer(handlerATR,0,0,10,atr);
   CopyBuffer(handlerBB,1,0,10,bbhigh);
   CopyBuffer(handlerBB,2,0,10,bblow);
   CopyBuffer(handlerRSI,0,0,10,rsi);
   double curr_close = iClose(_Symbol,PERIOD_CURRENT,0);
   double prev_close = iClose(_Symbol,PERIOD_CURRENT,1);

   bool active_order = PositionSelect(_Symbol);
   
   if (active_order == false && isSameBar()==false) {
         if (curr_close > slowsma[0] && checkPreviousBars(BACK_BARS)==true) {
            // TENDENCIA ALCISTA
            trade.Buy(LOTAJE,_Symbol,SymbolInfoDouble(_Symbol,SYMBOL_ASK),NULL,NULL,"Order BUY");
         }
   } else {
      if (curr_close >= fastema[0] || curr_close < slowsma[0]) {
         trade.PositionClose(_Symbol);
      }
      //TrailingStopBasedOnATR();
   }
  }
//+------------------------------------------------------------------+

bool checkPreviousBars(int num_bars) {
   
   double close1 = iClose(_Symbol,PERIOD_CURRENT,1);
   double close2 = iClose(_Symbol,PERIOD_CURRENT,2);
   double close3 = iClose(_Symbol,PERIOD_CURRENT,3);
   
   double open1 = iOpen(_Symbol,PERIOD_CURRENT,1);
   double open2 = iOpen(_Symbol,PERIOD_CURRENT,2);
   double open3 = iOpen(_Symbol,PERIOD_CURRENT,3);
   
   bool flag1 = close1 < open1;
   bool flag2 = close2 < open2;
   bool flag3 = close3 < open3;
   
   if (flag1==true && flag2==true && flag3==true) {
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isSameBar()
  {
// Obtener la hora de apertura de la vela actual
   datetime current_candle_open_time = iTime(_Symbol, PERIOD_CURRENT, 0);

// Comparar la hora de apertura de la vela actual con la de la iteración anterior
   if(current_candle_open_time == previous_candle_open_time)
     {
      return true;
     }
   else
     {
      // Actualizar la variable global con la hora de apertura de la vela actual
      previous_candle_open_time = current_candle_open_time;
      return false;
     }
  }
  
//+------------------------------------------------------------------+
//| Calculate the ATR and update trailing stop                       |
//+------------------------------------------------------------------+
void TrailingStopBasedOnATR()
  {
// Define ATR parameters
   double atrMultiplier = ATR_FACTOR;  // Multiplier for the ATR value

// Get the current ATR value
   double atrValue = atr[0];

// Check all open positions
   for(int i = 0; i < PositionsTotal(); i++)
     {
      // Get the position ticket
      ulong ticket = PositionGetTicket(i);
      // Get the position details
      if(PositionSelectByTicket(ticket))
        {
         double stopLoss = PositionGetDouble(POSITION_SL);
         double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double trailingStop = 0;

         // Check if the position is a buy or sell
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            // Calculate the trailing stop for a buy position
            trailingStop = NormalizeDouble((currentPrice - atrValue * atrMultiplier), Digits());
            // Update the stop loss if the new trailing stop is higher than the current stop loss
            if(stopLoss < trailingStop && trailingStop < currentPrice)
              {
               bool flag_1 = trade.PositionModify(ticket, trailingStop, NULL);
               // Modify the position with the new stop loss
               if(flag_1 == false)
                 {
                  Print("Error modifying position: ", GetLastError());
                 }
              }
           }
         else
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               // Calculate the trailing stop for a sell position
               trailingStop = NormalizeDouble((currentPrice + atrValue * atrMultiplier), Digits());
               // Update the stop loss if the new trailing stop is lower than the current stop loss
               if(stopLoss > trailingStop && trailingStop > currentPrice)
                 {
                  // Modify the position with the new stop loss
                  bool flag_2 = trade.PositionModify(ticket, trailingStop, NULL);
                  if(flag_2 == false)
                    {
                     Print("Error modifying position: ", GetLastError());
                    }
                 }
              }
        }
     }
  }
//+------------------------------------------------------------------+