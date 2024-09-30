//+------------------------------------------------------------------+
//|                                                   H_22082024.mq5 |
//|                         Copyright 2024, F&F Trading Applications |
//|                                      https://www.francperez.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, F&F Trading Applications"
#property link      "https://www.francperez.com/"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <DKSimplestCSVReader.mqh>
COrderInfo order;
CPositionInfo Posicion;
CTrade trade;
CDKSimplestCSVReader CSVFile;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string terminal_data_path=TerminalInfoString(TERMINAL_DATA_PATH);
string Filename=terminal_data_path+"\\MQL5\\Files\\poc_phf_gc.csv";
//string Filename = "C:\Users\iamfr\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Files\poc_phf_gc.csv";

string ticker = "GC_Z";

datetime date[];
double poc[];
double phf[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
// Read file pass FILE_ANSI for ANSI files or another flag for another codepage.
// Give values separator and flag of 1sr line header in the file
   ReadCSVToArrays("MQL5\\Files\\poc_phf_gc.csv",date,poc,phf);
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

   if(temp_now.hour == 1 && temp_now.min == 00 && temp_now.sec == 00)
     {

     }
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ReadCSVToArrays(string file_name, datetime &col1[], double &col2[], double &col3[])
  {
// Open the CSV file for reading
   int file_handle = FileOpen(file_name, FILE_READ | FILE_CSV, ",");

   if(file_handle == INVALID_HANDLE)
     {
      int error_code = _LastError;
      Print("Failed to open file. Error code: ", error_code,", Filename: ", file_name);
      return;
     }

// Reset array sizes
   ArrayResize(col1, 0);
   ArrayResize(col2, 0);
   ArrayResize(col3, 0);

// Loop through the file until the end
   while(!FileIsEnding(file_handle))
     {
      // Read each column value and add to corresponding arrays
      datetime value1 = FileReadDatetime(file_handle);
      double value2 = FileReadNumber(file_handle);
      double value3 = FileReadNumber(file_handle);

      // Append to arrays
      int current_size = ArraySize(col1);
      ArrayResize(col1, current_size + 1);
      ArrayResize(col2, current_size + 1);
      ArrayResize(col3, current_size + 1);

      col1[current_size] = value1;
      col2[current_size] = value2;
      col3[current_size] = value3;
     }

// Close the file after reading
   FileClose(file_handle);
  }
//+------------------------------------------------------------------+
