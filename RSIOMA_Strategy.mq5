//+------------------------------------------------------------------+
//|                                              RSIOMA_Strategy.mq5 |
//|                                                   Trader_creador |
//|  https://youtu.be/L7rWkOIcm7c?list=PLKgAAPnBsSIHODJbuIykPf5L9yta |
//+------------------------------------------------------------------+
#property copyright "Franc Pérez"
#property link      "https://francperez.com"
#property version   "1.00"

#include <Trade\Trade.mqh>;
CTrade trade;

input int      LOTAJE = 1;
input int      TAKEPROFIT=25;
input int      STOPLOSS=100;
input int      ATR_PERIOD=13;
input double   ATR_FACTOR=1.5;
input int      ADX_PERIOD=14;
input int      ADX_UMBRAL=25;


// Handlers
int handlerRSIOMA;
int handlerATR;
int handlerADX;

// Buffers
double rsioma[10];
double rsioma_mean[10];
double atr[10];
double adx[10];
double plusdi[10];
double minusdi[10];

// Variables
int current_order_direction = 0;
datetime previous_candle_open_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   handlerRSIOMA = iCustom(_Symbol,PERIOD_CURRENT,"Custom/RSIOMA");
   handlerATR = iATR(_Symbol, PERIOD_CURRENT, ATR_PERIOD);
   handlerADX = iADX(_Symbol,PERIOD_CURRENT,ADX_PERIOD);
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
   CopyBuffer(handlerRSIOMA,0,0,10,rsioma);
   CopyBuffer(handlerRSIOMA,3,0,10,rsioma_mean);
   CopyBuffer(handlerADX,0,0,10,adx);
   CopyBuffer(handlerADX,1,0,10,plusdi);
   CopyBuffer(handlerADX,2,0,10,minusdi);

   bool active_position = PositionSelect(_Symbol);

   if(active_position==false && isSameBar()==false)
     {

      // RSIOMA crosses above 80 - BUY SIGNAL 
      if(rsioma[2] < 80 && rsioma[1] > 80 && rsioma_mean[1] > 50 && adx[1] > ADX_UMBRAL)
        {
         // BUY ORDER
         double sl = NormalizeDouble((SymbolInfoDouble(_Symbol,SYMBOL_ASK) - STOPLOSS), Digits());
         double tp = NormalizeDouble((SymbolInfoDouble(_Symbol,SYMBOL_ASK) + TAKEPROFIT), Digits());
         trade.Buy(LOTAJE,_Symbol,SymbolInfoDouble(_Symbol,SYMBOL_ASK),sl,NULL,"BUY ORDER");
         current_order_direction = 1;
        }

      // RSIOMA crosses below 20 - SELL SIGNAL
      if(rsioma[2] > 20 && rsioma[1] < 20 && rsioma_mean[1] < 50 && adx[1] > ADX_UMBRAL)
        {
         // SELL ORDER
         double sl = NormalizeDouble((SymbolInfoDouble(_Symbol,SYMBOL_BID) + STOPLOSS), Digits());
         double tp = NormalizeDouble((SymbolInfoDouble(_Symbol,SYMBOL_BID) - TAKEPROFIT), Digits());
         trade.Sell(LOTAJE,_Symbol,SymbolInfoDouble(_Symbol,SYMBOL_BID),sl,NULL,"SELL ORDER");
         current_order_direction = -1;
        }

     }
   else
     {
      TrailingStop(STOPLOSS);
      //TrailingStopBasedOnATR(ATR_FACTOR,atr[1]);
      
      
      // Exit long
      /*
      if (current_order_direction == 1) {
         current_order_direction = 0;

         if (plusdi[1] > adx[1] || plusdi[0] < adx[0]) {
            trade.PositionClose(_Symbol);
         }
      }

      // Exit short
      if (current_order_direction == -1) {
         current_order_direction = 0;

         if (minusdi[1] > adx[1] || minusdi[0] < adx[0]) {
            trade.PositionClose(_Symbol);
         }
      }*/
     }
  }
//+------------------------------------------------------------------+

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
//| Update trailing stop                                             |
//+------------------------------------------------------------------+
void TrailingStop(int stoploss)
  {
// Check all open positions
   for(int i = 0; i < PositionsTotal(); i++)
     {
      // Get the position ticket
      ulong ticket = PositionGetTicket(i);
      // Get the position details
      if(PositionSelectByTicket(ticket))
        {
         double stopLoss = PositionGetDouble(POSITION_SL);
         double takeProfit = PositionGetDouble(POSITION_TP);
         double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double trailingStop = 0;

         // Check if the position is a buy or sell
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            // Calculate the trailing stop for a buy position
            trailingStop = NormalizeDouble((currentPrice - stoploss), Digits());
            // Update the stop loss if the new trailing stop is higher than the current stop loss
            if(stopLoss < trailingStop && trailingStop < currentPrice)
              {
               bool flag_1 = trade.PositionModify(ticket, trailingStop, takeProfit);
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
               trailingStop = NormalizeDouble((currentPrice + stoploss), Digits());
               // Update the stop loss if the new trailing stop is lower than the current stop loss
               if(stopLoss > trailingStop && trailingStop > currentPrice)
                 {
                  // Modify the position with the new stop loss
                  bool flag_2 = trade.PositionModify(ticket, trailingStop, takeProfit);
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
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate the ATR and update trailing stop                       |
//+------------------------------------------------------------------+
void TrailingStopBasedOnATR(double atrMultiplier, double atrValue)
  {

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