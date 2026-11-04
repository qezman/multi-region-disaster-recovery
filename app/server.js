import Fastify from "fastify";
import crypto from "crypto";
import { pool, query, classifyError } from "./db.js";

const region = process.env.AWS_REGION_NAME || "unknown";
const port = Number(process.env.PORT || 3000);

const fastify = Fastify({
  logger: { base: { region } },
  // strict body checks: "100" is not an amount, and unknown fields are rejected
  ajv: { customOptions: { coerceTypes: false, removeAdditional: false } },
});

// demo rates, not live data. Amounts are in minor units (pence, cents, kobo)
const RATES = {
  'GBP:NGN': { rate: '1950.000000', feeBps: 120 },
  'USD:NGN': { rate: '1550.000000', feeBps: 120 },
  'EUR:NGN': { rate: '1700.000000', feeBps: 120 },
  'CAD:NGN': { rate: '1120.000000', feeBps: 120 },
};

// every query returns the row plus its age, so status uses the database clock
const COLUMNS = "*, extract(epoch from now() - created_at)::float8 AS age";

// "2050.25" -> 2050250000n (millionths), so the money maths stays in integers
function toMicros(rate) {
  const [whole, frac = ""] = rate.split(".");
  return BigInt(whole + frac.padEnd(6, "0").slice(0, 6));
}

// sorted keys, so the same body always hashes the same
function sortObjectKeys(obj) {
  if (obj === null || typeof obj !== "object" || Array.isArray(obj)) {
    return obj;
  }
  return Object.keys(obj)
    .sort()
    .reduce((acc, key) => {
      acc[key] = sortObjectKeys(obj[key]);
      return acc;
    }, {});
}

// no worker yet, so status comes from how old the transfer is
function statusFor(ageSeconds) {
  if (ageSeconds < 5) return "pending";
  if (ageSeconds < 20) return "processing";
  return "completed";
}

function toTransfer(row) {
  return {
    id: row.id,
    status: statusFor(row.age),
    amount: Number(row.amount),
    source_currency: row.source_currency,
    target_currency: row.target_currency,
    fx_rate: Number(row.fx_rate),
    fee: Number(row.fee),
    recipient_receives: Number(row.recipient_receives),
    recipient: row.recipient,
    created_in_region: row.region,
    created_at: row.created_at,
  };
}

// every response says which region served it
fastify.addHook("onSend", async (request, reply, payload) => {
  reply.header("X-Served-By-Region", region);
  return payload;
});

fastify.addHook("preSerialization", async (request, reply, payload) => {
  if (payload && typeof payload === "object" && !Array.isArray(payload)) {
    payload.region = region;
  }
  return payload;
});

fastify.setNotFoundHandler((request, reply) => {
  reply.code(404).send({ error: "Not Found", message: "Route not found" });
});

fastify.setErrorHandler((error, request, reply) => {
  if (error.validation) {
    return reply
      .code(400)
      .send({ error: "Bad Request", message: error.message });
  }

  // fastify's own 4xx errors (bad JSON, wrong content type) pass through
  if (error.statusCode >= 400 && error.statusCode < 500) {
    return reply
      .code(error.statusCode)
      .send({ error: error.name, message: error.message });
  }

  const kind = classifyError(error);
  if (kind === "read-only") {
    request.log.warn("write rejected, database is read-only");
    return reply
      .code(503)
      .send({
        error: "read_only_mode",
        message: "Database is in read-only mode",
      });
  }
  if (kind === "unavailable") {
    request.log.error({ code: error.code }, "database unavailable");
    return reply
      .code(503)
      .send({
        error: "db_unavailable",
        message: "Database is currently unavailable",
      });
  }

  request.log.error(error);
  return reply
    .code(500)
    .send({
      error: "Internal Server Error",
      message: "An unexpected error occurred",
    });
});

// never touches the database, so a DB outage doesn't pull the task out of the load balancer
fastify.get("/health", async () => ({ status: "ok", region }));

const postTransferSchema = {
  body: {
    type: "object",
    additionalProperties: false,
    required: ["amount", "source_currency", "target_currency", "recipient"],
    properties: {
      amount: { type: "integer", minimum: 1, maximum: 1000000000000 },
      source_currency: { type: "string", pattern: "^[A-Z]{3}$" },
      target_currency: { type: "string", pattern: "^[A-Z]{3}$" },
      recipient: {
        type: "object",
        additionalProperties: false,
        required: ["name", "bank", "account_number"],
        properties: {
          name: { type: "string", minLength: 1, maxLength: 200 },
          bank: { type: "string", minLength: 1, maxLength: 200 },
          account_number: { type: "string", minLength: 1, maxLength: 34 },
        },
      },
    },
  },
};

fastify.post("/transfers", {
  schema: postTransferSchema,
  // runs before body validation, so a missing key is reported first
  preValidation: async (request, reply) => {
    const key = request.headers["idempotency-key"];
    if (!key || key.length > 255) {
      reply
        .code(400)
        .send({
          error: "Bad Request",
          message: "Missing or invalid Idempotency-Key header",
        });
      return reply;
    }
    request.idempotencyKey = key;
  },
  handler: async (request, reply) => {
    const body = request.body;

    const pair = RATES[`${body.source_currency}:${body.target_currency}`];
    if (!pair) {
      return reply.code(422).send({
        error: "unsupported_currency_pair",
        message: `Supported pairs: ${Object.keys(RATES).join(", ")}`,
      });
    }

    const amount = BigInt(body.amount);
    const fee = (amount * BigInt(pair.feeBps) + 9999n) / 10000n; // rounded up
    const receives = ((amount - fee) * toMicros(pair.rate)) / 1000000n; // rounded down
    if (receives <= 0n) {
      return reply
        .code(422)
        .send({
          error: "amount_too_small",
          message: "Amount does not cover the fee",
        });
    }

    const requestHash = crypto
      .createHash("sha256")
      .update(JSON.stringify(sortObjectKeys(body)))
      .digest("hex");

    // the unique key does the locking: of N concurrent requests, exactly one insert wins
    const inserted = await query(
      `INSERT INTO transfers (idempotency_key, request_hash, amount, source_currency, target_currency,
                              fx_rate, fee, recipient_receives, recipient, region)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       ON CONFLICT (idempotency_key) DO NOTHING
       RETURNING ${COLUMNS}`,
      [
        request.idempotencyKey,
        requestHash,
        amount.toString(),
        body.source_currency,
        body.target_currency,
        pair.rate,
        fee.toString(),
        receives.toString(),
        body.recipient,
        region,
      ],
    );
    if (inserted.rows.length === 1) {
      return reply.code(201).send(toTransfer(inserted.rows[0]));
    }

    // the key already exists: replay it if the body matches, refuse if it doesn't
    const existing = await query(
      `SELECT ${COLUMNS} FROM transfers WHERE idempotency_key = $1`,
      [request.idempotencyKey],
    );
    const row = existing.rows[0];
    if (row.request_hash !== requestHash) {
      return reply.code(422).send({
        error: "idempotency_key_reuse",
        message: "Idempotency key was already used with a different body",
      });
    }

    reply.header("Idempotent-Replay", "true");
    return reply.code(200).send(toTransfer(row));
  },
});

const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

fastify.get("/transfers/:id", async (request, reply) => {
  const { id } = request.params;

  // a malformed id would make Postgres throw (22P02), so treat it as not found
  if (!uuidRegex.test(id)) {
    return reply
      .code(404)
      .send({ error: "Not Found", message: "Transfer not found" });
  }

  const res = await query(`SELECT ${COLUMNS} FROM transfers WHERE id = $1`, [
    id,
  ]);
  if (res.rows.length === 0) {
    return reply
      .code(404)
      .send({ error: "Not Found", message: "Transfer not found" });
  }
  return toTransfer(res.rows[0]);
});

fastify.get("/transfers", async (request) => {
  // query strings aren't coerced, so parse limit by hand: default 20, max 100
  const parsed = Number.parseInt(request.query.limit, 10);
  const limit = Number.isNaN(parsed) ? 20 : Math.min(Math.max(parsed, 1), 100);

  const res = await query(
    `SELECT ${COLUMNS} FROM transfers ORDER BY created_at DESC LIMIT $1`,
    [limit],
  );
  return { transfers: res.rows.map(toTransfer) };
});

let isShuttingDown = false;
async function gracefulShutdown(signal) {
  if (isShuttingDown) return;
  isShuttingDown = true;
  fastify.log.info(`Received ${signal}, starting graceful shutdown.`);

  try {
    await fastify.close();
    if (pool) {
      await pool.end();
    }
    process.exit(0);
  } catch (err) {
    console.error("Error during shutdown:", err);
    process.exit(1);
  }
}

process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT", () => gracefulShutdown("SIGINT"));

const start = async () => {
  try {
    await fastify.listen({ port, host: "0.0.0.0" });
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};
start();
