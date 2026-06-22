-- ============================================================
-- Orbit App — Supabase Schema
-- 在 Supabase 控制台 SQL Editor 里粘贴并执行
-- ============================================================

-- 1. 用户档案（扩展 auth.users）
CREATE TABLE profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name  TEXT NOT NULL DEFAULT '',
  bio           TEXT DEFAULT '',
  invite_code   TEXT UNIQUE NOT NULL,
  avatar_json   JSONB DEFAULT '{}',
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 好友关系（双向：A→B 和 B→A 各一行）
CREATE TABLE friendships (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  friend_id   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  is_favorite BOOLEAN DEFAULT FALSE,
  is_ghost    BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);

-- 3. 位置（每用户一行，UPSERT 更新）
CREATE TABLE locations (
  user_id        UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  latitude       DOUBLE PRECISION NOT NULL DEFAULT 0,
  longitude      DOUBLE PRECISION NOT NULL DEFAULT 0,
  location_name  TEXT DEFAULT '',
  battery_level  INT DEFAULT 100,
  is_charging    BOOLEAN DEFAULT FALSE,
  movement       TEXT DEFAULT 'stationary',
  speed_kmh      DOUBLE PRECISION DEFAULT 0,
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- 4. 会话（两个用户之间）
CREATE TABLE conversations (
  id               TEXT PRIMARY KEY,  -- 排序后拼接：uuid1_uuid2
  user1_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  user2_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  last_message     TEXT DEFAULT '',
  last_message_at  TIMESTAMPTZ DEFAULT NOW(),
  unread_count_1   INT DEFAULT 0,
  unread_count_2   INT DEFAULT 0
);

-- 5. 消息
CREATE TABLE messages (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id  TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id        UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  kind             TEXT NOT NULL DEFAULT 'text',  -- text / location / ping
  content          JSONB NOT NULL DEFAULT '{}',
  is_read          BOOLEAN DEFAULT FALSE,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- RLS (Row Level Security)
-- ============================================================
ALTER TABLE profiles      ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships   ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations     ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages      ENABLE ROW LEVEL SECURITY;

-- profiles：所有登录用户可读，只能改自己
CREATE POLICY "profiles_read"   ON profiles FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (id = auth.uid());
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (id = auth.uid());

-- friendships：只能看/改自己的
CREATE POLICY "friendships_all" ON friendships FOR ALL USING (user_id = auth.uid());

-- locations：可读好友位置，只能改自己
CREATE POLICY "locations_read"   ON locations FOR SELECT USING (
  user_id = auth.uid() OR
  EXISTS (SELECT 1 FROM friendships WHERE user_id = auth.uid() AND friend_id = locations.user_id)
);
CREATE POLICY "locations_upsert" ON locations FOR ALL USING (user_id = auth.uid());

-- conversations：参与者可读写
CREATE POLICY "conversations_all" ON conversations FOR ALL USING (
  user1_id = auth.uid() OR user2_id = auth.uid()
);

-- messages：会话参与者可读写
CREATE POLICY "messages_all" ON messages FOR ALL USING (
  EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = messages.conversation_id
    AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
  )
);

-- ============================================================
-- Realtime（开启 locations 和 messages 的实时推送）
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE locations;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE friendships;

-- ============================================================
-- 新用户注册时自动创建 profile（触发器）
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO profiles (id, display_name, invite_code)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', '新用户'),
    'ORBIT-' || UPPER(SUBSTR(REPLACE(NEW.id::TEXT, '-', ''), 1, 6))
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
