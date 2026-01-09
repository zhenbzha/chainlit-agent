import os
import sys
from dotenv import load_dotenv
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional
from chat_request import generate_response_agent

load_dotenv()

app = FastAPI()

@app.get("/")
async def root():
    return {"message": "Hello World"}

class Item(BaseModel):
    question: str
    thread_id: Optional[str] = None

@app.post("/api/generate_response")
def generate_response(item: Item) -> dict:
    result = generate_response_agent(item.question, item.thread_id)
    return result

@app.get("/api/test")
def test(question: str = "What products do you have?") -> dict:
    result = generate_response_agent(question, None)
    return result

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
