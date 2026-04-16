-- Single-device enforcement for E2EE security
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS active_device_id VARCHAR(255),
    ADD COLUMN IF NOT EXISTS device_last_active TIMESTAMP;
