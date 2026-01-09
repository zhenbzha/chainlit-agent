import sys
import os
import chainlit as cl
import requests

env = os.getenv("ENVIRONMENT", "")
base_url = os.getenv("API_URL")
if env == "azure":
    api_url = f"{base_url}/api/generate_response"
else:
    api_url = "http://localhost:8000/api/generate_response"


@cl.on_chat_start
async def main():
    # Initialize thread_id as None for new conversations
    cl.user_session.set("thread_id", None)
    await cl.Message(content="""Hello there, I am your assistant. I can answer questions based on the information provided in the knowledge base""").send()

@cl.on_message
async def on_message(msg: cl.Message):
    question = msg.content

    thread_id = cl.user_session.get("thread_id")

    # Data to be sent
    data = {
        "question": question,
        "thread_id": thread_id
    }

    # A POST request to the API
    response = requests.post(api_url, json=data)
    result = response.json()

    # Store the thread_id for conversation continuity
    if result.get("thread_id"):
        cl.user_session.set("thread_id", result.get("thread_id"))

    # Print the response
    await cl.Message(result.get("answer")).send()


if __name__ == "__main__":
    from chainlit.cli import run_chainlit
    run_chainlit(__file__)
