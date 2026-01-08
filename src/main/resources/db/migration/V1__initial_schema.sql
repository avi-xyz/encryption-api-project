-- Initial schema: encrypted_data table
-- Creates the core table for storing encrypted data

CREATE TABLE encrypted_data (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cipher_text MEDIUMBLOB NOT NULL,
    encryption_key BLOB NOT NULL,
    iv VARBINARY(12) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Index for performance on timestamp queries
CREATE INDEX idx_created_at ON encrypted_data(created_at);
