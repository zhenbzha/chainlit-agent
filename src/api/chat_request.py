from dotenv import load_dotenv
load_dotenv()

import os
import sys
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import (
    PromptAgentDefinition,
    AzureAISearchAgentTool,
    AzureAISearchToolResource,
    AISearchIndexResource,
    AzureAISearchQueryType,
)
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../')))
from utils.env_util import get_project_endpoint, get_aisearch_conn

# Initialize the project client with the new endpoint format
project_endpoint = get_project_endpoint()
credential = DefaultAzureCredential()
project_client = AIProjectClient(
    credential=credential,
    endpoint=project_endpoint,
)

index_name = os.environ["AZURE_SEARCH_INDEX"]
aisearch_conn_id = get_aisearch_conn()

# Initialize Azure AI Search tool for the agent
ai_search_tool = AzureAISearchAgentTool(
    azure_ai_search=AzureAISearchToolResource(
        indexes=[
            AISearchIndexResource(
                project_connection_id=aisearch_conn_id,
                index_name=index_name,
                query_type=AzureAISearchQueryType.VECTOR_SEMANTIC_HYBRID,
            ),
        ]
    )
)

# Create the agent with search tool
agent = project_client.agents.create_version(
    agent_name="product-assistant",
    definition=PromptAgentDefinition(
        model=os.environ.get("AZURE_OPENAI_CHAT_DEPLOYMENT", "gpt-4.1-mini"),
        instructions="""
            system:
            You are an assistant that provides information based on a knowledge base. You have access to an AI search tool that you must use for factual information.

            Core principles:
            1. For ANY factual information (dates, specifications, prices, features, etc.), you MUST verify using the knowledge base
            2. NEVER make up or hallucinate information
            3. If factual information is not found in the knowledge base, respond with: "I apologize, but I don't have that information in my knowledge base."
            4. You may engage in general conversation without searching, but ANY factual claims must be verified
            5. For questions about products, features, or any specific details, always search the knowledge base

            Remember:
            - All factual information MUST come from the knowledge base
            - It's better to admit not having information than to provide unverified details
        """,
        tools=[ai_search_tool],
    ),
)

print(f"Agent created (id: {agent.id}, name: {agent.name}, version: {agent.version})")

# Get OpenAI client for conversations
openai_client = project_client.get_openai_client()


def generate_response_agent(question, thread_id):
    """Generate a response using the agent with the new OpenAI Responses API."""

    # Create or continue a conversation
    if thread_id:
        # Continue existing conversation
        response = openai_client.responses.create(
            conversation=thread_id,
            extra_body={"agent": {"name": agent.name, "type": "agent_reference"}},
            input=question,
        )
    else:
        # Create new conversation with the question
        conversation = openai_client.conversations.create(
            items=[{"type": "message", "role": "user", "content": question}],
        )
        response = openai_client.responses.create(
            conversation=conversation.id,
            extra_body={"agent": {"name": agent.name, "type": "agent_reference"}},
            input="",
        )
        thread_id = conversation.id

    assistant_message = response.output_text if hasattr(response, 'output_text') else str(response)
    print(f"Assistant response: {assistant_message}")

    return {"question": question, "answer": assistant_message, "thread_id": thread_id}
