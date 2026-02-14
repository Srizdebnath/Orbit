from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware  # <--- IMPORT THIS
from pydantic import BaseModel
from services.llm import parse_intent
from services.routing import generate_calldata
from models.intent import UserIntent, SwapRoute

app = FastAPI(title="Orbit Protocol Agent")

# --- CONFIGURE CORS ---
origins = [
    "http://localhost:3000",  # Your Frontend
    "http://127.0.0.1:3000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,    # Allow these origins
    allow_credentials=True,
    allow_methods=["*"],      # Allow all methods (POST, GET, OPTIONS, etc.)
    allow_headers=["*"],      # Allow all headers
)

@app.get("/")
def read_root():
    return {"status": "Orbit Agent Online", "engine": "Groq Llama3"}

@app.post("/solve_intent", response_model=SwapRoute)
async def solve_intent(intent: UserIntent):
    print(f"Received intent: {intent.raw_text} from {intent.user_address}")
    
    # 1. AI Parsing
    try:
        parsed = await parse_intent(intent.raw_text)
        print(f"Parsed: {parsed}")
    except Exception as e:
        print(f"AI Error: {e}")
        raise HTTPException(status_code=400, detail=f"AI Parsing Failed: {str(e)}")

    # 2. Routing & Pricing
    try:
        route = generate_calldata(parsed, intent.user_address)
        return route
    except Exception as e:
        print(f"Routing Error: {e}")
        raise HTTPException(status_code=500, detail=f"Routing Failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)