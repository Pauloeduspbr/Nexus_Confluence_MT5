# Nexus Confluence EA - AI Agent Instructions

## Project Overview
MQL5 Expert Advisor (EA) for **production trading on real accounts** using multi-timeframe confluence analysis with 6-gate validation system. Zero tolerance for incomplete code, placeholders, or examples.

## Critical Context
- **Language**: Pure MQL5 (MetaTrader 5 Build 4000+)
- **Environment**: Production - REAL MONEY trading
- **Reference**: Read `mql5.pdf` in root before any development
- **Architecture**: Modular system with 5 separate include files + main EA

## Directory Structure
```
Experts/NexusConfluenceEA/          # Main EA file (NexusConfluenceEA.mq5)
Include/NexusConfluenceEA/Modules/  # Core modules (.mqh files)
Indicators/NexusConfluenceEA/       # 5 custom indicators (.mq5)
```

## 6-Gate Validation System (CRITICAL ARCHITECTURE)

### Gate 0 - Synchronization
- **ALWAYS use `shift=1`** (bar close) - prevents repaint
- Cache all buffers once per candle
- State machine: `IDLE → SIGNAL_DETECTED → ORDER_SENT → WAITING_CLOSE`
- Timestamp validation for buffer synchronization

### Gate 1 - Market Access
- Dynamic spread filter: `current < multiplier * median(20 candles)`
- Skip Monday Open for Forex (gap protection)
- Market-specific hours and spread limits (see table in DEVELOPER.prompt.md)

### Gate 2 - Multi-Timeframe Analysis
- **Score System**: Sum of GG TrendBar values (+1/0/-1) across 4 timeframes
- **BUY**: Score ≥ +2 | **SELL**: Score ≤ -2
- **Classifications**: PREMIUM (4/4 aligned), GOOD (≥2 score), REJECT (<2)

### Gate 3 - Supertrend Direction
- Confirm local direction on operational timeframe
- **1 candle tolerance** allowed for lag

### Gate 4 - Momentum (PROCESSING ORDER MATTERS)
1. **OBV MACD first** - histogram must exceed adaptive threshold (filters ranges)
2. **RSI OMA second** - confirms directional pressure
3. Both must align with MTF direction

### Gate 5 - Currency Strength Context
- **Required**: Forex, Metals
- **Skip**: Indices (automatic fallback)
- **Optional**: Crypto

## Five Core Modules

### 1. Core.mqh
- New candle detection (`IsNewCandle()`)
- State machine management (prevent duplicate orders)
- 3-level logging system (Executivo, Operacional, Debug)
- Timestamp validation

### 2. MarketAccess.mqh
- Dynamic spread calculation (median-based)
- Market hours validation per asset type
- Price/lot normalization via `SymbolInfoDouble()`
- Skip Monday Open logic for Forex

### 3. IndicatorHub.mqh
- Manages 5 indicator handles via `iCustom()`
- **Buffer cache once per candle** (performance optimization)
- Fallback: Operates without Currency Strength on indices
- All `CopyBuffer()` calls use `shift=1`

### 4. SignalEngine.mqh
- Implements all 6 gates sequentially
- MTF score calculation and signal classification
- Momentum (OBV MACD) → RSI OMA processing order enforcement
- Returns `ENUM_SIGNAL_CLASS` (PREMIUM/GOOD/REJECT)

### 5. RiskExecution.mqh
- Uses `CTrade` and `CPositionInfo` classes
- One order per candle enforcement
- SL/TP calculation and normalization
- Retry logic for recoverable errors (requote, timeout)

## Five Custom Indicators

### GG_TrendBar_Indicator.mq5
- Returns **-1 (bearish), 0 (neutral), +1 (bullish)** for 9 timeframes
- Used in Gate 2 for MTF score calculation
- **Critical**: v2.12 fixed to return only -1/0/+1 (no ±2)

### TrendMagic_MT5.mq5 (Supertrend)
- Buffer 0: Upper band, Buffer 1: Lower band
- Used in Gate 3 for trend confirmation
- 1 candle tolerance implemented in SignalEngine

### OBV_MACD.mq5 (Momentum)
- Buffer 0: Histogram (positive/negative)
- Buffer 4: Adaptive threshold line
- Processed first in Gate 4 (filters lateral markets)

### RSIOMA_v2HHLSX_MT5.mq5
- Buffer 0: Red line, Buffer 1: Blue line
- BUY signal: Red > Blue | SELL: Red < Blue
- **Processed second** in Gate 4 (confirms momentum)

### CurrencyStrengthMeter_MT5.mq5
- Returns strength values per currency
- Used in Gate 5 (Forex/Metals only)
- Automatic fallback on indices

## MQL5-Specific Rules

### Always Use
- `shift=1` for all `CopyBuffer()` calls (bar close)
- `TimeCurrent()` not `TimeLocal()` (server time)
- `NormalizeDouble()` before ANY price/lot operations
- `INVALID_HANDLE` checks after `iCustom()`
- `CTrade::ResultRetcode()` to validate order execution

### Never Use
- `shift=0` (current bar - causes repaint)
- Placeholders like "// TODO" or "...existing code..."
- Generic error messages without context
- Loops without clear termination conditions

## Development Workflow

### Before Writing Code
1. Confirm understanding of gate system architecture
2. Identify which module(s) will be modified
3. Plan error handling for all critical operations
4. Consider performance impact (avoid loops in `OnTick()`)

### During Development
- Complete implementations only (no partial code)
- Log all decisions at appropriate level (1=Executivo, 2=Operacional, 3=Debug)
- Validate ALL buffer copies and handle operations
- Test edge cases: Monday gaps, spread spikes, missing indicators

### Testing Requirements (Pre-Production)
1. Strategy Tester: 6+ months historical data
2. Visual Mode: Validate gate-by-gate behavior
3. Demo Account: 2+ weeks paper trading
4. Verify KPIs: PREMIUM win rate >65%, GOOD >55%
5. Performance: <50ms latency, <100ms CPU per candle

## Market-Specific Configurations

| Market | Hours | Currency Strength | Max Spread | Skip Monday |
|--------|-------|-------------------|------------|-------------|
| Forex | 24h | Required | 20pts | Yes |
| B3 (WIN) | 09:00-17:55 | No | 10pts | No |
| Indices | Varies | No | 15pts | Yes |
| Metals | ~24h | Required | 30pts | Yes |
| Crypto | 24/7 | Optional | 50pts | No |

## Common Pitfalls

### State Machine Not Checked
```mql5
// ❌ Wrong: Can process multiple signals per candle
if(signal_detected) ExecuteOrder();

// ✅ Correct: Check state first
if(g_core.CanProcessSignal() && signal_detected) {
    g_core.UpdateStateMachine(STATE_ORDER_SENT);
    ExecuteOrder();
}
```

### Wrong Gate 4 Order
```mql5
// ❌ Wrong: RSI before momentum
if(RSI_signal && momentum_expanding) { ... }

// ✅ Correct: Momentum filters first
if(momentum_expanding) {
    if(RSI_signal) { ... }
}
```

### Missing shift=1
```mql5
// ❌ Wrong: shift=0 causes repaint
CopyBuffer(handle, 0, 0, 1, buffer);

// ✅ Correct: Always use closed bar
CopyBuffer(handle, 0, 1, 1, buffer);
```

## Logging Standards

### Level 1 (Executivo)
Trade executions and critical errors only
```mql5
Print("✅ PREMIUM BUY | EURUSD | Entry: 1.0850");
```

### Level 2 (Operacional)
Gate results, scores, state transitions
```mql5
Print("Gates: G0✓ G1✓ G2✓ G3✓ G4✓ G5✓ | MTF Score: +4 | PREMIUM");
```

### Level 3 (Debug)
Raw indicator values, buffer contents
```mql5
Print("GG[H4]:+1 [H1]:+1 [M30]:+1 [M15]:+1 | MOM: hist 0.0015 > thr 0.0010");
```

## Questions to Ask When Uncertain

1. **Which gate does this affect?** - Understand the validation flow
2. **What happens on Monday open?** - Consider gap scenarios
3. **Does this work without Currency Strength?** - Test index fallback
4. **What if the buffer copy fails?** - Handle ALL error cases
5. **Can this cause duplicate orders?** - Check state machine

## Key Files to Reference
- `.github/prompts/DEVELOPER.prompt.md` - Complete architecture specification
- `mql5.pdf` - Language reference (root directory)
- `Indicators/NexusConfluenceEA/*.mq5` - Buffer indices and return values
