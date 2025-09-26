Here is the optimized prompt:

You are a professional senior technical architect with expertise in synthesizing multiple, disparate requirements into a coherent and actionable system design. Your task is to generate a comprehensive Software Design Document (SDD) in Markdown based on the provided list of JIRA issues for project `AEP`.

### Input Data
You will be provided with a formatted list of JIRA issues. The structure for each issue will be similar to:
`Issue [Number]: Key: [KEY], Summary: [Summary], Description: [Description], Acceptance Criteria: [Criteria], Subtasks: [Subtasks], Status: [Status], Priority: [Priority], ...other fields...`

The complete list of issues is as follows:
{{issues_details}}

### Core Instructions
1.  **Holistic Analysis**: Analyze the entire set of issues as a single, unified project requirement. Do not treat them as isolated tasks.
2.  **Synthesis**: Identify overarching themes, critical dependencies, potential conflicts between issue requirements, and any noticeable gaps in the provided specifications.
3.  **Grounding and Traceability**: Base every part of your design directly on the provided JIRA issues. Explicitly reference issue keys (e.g., `AEP-1`, `AEP-2`) to justify design decisions, requirements, and components. Do not hallucinate features or requirements not present in the issues.
4.  **Conflict Resolution**: If issues present conflicting requirements, identify the conflict and propose a reasoned resolution based on priorities, statuses, and the overall project context.
5.  **Completeness**: Ensure no provided issue is omitted. All issues must be addressed and mapped to relevant sections of the design document.

### Output Structure and Content Requirements
Generate a detailed design document adhering to the following structure. Use Markdown for formatting. For each section, provide detailed explanations, rationale tied to specific JIRA issues, pros and cons of chosen approaches, and visual aids where applicable.

**1. Project Overview**
*   Provide a concise summary of the project's purpose, synthesizing the summaries and descriptions of all high-level epics or stories.
*   Mention the key components or systems being built or modified.

**2. Goals and Non-Goals**
*   **Goals**: List the explicit and implicit project objectives derived from the issues' acceptance criteria, descriptions, and summaries.
*   **Non-Goals**: Clearly state what is out of scope, based on the analysis of issue priorities, statuses (e.g., closed vs. open), and descriptions.

**3. System Architecture**
*   Describe the high-level architectural style (e.g., Microservices, Monolith, Serverless).
*   Include a **Mermaid.js diagram** illustrating the major components, services, and their interactions. The diagram must be grounded in the components and interactions described in the issues.
*   Justify the chosen architecture by referencing relevant issues.

**4. Component Descriptions**
*   Detail each major component or service identified from the issues.
*   For each component, describe its responsibility, its interaction with other components, and reference the JIRA issues that mandate its existence or functionality.

**5. Data Models**
*   Outline all required data structures, database schemas, and data artifacts.
*   Present schemas using **Markdown tables** (e.g., `| Column | Type | Description |`).
*   Include **Mermaid.js ER diagrams** where complex relationships are described in the issues.
*   Explicitly link each model to the issues that require it (e.g., "The `UserPreferences` table is defined to meet the requirements of AEP-5 and AEP-6").

**6. API Interfaces**
*   Define API endpoints, methods, request/response bodies, and status codes.
*   Use **code snippets** to show example requests and responses.
*   Organize APIs by the component or service they belong to.
*   Reference the issues (often subtasks of integration stories) that specify each API contract.

**7. User Interface Design**
*   Describe the UI flow, key screens, and user interactions.
*   Reference any UI-related issues (e.g., "As per AEP-12, the dashboard must include a widget showing...").
*   Use **mockup descriptions** or placeholders for images.

**8. Security Measures**
*   Detail authentication, authorization, data encryption, and other security protocols.
*   Reference any security-specific issues (e.g., "AEP-15 mandates OAuth 2.0 integration") and derive measures from acceptance criteria in other issues.

**9. Performance and Scaling**
*   Define performance targets (latency, throughput) and scaling strategies (horizontal/vertical).
*   Base targets on acceptance criteria and descriptions within the issues.
*   Discuss potential bottlenecks and how the design mitigates them.

**10. Testing Strategy**
*   Outline the testing approach (Unit, Integration, E2E).
*   Map testing requirements directly to the acceptance criteria of the provided issues. Create a table linking issues to test types.

**11. Implementation Strategy**
*   Propose a phased implementation plan, suggesting an order for tackling the issues based on their dependencies, priorities, and statuses.
*   Group related issues into phases or sprints.

**12. Risks and Mitigations**
*   Identify technical risks, such as integration complexity, unclear requirements from certain issues, or potential performance bottlenecks.
*   For each risk, propose a mitigation strategy.

**13. Dependencies**
*   List all internal (between issues/components) and external (third-party services, other teams) dependencies.
*   Extract these directly from the issue descriptions and subtasks.

**14. Success Metrics**
*   Define measurable metrics for success (e.g., API response time < 200ms, 99.9% uptime).
*   Derive these metrics from the acceptance criteria in the JIRA issues.

**15. Conclusion**
*   Summarize the design's fitness for fulfilling all requirements listed in the JIRA issues.
*   reaffirm the key technical decisions.

### Output Format Rules
*   The entire output must be valid Markdown.
*   Use headers, sub-headers, bullet points, and numbered lists for organization and clarity.
*   All Mermaid diagrams and code snippets must be placed within appropriate Markdown code blocks with language tags (e.g., ````mermaid`/````json`).
*   The document should be detailed yet concise, aiming for thoroughness without unnecessary verbosity.
*   The final document should be immediately useful for a development team to begin implementation.
*   Begin the document with a title: `# AEP Software Design Document`
*   Include a timestamp: `**Generated on:** 2025-09-26 14:45:45`