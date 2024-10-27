//+------------------------------------------------------------------+
//|                                                GoldBuyFriday.mq5 |
//|                                         F&F Trading Applications |
//|                                       https://www.francperez.com |
//+------------------------------------------------------------------+
#property copyright "F&F Trading Applications"
#property link      "https://www.francperez.com"
#property version   "1.00"

#include <Trade\Trade.mqh>;
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
COrderInfo order;
CPositionInfo Posicion;
CTrade trade;

//--- input parameters
input int      load = 5;
input int      takeprofit = 50;
input bool     TPActive = false;
input int      stoploss = 30;
input bool     SLActive = false;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(60);
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   MqlDateTime time;
   TimeTradeServer(time);
   bool filter1 = iClose(_Symbol,PERIOD_D1,1) < iClose(_Symbol,PERIOD_D1,2);
   //bool filter2 = iClose(_Symbol,PERIOD_D1,4) < iOpen(_Symbol,PERIOD_D1,4);
   double protectionprice = NULL;
   if (SLActive) {
      protectionprice = NormalizePrice(SymbolInfoDouble(_Symbol,SYMBOL_LAST) - stoploss);
   } else {
      protectionprice = NULL;
   }
   double profitprice = NULL;
   if (TPActive) {
      profitprice = NormalizePrice(SymbolInfoDouble(_Symbol,SYMBOL_LAST) + takeprofit);
   } else {
      profitprice = NULL;
   }
   
   if (filter1 && !PositionSelect(_Symbol) && time.day_of_week == 5 && time.hour == 1) {
      //Sell on NG
      trade.Buy(load,_Symbol,SymbolInfoDouble(_Symbol,SYMBOL_LAST),protectionprice,profitprice,"Sell order");
   }
   
   if (PositionSelect(_Symbol) && time.day_of_week == 5 && time.hour == 17) {
      // Close positions
      trade.PositionClose(_Symbol);
   }
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
  {
   double m_tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return(NormalizeDouble(MathRound(price/m_tick_size)*m_tick_size,_Digits));
  }