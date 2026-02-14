from fastapi import FastAPI

app = FastAPI(title="Orbit Protocol Agent")

@app.get("/")
def read_root():
    return {"system": "Orbit Protocol", "status": "online", "mode": "production"}

@app.get("/health")
def health_check():
    # In the future, this will check connection to OP Stack RPCs
    return {"db": "ok", "blockchain_connection": "pending"}