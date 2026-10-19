import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import { createServer } from 'node:http';
import { mkdir, readFile, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Pool } from 'pg';

import {
  generateTemporaryPassword,
  hashAccessToken,
  hashPassword,
  signPhotoUrl,
  verifyPassword,
  verifyPhotoUrlSignature,
} from './security.js';
import {
  parsePhotoPath,
  photoContentType,
  resolvePhotoPath,
} from './photo_paths.js';

const jsonBodyLimit = 1024 * 1024;
const photoBodyLimit = 10 * 1024 * 1024;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const durationUnits = new Set(['minutes', 'hours', 'days', 'months']);
const allowedOrigins = new Set([
  'http://localhost:5211',
  'http://127.0.0.1:5211',
]);

class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export function readLocalApiConfig(environment = process.env) {
  const databaseUrl = parseUrl(
    environment.PARKING_LOCAL_DATABASE_URL,
    'PARKING_LOCAL_DATABASE_URL',
  );
  if (
    !['postgres:', 'postgresql:'].includes(databaseUrl.protocol) ||
    !['127.0.0.1', 'localhost', '[::1]', '::1'].includes(databaseUrl.hostname) ||
    databaseUrl.port !== '5432' ||
    databaseUrl.pathname !== '/parking_local' ||
    databaseUrl.username !== 'parking_api' ||
    databaseUrl.password.length === 0 ||
    databaseUrl.search.length > 0 ||
    databaseUrl.hash.length > 0
  ) {
    throw new Error(
      'The local API database must be parking_local on the loopback host.',
    );
  }

  const apiUrl = parseUrl(
    environment.PARKING_LOCAL_API_URL ?? 'http://127.0.0.1:8765',
    'PARKING_LOCAL_API_URL',
  );
  const port = Number(environment.PARKING_LOCAL_API_PORT ?? apiUrl.port);
  if (
    apiUrl.protocol !== 'http:' ||
    !['127.0.0.1', 'localhost', '[::1]', '::1'].includes(apiUrl.hostname) ||
    apiUrl.username.length > 0 ||
    apiUrl.password.length > 0 ||
    apiUrl.search.length > 0 ||
    apiUrl.hash.length > 0 ||
    (apiUrl.pathname.length > 0 && apiUrl.pathname !== '/') ||
    !Number.isInteger(port) ||
    port < 1 ||
    port > 65535
  ) {
    throw new Error('The local API must use an HTTP loopback address.');
  }

  const signingSecret = environment.PARKING_LOCAL_API_SIGNING_SECRET ?? '';
  if (Buffer.byteLength(signingSecret, 'utf8') < 32) {
    throw new Error('The local API signing secret must be at least 32 bytes.');
  }

  const storageRoot = environment.PARKING_LOCAL_STORAGE_DIR ?? '';
  if (!path.isAbsolute(storageRoot)) {
    throw new Error('PARKING_LOCAL_STORAGE_DIR must be an absolute path.');
  }

  return {
    apiUrl: new URL('/', apiUrl).toString().replace(/\/$/, ''),
    databaseUrl: databaseUrl.toString(),
    host: '127.0.0.1',
    port,
    signingSecret,
    storageRoot: path.resolve(storageRoot),
  };
}

export function createLocalApiServer({ pool, config }) {
  const storageRoot = path.resolve(config.storageRoot);
  const signingSecret = config.signingSecret;
  const server = createServer(async (request, response) => {
    let url;
    try {
      validateHost(request, config.port);
      setCorsHeaders(request, response);
      url = new URL(request.url ?? '/', `http://${request.headers.host}`);

      if (request.method === 'OPTIONS') {
        response.writeHead(204);
        response.end();
        return;
      }

      if (request.method === 'GET' && url.pathname === '/healthz') {
        await pool.query('select 1');
        sendJson(response, 200, { status: 'ok' });
        return;
      }

      if (request.method === 'POST' && url.pathname === '/api/auth/sign-in') {
        await signIn(request, response, pool);
        return;
      }

      if (
        request.method === 'GET' &&
        url.pathname === '/api/photos/content'
      ) {
        await serveSignedPhoto(url, response, {
          signingSecret,
          storageRoot,
        });
        return;
      }

      const user = await authenticateRequest(request, pool);
      if (
        user.requiresPasswordChange &&
        !(
          request.method === 'GET' &&
          url.pathname === '/api/auth/me'
        ) &&
        !(
          request.method === 'POST' &&
          ['/api/auth/change-password', '/api/auth/sign-out'].includes(
            url.pathname,
          )
        )
      ) {
        throw new ApiError(
          403,
          'password_change_required',
          'Change your temporary password before accessing local parking data.',
        );
      }

      await routeAuthenticatedRequest(request, response, url, user, {
        pool,
        signingSecret,
        storageRoot,
        apiUrl: config.apiUrl,
      });
    } catch (error) {
      if (response.headersSent) {
        response.destroy();
        return;
      }

      if (error instanceof ApiError) {
        sendJson(response, error.status, {
          error: { code: error.code, message: error.message },
        });
        return;
      }

      console.error(
        `[local-api] ${request.method ?? 'unknown'} ${url?.pathname ?? '/'}: request failed`,
      );
      sendJson(response, 500, {
        error: {
          code: 'server_error',
          message: 'The local API could not complete the request.',
        },
      });
    }
  });

  return server;
}

function validateHost(request, port) {
  const host = (request.headers.host ?? '').toLowerCase();
  const allowedHosts = new Set([
    `127.0.0.1:${port}`,
    `localhost:${port}`,
    `[::1]:${port}`,
  ]);
  if (!allowedHosts.has(host)) {
    throw new ApiError(400, 'invalid_host', 'The local API host is invalid.');
  }
}

function setCorsHeaders(request, response) {
  const origin = request.headers.origin;
  if (origin == null) {
    return;
  }
  if (!allowedOrigins.has(origin)) {
    throw new ApiError(403, 'origin_not_allowed', 'This local origin is not allowed.');
  }

  response.setHeader('Access-Control-Allow-Origin', origin);
  response.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,PUT,DELETE,OPTIONS');
  response.setHeader(
    'Access-Control-Allow-Headers',
    'Authorization,Content-Type,X-Upsert',
  );
  response.setHeader('Access-Control-Max-Age', '600');
  response.setHeader('Vary', 'Origin');
}

async function routeAuthenticatedRequest(
  request,
  response,
  url,
  user,
  dependencies,
) {
  const { method } = request;
  const { pathname } = url;
  const { pool, signingSecret, storageRoot, apiUrl } = dependencies;

  if (method === 'GET' && pathname === '/api/auth/me') {
    sendJson(response, 200, {
      id: user.id,
      email: user.email,
      requiresTemporaryPasswordChange: user.requiresPasswordChange,
    });
    return;
  }
  if (method === 'POST' && pathname === '/api/auth/change-password') {
    await changePassword(request, response, user, pool);
    return;
  }
  if (method === 'POST' && pathname === '/api/auth/sign-out') {
    await pool.query(
      'delete from core.auth_sessions where token_hash = $1',
      [user.tokenHash],
    );
    response.writeHead(204);
    response.end();
    return;
  }

  if (pathname.startsWith('/api/tenants')) {
    await handleTenantRequest(request, response, url, user, pool);
    return;
  }
  if (pathname.startsWith('/api/parking-sessions')) {
    await handleParkingRequest(request, response, url, user, pool);
    return;
  }
  if (pathname === '/api/photos' || pathname.startsWith('/api/photos/')) {
    await handlePhotoRequest(request, response, url, user, {
      pool,
      signingSecret,
      storageRoot,
      apiUrl,
    });
    return;
  }

  throw new ApiError(404, 'not_found', 'The requested local API route was not found.');
}

async function authenticateRequest(request, pool) {
  const authorization = request.headers.authorization ?? '';
  const match = /^Bearer ([A-Za-z0-9_-]{40,})$/.exec(authorization);
  if (match == null) {
    throw new ApiError(401, 'authentication_required', 'Sign in to continue.');
  }

  const tokenHash = hashAccessToken(match[1]);
  const result = await pool.query(
    `select u.id, u.email, u.requires_password_change
       from core.auth_sessions as auth_session
       join core.users as u on u.id = auth_session.user_id
      where auth_session.token_hash = $1
        and auth_session.expires_at > now()`,
    [tokenHash],
  );
  const row = result.rows[0];
  if (row == null) {
    throw new ApiError(401, 'session_expired', 'Your local sign-in session expired.');
  }

  return {
    id: row.id,
    email: row.email,
    requiresPasswordChange: row.requires_password_change,
    tokenHash,
  };
}

async function signIn(request, response, pool) {
  const body = await readJsonBody(request);
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  if (email.length > 254 || password.length > 128 || password.length === 0) {
    throw new ApiError(400, 'invalid_credentials', 'The email or password is incorrect.');
  }

  const result = await pool.query(
    `select id, email, password_hash, requires_password_change
       from core.users
      where lower(email) = $1
      limit 1`,
    [email],
  );
  const user = result.rows[0];
  if (user == null || !(await verifyPassword(password, user.password_hash))) {
    throw new ApiError(401, 'invalid_credentials', 'The email or password is incorrect.');
  }

  const token = randomBytes(32).toString('base64url');
  const tokenHash = hashAccessToken(token);
  const expiresAt = new Date(Date.now() + 8 * 60 * 60 * 1000);
  await pool.query(
    'delete from core.auth_sessions where expires_at <= now()',
  );
  await pool.query(
    `insert into core.auth_sessions (token_hash, user_id, expires_at)
     values ($1, $2, $3)`,
    [tokenHash, user.id, expiresAt],
  );
  sendJson(response, 200, {
    accessToken: token,
    expiresAt: expiresAt.toISOString(),
    user: {
      id: user.id,
      email: user.email,
      requiresTemporaryPasswordChange: user.requires_password_change,
    },
  });
}

async function changePassword(request, response, user, pool) {
  if (!user.requiresPasswordChange) {
    throw new ApiError(
      409,
      'password_change_not_required',
      'This local account does not require a temporary password change.',
    );
  }
  const body = await readJsonBody(request);
  const password = typeof body.newPassword === 'string' ? body.newPassword : '';
  if (password.length < 12 || password.length > 128) {
    throw new ApiError(
      400,
      'invalid_password',
      'Use a password between 12 and 128 characters.',
    );
  }

  const passwordHash = await hashPassword(password);
  await pool.query(
    `update core.users
        set password_hash = $2,
            requires_password_change = false
      where id = $1`,
    [user.id, passwordHash],
  );
  sendJson(response, 200, { success: true });
}

async function handleTenantRequest(request, response, url, user, pool) {
  const segments = pathSegments(url.pathname);
  if (segments.length === 3 && segments[2] === 'access' && request.method === 'GET') {
    await loadTenantAccess(response, user.id, pool);
    return;
  }
  if (segments.length === 2 && segments[1] === 'tenants' && request.method === 'POST') {
    await createTenant(request, response, user, pool);
    return;
  }

  if (segments.length >= 3 && segments[1] === 'tenants') {
    const tenantId = requireUuid(segments[2], 'tenant');
    if (segments.length === 3 && request.method === 'PATCH') {
      await updateTenant(request, response, user, tenantId, pool);
      return;
    }
    if (
      segments.length === 4 &&
      ['archive', 'restore'].includes(segments[3]) &&
      request.method === 'POST'
    ) {
      await setTenantArchived(response, user, tenantId, segments[3] === 'archive', pool);
      return;
    }
    if (
      segments.length === 4 &&
      segments[3] === 'members' &&
      request.method === 'GET'
    ) {
      await listTenantMembers(response, user, tenantId, pool);
      return;
    }
    if (
      segments.length === 4 &&
      segments[3] === 'members' &&
      request.method === 'POST'
    ) {
      await addTenantMember(request, response, user, tenantId, pool);
      return;
    }
    if (
      segments.length === 5 &&
      segments[3] === 'members' &&
      request.method === 'PATCH'
    ) {
      await updateTenantMemberRole(
        request,
        response,
        user,
        tenantId,
        requireUuid(segments[4], 'user'),
        pool,
      );
      return;
    }
    if (
      segments.length === 5 &&
      segments[3] === 'members' &&
      request.method === 'DELETE'
    ) {
      await removeTenantMember(
        response,
        user,
        tenantId,
        requireUuid(segments[4], 'user'),
        pool,
      );
      return;
    }
  }

  throw new ApiError(404, 'not_found', 'The requested tenant route was not found.');
}

async function loadTenantAccess(response, userId, pool) {
  const isSuperAdmin = await hasSuperAdminRole(userId, pool);
  const tenantsResult = await pool.query(
    `select t.id, t.name, t.slug, t.archived_at, m.role
       from core.tenants as t
       left join core.tenant_memberships as m
         on m.tenant_id = t.id and m.user_id = $1
      where $2::boolean
         or exists (
           select 1
             from core.tenant_memberships as membership
            where membership.tenant_id = t.id
              and membership.user_id = $1
              and t.archived_at is null
         )
      order by t.name, t.id`,
    [userId, isSuperAdmin],
  );
  const membershipsResult = isSuperAdmin
    ? { rows: [] }
    : await pool.query(
        `select membership.tenant_id, membership.role
           from core.tenant_memberships as membership
           join core.tenants as t on t.id = membership.tenant_id
          where membership.user_id = $1
            and t.archived_at is null
          order by membership.tenant_id`,
        [userId],
      );

  sendJson(response, 200, {
    isSuperAdmin,
    memberships: membershipsResult.rows,
    tenants: tenantsResult.rows,
  });
}

async function createTenant(request, response, user, pool) {
  await requireSuperAdmin(user.id, pool);
  const body = await readJsonBody(request);
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  const ownerEmail =
    typeof body.ownerEmail === 'string' ? body.ownerEmail.trim().toLowerCase() : '';
  const requestId = requireUuid(body.requestId, 'request');
  if (name.length < 1 || name.length > 120 || !isValidEmail(ownerEmail)) {
    throw new ApiError(400, 'invalid_request', 'Check the tenant name and owner email.');
  }

  const result = await withTransaction(pool, async (client) => {
    await client.query(
      'select pg_advisory_xact_lock(hashtextextended($1, 0))',
      [requestId],
    );
    const existingResult = await client.query(
      `select request.requested_by, request.tenant_id, request.owner_user_id,
              request.tenant_name, request.owner_created,
              owner.requires_password_change
         from core.tenant_creation_requests as request
         join core.users as owner on owner.id = request.owner_user_id
        where request.request_id = $1
        for update of request, owner`,
      [requestId],
    );
    const existing = existingResult.rows[0];
    if (existing != null) {
      if (
        existing.requested_by !== user.id ||
        existing.tenant_name !== name ||
        existing.owner_user_id == null
      ) {
        throw new ApiError(
          409,
          'request_id_reused',
          'This tenant request ID was already used for different data.',
        );
      }

      const ownerResult = await client.query(
        'select id, email, requires_password_change from core.users where id = $1',
        [existing.owner_user_id],
      );
      const owner = ownerResult.rows[0];
      if (
        owner == null ||
        owner.email.toLowerCase() !== ownerEmail
      ) {
        throw new ApiError(
          409,
          'request_id_reused',
          'This tenant request ID was already used for different data.',
        );
      }

      let temporaryPassword;
      if (existing.owner_created && owner.requires_password_change) {
        temporaryPassword = generateTemporaryPassword();
        const passwordHash = await hashPassword(temporaryPassword);
        await client.query(
          'update core.users set password_hash = $2 where id = $1',
          [owner.id, passwordHash],
        );
      }

      const tenantResult = await client.query(
        `select id, name, slug, archived_at
           from core.tenants where id = $1`,
        [existing.tenant_id],
      );
      if (tenantResult.rows[0] == null) {
        throw new ApiError(404, 'tenant_not_found', 'The tenant for this request was not found.');
      }

      return {
        tenant: tenantResult.rows[0],
        temporaryPassword,
      };
    }

    let ownerResult = await client.query(
      `select id, email
         from core.users
        where lower(email) = $1
        limit 1`,
      [ownerEmail],
    );
    let owner = ownerResult.rows[0];
    let temporaryPassword;
    let ownerCreated = false;
    if (owner == null) {
      temporaryPassword = generateTemporaryPassword();
      const passwordHash = await hashPassword(temporaryPassword);
      ownerResult = await client.query(
        `insert into core.users (
           email, password_hash, requires_password_change
         )
         values ($1, $2, true)
         returning id, email`,
        [ownerEmail, passwordHash],
      );
      owner = ownerResult.rows[0];
      ownerCreated = true;
    }

    const slugBase =
      name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '')
        .slice(0, 60) || 'workspace';
    const slug = `${slugBase}-${randomBytes(4).toString('hex')}`;
    const tenantResult = await client.query(
      `insert into core.tenants (name, slug, created_by)
       values ($1, $2, $3)
       returning id, name, slug, archived_at`,
      [name, slug, user.id],
    );
    const tenant = tenantResult.rows[0];
    await client.query(
      `insert into core.tenant_memberships (tenant_id, user_id, role)
       values ($1, $2, 'owner')`,
      [tenant.id, owner.id],
    );
    await client.query(
      `insert into core.tenant_creation_requests (
         request_id, requested_by, tenant_id, owner_user_id, tenant_name,
         owner_created
       )
       values ($1, $2, $3, $4, $5, $6)`,
      [requestId, user.id, tenant.id, owner.id, name, ownerCreated],
    );

    return { tenant, temporaryPassword };
  });

  sendJson(response, 200, {
    success: true,
    tenant: result.tenant,
    ...(result.temporaryPassword == null
      ? {}
      : { temporaryPassword: result.temporaryPassword }),
  });
}

async function updateTenant(request, response, user, tenantId, pool) {
  await requireSuperAdmin(user.id, pool);
  const body = await readJsonBody(request);
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  if (name.length < 1 || name.length > 120) {
    throw new ApiError(400, 'invalid_request', 'Enter a tenant name from 1 to 120 characters.');
  }

  const result = await pool.query(
    `update core.tenants
        set name = $2
      where id = $1
      returning id, name, slug, archived_at`,
    [tenantId, name],
  );
  if (result.rows[0] == null) {
    throw new ApiError(404, 'tenant_not_found', 'The tenant was not found.');
  }
  sendJson(response, 200, result.rows[0]);
}

async function setTenantArchived(response, user, tenantId, archived, pool) {
  await requireSuperAdmin(user.id, pool);
  const result = await pool.query(
    `update core.tenants
        set archived_at = case
          when $2::boolean then coalesce(archived_at, now())
          else null
        end
      where id = $1
      returning id`,
    [tenantId, archived],
  );
  if (result.rows[0] == null) {
    throw new ApiError(404, 'tenant_not_found', 'The tenant was not found.');
  }
  response.writeHead(204);
  response.end();
}

async function listTenantMembers(response, user, tenantId, pool) {
  await requireSuperAdmin(user.id, pool);
  await requireTenantExists(tenantId, pool);
  const result = await pool.query(
    `select membership.user_id, user_account.email, membership.role
       from core.tenant_memberships as membership
       join core.users as user_account on user_account.id = membership.user_id
      where membership.tenant_id = $1
      order by membership.role, lower(user_account.email), membership.user_id`,
    [tenantId],
  );
  sendJson(response, 200, { items: result.rows });
}

async function addTenantMember(request, response, user, tenantId, pool) {
  await requireSuperAdmin(user.id, pool);
  const body = await readJsonBody(request);
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  const role = body.role;
  if (!isValidEmail(email) || !['owner', 'member'].includes(role)) {
    throw new ApiError(400, 'invalid_request', 'Enter a valid email and tenant role.');
  }

  const result = await withTransaction(pool, async (client) => {
    await lockTenant(client, tenantId);
    const tenant = await client.query(
      'select archived_at from core.tenants where id = $1',
      [tenantId],
    );
    if (tenant.rows[0] == null) {
      throw new ApiError(404, 'tenant_not_found', 'The tenant was not found.');
    }
    if (tenant.rows[0].archived_at != null) {
      throw new ApiError(409, 'tenant_archived', 'Restore the tenant before adding members.');
    }

    const account = await client.query(
      'select id, email from core.users where lower(email) = $1 limit 1',
      [email],
    );
    const member = account.rows[0];
    if (member == null) {
      throw new ApiError(404, 'account_not_found', 'The local account was not found.');
    }
    await client.query(
      `insert into core.tenant_memberships (tenant_id, user_id, role)
       values ($1, $2, $3)
       on conflict (tenant_id, user_id)
       do update set role = excluded.role`,
      [tenantId, member.id, role],
    );
    return { user_id: member.id, email: member.email, role };
  });
  sendJson(response, 200, result);
}

async function updateTenantMemberRole(
  request,
  response,
  user,
  tenantId,
  userId,
  pool,
) {
  await requireSuperAdmin(user.id, pool);
  const body = await readJsonBody(request);
  if (!['owner', 'member'].includes(body.role)) {
    throw new ApiError(400, 'invalid_request', 'Choose owner or member.');
  }

  await withTransaction(pool, async (client) => {
    await lockTenant(client, tenantId);
    const current = await client.query(
      `select role from core.tenant_memberships
        where tenant_id = $1 and user_id = $2
        for update`,
      [tenantId, userId],
    );
    const membership = current.rows[0];
    if (membership == null) {
      throw new ApiError(404, 'member_not_found', 'The tenant member was not found.');
    }
    await preserveTenantOwner(client, tenantId, membership.role, body.role);
    await client.query(
      `update core.tenant_memberships set role = $3
        where tenant_id = $1 and user_id = $2`,
      [tenantId, userId, body.role],
    );
  });
  response.writeHead(204);
  response.end();
}

async function removeTenantMember(response, user, tenantId, userId, pool) {
  await requireSuperAdmin(user.id, pool);
  await withTransaction(pool, async (client) => {
    await lockTenant(client, tenantId);
    const current = await client.query(
      `select role from core.tenant_memberships
        where tenant_id = $1 and user_id = $2
        for update`,
      [tenantId, userId],
    );
    const membership = current.rows[0];
    if (membership == null) {
      throw new ApiError(404, 'member_not_found', 'The tenant member was not found.');
    }
    await preserveTenantOwner(client, tenantId, membership.role, null);
    await client.query(
      'delete from core.tenant_memberships where tenant_id = $1 and user_id = $2',
      [tenantId, userId],
    );
  });
  response.writeHead(204);
  response.end();
}

async function preserveTenantOwner(client, tenantId, oldRole, newRole) {
  if (oldRole !== 'owner' || newRole === 'owner') {
    return;
  }
  const result = await client.query(
    `select count(*)::integer as owner_count
       from core.tenant_memberships
      where tenant_id = $1 and role = 'owner'`,
    [tenantId],
  );
  if (result.rows[0].owner_count <= 1) {
    throw new ApiError(409, 'owner_required', 'A tenant must keep at least one owner.');
  }
}

async function lockTenant(client, tenantId) {
  const result = await client.query(
    'select id from core.tenants where id = $1 for update',
    [tenantId],
  );
  if (result.rows[0] == null) {
    throw new ApiError(404, 'tenant_not_found', 'The tenant was not found.');
  }
}

async function requireTenantExists(tenantId, pool) {
  const result = await pool.query(
    'select id from core.tenants where id = $1',
    [tenantId],
  );
  if (result.rows[0] == null) {
    throw new ApiError(404, 'tenant_not_found', 'The tenant was not found.');
  }
}

async function handleParkingRequest(request, response, url, user, pool) {
  if (url.pathname === '/api/parking-sessions/summary' && request.method === 'GET') {
    await getParkingSummary(response, url, user, pool);
    return;
  }
  if (url.pathname === '/api/parking-sessions' && request.method === 'GET') {
    await listParkingSessions(response, url, user, pool);
    return;
  }
  if (url.pathname === '/api/parking-sessions' && request.method === 'POST') {
    await insertParkingSession(request, response, user, pool);
    return;
  }

  const segments = pathSegments(url.pathname);
  if (
    segments.length === 3 &&
    segments[1] === 'parking-sessions' &&
    request.method === 'GET'
  ) {
    const session = await findAuthorizedSession(
      user.id,
      requireUuid(segments[2], 'session'),
      pool,
    );
    sendJson(response, 200, session);
    return;
  }
  if (
    segments.length === 3 &&
    segments[1] === 'parking-sessions' &&
    request.method === 'PATCH'
  ) {
    await updateParkingSession(
      request,
      response,
      user,
      requireUuid(segments[2], 'session'),
      pool,
    );
    return;
  }
  if (
    segments.length === 3 &&
    segments[1] === 'parking-sessions' &&
    request.method === 'DELETE'
  ) {
    await deleteParkingSession(
      response,
      user,
      requireUuid(segments[2], 'session'),
      pool,
    );
    return;
  }

  throw new ApiError(404, 'not_found', 'The requested parking route was not found.');
}

async function listParkingSessions(response, url, user, pool) {
  const tenantId = parseOptionalUuid(url.searchParams.get('tenant_id'), 'tenant');
  await requireTenantAccess(user.id, tenantId, pool);
  const offset = parseInteger(url.searchParams.get('offset') ?? '0', 0, 1000000);
  const limit = parseInteger(url.searchParams.get('limit') ?? '50', 1, 101);
  const search = url.searchParams.get('search')?.trim() ?? '';
  if (search.length > 128) {
    throw new ApiError(400, 'invalid_request', 'The registration search is too long.');
  }

  const result = await pool.query(
    `select id, tenant_id, plate_number, photo_path, entry_time,
            allowed_duration_value, allowed_duration_unit, expires_at,
            created_by, created_at, updated_at, total_charge, paid_amount
       from core.parking_sessions
      where ($1::uuid is null or tenant_id = $1)
        and ($2::text = '' or position(lower($2) in lower(plate_number)) > 0)
      order by entry_time desc, id desc
      limit $3 offset $4`,
    [tenantId, search, limit, offset],
  );
  sendJson(response, 200, { sessions: result.rows });
}

async function getParkingSummary(response, url, user, pool) {
  const tenantId = parseOptionalUuid(url.searchParams.get('tenant_id'), 'tenant');
  await requireTenantAccess(user.id, tenantId, pool);
  const result = await pool.query(
    `select
       count(*) filter (where expires_at > $2)::integer as active_count,
       count(*) filter (where expires_at <= $2)::integer as expired_count
     from core.parking_sessions
     where $1::uuid is null or tenant_id = $1`,
    [tenantId, new Date().toISOString()],
  );
  sendJson(response, 200, {
    activeCount: result.rows[0].active_count,
    expiredCount: result.rows[0].expired_count,
  });
}

async function insertParkingSession(request, response, user, pool) {
  const body = await readJsonBody(request);
  const tenantId = requireUuid(body.tenant_id, 'tenant');
  await requireTenantAccess(user.id, tenantId, pool);
  const values = validateParkingValues(body, null);
  const result = await pool.query(
    `insert into core.parking_sessions (
       tenant_id, plate_number, entry_time, allowed_duration_value,
       allowed_duration_unit, expires_at, created_by, total_charge, paid_amount
     )
     values ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     returning id`,
    [
      tenantId,
      values.plateNumber,
      values.entryTime,
      values.durationValue,
      values.durationUnit,
      values.expiresAt,
      user.id,
      values.totalCharge,
      values.paidAmount,
    ],
  );
  sendJson(response, 201, { id: result.rows[0].id });
}

async function updateParkingSession(request, response, user, sessionId, pool) {
  const body = await readJsonBody(request);
  const allowedFields = new Set([
    'plate_number',
    'entry_time',
    'allowed_duration_value',
    'allowed_duration_unit',
    'expires_at',
    'photo_path',
    'total_charge',
    'paid_amount',
  ]);
  if (
    Object.keys(body).length === 0 ||
    Object.keys(body).some((key) => !allowedFields.has(key))
  ) {
    throw new ApiError(400, 'invalid_request', 'The parking-session update is invalid.');
  }

  const current = await findAuthorizedSession(user.id, sessionId, pool);
  const next = validateParkingValues(body, current);
  if (
    Object.hasOwn(body, 'photo_path') &&
    body.photo_path != null &&
    !isSessionPhotoPath(body.photo_path, current)
  ) {
    throw new ApiError(400, 'invalid_photo_path', 'The vehicle photo path is invalid.');
  }

  const columnNames = {
    plate_number: 'plate_number',
    entry_time: 'entry_time',
    allowed_duration_value: 'allowed_duration_value',
    allowed_duration_unit: 'allowed_duration_unit',
    expires_at: 'expires_at',
    photo_path: 'photo_path',
    total_charge: 'total_charge',
    paid_amount: 'paid_amount',
  };
  const values = [];
  const assignments = [];
  for (const [key, value] of Object.entries(body)) {
    values.push(
      key === 'plate_number'
        ? next.plateNumber
        : key === 'entry_time'
        ? next.entryTime
        : key === 'allowed_duration_value'
        ? next.durationValue
        : key === 'allowed_duration_unit'
        ? next.durationUnit
        : key === 'expires_at'
        ? next.expiresAt
        : key === 'total_charge'
        ? next.totalCharge
        : key === 'paid_amount'
        ? next.paidAmount
        : value,
    );
    assignments.push(`${columnNames[key]} = $${values.length}`);
  }
  values.push(sessionId);
  const result = await pool.query(
    `update core.parking_sessions
        set ${assignments.join(', ')}
      where id = $${values.length}
      returning id`,
    values,
  );
  if (result.rows[0] == null) {
    throw new ApiError(404, 'session_not_found', 'The parking session was not found.');
  }
  response.writeHead(204);
  response.end();
}

async function deleteParkingSession(response, user, sessionId, pool) {
  await findAuthorizedSession(user.id, sessionId, pool);
  await pool.query('delete from core.parking_sessions where id = $1', [sessionId]);
  response.writeHead(204);
  response.end();
}

function validateParkingValues(body, current) {
  const plateValue = Object.hasOwn(body, 'plate_number')
    ? body.plate_number
    : current?.plate_number;
  const plateNumber =
    typeof plateValue === 'string' ? plateValue.trim().toUpperCase() : '';
  if (plateNumber.length < 1 || plateNumber.length > 64) {
    throw new ApiError(400, 'invalid_request', 'Enter a registration from 1 to 64 characters.');
  }

  const entryValue = Object.hasOwn(body, 'entry_time')
    ? body.entry_time
    : current?.entry_time;
  const expiresValue = Object.hasOwn(body, 'expires_at')
    ? body.expires_at
    : current?.expires_at;
  const entryTime = parseDateTime(entryValue, 'entry time');
  const expiresAt = parseDateTime(expiresValue, 'expiry time');
  if (expiresAt <= entryTime) {
    throw new ApiError(400, 'invalid_request', 'The expiry time must follow the entry time.');
  }

  const durationValue =
    Object.hasOwn(body, 'allowed_duration_value')
      ? body.allowed_duration_value
      : current?.allowed_duration_value;
  if (!Number.isInteger(durationValue) || durationValue < 1) {
    throw new ApiError(400, 'invalid_request', 'Enter a positive parking duration.');
  }
  const durationUnit =
    Object.hasOwn(body, 'allowed_duration_unit')
      ? body.allowed_duration_unit
      : current?.allowed_duration_unit;
  if (!durationUnits.has(durationUnit)) {
    throw new ApiError(400, 'invalid_request', 'Choose a supported duration unit.');
  }

  const totalChargeValue = Object.hasOwn(body, 'total_charge')
    ? body.total_charge
    : (current?.total_charge ?? 0);
  const totalCharge = Number(totalChargeValue);
  if (!Number.isFinite(totalCharge) || totalCharge < 0) {
    throw new ApiError(400, 'invalid_request', 'The parking charge cannot be negative.');
  }

  const paidAmountValue = Object.hasOwn(body, 'paid_amount')
    ? body.paid_amount
    : (current?.paid_amount ?? 0);
  const paidAmount = Number(paidAmountValue);
  if (!Number.isFinite(paidAmount) || paidAmount < 0) {
    throw new ApiError(400, 'invalid_request', 'The amount paid cannot be negative.');
  }
  if (paidAmount > totalCharge) {
    throw new ApiError(
      400,
      'invalid_request',
      'The amount paid cannot exceed the total parking charge.',
    );
  }

  return {
    plateNumber,
    entryTime,
    expiresAt,
    durationValue,
    durationUnit,
    totalCharge,
    paidAmount,
  };
}

async function findAuthorizedSession(userId, sessionId, pool) {
  const result = await pool.query(
    `select id, tenant_id, plate_number, photo_path, entry_time,
            allowed_duration_value, allowed_duration_unit, expires_at,
            created_by, created_at, updated_at, total_charge, paid_amount
       from core.parking_sessions
      where id = $1`,
    [sessionId],
  );
  const session = result.rows[0];
  if (session == null) {
    throw new ApiError(404, 'session_not_found', 'The parking session was not found.');
  }
  await requireTenantAccess(userId, session.tenant_id, pool);
  return session;
}

async function requireTenantAccess(userId, tenantId, pool) {
  const isSuperAdmin = await hasSuperAdminRole(userId, pool);
  if (tenantId == null) {
    if (isSuperAdmin) {
      return;
    }
    throw new ApiError(400, 'tenant_required', 'Choose a tenant before accessing parking data.');
  }
  if (isSuperAdmin) {
    return;
  }
  const membership = await pool.query(
    `select 1
       from core.tenant_memberships as membership
       join core.tenants as tenant on tenant.id = membership.tenant_id
      where membership.user_id = $1
        and membership.tenant_id = $2
        and tenant.archived_at is null`,
    [userId, tenantId],
  );
  if (membership.rows[0] == null) {
    throw new ApiError(403, 'tenant_access_denied', 'You do not have access to this tenant.');
  }
}

async function hasSuperAdminRole(userId, pool) {
  const result = await pool.query(
    'select 1 from core.super_admins where user_id = $1',
    [userId],
  );
  return result.rows.length > 0;
}

async function requireSuperAdmin(userId, pool) {
  if (!(await hasSuperAdminRole(userId, pool))) {
    throw new ApiError(403, 'super_admin_required', 'Only a Super Admin can manage tenants.');
  }
}

async function handlePhotoRequest(
  request,
  response,
  url,
  user,
  dependencies,
) {
  const { pool, signingSecret, storageRoot, apiUrl } = dependencies;
  if (request.method === 'POST' && url.pathname === '/api/photos/signed-url') {
    const body = await readJsonBody(request);
    const photoPath = requirePhotoPath(body.path);
    const expiresInSeconds = parseInteger(body.expiresInSeconds, 1, 3600);
    const session = await requirePhotoSession(user.id, photoPath, pool);
    if (session.photo_path !== photoPath) {
      throw new ApiError(404, 'photo_not_found', 'The private vehicle photo was not found.');
    }

    const expiresAt = Math.floor(Date.now() / 1000) + expiresInSeconds;
    const signature = signPhotoUrl(signingSecret, photoPath, expiresAt);
    const signedUrl = new URL('/api/photos/content', apiUrl);
    signedUrl.searchParams.set('path', photoPath);
    signedUrl.searchParams.set('expires', String(expiresAt));
    signedUrl.searchParams.set('signature', signature);
    sendJson(response, 200, { url: signedUrl.toString() });
    return;
  }

  if (request.method === 'PUT' && url.pathname === '/api/photos/upload') {
    const photoPath = requirePhotoPath(url.searchParams.get('path'));
    const session = await requirePhotoSession(user.id, photoPath, pool);
    if (!isSessionPhotoPath(photoPath, session)) {
      throw new ApiError(403, 'invalid_photo_path', 'The vehicle photo path is not allowed.');
    }

    const contentType = (request.headers['content-type'] ?? '')
      .split(';', 1)[0]
      .trim()
      .toLowerCase();
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(contentType)) {
      throw new ApiError(415, 'unsupported_photo_type', 'Use a JPEG, PNG, or WebP photo.');
    }
    const extensionType = photoContentType(photoPath);
    if (extensionType !== contentType) {
      throw new ApiError(415, 'unsupported_photo_type', 'The photo extension and type do not match.');
    }

    const bytes = await readRawBody(request, photoBodyLimit);
    if (bytes.length === 0) {
      throw new ApiError(400, 'invalid_photo', 'The selected vehicle photo is empty.');
    }
    const target = resolvePhotoPath(storageRoot, photoPath);
    await mkdir(path.dirname(target), { recursive: true });
    if (request.headers['x-upsert'] === 'true') {
      await writeFile(target, bytes);
    } else {
      try {
        await writeFile(target, bytes, { flag: 'wx' });
      } catch (error) {
        if (error.code === 'EEXIST') {
          throw new ApiError(409, 'photo_exists', 'A photo already exists at this path.');
        }
        throw error;
      }
    }
    response.writeHead(204);
    response.end();
    return;
  }

  if (request.method === 'DELETE' && url.pathname === '/api/photos') {
    const photoPath = requirePhotoPath(url.searchParams.get('path'));
    await requirePhotoSession(user.id, photoPath, pool);
    const target = resolvePhotoPath(storageRoot, photoPath);
    try {
      await unlink(target);
    } catch (error) {
      if (error.code !== 'ENOENT') {
        throw error;
      }
    }
    response.writeHead(204);
    response.end();
    return;
  }

  throw new ApiError(404, 'not_found', 'The requested photo route was not found.');
}

async function requirePhotoSession(userId, photoPath, pool) {
  const parsedPath = parsePhotoPath(photoPath);
  if (parsedPath == null) {
    throw new ApiError(400, 'invalid_photo_path', 'The vehicle photo path is invalid.');
  }
  const session = await findAuthorizedSession(userId, parsedPath.sessionId, pool);
  if (session.created_by !== parsedPath.userId) {
    throw new ApiError(403, 'invalid_photo_path', 'The vehicle photo path is not allowed.');
  }
  return session;
}

async function serveSignedPhoto(url, response, dependencies) {
  const { signingSecret, storageRoot } = dependencies;
  const photoPath = url.searchParams.get('path') ?? '';
  const expiresText = url.searchParams.get('expires') ?? '';
  const signature = url.searchParams.get('signature') ?? '';
  const expiresAt = Number(expiresText);
  if (
    parsePhotoPath(photoPath) == null ||
    !Number.isSafeInteger(expiresAt) ||
    expiresAt <= Math.floor(Date.now() / 1000) ||
    expiresAt > Math.floor(Date.now() / 1000) + 3600 ||
    !verifyPhotoUrlSignature(
      signingSecret,
      photoPath,
      expiresAt,
      signature,
    )
  ) {
    throw new ApiError(403, 'invalid_photo_signature', 'The private photo link is invalid or expired.');
  }

  const target = resolvePhotoPath(storageRoot, photoPath);
  try {
    const bytes = await readFile(target);
    response.writeHead(200, {
      'Cache-Control': 'private, no-store',
      'Content-Length': bytes.length,
      'Content-Type': photoContentType(photoPath),
      'X-Content-Type-Options': 'nosniff',
    });
    response.end(bytes);
  } catch (error) {
    if (error.code === 'ENOENT') {
      throw new ApiError(404, 'photo_not_found', 'The private vehicle photo was not found.');
    }
    throw error;
  }
}

async function readJsonBody(request) {
  const contentType = request.headers['content-type'] ?? '';
  if (!contentType.toLowerCase().startsWith('application/json')) {
    throw new ApiError(415, 'invalid_content_type', 'Send a JSON request body.');
  }
  const bytes = await readRawBody(request, jsonBodyLimit);
  try {
    const parsed = JSON.parse(bytes.toString('utf8'));
    if (parsed == null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new Error('Body must be an object.');
    }
    return parsed;
  } catch {
    throw new ApiError(400, 'invalid_json', 'The request body is not valid JSON.');
  }
}

async function readRawBody(request, limit) {
  const chunks = [];
  let length = 0;
  for await (const chunk of request) {
    length += chunk.length;
    if (length > limit) {
      request.resume();
      throw new ApiError(413, 'body_too_large', 'The request body is too large.');
    }
    chunks.push(chunk);
  }
  return Buffer.concat(chunks, length);
}

async function withTransaction(pool, operation) {
  const client = await pool.connect();
  try {
    await client.query('begin');
    const result = await operation(client);
    await client.query('commit');
    return result;
  } catch (error) {
    await client.query('rollback').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

function sendJson(response, status, body) {
  const bytes = Buffer.from(JSON.stringify(body));
  response.writeHead(status, {
    'Content-Length': bytes.length,
    'Content-Type': 'application/json; charset=utf-8',
    'X-Content-Type-Options': 'nosniff',
  });
  response.end(bytes);
}

function pathSegments(pathname) {
  try {
    return pathname
      .split('/')
      .filter(Boolean)
      .map((segment) => decodeURIComponent(segment));
  } catch {
    throw new ApiError(400, 'invalid_path', 'The request path is invalid.');
  }
}

function requireUuid(value, label) {
  if (typeof value !== 'string' || !uuidPattern.test(value)) {
    throw new ApiError(400, 'invalid_request', `The ${label} ID is invalid.`);
  }
  return value;
}

function parseOptionalUuid(value, label) {
  if (value == null || value === '') {
    return null;
  }
  return requireUuid(value, label);
}

function parseInteger(value, minimum, maximum) {
  const parsed = typeof value === 'number' ? value : Number(value);
  if (
    !Number.isSafeInteger(parsed) ||
    parsed < minimum ||
    parsed > maximum
  ) {
    throw new ApiError(400, 'invalid_request', 'A numeric request value is invalid.');
  }
  return parsed;
}

function parseDateTime(value, label) {
  if (typeof value !== 'string' && !(value instanceof Date)) {
    throw new ApiError(400, 'invalid_request', `The ${label} is invalid.`);
  }
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) {
    throw new ApiError(400, 'invalid_request', `The ${label} is invalid.`);
  }
  return date.toISOString();
}

function requirePhotoPath(value) {
  if (parsePhotoPath(value) == null) {
    throw new ApiError(400, 'invalid_photo_path', 'The vehicle photo path is invalid.');
  }
  return value;
}

function isSessionPhotoPath(photoPath, session) {
  const parts = parsePhotoPath(photoPath);
  return (
    parts != null &&
    parts.userId === session.created_by &&
    parts.sessionId === session.id
  );
}

function isValidEmail(email) {
  return (
    email.length <= 254 &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  );
}

function parseUrl(value, fieldName) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`${fieldName} is required.`);
  }

  try {
    return new URL(value);
  } catch {
    throw new Error(`${fieldName} must be a valid URL.`);
  }
}

async function start() {
  const config = readLocalApiConfig();
  const pool = new Pool({
    connectionString: config.databaseUrl,
    max: 5,
    connectionTimeoutMillis: 5000,
    idleTimeoutMillis: 30000,
    application_name: 'parking-local-api',
  });
  await pool.query('select 1');
  await mkdir(config.storageRoot, { recursive: true });
  const server = createLocalApiServer({ pool, config });
  server.listen(config.port, config.host, () => {
    console.log(`Local parking API listening at ${config.apiUrl}`);
  });

  const shutdown = async () => {
    server.close();
    await pool.end();
  };
  process.once('SIGINT', shutdown);
  process.once('SIGTERM', shutdown);
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))
) {
  start().catch((error) => {
    console.error(`[local-api] Startup failed: ${error.message}`);
    process.exitCode = 1;
  });
}
