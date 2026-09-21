# Checklist: AI & LLM Applications (OWASP Top 10 for LLM)

## 1. Prompt Injection: Direct & Indirect (LLM01)
- [ ] **Indirect Prompt Injection**: Identify where untrusted external data (user uploads, web scraped content, emails, customer tickets, database records) is formatted into prompts sent to the LLM. Verify delimiters, system instructions, and secondary validation protect against instructions embedded in data overriding the system instructions.
- [ ] **System Prompt & Internal Instruction Leakage (LLM07)**: Check if adversarial prompts can coerce the model into dumping confidential system instructions, internal API keys, or proprietary guidelines.

## 2. Insecure Output Handling & Model-to-Sink Dataflow (LLM05)
- [ ] **LLM Output Fed to Sensitive Sinks**: Trace model output after generation. Does the application pass raw LLM text into:
  - Command execution (`exec`, shell)?
  - Database queries (raw SQL / NoSQL)?
  - Template or code execution engines (`eval()`)?
  - Web views without HTML escaping (causing Stored XSS)?
- [ ] **Structured Output Validation**: Ensure that if the model returns JSON or code, the output is strictly validated against a schema (e.g. JSON schema, Pydantic) before executing or storing.

## 3. Excessive Agency & Tool Calling Authorization (LLM06)
- [ ] **Unbounded Tool Permissions**: When using function calling / tools, verify that the model cannot invoke administrative, destructive, or unauthorized tools (e.g. deleting databases, altering user permissions, transferring funds) without explicit server-side authorization checks and human confirmation.
- [ ] **BFLA on LLM Tools**: Verify that tools called by the model check the authorization context of the initiating end-user, not the elevated privileges of the backend service account.

## 4. Resource Exhaustion & Denial of Wallet (LLM10)
- [ ] **Token & Loop Limits**: Verify that recursive or agentic LLM loops have hard iteration caps and maximum token budgets, preventing infinite prompt loops that exhaust API billing credits.
