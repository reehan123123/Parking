import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Client } from 'pg';

const databaseUrl = process.env.TENANT_MEMBER_TEST_DATABASE_URL;

test(
  'concurrent member additions serialize the final tenant slot',
  {
    skip: databaseUrl
      ? false
      : 'Set TENANT_MEMBER_TEST_DATABASE_URL to a local Supabase database.',
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
        'The tenant member concurrency test requires the local Supabase PostgreSQL endpoint.',
      );
    }

    const ownerId = randomUUID();
    const firstMemberId = randomUUID();
    const secondMemberId = randomUUID();
    const tenantId = randomUUID();
    const ownerSessionId = randomUUID();
    const ownerInstallationId = randomUUID();
    const firstEmail = `member-slot-${randomUUID()}@example.test`;
    const secondEmail = `member-slot-${randomUUID()}@example.test`;
    const setupClient = new Client({ connectionString: databaseUrl });
    const firstClient = new Client({ connectionString: databaseUrl });
    const secondClient = new Client({ connectionString: databaseUrl });
    let isSetupConnected = false;

    try {
      await setupClient.connect();
      isSetupConnected = true;
      await setupClient.query(
        `insert into auth.users (id, email)
         values ($1, $2), ($3, $4), ($5, $6)`,
        [ownerId, `owner-${randomUUID()}@example.test`,
          firstMemberId, firstEmail, secondMemberId, secondEmail],
      );
      await setupClient.query(
        `insert into public.tenants (id, name, slug, created_by, valid_until)
         values (
           $1,
           'Tenant member concurrency test',
           $2,
           $3,
           (now() at time zone 'Asia/Kolkata')::date + 3650
         )`,
        [tenantId, `member-test-${tenantId.replaceAll('-', '')}`, ownerId],
      );
      await setupClient.query(
        `insert into public.tenant_memberships (tenant_id, user_id, role)
         values ($1, $2, 'owner')`,
        [tenantId, ownerId],
      );
      await setupClient.query(
        `insert into public.device_sessions (
           tenant_id,
           user_id,
           auth_session_id,
           installation_id
         )
         values ($1, $2, $3, $4)`,
        [tenantId, ownerId, ownerSessionId, ownerInstallationId],
      );

      await Promise.all([firstClient.connect(), secondClient.connect()]);
      const results = await Promise.all([
        addMember(firstClient, ownerId, ownerSessionId, tenantId, firstEmail),
        addMember(secondClient, ownerId, ownerSessionId, tenantId, secondEmail),
      ]);

      const accepted = results.filter((result) => result.accepted);
      const rejected = results.filter((result) => !result.accepted);
      assert.equal(accepted.length, 1);
      assert.equal(rejected.length, 1);
      assert.equal(rejected[0].reason, 'MEMBER_LIMIT_REACHED');

      const activeMembers = await setupClient.query(
        `select count(*)::integer as count
         from public.tenant_memberships
         where tenant_id = $1 and role = 'member'`,
        [tenantId],
      );
      assert.equal(activeMembers.rows[0].count, 1);
    } finally {
      await Promise.allSettled([firstClient.end(), secondClient.end()]);
      if (isSetupConnected) {
        await setupClient.query(
          'delete from public.tenants where id = $1',
          [tenantId],
        );
        await setupClient.query(
          'delete from auth.users where id = any($1::uuid[])',
          [[ownerId, firstMemberId, secondMemberId]],
        );
        await setupClient.end();
      }
    }
  },
);

async function addMember(client, ownerId, ownerSessionId, tenantId, email) {
  await client.query('begin');
  try {
    await client.query('set local role authenticated');
    await client.query(
      "select set_config('request.jwt.claim.sub', $1, true)",
      [ownerId],
    );
    await client.query(
      "select set_config('request.jwt.claims', $1, true)",
      [
        JSON.stringify({
          sub: ownerId,
          role: 'authenticated',
          session_id: ownerSessionId,
          app_metadata: {},
        }),
      ],
    );
    const result = await client.query(
      `select public.add_tenant_member($1::uuid, $2::text, 'member') as result`,
      [tenantId, email],
    );
    await client.query('commit');
    return { accepted: true, member: result.rows[0].result };
  } catch (error) {
    await client.query('rollback');
    if (error.code === 'P0001' && error.message === 'MEMBER_LIMIT_REACHED') {
      return { accepted: false, reason: error.message };
    }
    throw error;
  }
}
