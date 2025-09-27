#!/usr/bin/env python3
"""
IPM-55: Advisory Signal Generation Algorithm with Confidence Scoring

This module implements the advisory signal generation algorithm for Indian equity markets.
It processes integrated market data, news, and sentiment to generate buy/hold/sell signals
with confidence scoring.

Key Features:
- Multi-factor signal generation using technical indicators, fundamental data, and sentiment
- Confidence scoring based on signal strength and data quality
- Configurable thresholds and parameters
- Integration with market data sources
"""

import logging
import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from enum import Enum
import json
from datetime import datetime, timedelta

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SignalType(Enum):
    """Enumeration of possible advisory signals"""
    STRONG_BUY = "STRONG_BUY"
    BUY = "BUY"
    HOLD = "HOLD"
    SELL = "SELL"
    STRONG_SELL = "STRONG_SELL"


@dataclass
class AdvisorySignal:
    """Data class representing an advisory signal"""
    symbol: str
    signal_type: SignalType
    confidence_score: float
    generated_at: datetime
    rationale: str
    price_target: Optional[float] = None
    stop_loss: Optional[float] = None
    time_horizon: Optional[str] = None


class SignalGenerator:
    """
    Main class for generating advisory signals with confidence scoring
    """
    
    def __init__(self, config_path: str = "config/signal_config.json"):
        """
        Initialize the signal generator with configuration
        
        Args:
            config_path: Path to configuration file
        """
        self.config = self._load_config(config_path)
        self.technical_weights = self.config.get("technical_weights", {})
        self.fundamental_weights = self.config.get("fundamental_weights", {})
        self.sentiment_weights = self.config.get("sentiment_weights", {})
        self.thresholds = self.config.get("thresholds", {})
        
    def _load_config(self, config_path: str) -> Dict:
        """
        Load configuration from JSON file
        
        Args:
            config_path: Path to configuration file
            
        Returns:
            Dictionary containing configuration parameters
        """
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            logger.warning(f"Configuration file {config_path} not found. Using default configuration.")
            return self._get_default_config()
        except json.JSONDecodeError as e:
            logger.error(f"Error parsing configuration file: {e}")
            return self._get_default_config()
    
    def _get_default_config(self) -> Dict:
        """Return default configuration parameters"""
        return {
            "technical_weights": {
                "rsi": 0.25,
                "macd": 0.20,
                "bollinger_bands": 0.15,
                "moving_averages": 0.20,
                "volume_analysis": 0.10,
                "momentum": 0.10
            },
            "fundamental_weights": {
                "pe_ratio": 0.30,
                "pb_ratio": 0.20,
                "debt_to_equity": 0.15,
                "profit_growth": 0.20,
                "dividend_yield": 0.15
            },
            "sentiment_weights": {
                "news_sentiment": 0.40,
                "social_media_sentiment": 0.30,
                "analyst_recommendations": 0.30
            },
            "thresholds": {
                "strong_buy": 0.8,
                "buy": 0.6,
                "hold_min": -0.2,
                "hold_max": 0.2,
                "sell": -0.6,
                "strong_sell": -0.8
            },
            "data_quality_threshold": 0.7,
            "min_data_points": 10
        }
    
    def generate_signals(self, market_data: pd.DataFrame, 
                        fundamental_data: pd.DataFrame,
                        sentiment_data: pd.DataFrame) -> List[AdvisorySignal]:
        """
        Generate advisory signals for multiple securities
        
        Args:
            market_data: DataFrame containing technical indicators and price data
            fundamental_data: DataFrame containing fundamental data
            sentiment_data: DataFrame containing sentiment data
            
        Returns:
            List of AdvisorySignal objects
        """
        signals = []
        
        # Get unique symbols from all data sources
        symbols = set(market_data.get('symbol', [])) | \
                 set(fundamental_data.get('symbol', [])) | \
                 set(sentiment_data.get('symbol', []))
        
        for symbol in symbols:
            try:
                signal = self._generate_signal_for_symbol(
                    symbol, market_data, fundamental_data, sentiment_data
                )
                if signal:
                    signals.append(signal)
            except Exception as e:
                logger.error(f"Error generating signal for {symbol}: {e}")
                continue
        
        return signals
    
    def _generate_signal_for_symbol(self, symbol: str,
                                   market_data: pd.DataFrame,
                                   fundamental_data: pd.DataFrame,
                                   sentiment_data: pd.DataFrame) -> Optional[AdvisorySignal]:
        """
        Generate advisory signal for a single symbol
        
        Args:
            symbol: Stock symbol
            market_data: Technical data DataFrame
            fundamental_data: Fundamental data DataFrame
            sentiment_data: Sentiment data DataFrame
            
        Returns:
            AdvisorySignal object or None if insufficient data
        """
        # Filter data for the specific symbol
        symbol_market_data = market_data[market_data['symbol'] == symbol]
        symbol_fundamental_data = fundamental_data[fundamental_data['symbol'] == symbol]
        symbol_sentiment_data = sentiment_data[sentiment_data['symbol'] == symbol]
        
        # Check if we have sufficient data
        if (len(symbol_market_data) < self.config.get('min_data_points', 10) or
            len(symbol_fundamental_data) == 0 or
            len(symbol_sentiment_data) == 0):
            logger.warning(f"Insufficient data for {symbol}")
            return None
        
        # Calculate individual scores
        technical_score = self._calculate_technical_score(symbol_market_data)
        fundamental_score = self._calculate_fundamental_score(symbol_fundamental_data)
        sentiment_score = self._calculate_sentiment_score(symbol_sentiment_data)
        
        # Calculate overall score (weighted average)
        overall_score = self._calculate_overall_score(
            technical_score, fundamental_score, sentiment_score
        )
        
        # Determine signal type based on thresholds
        signal_type = self._determine_signal_type(overall_score)
        
        # Calculate confidence score
        confidence_score = self._calculate_confidence_score(
            technical_score, fundamental_score, sentiment_score,
            symbol_market_data, symbol_fundamental_data, symbol_sentiment_data
        )
        
        # Generate rationale
        rationale = self._generate_rationale(
            symbol, technical_score, fundamental_score, sentiment_score,
            signal_type, overall_score
        )
        
        # Calculate price target and stop loss if possible
        current_price = symbol_market_data['close'].iloc[-1] if not symbol_market_data.empty else None
        price_target, stop_loss = self._calculate_price_targets(
            current_price, overall_score, symbol_market_data
        )
        
        return AdvisorySignal(
            symbol=symbol,
            signal_type=signal_type,
            confidence_score=confidence_score,
            generated_at=datetime.now(),
            rationale=rationale,
            price_target=price_target,
            stop_loss=stop_loss,
            time_horizon="3-6 months"
        )
    
    def _calculate_technical_score(self, market_data: pd.DataFrame) -> float:
        """
        Calculate technical analysis score
        
        Args:
            market_data: DataFrame with technical indicators
            
        Returns:
            Technical score between -1 and 1
        """
        if market_data.empty:
            return 0.0
        
        latest_data = market_data.iloc[-1]
        score = 0.0
        
        # RSI analysis (0-100, >70 overbought, <30 oversold)
        if 'rsi' in latest_data and not pd.isna(latest_data['rsi']):
            rsi_score = (50 - latest_data['rsi']) / 50  # Normalize to -1 to 1
            score += rsi_score * self.technical_weights.get('rsi', 0.25)
        
        # MACD analysis
        if 'macd' in latest_data and 'macd_signal' in latest_data:
            if not pd.isna(latest_data['macd']) and not pd.isna(latest_data['macd_signal']):
                macd_score = 1.0 if latest_data['macd'] > latest_data['macd_signal'] else -1.0
                score += macd_score * self.technical_weights.get('macd', 0.20)
        
        # Bollinger Bands analysis
        if all(col in latest_data for col in ['close', 'bb_upper', 'bb_lower']):
            if not any(pd.isna(latest_data[col]) for col in ['close', 'bb_upper', 'bb_lower']):
                bb_position = (latest_data['close'] - latest_data['bb_lower']) / \
                             (latest_data['bb_upper'] - latest_data['bb_lower'])
                bb_score = (bb_position - 0.5) * 2  # Normalize to -1 to 1
                score += bb_score * self.technical_weights.get('bollinger_bands', 0.15)
        
        # Moving averages
        if all(col in latest_data for col in ['close', 'sma_50', 'sma_200']):
            if not any(p
# Code truncated at 10000 characters