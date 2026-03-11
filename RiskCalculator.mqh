//+------------------------------------------------------------------+
//|                                                      RiskCalculator.mqh |
//|                        Copyright 2024, MonEA1 Project              |
//|                                             https://www.monea1.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MonEA1 Project"
#property link      "https://www.monea1.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Risk Calculator Class                                            |
//+------------------------------------------------------------------+
class CRiskCalculator
{
private:
   // Risk parameters
   double   m_riskPercent;      // Risk percentage per trade (0.5-1%)
   double   m_stopLossPips;     // Stop loss in pips (30)
   double   m_takeProfitPips;   // Take profit in pips (60)
   double   m_minLot;           // Minimum lot size
   double   m_maxLot;           // Maximum lot size
   
   // Broker information
   double   m_tickSize;         // Symbol tick size
   double   m_tickValue;        // Symbol tick value
   double   m_point;            // Symbol point value
   
   // Calculation method
   string   m_lotMethod;        // "EquityRisk" or "BalanceRisk"
   
public:
   // Constructor
   CRiskCalculator()
   {
      m_riskPercent = 1.0;
      m_stopLossPips = 30.0;
      m_takeProfitPips = 60.0;
      m_minLot = 0.01;
      m_maxLot = 5.0;
      m_lotMethod = "EquityRisk";
      
      // Initialize broker values
      m_tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      m_tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      m_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   }
   
   // Destructor
   ~CRiskCalculator() {}
   
   // Set risk parameters
   void SetRiskParameters(double riskPercent, double slPips, double tpPips, 
                         double minLot = 0.01, double maxLot = 5.0, string lotMethod = "EquityRisk")
   {
      m_riskPercent = MathMax(0.1, MathMin(riskPercent, 5.0));  // Limit risk to 0.1-5%
      m_stopLossPips = MathMax(1.0, slPips);
      m_takeProfitPips = MathMax(1.0, tpPips);
      m_minLot = MathMax(0.01, minLot);
      m_maxLot = MathMax(m_minLot, maxLot);
      m_lotMethod = lotMethod;
   }
   
   // Calculate lot size based on risk percentage
   double CalculateLotSize()
   {
      double lotSize = 0.0;
      
      // Get account equity or balance based on method
      double accountValue = 0.0;
      if(m_lotMethod == "EquityRisk")
         accountValue = AccountInfoDouble(ACCOUNT_EQUITY);
      else
         accountValue = AccountInfoDouble(ACCOUNT_BALANCE);
      
      // Calculate risk amount in account currency
      double riskAmount = accountValue * (m_riskPercent / 100.0);
      
      // Calculate pip value for the symbol
      double pipValue = CalculatePipValue();
      
      // Calculate lot size
      if(pipValue > 0 && m_stopLossPips > 0)
      {
         // Formula: Lot = Risk Amount / (Stop Loss in Pips * Pip Value)
         lotSize = riskAmount / (m_stopLossPips * pipValue);
         
         // Adjust for contract size (standard lot = 100,000 units)
         double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
         if(contractSize > 0)
            lotSize = lotSize * (100000.0 / contractSize);
      }
      
      // Apply lot size constraints
      lotSize = NormalizeLotSize(lotSize);
      
      return lotSize;
   }
   
   // Calculate pip value for current symbol
   double CalculatePipValue()
   {
      double pipValue = 0.0;
      
      // For Forex pairs, pip is usually 0.0001 for most pairs, 0.01 for JPY pairs
      double pipSize = 0.0001;
      string symbol = _Symbol;
      
      // Check if it's a JPY pair
      if(StringFind(symbol, "JPY") != -1)
         pipSize = 0.01;
      
      // Calculate pip value
      pipValue = (pipSize / m_point) * m_tickValue;
      
      return pipValue;
   }
   
   // Normalize lot size to broker requirements and constraints
   double NormalizeLotSize(double lotSize)
   {
      // Get broker lot step
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      // Round to nearest lot step
      if(lotStep > 0)
         lotSize = MathRound(lotSize / lotStep) * lotStep;
      
      // Apply minimum and maximum constraints
      lotSize = MathMax(m_minLot, MathMin(m_maxLot, lotSize));
      
      // Get broker minimum and maximum lots
      double brokerMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double brokerMaxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
      // Apply broker constraints
      lotSize = MathMax(brokerMinLot, MathMin(brokerMaxLot, lotSize));
      
      return lotSize;
   }
   
   // Calculate stop loss price for buy order
   double CalculateBuyStopLoss(double entryPrice)
   {
      return entryPrice - (m_stopLossPips * m_point * 10);
   }
   
   // Calculate stop loss price for sell order
   double CalculateSellStopLoss(double entryPrice)
   {
      return entryPrice + (m_stopLossPips * m_point * 10);
   }
   
   // Calculate take profit price for buy order
   double CalculateBuyTakeProfit(double entryPrice)
   {
      return entryPrice + (m_takeProfitPips * m_point * 10);
   }
   
   // Calculate take profit price for sell order
   double CalculateSellTakeProfit(double entryPrice)
   {
      return entryPrice - (m_takeProfitPips * m_point * 10);
   }
   
   // Calculate risk/reward ratio
   double CalculateRiskRewardRatio()
   {
      if(m_stopLossPips > 0)
         return m_takeProfitPips / m_stopLossPips;
      return 0.0;
   }
   
   // Get risk amount for current trade
   double GetRiskAmount(double lotSize)
   {
      double pipValue = CalculatePipValue();
      return lotSize * m_stopLossPips * pipValue;
   }
   
   // Get potential profit for current trade
   double GetPotentialProfit(double lotSize)
   {
      double pipValue = CalculatePipValue();
      return lotSize * m_takeProfitPips * pipValue;
   }
   
   // Validate if risk parameters are within acceptable limits
   bool ValidateRiskParameters()
   {
      // Check risk percentage
      if(m_riskPercent < 0.1 || m_riskPercent > 5.0)
         return false;
      
      // Check stop loss
      if(m_stopLossPips < 1.0)
         return false;
      
      // Check take profit
      if(m_takeProfitPips < 1.0)
         return false;
      
      // Check lot constraints
      if(m_minLot < 0.01 || m_maxLot < m_minLot)
         return false;
      
      // Check risk/reward ratio (minimum 1:1)
      if(CalculateRiskRewardRatio() < 1.0)
         return false;
      
      return true;
   }
   
   // Get current risk settings as string for logging
   string GetRiskSettings()
   {
      string settings = "";
      settings += StringFormat("Risk: %.2f%%, ", m_riskPercent);
      settings += StringFormat("SL: %.0f pips, ", m_stopLossPips);
      settings += StringFormat("TP: %.0f pips, ", m_takeProfitPips);
      settings += StringFormat("RR: %.2f:1", CalculateRiskRewardRatio());
      return settings;
   }
};

//+------------------------------------------------------------------+
