//+------------------------------------------------------------------+
//|                                                     MonEA1.mq5   |
//|                        Copyright 2024, MetaQuotes Ltd.           |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Range Breakout Asian Session EA for FundedNext"
#property strict

//--- Include files
#include "MonEA1_Config.mqh"
#include "MonEA1_Utils.mqh"
#include "MonEA1_Trade.mqh"
#include "MonEA1_Risk.mqh"
#include "MonEA1_Filters.mqh"

//--- Global variables
input string   EA_Name = "MonEA1";
input double   Magic_Number = 123456; // Unique EA identifier

//--- Session times (GMT)
input int      Asian_Start_Hour = 0;   // Asian session start hour (0 = midnight)
input int      Asian_End_Hour = 6;     // Asian session end hour
input int      London_Open_Hour = 8;   // London session open hour
input int      Valid_Break_End_Hour = 11; // End hour for valid breakouts

//--- Range calculation
input ENUM_TIMEFRAMES Range_TF = PERIOD_D1; // Timeframe for range analysis
input string   Range_Calc_Method = "Closed_Candles"; // Method: Closed_Candles
input int      Margin_Pips = 5; // Margin to filter noise in range
input double   Min_Range_Pips = 30.0; // Minimum range width in pips
input double   Max_Range_Pips = 120.0; // Maximum range width in pips

//--- Execution parameters
input ENUM_TIMEFRAMES Exec_TF = PERIOD_M30; // Timeframe for trade execution
input int      Max_Open_Trades = 1; // Maximum open trades at once
input int      Max_Trades_Per_Day = 3; // Maximum trades per day
input double   Min_Time_Between_Trades_Hrs = 1.0; // Minimum hours between trades

//--- Risk management
input double   Risk_Percent = 1.0; // Risk percentage per trade (0.5-1%)
input double   SL_Pips = 30.0; // Stop loss in pips
input double   TP_Pips = 60.0; // Take profit in pips (if fixed)
input string   Lot_Method = "EquityRisk"; // Lot sizing method
input double   Min_Lot = 0.01; // Minimum lot size
input double   Max_Lot = 5.0; // Maximum lot size

//--- Breakout confirmation
input int      ATR_Period = 14; // ATR period for volatility filter
input double   ATR_Mult_Min = 1.25; // Minimum ATR multiplier for breakout
input double   ATR_Mult_Max = 3.0; // Maximum ATR multiplier for breakout
input bool     Use_Volume_Confirm = true; // Enable volume confirmation
input int      Volume_Period = 20; // Period for volume SMA
input double   Volume_Mult_Threshold = 1.5; // Volume threshold multiplier

//--- Take profit and trailing stop
input string   TP_Method = "Dynamic_ATR"; // TP method: Dynamic_ATR or Fixed
input double   ATR_TP_Mult = 3.0; // Multiplier for dynamic TP based on ATR
input double   Fixed_RR = 1.5; // Fixed risk-reward ratio (if TP_Method = Fixed)
input bool     Use_Trailing_Stop = true; // Enable trailing stop
input string   Trail_Method = "ATR"; // Trailing method: ATR or Fixed
input double   Trail_Mult = 0.5; // Multiplier for ATR trailing
input double   Trail_Activation_PC = 50.0; // Activation after % of profit

//--- Filters
input bool     Use_Trend_Filter = true; // Enable trend filter
input string   Trend_Filter_Type = "EMA_ADX"; // Type: EMA_ADX or Strict_EMA
input int      EMA_Period = 200; // EMA period for trend filter
input ENUM_TIMEFRAMES EMA_TF = PERIOD_H1; // Timeframe for EMA
input int      ADX_Period = 14; // ADX period for trend strength
input double   ADX_Threshold = 20.0; // ADX threshold for strong trend

input bool     Use_Vol_Filter = true; // Enable volatility filter (Bollinger Bands)
input int      BB_Period = 20; // Bollinger Bands period
input double   BB_Dev = 2.0; // Bollinger Bands deviation

input bool     Use_News_Filter = true; // Enable news filter
input string   News_Filter_Type = "FFCal"; // Type: FFCal or Manual
input string   Impact_Level = "High"; // Impact level: High or Medium
input int      Pause_Before_Min = 60; // Minutes to pause before news
input int      Pause_After_Min = 30; // Minutes to pause after news

input bool     Weekend_Close = true; // Close trades before weekend
input int      Close_Hour_Fri = 21; // Hour to close on Friday (GMT)
input bool     Close_If_In_Profit = true; // Close only if in profit

input string   Allowed_Pairs = "EURUSD,GBPUSD,USDJPY"; // Allowed trading pairs
input double   Min_ATR_Pips = 20.0; // Minimum ATR in pips to trade
input double   Max_ATR_Pips = 150.0; // Maximum ATR in pips to trade

//--- Internal variables
double Asian_High, Asian_Low;
datetime Last_Trade_Time = 0;
double Daily_PnL = 0.0;
datetime Last_Daily_Reset = 0;
bool Is_Range_Break = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize utilities
   if(!Utils_Init())
      return INIT_FAILED;
   
   //--- Initialize trade module
   if(!Trade_Init(Magic_Number))
      return INIT_FAILED;
   
   //--- Initialize risk module
   if(!Risk_Init(Risk_Percent, Min_Lot, Max_Lot, Lot_Method))
      return INIT_FAILED;
   
   //--- Initialize filters
   if(!Filters_Init())
      return INIT_FAILED;
   
   //--- Check if current symbol is allowed
   if(!Is_Symbol_Allowed(Symbol()))
   {
      Print("Symbol not allowed: ", Symbol());
      return INIT_FAILED;
   }
   
   Print("EA initialized successfully for symbol: ", Symbol());
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Clean up
   Trade_Deinit();
   Filters_Deinit();
   Print("EA deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for daily reset
   Check_Daily_Reset();
   
   //--- Check daily drawdown limit (4-5%)
   if(Daily_PnL < -4.0) // Using 4% as per specification
   {
      Close_All_Trades();
      Print("Daily drawdown limit reached. Stopping EA.");
      ExpertRemove();
      return;
   }
   
   //--- Check if trading is allowed
   if(!Is_Trading_Allowed())
      return;
   
   //--- Check for weekend close
   if(Weekend_Close && Is_Time_To_Close_Friday())
   {
      Close_Weekend_Trades();
      return;
   }
   
   //--- Check news filter
   if(Use_News_Filter && Is_News_Period())
   {
      Print("News filter active. Pausing trading.");
      return;
   }
   
   //--- Calculate Asian range if it's time
   if(Is_Asian_Session_End() && !Is_Range_Break)
   {
      Calculate_Asian_Range();
      if(Is_Range_Valid())
      {
         Place_Pending_Orders();
      }
   }
   
   //--- Check for breakout after London open
   if(Is_London_Session_Open() && Is_Range_Valid() && !Is_Range_Break)
   {
      Check_Breakout();
   }
   
   //--- Manage open trades (trailing stop, etc.)
   Manage_Open_Trades();
   
   //--- Check for early break before London
   if(Is_Early_Break())
   {
      Cancel_Pending_Orders();
      Is_Range_Break = false;
   }
}

//+------------------------------------------------------------------+
//| Calculate Asian range from midnight to 6h GMT                    |
//+------------------------------------------------------------------+
void Calculate_Asian_Range()
{
   datetime start_time = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 00:00");
   datetime end_time = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 06:00");
   
   Asian_High = 0;
   Asian_Low = 999999;
   
   for(datetime t = start_time; t <= end_time; t += PeriodSeconds(Range_TF))
   {
      double high = iHigh(Symbol(), Range_TF, iBarShift(Symbol(), Range_TF, t));
      double low = iLow(Symbol(), Range_TF, iBarShift(Symbol(), Range_TF, t));
      
      if(high > Asian_High) Asian_High = high;
      if(low < Asian_Low) Asian_Low = low;
   }
   
   // Apply margin
   Asian_High += Margin_Pips * Point();
   Asian_Low -= Margin_Pips * Point();
   
   Print("Asian Range calculated: High=", Asian_High, " Low=", Asian_Low);
}

//+------------------------------------------------------------------+
//| Check if range is valid based on filters                         |
//+------------------------------------------------------------------+
bool Is_Range_Valid()
{
   double range_pips = (Asian_High - Asian_Low) / Point();
   
   // Check min/max range
   if(range_pips < Min_Range_Pips || range_pips > Max_Range_Pips)
   {
      Print("Range invalid: ", range_pips, " pips (min=", Min_Range_Pips, " max=", Max_Range_Pips, ")");
      return false;
   }
   
   // Check volatility filter (Bollinger Bands)
   if(Use_Vol_Filter && !Check_BB_Filter(range_pips))
   {
      Print("Range failed BB filter");
      return false;
   }
   
   // Check ATR filter
   double atr_value = iATR(Symbol(), PERIOD_H1, ATR_Period, 0);
   double atr_pips = atr_value / Point();
   if(atr_pips < Min_ATR_Pips || atr_pips > Max_ATR_Pips)
   {
      Print("ATR out of range: ", atr_pips, " pips");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Place pending buy stop and sell stop orders                      |
//+------------------------------------------------------------------+
void Place_Pending_Orders()
{
   // Calculate lot size
   double lot_size = Calculate_Lot_Size(SL_Pips);
   
   // Place buy stop order
   double buy_price = Asian_High;
   double buy_sl = Asian_Low;
   double buy_tp = Calculate_TP_Price(buy_price, buy_sl, OP_BUY);
   
   if(Trade_PlacePending(OP_BUYSTOP, lot_size, buy_price, buy_sl, buy_tp, 0, "Asian Range Buy Stop"))
      Print("Buy stop order placed at ", buy_price);
   
   // Place sell stop order
   double sell_price = Asian_Low;
   double sell_sl = Asian_High;
   double sell_tp = Calculate_TP_Price(sell_price, sell_sl, OP_SELL);
   
   if(Trade_PlacePending(OP_SELLSTOP, lot_size, sell_price, sell_sl, sell_tp, 0, "Asian Range Sell Stop"))
      Print("Sell stop order placed at ", sell_price);
}

//+------------------------------------------------------------------+
//| Check for breakout with confirmation filters                     |
//+------------------------------------------------------------------+
void Check_Breakout()
{
   double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   // Check if price has broken above high or below low
   if(current_price > Asian_High)
   {
      if(Is_Breakout_Confirmed(OP_BUY))
      {
         Execute_Breakout_Trade(OP_BUY);
         Is_Range_Break = true;
      }
   }
   else if(current_price < Asian_Low)
   {
      if(Is_Breakout_Confirmed(OP_SELL))
      {
         Execute_Breakout_Trade(OP_SELL);
         Is_Range_Break = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if breakout is confirmed with ATR and volume               |
//+------------------------------------------------------------------+
bool Is_Breakout_Confirmed(int order_type)
{
   // Check ATR filter
   double atr_value = iATR(Symbol(), PERIOD_H1, ATR_Period, 0);
   double breakout_distance = (order_type == OP_BUY) ? (SymbolInfoDouble(Symbol(), SYMBOL_BID) - Asian_High) : (Asian_Low - SymbolInfoDouble(Symbol(), SYMBOL_ASK));
   
   if(breakout_distance < (ATR_Mult_Min * atr_value))
   {
      Print("Breakout failed ATR filter: distance=", breakout_distance/Point(), " pips, min required=", (ATR_Mult_Min * atr_value)/Point(), " pips");
      return false;
   }
   
   // Check volume confirmation
   if(Use_Volume_Confirm && !Check_Volume_Confirmation())
   {
      Print("Breakout failed volume confirmation");
      return false;
   }
   
   // Check trend filter
   if(Use_Trend_Filter && !Check_Trend_Filter(order_type))
   {
      Print("Breakout failed trend filter");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Execute breakout trade (market order)                            |
//+------------------------------------------------------------------+
void Execute_Breakout_Trade(int order_type)
{
   // Cancel opposite pending order
   Cancel_Pending_Orders();
   
   // Calculate lot size
   double lot_size = Calculate_Lot_Size(SL_Pips);
   
   // Calculate SL and TP
   double sl_price = (order_type == OP_BUY) ? Asian_Low : Asian_High;
   double entry_price = (order_type == OP_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double tp_price = Calculate_TP_Price(entry_price, sl_price, order_type);
   
   // Place market order
   if(Trade_PlaceMarket(order_type, lot_size, sl_price, tp_price, "Asian Range Breakout"))
   {
      Print("Breakout trade executed: ", (order_type == OP_BUY) ? "BUY" : "SELL");
      Last_Trade_Time = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Manage open trades (trailing stop, etc.)                         |
//+------------------------------------------------------------------+
void Manage_Open_Trades()
{
   if(Use_Trailing_Stop)
   {
      Trailing_Stop_Manager();
   }
   
   // Update daily PnL
   Update_Daily_PnL();
}

//+------------------------------------------------------------------+
//| Trailing stop manager                                            |
//+------------------------------------------------------------------+
void Trailing_Stop_Manager()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == Magic_Number && OrderSymbol() == Symbol())
         {
            double current_price = (OrderType() == OP_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_BID) : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
            double open_price = OrderOpenPrice();
            double sl_price = OrderStopLoss();
            double tp_price = OrderTakeProfit();
            
            // Calculate profit in pips
            double profit_pips = (OrderType() == OP_BUY) ? (current_price - open_price) / Point() : (open_price - current_price) / Point();
            double tp_pips = (OrderType() == OP_BUY) ? (tp_price - open_price) / Point() : (open_price - tp_price) / Point();
            
            // Check if trailing should be activated
            if(profit_pips >= (Trail_Activation_PC / 100.0) * tp_pips)
            {
               double new_sl = Calculate_Trailing_SL(OrderType(), current_price, sl_price);
               
               if((OrderType() == OP_BUY && new_sl > sl_price) || (OrderType() == OP_SELL && new_sl < sl_price))
               {
                  if(Trade_ModifyOrder(OrderTicket(), OrderOpenPrice(), new_sl, OrderTakeProfit()))
                     Print("Trailing stop updated for ticket ", OrderTicket(), " new SL=", new_sl);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate trailing stop loss price                               |
//+------------------------------------------------------------------+
double Calculate_Trailing_SL(int order_type, double current_price, double current_sl)
{
   if(Trail_Method == "ATR")
   {
      double atr_value = iATR(Symbol(), PERIOD_H1, ATR_Period, 0);
      double trail_distance = Trail_Mult * atr_value;
      
      if(order_type == OP_BUY)
         return current_price - trail_distance;
      else
         return current_price + trail_distance;
   }
   else // Fixed method
   {
      double trail_pips = Trail_Mult * SL_Pips * Point();
      
      if(order_type == OP_BUY)
         return current_price - trail_pips;
      else
         return current_price + trail_pips;
   }
}

//+------------------------------------------------------------------+
//| Calculate take profit price                                      |
//+------------------------------------------------------------------+
double Calculate_TP_Price(double entry_price, double sl_price, int order_type)
{
   if(TP_Method == "Dynamic_ATR")
   {
      double atr_value = iATR(Symbol(), PERIOD_H1, ATR_Period, 0);
      double tp_distance = ATR_TP_Mult * atr_value;
      
      if(order_type == OP_BUY)
         return entry_price + tp_distance;
      else
         return entry_price - tp_distance;
   }
   else // Fixed RR
   {
      double sl_distance = MathAbs(entry_price - sl_price);
      double tp_distance = Fixed_RR * sl_distance;
      
      if(order_type == OP_BUY)
         return entry_price + tp_distance;
      else
         return entry_price - tp_distance;
   }
}

//+------------------------------------------------------------------+
//| Check if symbol is allowed                                       |
//+------------------------------------------------------------------+
bool Is_Symbol_Allowed(string symbol)
{
   string pairs[];
   StringSplit(Allowed_Pairs, ',', pairs);
   
   for(int i = 0; i < ArraySize(pairs); i++)
   {
      if(StringTrimLeft(StringTrimRight(pairs[i])) == symbol)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed (time between trades, max trades)    |
//+------------------------------------------------------------------+
bool Is_Trading_Allowed()
{
   // Check max open trades
   if(Trade_CountOpen() >= Max_Open_Trades)
      return false;
   
   // Check max trades per day
   if(Trade_CountToday() >= Max_Trades_Per_Day)
      return false;
   
   // Check time between trades
   if(Last_Trade_Time > 0 && (TimeCurrent() - Last_Trade_Time) < (Min_Time_Between_Trades_Hrs * 3600))
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if it's time to close trades before weekend                |
//+------------------------------------------------------------------+
bool Is_Time_To_Close_Friday()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(dt.day_of_week == 5) // Friday
   {
      if(dt.hour >= Close_Hour_Fri)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Close trades before weekend                                      |
//+------------------------------------------------------------------+
void Close_Weekend_Trades()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == Magic_Number && OrderSymbol() == Symbol())
         {
            if(!Close_If_In_Profit || OrderProfit() > 0)
            {
               if(Trade_CloseOrder(OrderTicket()))
                  Print("Weekend close: Order ", OrderTicket(), " closed");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for daily reset                                            |
//+------------------------------------------------------------------+
void Check_Daily_Reset()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(dt.day != Last_Daily_Reset)
   {
      Daily_PnL = 0.0;
      Last_Daily_Reset = dt.day;
      Is_Range_Break = false;
      Print("Daily reset: PnL reset to 0");
   }
}

//+------------------------------------------------------------------+
//| Update daily PnL                                                 |
//+------------------------------------------------------------------+
void Update_Daily_PnL()
{
   double total_profit = 0.0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == Magic_Number && OrderSymbol() == Symbol())
         {
            total_profit += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }
   
   Daily_PnL = total_profit / AccountInfoDouble(ACCOUNT_BALANCE) * 100.0;
}

//+------------------------------------------------------------------+
//| Close all trades                                                 |
//+------------------------------------------------------------------+
void Close_All_Trades()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == Magic_Number && OrderSymbol() == Symbol())
         {
            Trade_CloseOrder(OrderTicket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Cancel all pending orders                                        |
//+------------------------------------------------------------------+
void Cancel_Pending_Orders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == Magic_Number && OrderSymbol() == Symbol())
         {
            if(OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP)
            {
               Trade_DeleteOrder(OrderTicket());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if Asian session has ended                                 |
//+------------------------------------------------------------------+
bool Is_Asian_Session_End()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   return (dt.hour >= Asian_End_Hour && dt.hour < Asian_End_Hour + 1);
}

//+------------------------------------------------------------------+
//| Check if London session is open                                  |
//+------------------------------------------------------------------+
bool Is_London_Session_Open()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   return (dt.hour >= London_Open_Hour);
}

//+------------------------------------------------------------------+
//| Check for early break before London                              |
//+------------------------------------------------------------------+
bool Is_Early_Break()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(dt.hour > Asian_End_Hour && dt.hour < London_Open_Hour)
   {
      double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      if(current_price > Asian_High || current_price < Asian_Low)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| The following functions are implemented in included files:       |
//| - Check_BB_Filter() in MonEA1_Filters.mqh                        |
//| - Check_Volume_Confirmation() in MonEA1_Filters.mqh              |
//| - Check_Trend_Filter() in MonEA1_Filters.mqh                     |
//| - Is_News_Period() in MonEA1_Filters.mqh                         |
//| - Calculate_Lot_Size() in MonEA1_Risk.mqh                        |
//| - Trade_* functions in MonEA1_Trade.mqh                          |
//| - Utils_* functions in MonEA1_Utils.mqh                          |
//+------------------------------------------------------------------+
