import pg from "pg";

const { Pool } = pg;

// hosts reached without TLS: docker compose and local dev
const LOCAL_HOSTS = new Set(["localhost", "127.0.0.1", "postgres"]);

// errors that mean "can't reach the database", not "bad query"
const UNAVAILABLE_CODES = new Set([
  "ECONNREFUSED", "ENOTFOUND", "ETIMEDOUT", "ECONNRESET", "EAI_AGAIN",
  "57P01", "57P03", "53300", "DATABASE_UNCONFIGURED",
]);

let pool = null;
let configError = process.env.DATABASE_URL ? null : "DATABASE_URL is not set";

if (!configError) {
  try {
    const url = new URL(process.env.DATABASE_URL);
    const host = process.env.DB_HOST || url.hostname; // DB_HOST overrides the host in the URL

    pool = new Pool({
      host,
      port: Number(url.port || 5432),
      user: decodeURIComponent(url.username),
      password: decodeURIComponent(url.password),
      database: decodeURIComponent(url.pathname.slice(1)),
      // RDS Postgres 16 enforces TLS; v1 skips CA verification
      ssl: LOCAL_HOSTS.has(host) ? false : { rejectUnauthorized: false },
      max: 5,
      connectionTimeoutMillis: 3000, // fail fast instead of hanging a request
      statement_timeout: 10000,
    });

    // an idle connection can drop (failover, network); log it instead of crashing
    pool.on("error", (err) => console.error("idle database connection error:", err.message));
  } catch (err) {
    configError = `invalid DATABASE_URL: ${err.message}`;
  }
}

if (configError) console.error(`${configError}; database routes will return 503`);

export async function query(text, params) {
  if (!pool) {
    const err = new Error(configError);
    err.code = "DATABASE_UNCONFIGURED";
    throw err;
  }
  return pool.query(text, params);
}

// "read-only", "unavailable", or null for anything else
export function classifyError(err) {
  const code = err?.code ? String(err.code) : "";
  if (code === "25006") return "read-only"; // what a standby replica returns for writes
  if (UNAVAILABLE_CODES.has(code) || code.startsWith("08")) return "unavailable";
  if (/timeout exceeded when trying to connect|Connection terminated/i.test(err?.message ?? "")) return "unavailable";
  return null;
}

export { pool };
