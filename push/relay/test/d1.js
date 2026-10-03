// A D1 stand-in on node:sqlite, covering the calls the relay makes.
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";

export function memoryD1() {
  const db = new DatabaseSync(":memory:");
  db.exec(readFileSync(new URL("../migrations/0001_devices.sql", import.meta.url), "utf8"));
  const statement = (sql, params = []) => ({
    bind: (...values) => statement(sql, values),
    all: async () => ({ results: db.prepare(sql).all(...params).map((row) => ({ ...row })) }),
    run: async () => (db.prepare(sql).run(...params), { success: true }),
    exec: () => db.prepare(sql).run(...params),
  });
  return {
    sqlite: db,
    prepare: (sql) => statement(sql),
    batch: async (statements) => {
      db.exec("BEGIN");
      try {
        for (const s of statements) s.exec();
        db.exec("COMMIT");
      } catch (error) {
        db.exec("ROLLBACK");
        throw error;
      }
      return statements.map(() => ({ success: true }));
    },
  };
}

export const rows = (d1) => d1.sqlite.prepare("SELECT * FROM devices ORDER BY updated_at DESC").all();
