-- Devices registered for notifications, by the hash of their auth key.
CREATE TABLE devices (
  key_id TEXT NOT NULL,
  token TEXT NOT NULL,
  platform TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (key_id, token)
) WITHOUT ROWID;
