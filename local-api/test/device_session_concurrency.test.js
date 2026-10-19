import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Client } from 'pg';

const databaseUrl = process.env.DEVICE_SESSION_TEST_DATABASE_URL;

test(
  'concurrent registrations serialize the final device slot',
  {
    skip: databaseUrl
      ? false
      : 'Set DEVICE_SESSION_TEST_DATABASE_URL to a local Supabase database.',
  },
  async () => {
    const databaseUri = new URL(databaseUrl);
    const isLocalSupabaseDatabase =
      ['postgres:', 'postgresql:'].includes(databaseUri.protocol) &&
      ['localhost', '127.0.0.1', '[::1]', '::1'].includes(databaseUri.hostname) &&
      databaseUri.port === '54322' &&
      databaseUri.pathname === '/postgres' &&
      databaseUri.username === 'postgres';
    if (!isLocalSupabaseDatabase) {
      throw new Error(
        'The device-session concurrency test requires the local Supabase PostgreSQL endpoint.',
      );
    }

    const userId = randomUUID();
    const tenantId = randomUUID();
    const firstInstallationId = randomUUID();
    const secondInstallationId = randomUUID();
    const sessionIds = [randomUUID(), randomUUID()];
    const email = `device-session-${randomUUID()}@example.test`;
    const setupClient = new Client({ connectionString: databaseUrl });
    const firstClient = new Client({ connectionString: databaseUrl });
    const secondClient = new Client({ connectionString: databaseUrl });
    let isSetupConnected = false;

    try {
      await setupClient.connect();
      isSetupConnected = true;
      await setupClient.query(
        'insert into auth.users (id, email) values ($1, $2)',
        [userId, email],
      );
      await setupClient.query(
        `insert into public.tenants (
           id,
           name,
           slug,
           created_by,
           valid_until
         )
         values (
           $1,
           $2,
           $3,
           $4,
           (now() at time zone 'Asia/Kolkata')::date + 3650
         )`,
        [
          tenantId,
          'Device session concurrency test',
          `device-session-${tenantId.replaceAll('-', '')}`,
          userId,
        ],
      );
      await setupClient.query(
        `insert into public.tenant_memberships (tenant_id, user_id, role)
         values ($1, $2, 'owner')`,
        [tenantId, userId],
      );
      await setupClient.query(
        `update public.tenant_device_session_policies
         set device_limit = 1
         where tenant_id = $1`,
        [tenantId],
      );

      await Promise.all([firstClient.connect(), secondClient.connect()]);
      const results = await Promise.all([
        registerSession(
          firstClient,
          userId,
          tenantId,
          sessionIds[0],
          firstInstallationId,
        ),
        registerSession(
          secondClient,
          userId,
          tenantId,
          sessionIds[1],
          secondInstallationId,
        ),
      ]);

      const accepted = results.filter((result) => result.accepted === true);
      const rejected = results.filter((result) => result.accepted === false);
      assert.equal(accepted.length, 1);
      assert.equal(rejected.length, 1);
      assert.equal(rejected[0].reason, 'device_limit_reached');
      assert.equal(rejected[0].effective_limit, 1);

      const activeDevices = await setupClient.query(
        `select count(distinct installation_id)::integer as count
         from public.device_sessions
         where tenant_id = $1 and user_id = $2 and status = 'active'`,
        [tenantId, userId],
      );
      assert.equal(activeDevices.rows[0].count, 1);
    } finally {
      await Promise.allSettled([
        firstClient.end(),
        secondClient.end(),
      ]);
      if (isSetupConnected) {
        await setupClient.query(
          'delete from public.device_session_audit_events where tenant_id = $1',
          [tenantId],
        );
        await setupClient.query('delete from public.tenants where id = $1', [
          tenantId,
        ]);
        await setupClient.query('delete from auth.users where id = $1', [
          userId,
        ]);
        await setupClient.end();
      }
    }
  },
);

async function registerSession(
  client,
  userId,
  tenantId,
  sessionId,
  installationId,
) {
  await client.query('begin');
  try {
    await client.query('set local role authenticated');
    await client.query(
      "select set_config('request.jwt.claim.sub', $1, true)",
      [userId],
    );
    await client.query(
      "select set_config('request.jwt.claims', $1, true)",
      [
        JSON.stringify({
          sub: userId,
          role: 'authenticated',
          session_id: sessionId,
          app_metadata: {},
        }),
      ],
    );
    const result = await client.query(
      `select public.register_device_session($1::uuid, $2::uuid) as result`,
      [tenantId, installationId],
    );
    await client.query('commit');
    return result.rows[0].result;
  } catch (error) {
    await client.query('rollback');
    throw error;
  }
}
