-- V3: Message Requests — статус участника диалога (ACTIVE/PENDING)
-- PENDING = запрос сообщения (получатель ещё не принял)
-- ACTIVE = обычный участник (принял или инициатор)

ALTER TABLE conversation_participants ADD COLUMN status VARCHAR(20) DEFAULT 'ACTIVE';
UPDATE conversation_participants SET status = 'ACTIVE' WHERE status IS NULL;
ALTER TABLE conversation_participants ALTER COLUMN status SET DEFAULT 'ACTIVE';
CREATE INDEX idx_participants_status ON conversation_participants(user_id, status);
