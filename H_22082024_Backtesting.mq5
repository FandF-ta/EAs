//+------------------------------------------------------------------+
//|                                                   H_22082024.mq5 |
//|                         Copyright 2024, F&F Trading Applications |
//|                                      https://www.francperez.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, F&F Trading Applications"
#property link      "https://www.francperez.com/"
#property version   "1.00"

#include <Trade\Trade.mqh>;
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
COrderInfo order;
CPositionInfo Posicion;
CTrade trade;

ENUM_TIMEFRAMES tf = PERIOD_M1;
string ticker = "SI_Z";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   string terminal_data_path=TerminalInfoString(TERMINAL_DATA_PATH);
   string filename=terminal_data_path+"\\MQL5\\Files\\SI_H22082024_Output_Data.csv";
   int filehandle=FileOpen(filename,FILE_READ|FILE_CSV, ',');
   if(filehandle!=INVALID_HANDLE)
     {
      PrintFormat("%s file is available for reading",filename);
      PrintFormat("File path: %s\\Files\\",TerminalInfoString(TERMINAL_DATA_PATH));
      //--- close the file
      FileClose(filehandle);
      PrintFormat("Data is read, %s file is closed",filename);
     }
   else
      PrintFormat("Failed to open %s file, Error code = %d",filename,GetLastError());
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   MqlDateTime temp_now;
   TimeCurrent(temp_now);

   if(temp_now.hour == 0 && temp_now.min == 00 && temp_now.sec == 01)
     {
     
      
     }
  }

//+------------------------------------------------------------------+