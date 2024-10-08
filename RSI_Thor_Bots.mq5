//+------------------------------------------------------------------+
//|                                                RSI_Thor_Bots.mq5 |
//|                                                   Trader_creador |
//|  https://youtu.be/L7rWkOIcm7c?list=PLKgAAPnBsSIHODJbuIykPf5L9yta |
//+------------------------------------------------------------------+
#property copyright "Trader_creador"
#property link      "https://youtu.be/L7rWkOIcm7c?list=PLKgAAPnBsSIHODJbuIykPf5L9yta"
#property version   "1.00"

#include <Trade\Trade.mqh>;
#include <Trade\OrderInfo.mqh>
CTrade trade;
COrderInfo order;

datetime previous_candle_open_time = 0;
datetime last_open_trade_time = 0;

// Inputs

double input   LOTAJE = 1.0;  // Lotaje de las operaciones
int input      RSI_PERIOD = 13; // Periodo de RSI
int input      RSI_LOW = 30;
int input      RSI_HIGH = 70;
double input   MAX_PROFIT = 2.0;
double input   MAX_LOSS = -4.00;

// Handlers
int handlerRSI;

// Buffers
double rsi[10];

// Flags
bool flagRSI = false;
int direction = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   handlerRSI = iRSI(_Symbol,PERIOD_H1,RSI_PERIOD,PRICE_CLOSE);
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
   CopyBuffer(handlerRSI,0,0,10,rsi);
   
   //bool active_order = PositionSelect(_Symbol);
   
   if (rsi[2] < RSI_LOW && rsi[1] > RSI_LOW && isTimeToTrade()==true && isSameBar()==false ) {
      // OPERA BUY
      trade.Buy(LOTAJE,_Symbol,SymbolInfoDouble(_Symbol,SYMBOL_ASK),NULL,NULL,"BUY");
      last_open_trade_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   } else if (rsi[2] > RSI_HIGH && rsi[1] < RSI_HIGH && isTimeToTrade()==true && isSameBar()==false) {
      // OPERA SELL
      trade.Sell(LOTAJE,_Symbol,SymbolInfoDouble(_Symbol,SYMBOL_BID),NULL,NULL,"SELL");
      last_open_trade_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   }
   
   
   double profit = CalculateProfit();
   if (profit >= MAX_PROFIT || profit <= MAX_LOSS) {
      CloseAllOpenPositions();
   }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                   CalculateProfit |
//|                        Calculates the total profit of open trades|
//+------------------------------------------------------------------+
double CalculateProfit() 
{
   /*
   double total_profit = 0.0;

   // Loop through all orders
   for(int i = 0; i < PositionsTotal(); i++)
   {
      // Select the order by its index
      if(PositionSelectByTicket(i))
      {
         // Check if the order is open (not closed or pending)
         if(PositionGetInteger(POSITION_TYPE) == ORDER_TYPE_BUY || PositionGetInteger(POSITION_TYPE) == ORDER_TYPE_SELL)
         {
            total_profit = total_profit + PositionGetDouble(POSITION_PROFIT); // Add the profit of the current order to the total profit
         }
      }
   }
   
   return total_profit; // Return the total profit
   */
   double total_profit = 0;
   for( int i = PositionsTotal() - 1; i >= 0; i-- )
   {
      if( PositionGetSymbol( i ) == _Symbol )
         total_profit += PositionGetDouble( POSITION_PROFIT );
   };
   
   return total_profit;
}

//+------------------------------------------------------------------+
//|                                            CloseAllOpenPositions |
//|                      Closes all open positions                   |
//+------------------------------------------------------------------+

void CloseAllOpenPositions()
{
   // Loop through all orders
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      // Select the order by its index
      if(PositionSelectByTicket(i))
      {
         // Check if the order is open (buy or sell position)
         long type = PositionGetInteger(POSITION_TYPE);
         if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL)
         {
            // Close the position
            if(trade.PositionClose(i))
            {
               Print("Order closed successfully");
            }
            else
            {
               Print("Failed to close order");
            }
         }
      }
   }
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
//| Analise if is trading period                                     |
//+------------------------------------------------------------------+
bool isTimeToTrade()
  {
// Obtener la hora de apertura de la vela actual
   datetime tmp = iTime(_Symbol, PERIOD_CURRENT, 0);
   datetime tmp2 = iTime(_Symbol,PERIOD_CURRENT,3);
   MqlDateTime date1;
   TimeToStruct(tmp, date1);

// Set conditions
   if(date1.hour >= 9 && date1.hour <= 18)
     {
      //if (tmp2 == last_open_trade_time) {
         return true;
      //}
     }
   return false;
}
