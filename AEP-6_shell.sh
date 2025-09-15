# Issue: AEP-6
# Generated: 2025-09-15T09:50:30.599151
# Thread: 70aa205d-EP-6
# Enhanced: DeepSeek model code generation
# AI Model: deepseek/deepseek-chat-v3.1:free
# Max Length: 8000 characters
# Agent: Developer Agent for Development Domain

   git clone <repository-url>
   cd aep-project
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Start development services**
   ```bash
   docker-compose up -d
   ```

4. **Setup database**
   ```bash
   npm run db:migrate
   npm run db:seed
   ```

5. **Start development server**
   ```bash
   npm run dev
   ```

## Environment Variables

Create `.env` file with:
```
DATABASE_URL=postgresql://aep_user:password@localhost:5432/aep_staging_db
NODE_ENV=development