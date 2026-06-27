CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone        TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  bio          TEXT DEFAULT '',
  invite_code  TEXT UNIQUE NOT NULL,
  avatar       JSONB NOT NULL DEFAULT '{}',
  is_ghost     BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS friendships (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);
CREATE INDEX IF NOT EXISTS idx_friendships_user ON friendships(user_id);

CREATE TABLE IF NOT EXISTS locations (
  user_id       UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  latitude      DOUBLE PRECISION NOT NULL,
  longitude     DOUBLE PRECISION NOT NULL,
  battery       INTEGER NOT NULL DEFAULT 100,
  is_charging   BOOLEAN NOT NULL DEFAULT false,
  movement      TEXT NOT NULL DEFAULT 'stationary',
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS conversations (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  participant_a    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  participant_b    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  last_message     TEXT,
  last_message_at  TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(participant_a, participant_b)
);
CREATE INDEX IF NOT EXISTS idx_conv_a ON conversations(participant_a);
CREATE INDEX IF NOT EXISTS idx_conv_b ON conversations(participant_b);

CREATE TABLE IF NOT EXISTS messages (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content         TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(conversation_id, created_at);

CREATE TABLE IF NOT EXISTS places (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  emoji       TEXT NOT NULL DEFAULT '📍',
  latitude    DOUBLE PRECISION,
  longitude   DOUBLE PRECISION,
  visit_count INTEGER NOT NULL DEFAULT 1,
  last_visit  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_places_user ON places(user_id);
