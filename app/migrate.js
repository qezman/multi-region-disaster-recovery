import { pool } from './db.js';

// run once per database with `npm run migrate`, never from server.js: the standby is read-only
const migrationSQL = `
  CREATE TABLE IF NOT EXISTS transfers (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key    VARCHAR(255) UNIQUE NOT NULL,
    request_hash       VARCHAR(64) NOT NULL,
    amount             BIGINT NOT NULL CHECK (amount > 0),
    source_currency    VARCHAR(3) NOT NULL,
    target_currency    VARCHAR(3) NOT NULL,
    fx_rate            NUMERIC NOT NULL,
    fee                BIGINT NOT NULL,
    recipient_receives BIGINT NOT NULL,
    recipient          JSONB NOT NULL,
    region             VARCHAR(50) NOT NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );

  CREATE INDEX IF NOT EXISTS idx_transfers_created_at ON transfers (created_at DESC);
`;

async function runMigration() {
  if (!pool) {
    process.exitCode = 1;
    return;
  }
  try {
    await pool.query(migrationSQL);
    console.log('migrate: transfers table ready');
  } catch (err) {
    console.error('migrate failed:', err.message);
    process.exitCode = 1; // so a one-off ECS task shows as failed
  } finally {
    await pool.end();
  }
}

runMigration();
