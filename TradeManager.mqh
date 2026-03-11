//+------------------------------------------------------------------+
//|                                                      TradeManager.mqh |
//|                        Copyright 2024, MonEA1 Project              |
//|                                             https://www.monea1.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MonEA1 Project"
#property link      "https://www.monea1.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| CTradeManager class                                              |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
   CTrade           m_trade;               // Trade execution object
   CSymbolInfo      m_symbol;              // Symbol information
   CPositionInfo    m_position;            // Position information
   CAccountInfo     m_account;             // Account information
   
   // Risk management parameters
   double           m_riskPercent;         // Risk percentage per trade (0.5-1%)
   double           m_slPips;              // Stop loss in pips
   double           m_tpPips;              // Take profit in pips
   double           m_minLot;              // Minimum lot size
   double           m_maxLot;              // Maximum lot size
   double           m_dailyLossLimit;      // Daily loss limit percentage
   
   // Position tracking
   double           m_dailyPL;             // Daily profit/loss
   datetime         m_lastTradeTime;       // Time of last trade
   int              m_tradesToday;         // Number of trades today
   
   // Lot calculation method
   enum ENUM_LOT_METHOD
   {
      LOT_EQUITY_RISK,    // Based on equity
      LOT_FIXED,          // Fixed lot size
      LOT_BALANCE_RISK    // Based on balance
   };
   
   ENUM_LOT_METHOD m_lotMethod;            // Lot calculation method
   
public:
   // Constructor
   CTradeManager() : 
      m_riskPercent(1.0),
      m_slPips(30.0),
      m_tpPips(60.0),
      m_minLot(0.01),
      m_maxLot(5.0),
      m_dailyLossLimit(4.0),
      m_dailyPL(0.0),
      m_lastTradeTime(0),
      m_tradesToday(0),
      m_lotMethod(LOT_EQUITY_RISK)
   {
      // Initialize trade object
      m_trade.SetExpertMagicNumber(12345);
      m_trade.SetDeviationInPoints(10);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   }
   
   // Destructor
   ~CTradeManager() {}
   
   // Initialization method
   bool Init(string symbol, double riskPercent, double slPips, double tpPips, 
             double minLot, double maxLot, double dailyLossLimit, ENUM_LOT_METHOD lotMethod)
   {
      // Set parameters
      m_riskPercent = riskPercent;
      m_slPips = slPips;
      m_tpPips = tpPips;
      m_minLot = minLot;
      m_maxLot = maxLot;
      m_dailyLossLimit = dailyLossLimit;
      m_lotMethod = lotMethod;
      
      // Initialize symbol
      if(!m_symbol.Name(symbol))
      {
         Print("Failed to set symbol name: ", symbol);
         return false;
      }
      
      // Refresh symbol rates
      if(!m_symbol.RefreshRates())
      {
         Print("Failed to refresh symbol rates");
         return false;
      }
      
      // Reset daily tracking
      ResetDailyTracking();
      
      return true;
   }
   
   // Reset daily tracking
   void ResetDailyTracking()
   {
      m_dailyPL = 0.0;
      m_tradesToday = 0;
      
      // Check if it's a new day
      MqlDateTime dt;
      TimeCurrent(dt);
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;
      m_lastTradeTime = StructToTime(dt);
   }
   
   // Calculate lot size based on risk percentage
   double CalculateLotSize(double entryPrice, double stopLossPrice, ENUM_ORDER_TYPE orderType)
   {
      // Get current equity or balance based on method
      double capital = 0.0;
      
      switch(m_lotMethod)
      {
         case LOT_EQUITY_RISK:
            capital = m_account.Equity();
            break;
         case LOT_BALANCE_RISK:
            capital = m_account.Balance();
            break;
         case LOT_FIXED:
            // Return fixed lot based on risk percentage
            return NormalizeDouble(m_riskPercent / 100.0 * m_minLot, 2);
      }
      
      if(capital <= 0)
      {
         Print("Invalid capital amount: ", capital);
         return m_minLot;
      }
      
      // Calculate risk amount in account currency
      double riskAmount = capital * (m_riskPercent / 100.0);
      
      // Calculate stop loss distance in points
      double slDistance = 0.0;
      
      if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT)
      {
         slDistance = (entryPrice - stopLossPrice) / m_symbol.Point();
      }
      else if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_STOP || orderType == ORDER_TYPE_SELL_LIMIT)
      {
         slDistance = (stopLossPrice - entryPrice) / m_symbol.Point();
      }
      
      if(slDistance <= 0)
      {
         Print("Invalid stop loss distance: ", slDistance);
         return m_minLot;
      }
      
      // Calculate tick value for the risk
      double tickValue = m_symbol.TickValue();
      if(tickValue <= 0)
      {
         Print("Invalid tick value: ", tickValue);
         return m_minLot;
      }
      
      // Calculate lot size
      double lotSize = riskAmount / (slDistance * tickValue);
      
      // Adjust for contract size
      lotSize = lotSize / m_symbol.LotsStep();
      
      // Normalize lot size
      lotSize = NormalizeDouble(lotSize, 2);
      
      // Apply min/max limits
      if(lotSize < m_minLot) lotSize = m_minLot;
      if(lotSize > m_maxLot) lotSize = m_maxLot;
      
      // Ensure it's a valid lot step
      double lotStep = m_symbol.LotsStep();
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
      
      return lotSize;
   }
   
   // Execute buy order
   bool ExecuteBuy(double entryPrice, double slPrice, double tpPrice, string comment = "")
   {
      // Check daily loss limit
      if(!CheckDailyLossLimit())
      {
         Print("Daily loss limit reached. Trading stopped.");
         return false;
      }
      
      // Check if we can open new position
      if(!CanOpenNewPosition())
      {
         Print("Cannot open new position. Max positions reached or cooldown active.");
         return false;
      }
      
      // Calculate lot size
      double lotSize = CalculateLotSize(entryPrice, slPrice, ORDER_TYPE_BUY);
      
      // Execute buy order
      bool result = m_trade.Buy(lotSize, m_symbol.Name(), entryPrice, slPrice, tpPrice, comment);
      
      if(result)
      {
         UpdateTradeTracking();
         Print("Buy order executed. Lot size: ", lotSize, ", Entry: ", entryPrice, ", SL: ", slPrice, ", TP: ", tpPrice);
      }
      else
      {
         Print("Failed to execute buy order. Error: ", GetLastError());
      }
      
      return result;
   }
   
   // Execute sell order
   bool ExecuteSell(double entryPrice, double slPrice, double tpPrice, string comment = "")
   {
      // Check daily loss limit
      if(!CheckDailyLossLimit())
      {
         Print("Daily loss limit reached. Trading stopped.");
         return false;
      }
      
      // Check if we can open new position
      if(!CanOpenNewPosition())
      {
         Print("Cannot open new position. Max positions reached or cooldown active.");
         return false;
      }
      
      // Calculate lot size
      double lotSize = CalculateLotSize(entryPrice, slPrice, ORDER_TYPE_SELL);
      
      // Execute sell order
      bool result = m_trade.Sell(lotSize, m_symbol.Name(), entryPrice, slPrice, tpPrice, comment);
      
      if(result)
      {
         UpdateTradeTracking();
         Print("Sell order executed. Lot size: ", lotSize, ", Entry: ", entryPrice, ", SL: ", slPrice, ", TP: ", tpPrice);
      }
      else
      {
         Print("Failed to execute sell order. Error: ", GetLastError());
      }
      
      return result;
   }
   
   // Place buy stop order
   bool PlaceBuyStop(double price, double slPrice, double tpPrice, string comment = "")
   {
      // Calculate lot size
      double lotSize = CalculateLotSize(price, slPrice, ORDER_TYPE_BUY_STOP);
      
      // Place buy stop order
      bool result = m_trade.BuyStop(lotSize, price, m_symbol.Name(), slPrice, tpPrice, ORDER_TIME_GTC, 0, comment);
      
      if(result)
      {
         Print("Buy stop order placed. Price: ", price, ", Lot size: ", lotSize, ", SL: ", slPrice, ", TP: ", tpPrice);
      }
      else
      {
         Print("Failed to place buy stop order. Error: ", GetLastError());
      }
      
      return result;
   }
   
   // Place sell stop order
   bool PlaceSellStop(double price, double slPrice, double tpPrice, string comment = "")
   {
      // Calculate lot size
      double lotSize = CalculateLotSize(price, slPrice, ORDER_TYPE_SELL_STOP);
      
      // Place sell stop order
      bool result = m_trade.SellStop(lotSize, price, m_symbol.Name(), slPrice, tpPrice, ORDER_TIME_GTC, 0, comment);
      
      if(result)
      {
         Print("Sell stop order placed. Price: ", price, ", Lot size: ", lotSize, ", SL: ", slPrice, ", TP: ", tpPrice);
      }
      else
      {
         Print("Failed to place sell stop order. Error: ", GetLastError());
      }
      
      return result;
   }
   
   // Close all positions
   bool CloseAllPositions()
   {
      int total = PositionsTotal();
      bool allClosed = true;
      
      for(int i = total - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == m_symbol.Name())
            {
               if(!m_trade.PositionClose(m_position.Ticket()))
               {
                  Print("Failed to close position ", m_position.Ticket(), ". Error: ", GetLastError());
                  allClosed = false;
               }
               else
               {
                  Print("Position closed: ", m_position.Ticket());
               }
            }
         }
      }
      
      return allClosed;
   }
   
   // Delete all pending orders
   bool DeleteAllPendingOrders()
   {
      int total = OrdersTotal();
      bool allDeleted = true;
      
      for(int i = total - 1; i >= 0; i--)
      {
         if(OrderSelect(i, SELECT_BY_POS))
         {
            if(OrderSymbol() == m_symbol.Name())
            {
               if(!m_trade.OrderDelete(OrderTicket()))
               {
                  Print("Failed to delete order ", OrderTicket(), ". Error: ", GetLastError());
                  allDeleted = false;
               }
               else
               {
                  Print("Order deleted: ", OrderTicket());
               }
            }
         }
      }
      
      return allDeleted;
   }
   
   // Check daily loss limit
   bool CheckDailyLossLimit()
   {
      // Calculate current daily P/L
      double currentPL = CalculateDailyPL();
      
      // Get account balance
      double balance = m_account.Balance();
      
      if(balance <= 0) return true;
      
      // Calculate loss percentage
      double lossPercentage = (currentPL / balance) * 100.0;
      
      // Check if loss exceeds limit
      if(lossPercentage <= -m_dailyLossLimit)
      {
         Print("Daily loss limit exceeded. Current loss: ", lossPercentage, "%, Limit: ", m_dailyLossLimit, "%");
         
         // Close all positions
         CloseAllPositions();
         
         return false;
      }
      
      return true;
   }
   
   // Calculate daily profit/loss
   double CalculateDailyPL()
   {
      double totalPL = 0.0;
      
      // Get current date
      MqlDateTime currentDt;
      TimeCurrent(currentDt);
      datetime todayStart = StructToTime(currentDt);
      currentDt.hour = 0;
      currentDt.min = 0;
      currentDt.sec = 0;
      todayStart = StructToTime(currentDt);
      
      // Check positions opened today
      int total = PositionsTotal();
      
      for(int i = 0; i < total; i++)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == m_symbol.Name())
            {
               // Check if position was opened today
               if(m_position.Time() >= todayStart)
               {
                  totalPL += m_position.Profit();
               }
            }
         }
      }
      
      return totalPL;
   }
   
   // Check if we can open new position
   bool CanOpenNewPosition()
   {
      // Check max open positions
      int openPositions = 0;
      int total = PositionsTotal();
      
      for(int i = 0; i < total; i++)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == m_symbol.Name())
            {
               openPositions++;
            }
         }
      }
      
      // Allow only 1 open position at a time
      if(openPositions >= 1)
      {
         return false;
      }
      
      // Check cooldown between trades (1 hour minimum)
      if(m_lastTradeTime > 0)
      {
         datetime currentTime = TimeCurrent();
         double hoursSinceLastTrade = (currentTime - m_lastTradeTime) / 3600.0;
         
         if(hoursSinceLastTrade < 1.0)  // 1 hour cooldown
         {
            return false;
         }
      }
      
      // Check max trades per day (3)
      if(m_tradesToday >= 3)
      {
         return false;
      }
      
      return true;
   }
   
   // Update trade tracking
   void UpdateTradeTracking()
   {
      m_lastTradeTime = TimeCurrent();
      m_tradesToday++;
      
      // Reset daily tracking if it's a new day
      MqlDateTime dt;
      TimeCurrent(dt);
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;
      datetime todayStart = StructToTime(dt);
      
      if(m_lastTradeTime < todayStart)
      {
         ResetDailyTracking();
      }
   }
   
   // Apply trailing stop
   void ApplyTrailingStop(double activationPercent = 50.0, double trailMultiplier = 0.5)
   {
      int total = PositionsTotal();
      
      for(int i = 0; i < total; i++)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == m_symbol.Name())
            {
               // Get position details
               double openPrice = m_position.PriceOpen();
               double currentPrice = m_symbol.Bid();
               double slPrice = m_position.StopLoss();
               double profit = m_position.Profit();
               
               // Calculate profit percentage from entry to TP
               double profitPips = 0.0;
               double tpDistance = 0.0;
               
               if(m_position.PositionType() == POSITION_TYPE_BUY)
               {
                  profitPips = (currentPrice - openPrice) / m_symbol.Point();
                  tpDistance = m_tpPips;
               }
               else if(m_position.PositionType() == POSITION_TYPE_SELL)
               {
                  profitPips = (openPrice - currentPrice) / m_symbol.Point();
                  tpDistance = m_tpPips;
               }
               
               // Calculate profit percentage
               double profitPercent = (profitPips / tpDistance) * 100.0;
               
               // Check if trailing should be activated
               if(profitPercent >= activationPercent)
               {
                  // Calculate new stop loss based on ATR
                  double atrValue = iATR(m_symbol.Name(), PERIOD_H1, 14, 0);
                  double trailDistance = atrValue * trailMultiplier;
                  
                  double newSlPrice = 0.0;
                  
                  if(m_position.PositionType() == POSITION_TYPE_BUY)
                  {
                     newSlPrice = currentPrice - trailDistance;
                     
                     // Only move SL if it's higher than current SL
                     if(newSlPrice > slPrice || slPrice == 0)
                     {
                        if(m_trade.PositionModify(m_position.Ticket(), newSlPrice, m_position.TakeProfit()))
                        {
                           Print("Trailing stop applied. New SL: ", newSlPrice);
                        }
                     }
                  }
                  else if(m_position.PositionType() == POSITION_TYPE_SELL)
                  {
                     newSlPrice = currentPrice + trailDistance;
                     
                     // Only move SL if it's lower than current SL
                     if(newSlPrice < slPrice || slPrice == 0)
                     {
                        if(m_trade.PositionModify(m_position.Ticket(), newSlPrice, m_position.TakeProfit()))
                        {
                           Print("Trailing stop applied. New SL: ", newSlPrice);
                        }
                     }
                  }
               }
            }
         }
      }
   }
   
   // Close positions before weekend
   bool CloseBeforeWeekend(int closeHour = 21)
   {
      // Get current time
      MqlDateTime dt;
      TimeCurrent(dt);
      
      // Check if it's Friday and after specified hour
      if(dt.day_of_week == 5 && dt.hour >= closeHour)  // Friday = 5
      {
         Print("Closing all positions before weekend...");
         return CloseAllPositions();
      }
      
      return true;
   }
   
   // Getters
   double GetRiskPercent() const { return m_riskPercent; }
   double GetSlPips() const { return m_slPips; }
   double GetTpPips() const { return m_tpPips; }
   double GetDailyPL() const { return m_dailyPL; }
   int GetTradesToday() const { return m_tradesToday; }
   
   // Setters
   void SetRiskPercent(double value) { m_riskPercent = value; }
   void SetSlPips(double value) { m_slPips = value; }
   void SetTpPips(double value) { m_tpPips = value; }
   void SetDailyLossLimit(double value) { m_dailyLossLimit = value; }
   void SetLotMethod(ENUM_LOT_METHOD method) { m_lotMethod = method; }
};

//+------------------------------------------------------------------+
