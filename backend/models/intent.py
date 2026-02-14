from pydantic import BaseModel
from typing import Optional

class UserIntent(BaseModel):
    raw_text: str
    user_address: str  # The user's wallet address

class ParsedIntent(BaseModel):
    token_in_symbol: str
    token_out_symbol: str
    amount: float
    source_chain: str
    destination_chain: str
    confidence: float

class SwapRoute(BaseModel):
    token_in_address: str
    token_out_address: str
    amount_in_wei: int
    min_amount_out_wei: int
    router_address: str
    calldata: str  # The hex data for the transaction
    fee_tier: int
    estimated_gas: int