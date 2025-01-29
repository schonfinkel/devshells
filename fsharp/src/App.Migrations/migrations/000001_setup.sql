-- Initial Schemas
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS tooling;

-- Initial Roles
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'default_app_user') THEN
            CREATE ROLE default_app_user WITH LOGIN INHERIT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_app_user') THEN
            CREATE ROLE admin_app_user WITH LOGIN INHERIT;
        END IF;
    END
$$;
