import os
import json
from groq import Groq
from models.intent import ParsedIntent
from dotenv import load_dotenv

load_dotenv()

client = Groq(api_key=os.environ.get("GROQ_API_KEY"))

SYSTEM_PROMPT = """
You are an advanced DeFi Intent Parser for the Orbit Protocol.
Your job is to extract trading details from natural language.
Supported Chains: Base, Optimism, Mode, Zora.
Supported Tokens: ETH, USDC, USDT, WETH, OP, DEGEN.

Rules:
1. Identify the 'Source Chain' and 'Destination Chain'. If user says "on Optimism", that is the destination. If source is not specified, assume 'Base'.
2. Return amounts as floats.
3. Return strict JSON format only. No markdown, no yapping.

Example Input: "Swap 100 USDC to ETH on Optimism"
Example Output:
{
    "token_in_symbol": "USDC",
    "token_out_symbol": "ETH",
    "amount": 100.0,
    "source_chain": "Base",
    "destination_chain": "Optimism",
    "confidence": 0.99
}
"""

async def parse_intent(user_text: str) -> ParsedIntent:
    try:
        completion = client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_text}
            ],
            temperature=0,
            response_format={"type": "json_object"}
        )
        
        data = json.loads(completion.choices[0].message.content)
        return ParsedIntent(**data)
    except Exception as e:
        print(f"Groq Error: {e}")
        # Return a fallback or raise error
        raise ValueError("Could not parse intent")