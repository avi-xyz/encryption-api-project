-- Migration: Add Authentication and Authorization Tables
-- Description: Adds user management, audit logging, and updates encrypted_data for multi-tenancy
-- Version: 2.0
-- Date: 2026-01-07

-- ===========================================================================
-- 1. Create users table
-- ===========================================================================
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    cognito_user_id VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    INDEX idx_cognito_user_id (cognito_user_id),
    INDEX idx_email (email),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===========================================================================
-- 2. Create api_audit_log table
-- ===========================================================================
CREATE TABLE IF NOT EXISTS api_audit_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    action VARCHAR(50) NOT NULL,
    resource_id BIGINT NULL,
    ip_address VARCHAR(45) NULL,
    user_agent TEXT NULL,
    request_path VARCHAR(500) NULL,
    http_method VARCHAR(10) NULL,
    status VARCHAR(20) NOT NULL,
    error_message TEXT NULL,
    execution_time_ms INT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_user_action (user_id, action, created_at),
    INDEX idx_created_at (created_at),
    INDEX idx_status (status),

    CONSTRAINT fk_audit_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===========================================================================
-- 3. Modify encrypted_data table - add user_id column
-- ===========================================================================
-- Add user_id column if it doesn't exist
SET @dbname = DATABASE();
SET @tablename = "encrypted_data";
SET @columnname = "user_id";
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (table_name = @tablename)
      AND (table_schema = @dbname)
      AND (column_name = @columnname)
  ) > 0,
  "SELECT 1",
  CONCAT("ALTER TABLE ", @tablename, " ADD COLUMN ", @columnname, " VARCHAR(36) NULL AFTER id")
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- Create index for user data queries
-- Note: We don't use "IF NOT EXISTS" here because FlywayRepairConfig cleanup ensures clean state
CREATE INDEX idx_user_data ON encrypted_data(user_id, created_at DESC);

-- ===========================================================================
-- 4. Create API keys table (for API key rotation)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS api_keys (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(100) NOT NULL,
    key_value VARCHAR(255) NOT NULL UNIQUE,
    user_id VARCHAR(36) NULL,
    environment VARCHAR(50) NOT NULL DEFAULT 'production',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    last_used_at TIMESTAMP NULL,
    usage_count BIGINT NOT NULL DEFAULT 0,

    INDEX idx_key_value (key_value),
    INDEX idx_is_active (is_active),
    INDEX idx_user_id (user_id),

    CONSTRAINT fk_apikey_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===========================================================================
-- 5. Add foreign key constraint to encrypted_data (after user_id column exists)
-- ===========================================================================
-- Note: We'll add the foreign key constraint AFTER the migration phase
-- because existing data won't have user_id values yet.
-- The constraint will be added in a separate migration once data is cleaned up.

-- ===========================================================================
-- 6. Create view for user statistics
-- ===========================================================================
CREATE OR REPLACE VIEW user_statistics AS
SELECT
    u.id AS user_id,
    u.email,
    u.full_name,
    COUNT(DISTINCT ed.id) AS total_encrypted_records,
    COUNT(DISTINCT al.id) AS total_api_calls,
    MAX(ed.created_at) AS last_encryption_at,
    MAX(al.created_at) AS last_api_call_at,
    u.created_at AS user_created_at,
    u.last_login_at
FROM users u
LEFT JOIN encrypted_data ed ON u.id = ed.user_id
LEFT JOIN api_audit_log al ON u.id = al.user_id
GROUP BY u.id, u.email, u.full_name, u.created_at, u.last_login_at;

-- ===========================================================================
-- 7. Insert default system user (for any orphaned data)
-- ===========================================================================
INSERT INTO users (id, cognito_user_id, email, full_name, is_active)
VALUES (
    '00000000-0000-0000-0000-000000000000',
    'system',
    'system@encryption-api.internal',
    'System User',
    FALSE
)
ON DUPLICATE KEY UPDATE id=id;

-- ===========================================================================
-- 8. Update existing encrypted_data records to system user
-- ===========================================================================
UPDATE encrypted_data
SET user_id = '00000000-0000-0000-0000-000000000000'
WHERE user_id IS NULL;

-- ===========================================================================
-- 9. Make user_id NOT NULL after data migration
-- ===========================================================================
ALTER TABLE encrypted_data
    MODIFY COLUMN user_id VARCHAR(36) NOT NULL;

-- ===========================================================================
-- 10. Add foreign key constraint now that data is migrated
-- ===========================================================================
ALTER TABLE encrypted_data
    ADD CONSTRAINT fk_encrypted_data_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- ===========================================================================
-- Migration complete
-- ===========================================================================
