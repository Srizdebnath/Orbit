import requests
from web3 import Web3
from models.intent import ParsedIntent, SwapRoute

# --- CONFIG ---
CHAIN_IDS = {
    "Base": 8453,
    "Optimism": 10,
    "Mode": 34443
}

# Common Token Addresses (Mainnet)
TOKENS = {
    "Base": {
        "ETH": "0x4200000000000000000000000000000000000006", # WETH
        "USDC": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
    },
    "Optimism": {
        "ETH": "0x4200000000000000000000000000000000000006",
        "USDC": "0x0b2C639c533813f4Aa9D7837CAf992c96bdB5a88"
    }
}

# API for Prices (DefiLlama)
PRICE_API = "https://coins.llama.fi/prices/current"

def get_token_price(chain: str, token_addr: str) -> float:
    # DefiLlama format: chainName:address
    # Note: DefiLlama uses 'base' and 'optimism' (lowercase)
    chain_slug = chain.lower()
    query = f"{chain_slug}:{token_addr}"
    
    try:
        resp = requests.get(f"{PRICE_API}/{query}")
        data = resp.json()
        return data['coins'][query]['price']
    except:
        print(f"Price fetch failed for {query}")
        return 0.0

def generate_calldata(intent: ParsedIntent, user_address: str) -> SwapRoute:
    # 1. Resolve Addresses
    src_chain = intent.source_chain
    dst_chain = intent.destination_chain
    
    token_in = TOKENS.get(src_chain, {}).get(intent.token_in_symbol)
    token_out = TOKENS.get(dst_chain, {}).get(intent.token_out_symbol)
    
    if not token_in or not token_out:
        raise ValueError(f"Token not supported: {intent.token_in_symbol} -> {intent.token_out_symbol}")

    # 2. Calculate Wei Amounts
    # Decimals: USDC = 6, ETH = 18. 
    # For production, we need a robust decimal map. Assuming 18 for ETH, 6 for USDC.
    in_decimals = 6 if "USDC" in intent.token_in_symbol else 18
    out_decimals = 6 if "USDC" in intent.token_out_symbol else 18
    
    amount_in_wei = int(intent.amount * (10 ** in_decimals))

    # 3. Fetch Prices & Calc Slippage
    price_in = get_token_price(src_chain, token_in)
    price_out = get_token_price(dst_chain, token_out)
    
    if price_out == 0: raise ValueError("Could not fetch price")

    # Math: (AmountIn * PriceIn) / PriceOut
    expected_out = (intent.amount * price_in) / price_out
    min_out_wei = int(expected_out * 0.99 * (10 ** out_decimals)) # 1% Slippage

    # 4. ABI Encoding
    # We need to match the Solidity function signature:
    # initiateCrossChainSwap(address _tokenIn, uint256 _amountIn, uint256 _destChainId, address _tokenOutOnDest, uint24 _fee, uint256 _minAmountOut)
    
    # We construct the 4-byte selector manually to avoid importing a massive JSON ABI file for now
    # Function: initiateCrossChainSwap(address,uint256,uint256,address,uint24,uint256)
    w3 = Web3()
    
    function_signature = "initiateCrossChainSwap(address,uint256,uint256,address,uint24,uint256)"
    selector = w3.keccak(text=function_signature)[:4].hex()
    
    # Encode parameters
    params = w3.codec.encode(
        ['address', 'uint256', 'uint256', 'address', 'uint24', 'uint256'],
        [
            token_in,
            amount_in_wei,
            CHAIN_IDS.get(dst_chain, 10),
            token_out,
            3000, # 0.3% Pool Fee (Standard)
            min_out_wei
        ]
    )
    
    calldata = selector + params.hex()

    return SwapRoute(
        token_in_address=token_in,
        token_out_address=token_out,
        amount_in_wei=amount_in_wei,
        min_amount_out_wei=min_out_wei,
        router_address="0xPLACEHOLDER_ROUTER", # We will fill this in deployment phase
        calldata=calldata,
        fee_tier=3000,
        estimated_gas=200000 # Estimate
    )