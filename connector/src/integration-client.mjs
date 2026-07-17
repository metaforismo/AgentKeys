export class AgentKeysConnectorClient {
  constructor({ baseURL, token, fetchImpl = fetch }) {
    this.baseURL = new URL(baseURL);
    this.token = token;
    this.fetchImpl = fetchImpl;
  }

  upsert(agent) {
    return this.#request("PUT", "/v1/integrations/agent", agent);
  }

  async drain(agentID) {
    const result = await this.#request(
      "GET",
      `/v1/integrations/actions?agentID=${encodeURIComponent(agentID)}`,
    );
    return result.actions;
  }

  async #request(method, path, body) {
    const response = await this.fetchImpl(new URL(path, this.baseURL), {
      method,
      headers: {
        "X-AgentKeys-Integration-Token": this.token,
        ...(body ? { "Content-Type": "application/json" } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const payload = await response.json();
    if (!response.ok) throw new Error(`AgentKeys connector rejected request: ${payload.error ?? response.status}`);
    return payload;
  }
}
