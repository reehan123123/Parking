import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { unlink } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { Pool } from 'pg';

import { createLocalApiServer, readLocalApiConfig } from '../src/server.js';
import { generateTemporaryPassword, hashPassword } from '../src/security.js';
import { resolvePhotoPath } from '../src/photo_paths.js';

test('local API supports isolated auth, tenant, parking, and photo flows', async () => {
  const config = readLocalApiConfig();
  const pool = new Pool({
    connectionString: config.databaseUrl,
    max: 4,
    application_name: 'parking-local-api-integration-test',
  });
  const server = createLocalApiServer({ pool, config });
  const adminEmail = `api-admin-${randomUUID()}@parking.test`;
  const ownerEmail = `api-owner-${randomUUID()}@parking.test`;
  const adminPassword = generateTemporaryPassword();
  const ownerNewPassword = generateTemporaryPassword();
  const tenantIds = [];
  const requestIds = [];
  let adminId;
  let ownerId;
  let tenantId;
  let sessionId;
  let requestId;
  let photoPath;

  try {
    const adminHash = await hashPassword(adminPassword);
    const adminResult = await pool.query(
      `insert into core.users (
         email, password_hash, requires_password_change
       )
       values ($1, $2, false)
       returning id`,
      [adminEmail, adminHash],
    );
    adminId = adminResult.rows[0].id;
    await pool.query(
      'insert into core.super_admins (user_id) values ($1)',
      [adminId],
    );

    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const address = server.address();
    assert.ok(address && typeof address === 'object');
    config.port = address.port;
    config.apiUrl = `http://127.0.0.1:${address.port}`;
    const baseUrl = config.apiUrl;

    const adminSignIn = await request(baseUrl, 'POST', '/api/auth/sign-in', {
      body: { email: adminEmail, password: adminPassword },
    });
    assert.equal(adminSignIn.status, 200);
    const adminToken = adminSignIn.body.accessToken;
    assert.equal(adminSignIn.body.user.requiresTemporaryPasswordChange, false);

    const access = await request(baseUrl, 'GET', '/api/tenants/access', {
      token: adminToken,
    });
    assert.equal(access.status, 200);
    assert.equal(access.body.isSuperAdmin, true);

    requestId = randomUUID();
    const created = await request(baseUrl, 'POST', '/api/tenants', {
      token: adminToken,
      body: {
        name: 'Local API Test',
        ownerEmail,
        requestId,
      },
    });
    assert.equal(created.status, 200);
    assert.equal(created.body.success, true);
    assert.equal(typeof created.body.temporaryPassword, 'string');
    tenantId = created.body.tenant.id;
    tenantIds.push(tenantId);
    requestIds.push(requestId);

    const ownerSignIn = await request(baseUrl, 'POST', '/api/auth/sign-in', {
      body: {
        email: ownerEmail,
        password: created.body.temporaryPassword,
      },
    });
    assert.equal(ownerSignIn.status, 200);
    assert.equal(ownerSignIn.body.user.requiresTemporaryPasswordChange, true);
    ownerId = ownerSignIn.body.user.id;
    const blockedAccess = await request(
      baseUrl,
      'GET',
      '/api/tenants/access',
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(blockedAccess.status, 403);
    assert.equal(blockedAccess.body.error.code, 'password_change_required');

    const passwordChanged = await request(
      baseUrl,
      'POST',
      '/api/auth/change-password',
      {
        token: ownerSignIn.body.accessToken,
        body: { newPassword: ownerNewPassword },
      },
    );
    assert.equal(passwordChanged.status, 200);
    assert.equal(passwordChanged.body.success, true);

    const ownerAccess = await request(baseUrl, 'GET', '/api/tenants/access', {
      token: ownerSignIn.body.accessToken,
    });
    assert.equal(ownerAccess.status, 200);
    assert.equal(ownerAccess.body.isSuperAdmin, false);
    assert.ok(ownerAccess.body.tenants.some((tenant) => tenant.id === tenantId));

    const ownerCannotCreateTenant = await request(
      baseUrl,
      'POST',
      '/api/tenants',
      {
        token: ownerSignIn.body.accessToken,
        body: {
          name: 'Unauthorized Workspace',
          ownerEmail,
          requestId: randomUUID(),
        },
      },
    );
    assert.equal(ownerCannotCreateTenant.status, 403);

    const ownerCannotReadAnotherTenant = await request(
      baseUrl,
      'GET',
      `/api/parking-sessions?tenant_id=${randomUUID()}`,
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(ownerCannotReadAnotherTenant.status, 403);

    const ownerCannotBeRemovedAsLastOwner = await request(
      baseUrl,
      'DELETE',
      `/api/tenants/${tenantId}/members/${ownerId}`,
      { token: adminToken },
    );
    assert.equal(ownerCannotBeRemovedAsLastOwner.status, 409);
    assert.equal(
      ownerCannotBeRemovedAsLastOwner.body.error.code,
      'owner_required',
    );

    const secondRequestId = randomUUID();
    requestIds.push(secondRequestId);
    const existingOwnerTenant = await request(
      baseUrl,
      'POST',
      '/api/tenants',
      {
        token: adminToken,
        body: {
          name: 'Second Local Workspace',
          ownerEmail,
          requestId: secondRequestId,
        },
      },
    );
    assert.equal(existingOwnerTenant.status, 200);
    assert.equal(existingOwnerTenant.body.temporaryPassword, undefined);
    tenantIds.push(existingOwnerTenant.body.tenant.id);
    const existingOwnerSignIn = await request(
      baseUrl,
      'POST',
      '/api/auth/sign-in',
      { body: { email: ownerEmail, password: ownerNewPassword } },
    );
    assert.equal(existingOwnerSignIn.status, 200);
    assert.equal(
      existingOwnerSignIn.body.user.requiresTemporaryPasswordChange,
      false,
    );

    const entryTime = new Date(Date.now() - 60_000).toISOString();
    const expiresAt = new Date(Date.now() + 3_600_000).toISOString();
    const inserted = await request(baseUrl, 'POST', '/api/parking-sessions', {
      token: adminToken,
      body: {
        tenant_id: tenantId,
        plate_number: 'mh 03 ab 1234',
        entry_time: entryTime,
        allowed_duration_value: 60,
        allowed_duration_unit: 'minutes',
        expires_at: expiresAt,
        created_by: randomUUID(),
      },
    });
    assert.equal(inserted.status, 201);
    sessionId = inserted.body.id;

    const session = await request(
      baseUrl,
      'GET',
      `/api/parking-sessions/${sessionId}`,
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(session.status, 200);
    assert.equal(session.body.plate_number, 'MH 03 AB 1234');
    assert.equal(session.body.created_by, adminId);

    const ownerWithoutTenant = await request(
      baseUrl,
      'GET',
      '/api/parking-sessions',
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(ownerWithoutTenant.status, 400);
    const ownerList = await request(
      baseUrl,
      'GET',
      `/api/parking-sessions?tenant_id=${tenantId}&offset=0&limit=10`,
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(ownerList.status, 200);
    assert.equal(ownerList.body.sessions.length, 1);
    assert.equal(ownerList.body.sessions[0].id, sessionId);

    const summary = await request(
      baseUrl,
      'GET',
      `/api/parking-sessions/summary?tenant_id=${tenantId}`,
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(summary.status, 200);
    assert.equal(summary.body.activeCount, 1);
    assert.equal(summary.body.expiredCount, 0);

    photoPath = `${adminId}/${sessionId}/local-test.png`;
    const photoBytes = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);
    const uploaded = await request(
      baseUrl,
      'PUT',
      `/api/photos/upload?path=${encodeURIComponent(photoPath)}`,
      {
        token: adminToken,
        bytes: photoBytes,
        contentType: 'image/png',
      },
    );
    assert.equal(uploaded.status, 204);
    const linked = await request(
      baseUrl,
      'PATCH',
      `/api/parking-sessions/${sessionId}`,
      { token: adminToken, body: { photo_path: photoPath } },
    );
    assert.equal(linked.status, 204);

    const signed = await request(baseUrl, 'POST', '/api/photos/signed-url', {
      token: ownerSignIn.body.accessToken,
      body: { path: photoPath, expiresInSeconds: 300 },
    });
    assert.equal(signed.status, 200);
    const photoResponse = await fetch(signed.body.url);
    assert.equal(photoResponse.status, 200);
    assert.deepEqual(Buffer.from(await photoResponse.arrayBuffer()), photoBytes);

    const renamed = await request(baseUrl, 'PATCH', `/api/tenants/${tenantId}`, {
      token: adminToken,
      body: { name: 'Local API Test Renamed' },
    });
    assert.equal(renamed.status, 200);
    assert.equal(renamed.body.name, 'Local API Test Renamed');
    const archived = await request(
      baseUrl,
      'POST',
      `/api/tenants/${tenantId}/archive`,
      { token: adminToken, body: {} },
    );
    assert.equal(archived.status, 204);
    const blockedArchivedTenant = await request(
      baseUrl,
      'GET',
      `/api/parking-sessions?tenant_id=${tenantId}`,
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(blockedArchivedTenant.status, 403);
    const restored = await request(
      baseUrl,
      'POST',
      `/api/tenants/${tenantId}/restore`,
      { token: adminToken, body: {} },
    );
    assert.equal(restored.status, 204);

    const removedPhoto = await request(
      baseUrl,
      'DELETE',
      `/api/photos?path=${encodeURIComponent(photoPath)}`,
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(removedPhoto.status, 204);
    const removedSession = await request(
      baseUrl,
      'DELETE',
      `/api/parking-sessions/${sessionId}`,
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(removedSession.status, 204);
    const finalSummary = await request(
      baseUrl,
      'GET',
      `/api/parking-sessions/summary?tenant_id=${tenantId}`,
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(finalSummary.body.activeCount, 0);
    assert.equal(finalSummary.body.expiredCount, 0);

    const reusedRequest = await request(baseUrl, 'POST', '/api/tenants', {
      token: adminToken,
      body: {
        name: 'Local API Test',
        ownerEmail,
        requestId,
      },
    });
    assert.equal(reusedRequest.status, 200);
    assert.equal(reusedRequest.body.tenant.id, tenantId);
    assert.equal(reusedRequest.body.temporaryPassword, undefined);
  } finally {
    if (photoPath != null) {
      const photoFile = resolvePhotoPath(config.storageRoot, photoPath);
      if (photoFile != null) {
        await unlink(photoFile).catch((error) => {
          if (error.code !== 'ENOENT') {
            throw error;
          }
        });
      }
    }
    if (sessionId != null) {
      await pool.query('delete from core.parking_sessions where id = $1', [sessionId]);
    }
    if (tenantIds.length > 0) {
      await pool.query(
        'delete from core.parking_sessions where tenant_id = any($1::uuid[])',
        [tenantIds],
      );
      await pool.query('delete from core.tenants where id = any($1::uuid[])', [
        tenantIds,
      ]);
    }
    if (requestIds.length > 0) {
      await pool.query(
        'delete from core.tenant_creation_requests where request_id = any($1::uuid[])',
        [requestIds],
      );
    }
    if (adminId != null) {
      await pool.query('delete from core.super_admins where user_id = $1', [
        adminId,
      ]);
    }
    if (ownerId != null) {
      await pool.query('delete from core.users where id = $1', [ownerId]);
    }
    await pool.query('delete from core.users where lower(email) = $1', [
      ownerEmail,
    ]);
    if (adminId != null) {
      await pool.query('delete from core.users where id = $1', [adminId]);
    }
    if (server.listening) {
      await new Promise((resolve, reject) => {
        server.close((error) => (error == null ? resolve() : reject(error)));
      });
    }
    await pool.end();
  }
});

async function request(baseUrl, method, path, options = {}) {
  const headers = {};
  if (options.token != null) {
    headers.Authorization = `Bearer ${options.token}`;
  }
  let body;
  if (options.body != null) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(options.body);
  } else if (options.bytes != null) {
    headers['Content-Type'] = options.contentType;
    body = options.bytes;
  }

  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers,
    body,
  });
  const text = await response.text();
  let responseBody;
  if (text.length > 0 && response.headers.get('content-type')?.includes('json')) {
    responseBody = JSON.parse(text);
  }
  return { status: response.status, body: responseBody };
}
