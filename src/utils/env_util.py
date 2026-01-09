import os
from dotenv import load_dotenv
load_dotenv()

location = os.environ.get("AZURE_LOCATION", "")
subscription_id = os.environ.get("AZURE_SUBSCRIPTION_ID", "")
resource_group = os.environ.get("AZURE_RESOURCE_GROUP", "")
aifoundry_proj_name = os.environ.get("AZURE_AI_FOUNDRY_PROJECT_NAME", "")
openai_endpoint = os.environ.get("AZURE_OPENAI_ENDPOINT", "")

def get_project_endpoint() -> str:
    """
    Get the project endpoint for the AI Foundry project.
    For the new CognitiveServices-based Foundry model.
    """
    # The endpoint format is: https://{account}.cognitiveservices.azure.com/api/projects/{project}
    # Or we can use the AZURE_OPENAI_ENDPOINT directly with project name
    base_endpoint = openai_endpoint.rstrip('/')
    return f"{base_endpoint}/api/projects/{aifoundry_proj_name}"

def get_aifound_proj_conn_string() -> str:
    """
    Get the connection string for the AI Foundry project.
    Note: This is for backward compatibility with hub-based projects.
    For new Foundry projects, use get_project_endpoint() instead.
    """
    connection_string = f"{location}.api.azureml.ms;{subscription_id};{resource_group};{aifoundry_proj_name}"
    return connection_string

def get_aisearch_conn() -> str:
    """
    Get the AI Search connection ID for the new CognitiveServices-based Foundry model.
    """
    # Extract account name from endpoint (e.g., "aif-lz5jslducei7w" from "https://aif-lz5jslducei7w.cognitiveservices.azure.com/")
    account_name = openai_endpoint.replace("https://", "").split(".")[0]

    # New format for CognitiveServices-based Foundry
    aisearch_conn_id = f"/subscriptions/{subscription_id}/resourceGroups/{resource_group}/providers/Microsoft.CognitiveServices/accounts/{account_name}/projects/{aifoundry_proj_name}/connections/search-service-connection"
    return aisearch_conn_id

def get_openai_endpoint() -> str:
    """Get the Azure OpenAI endpoint."""
    return openai_endpoint
