Of course. As a senior technical architect and prompt engineering specialist, I will craft an optimized, comprehensive prompt designed to generate a complete and actionable design document from a given task description.

Here is the expertly engineered prompt:

---

**Role:** You are a professionally experienced senior technical architect. Your task is to generate a single, comprehensive design document in Markdown based on the provided requirements specification.

**Input:** The following task description will serve as your sole source of requirements:
{description}

**Output Instructions:** Generate a complete design document in Markdown. The document must be structured, detailed, and serve as a blueprint for a development team. Adhere strictly to the following outline and depth requirements.

### **1. Project Overview**
*   **Summary:** Provide a concise, high-level summary of the system to be built, its purpose, and its primary value proposition.
*   **Goals:** List 3-5 specific, measurable goals the system must achieve. Use bullet points.
*   **Non-Goals:** Explicitly list 2-3 items that are out of scope for this project to prevent scope creep. Use bullet points.
*   **Rationale:** Explain why this system is being built now and how it fits into the broader product or technical strategy.

### **2. System Architecture**
*   **High-Level Diagram:** Describe a system architecture diagram in text (e.g., "A client-server model with a React frontend, Node.js API layer, and PostgreSQL database, hosted on AWS"). Optionally, provide a Mermaid.js code block for a visual representation.
*   **Architectural Patterns:** Detail the chosen patterns (e.g., Microservices, Monolith, Serverless, Event-Driven). Justify this choice with 2-3 paragraphs discussing trade-offs (e.g., development speed, scalability, complexity).
*   **Data Flow:** Describe the end-to-end flow of a critical user request (e.g., "User submits form -> API Gateway -> Auth Service -> Data Processing Service -> Database -> Response"). Use a numbered list or a table.

### **3. Component Descriptions**
*   Break down the system into its logical components or services.
*   For each major component (e.g., `Web Frontend`, `Auth Service`, `Data API`, `Batch Job Processor`):
    *   **Purpose:** A single sentence on its responsibility.
    *   **Technology Stack:** Specify languages, frameworks, and key libraries (e.g., "Python, FastAPI, SQLAlchemy").
    *   **Interactions:** Describe which other components it communicates with and how (e.g., "Calls the User Service via gRPC for profile data").
*   Present this in a table for clarity.

### **4. Data Models**
*   **Database Choice:** Justify the choice of database technology (e.g., Relational SQL vs. NoSQL).
*   **Schema Definition:** Provide detailed definitions for at least two core entities. For each entity:
    *   **Table/Collection Name:** (e.g., `users`)
    *   **Fields:** List fields with data types, constraints, and a brief description.
    *   **Relationships:** Describe relationships to other entities (e.g., "One-to-Many with `posts` table").
*   **Example:** Include a code snippet showing a sample SQL `CREATE TABLE` statement or a JSON schema example.

### **5. API Interfaces**
*   **API Style:** Specify the style (e.g., REST, GraphQL, gRPC) and justify the choice.
*   **Endpoint Examples:** Provide detailed examples for 3-5 critical API endpoints.
    *   For each, include: **Endpoint** (e.g., `POST /v1/users`), **Request Body** (JSON example), **Response Body** (JSON example for success and error), and **Authentication** method.
*   **Example:** Use a Markdown code block to show a full example of a request and response.

### **6. User Interface Design**
*   **UI Framework:** Specify the frontend technology (e.g., React, Vue, Svelte).
*   **Key Screens:** Describe the layout and core components of 2-3 primary user screens (e.g., Dashboard, Data Entry Form).
*   **Interaction Patterns:** Detail how users will interact with the system for a primary use case (e.g., "The user clicks 'Generate Report', which triggers a background job. A status indicator updates via WebSocket.").

### **7. Security Measures**
*   **Authentication & Authorization:** Detail the method (e.g., OAuth 2.0, JWT) and how roles/permissions will be enforced.
*   **Data Security:** Describe encryption strategies (in-transit with TLS, at-rest), secret management (e.g., AWS Secrets Manager), and data sanitization practices.
*   **Threat Mitigation:** List specific measures against common threats (e.g., SQL injection, XSS, CSRF).

### **8. Performance & Scaling**
*   **Performance Targets:** Define quantitative goals (e.g., "API response time < 200ms p95", "Dashboard loads in < 2s").
*   **Scaling Strategy:** Describe how the architecture will scale horizontally/vertically to meet increased load. Mention specific resources (e.g., Database read replicas, auto-scaling groups, CDN).
*   **Bottleneck Analysis:** Identify a potential performance bottleneck (e.g., database queries) and propose a mitigation strategy (e.g., query optimization, caching with Redis).

### **9. Implementation Strategy**
*   **Phased Approach:** Propose a breakdown of the work into 2-3 logical phases or milestones (e.g., "Phase 1: Core API & DB, Phase 2: Basic UI, Phase 3: Advanced Features").
*   **Development Workflow:** Suggest a workflow (e.g., GitFlow, trunk-based development) and required tooling (CI/CD pipeline with Jenkins/GitHub Actions).

### **10. Risks & Mitigations**
*   **Risk Table:** Create a table with columns for `Risk`, `Probability`, `Impact`, and `Mitigation Strategy`.
*   **Identified Risks:** Include at least 3 technical risks (e.g., "Third-party API rate limiting", "Database schema migration failures", "Unexpected latency in a critical path") and their mitigations.

### **11. Testing Strategy**
*   **Testing Pyramid:** Outline the approach to unit, integration, and end-to-end (E2E) testing.
*   **Tools & Coverage:** Specify testing frameworks (e.g., Jest, Pytest, Cypress) and define coverage goals (e.g., ">80% unit test coverage for core services").
*   **QA Process:** Describe the manual and automated QA process before release.

### **12. Dependencies**
*   **Internal Dependencies:** List other teams or systems this project relies on.
*   **External Dependencies:** List all third-party services, APIs, and libraries, noting their purpose and licensing (e.g., "Stripe API for payments", "Apache Kafka under the Apache 2.0 License").

### **13. Success Metrics**
*   **Key Performance Indicators (KPIs):** Define 3-5 measurable metrics to track post-launch to gauge success (e.g., "User sign-ups per day", "System uptime (99.9%)", "Average report generation time").
*   **Monitoring:** Suggest how to monitor these metrics (e.g., Grafana dashboards, application logs).

### **14. Conclusion**
*   **Design Decision Summary:** Recap the key architectural and technology choices made and why they were selected.
*   **Next Steps:** Provide a clear, actionable list of immediate next steps for the engineering team (e.g., "1. Set up project repository. 2. Define CI/CD pipeline. 3. Implement core database schema.").

**Formatting Requirements:**
*   Use clear Markdown headings (`## H2`, `### H3`).
*   Use bullet points and numbered lists for readability.
*   Use tables to present structured, comparative information.
*   Use code blocks (```) for all code snippets, SQL schemas, and API examples.
*   Ensure the document is self-contained and can be understood without external context.

---