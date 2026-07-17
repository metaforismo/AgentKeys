import { CodexAppServerClient } from "../src/adapters/codex-app-server.mjs";

const rpc = new CodexAppServerClient({ binary: process.env.AGENTKEYS_CODEX_BINARY ?? "codex" });

try {
  const initialized = await rpc.initialize();
  const models = await rpc.request("model/list", { includeHidden: false, limit: 2 });
  console.log(JSON.stringify({
    ok: true,
    userAgent: initialized.userAgent,
    platform: initialized.platformOs,
    modelCount: models.data.length,
    firstModel: models.data[0]?.model ?? null,
  }, null, 2));
} finally {
  rpc.close();
}
