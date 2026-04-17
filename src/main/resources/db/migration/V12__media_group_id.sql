-- Media grouping for Telegram-style photo/video albums.
-- Multiple messages sharing the same media_group_id are rendered
-- as a single album bubble in the client. Kept nullable so that
-- every existing (and future single-media) row remains untouched.
ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS media_group_id UUID NULL;

CREATE INDEX IF NOT EXISTS idx_messages_media_group
    ON messages (conversation_id, media_group_id)
    WHERE media_group_id IS NOT NULL;
