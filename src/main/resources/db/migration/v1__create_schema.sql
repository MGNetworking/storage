CREATE TABLE files (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    stored_name VARCHAR(255) NOT NULL,
    file_hash CHAR(64) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    size BIGINT NOT NULL,
    storage_path VARCHAR(500) NOT NULL,
    uploaded_at TIMESTAMP DEFAULT NOW(),
    extra_metadata JSONB,
    CONSTRAINT unique_file_per_user UNIQUE (user_id, file_hash)
);