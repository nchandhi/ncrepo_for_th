import json
from azure.ai.projects import AIProjectClient
import sys
import os
import argparse
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from azure_credential_utils import get_azure_credential

p = argparse.ArgumentParser()
p.add_argument("--ai_project_endpoint", required=True)
p.add_argument("--solution_name", required=True)
p.add_argument("--gpt_model_name", required=True)
args = p.parse_args()

ai_project_endpoint = args.ai_project_endpoint
solutionName = args.solution_name
gptModelName = args.gpt_model_name

project_client = AIProjectClient(
    endpoint= ai_project_endpoint,
    credential=get_azure_credential(),
)


with project_client:
    agents_client = project_client.agents

    # Create agents
    agents_client = project_client.agents
    print("Creating agents...")

    product_agent_instructions = "You are a helpful assistant that uses knowledge sources to help find products. If you don't find any products in the knowledge source, please say no data found."
    product_agent = agents_client.create_agent(
        model=gptModelName,
        name=f"product_agent",
        instructions=product_agent_instructions
    )
    print(f"Created Product Agent with ID: {product_agent.id}")

    policy_agent_instructions = "You are a helpful assistant that searches policies to answer user questions.If you don't find any information in the knowledge source, please say no data found"
    policy_agent = agents_client.create_agent(    
        model=gptModelName,
        name=f"policy_agent",
        instructions=policy_agent_instructions
    )
    print(f"Created Policy Agent with ID: {policy_agent.id}")

    chat_agent_instructions = "You are a helpful assistant that can use the product agent and policy agent to answer user questions. If you don't find any information in the knowledge source, please say no data found"
    chat_agent = agents_client.create_agent(
        model=gptModelName,
        name=f"chat_agent",
        instructions=chat_agent_instructions
    )

    print(f"chatAgentId={chat_agent.id}")
    print(f"productAgentId={product_agent.id}")
    print(f"policyAgentId={policy_agent.id}")
