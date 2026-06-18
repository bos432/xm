# Project Application System Modernization

This directory is the new-system workspace for the ThinkPHP 3.1.2 replacement. It is intentionally isolated from the legacy site so the old system can remain available for read-only historical access while the Laravel/Vue system is built and verified.

## What Is Implemented Here

- `backend/`: Laravel 11 source scaffold, API routes, controllers, models, migrations, and security defaults for the core workflow.
- `frontend/`: Vue 3 + Vite + Element Plus application shell for the rebuilt admin and application portals.
- `scripts/`: non-destructive legacy risk scanning and migration helper scripts.
- `docs/`: implementation notes, legacy table mapping, rollout checklist, and acceptance tests.
- `docs/testing.md`: local verification, backend dependency restore, and migration dry-run commands.

## Local Tooling Status

The current machine has PHP 8.3, Node.js, and npm available. Composer is not currently on `PATH`, so the Laravel framework package cannot be installed in this run. After Composer is installed, initialize the backend dependencies with:

```powershell
cd modernization/backend
composer install
copy .env.example .env
php artisan key:generate
php artisan migrate
```

Install and run the frontend with:

```powershell
cd modernization/frontend
npm install
npm run dev
```

## Upgrade Strategy

1. Keep the legacy ThinkPHP system unchanged and read-only during development.
2. Build the new Laravel/Vue system in a test environment using a cloned database.
3. Route new project applications into the new system first.
4. Migrate historical records by module, starting with units, users, projects, files, reviews, and logs.
5. Retire old write paths only after data parity, file checks, and role-based workflow tests pass.
