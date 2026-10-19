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
  const memberEmail = `api-member-${randomUUID()}@parking.test`;
  const secondMemberEmail = `api-member-${randomUUID()}@parking.test`;
  const adminPassword = generateTemporaryPassword();
  const ownerNewPassword = generateTemporaryPassword();
  const memberPassword = generateTemporaryPassword();
  const secondMemberPassword = generateTemporaryPassword();
  const tenantIds = [];
  const requestIds = [];
  const memberIds = [];
  let adminId;
  let ownerId;
  let tenantId;
  let sessionId;
  let memberSessionId;
  let memberId;
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
    const memberHashes = await Promise.all([
      hashPassword(memberPassword),
      hashPassword(secondMemberPassword),
    ]);
    const membersResult = await pool.query(
      `insert into core.users (
         email, password_hash, requires_password_change
       )
       values ($1, $2, false), ($3, $4, false)
       returning id, email`,
      [memberEmail, memberHashes[0], secondMemberEmail, memberHashes[1]],
    );
    memberId = membersResult.rows.find((row) => row.email === memberEmail).id;
    const secondMemberId = membersResult.rows.find(
      (row) => row.email === secondMemberEmail,
    ).id;
    memberIds.push(memberId, secondMemberId);

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

    const initialCapacity = await request(
      baseUrl,
      'GET',
      `/api/tenants/${tenantId}/member-capacity`,
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(initialCapacity.status, 200);
    assert.equal(initialCapacity.body.member_limit, 1);
    assert.equal(initialCapacity.body.active_member_count, 0);
    assert.equal(initialCapacity.body.remaining_member_count, 1);

    const firstMemberAdded = await request(
      baseUrl,
      'POST',
      `/api/tenants/${tenantId}/members`,
      {
        token: ownerSignIn.body.accessToken,
        body: { email: memberEmail, role: 'member' },
      },
    );
    assert.equal(firstMemberAdded.status, 200);
    assert.equal(firstMemberAdded.body.role, 'member');
    const reachedCapacity = await request(
      baseUrl,
      'POST',
      `/api/tenants/${tenantId}/members`,
      {
        token: ownerSignIn.body.accessToken,
        body: { email: secondMemberEmail, role: 'member' },
      },
    );
    assert.equal(reachedCapacity.status, 409);
    assert.equal(reachedCapacity.body.error.code, 'member_limit_reached');
    assert.equal(reachedCapacity.body.error.details.memberLimit, 1);
    assert.equal(
      reachedCapacity.body.error.details.activeMemberCount,
      1,
    );

    const ownerCannotRaiseLimit = await request(
      baseUrl,
      'PATCH',
      `/api/tenants/${tenantId}/member-limit`,
      {
        token: ownerSignIn.body.accessToken,
        body: { memberLimit: 2 },
      },
    );
    assert.equal(ownerCannotRaiseLimit.status, 403);
    const ownerCannotAddAnotherOwner = await request(
      baseUrl,
      'POST',
      `/api/tenants/${tenantId}/members`,
      {
        token: ownerSignIn.body.accessToken,
        body: { email: secondMemberEmail, role: 'owner' },
      },
    );
    assert.equal(ownerCannotAddAnotherOwner.status, 403);

    const raisedCapacity = await request(
      baseUrl,
      'PATCH',
      `/api/tenants/${tenantId}/member-limit`,
      {
        token: adminToken,
        body: { memberLimit: 2 },
      },
    );
    assert.equal(raisedCapacity.status, 200);
    assert.equal(raisedCapacity.body.member_limit, 2);
    assert.equal(raisedCapacity.body.active_member_count, 1);
    const secondMemberAdded = await request(
      baseUrl,
      'POST',
      `/api/tenants/${tenantId}/members`,
      {
        token: ownerSignIn.body.accessToken,
        body: { email: secondMemberEmail, role: 'member' },
      },
    );
    assert.equal(secondMemberAdded.status, 200);

    const memberList = await request(
      baseUrl,
      'GET',
      `/api/tenants/${tenantId}/members`,
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(memberList.status, 200);
    const newMember = memberList.body.items.find(
      (member) => member.user_id === memberId,
    );
    assert.equal(newMember.can_view_entries, true);
    assert.equal(newMember.can_add_entries, false);
    assert.equal(newMember.can_edit_entries, false);
    assert.equal(newMember.can_delete_entries, false);

    const memberSignIn = await request(baseUrl, 'POST', '/api/auth/sign-in', {
      body: { email: memberEmail, password: memberPassword },
    });
    assert.equal(memberSignIn.status, 200);

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
    const memberCannotReadAnotherTenant = await request(
      baseUrl,
      'GET',
      `/api/parking-sessions?tenant_id=${existingOwnerTenant.body.tenant.id}`,
      { token: memberSignIn.body.accessToken },
    );
    assert.equal(memberCannotReadAnotherTenant.status, 403);

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

    const memberCanReadTenantEntries = await request(
      baseUrl,
      'GET',
      `/api/parking-sessions?tenant_id=${tenantId}&offset=0&limit=10`,
      { token: memberSignIn.body.accessToken },
    );
    assert.equal(memberCanReadTenantEntries.status, 200);
    assert.equal(memberCanReadTenantEntries.body.sessions.length, 1);
    const memberCannotAddWithoutPermission = await request(
      baseUrl,
      'POST',
      '/api/parking-sessions',
      {
        token: memberSignIn.body.accessToken,
        body: {
          tenant_id: tenantId,
          plate_number: 'MEMBER-DENIED-1',
          entry_time: entryTime,
          allowed_duration_value: 60,
          allowed_duration_unit: 'minutes',
          expires_at: expiresAt,
        },
      },
    );
    assert.equal(memberCannotAddWithoutPermission.status, 403);

    const permissionsUpdated = await request(
      baseUrl,
      'PATCH',
      `/api/tenants/${tenantId}/members/${memberId}/permissions`,
      {
        token: ownerSignIn.body.accessToken,
        body: {
          canViewEntries: false,
          canAddEntries: true,
          canEditEntries: false,
          canDeleteEntries: false,
        },
      },
    );
    assert.equal(permissionsUpdated.status, 204);
    const memberCannotBrowseWithoutView = await request(
      baseUrl,
      'GET',
      `/api/parking-sessions?tenant_id=${tenantId}`,
      { token: memberSignIn.body.accessToken },
    );
    assert.equal(memberCannotBrowseWithoutView.status, 403);
    const memberCannotEdit = await request(
      baseUrl,
      'PATCH',
      `/api/parking-sessions/${sessionId}`,
      {
        token: memberSignIn.body.accessToken,
        body: { plate_number: 'MEMBER-EDIT-DENIED' },
      },
    );
    assert.equal(memberCannotEdit.status, 403);
    const memberCannotDelete = await request(
      baseUrl,
      'DELETE',
      `/api/parking-sessions/${sessionId}`,
      { token: memberSignIn.body.accessToken },
    );
    assert.equal(memberCannotDelete.status, 403);
    const memberCanAddWithPermission = await request(
      baseUrl,
      'POST',
      '/api/parking-sessions',
      {
        token: memberSignIn.body.accessToken,
        body: {
          tenant_id: tenantId,
          plate_number: 'MEMBER-ADD-1',
          entry_time: entryTime,
          allowed_duration_value: 60,
          allowed_duration_unit: 'minutes',
          expires_at: expiresAt,
        },
      },
    );
    assert.equal(memberCanAddWithPermission.status, 201);
    memberSessionId = memberCanAddWithPermission.body.id;

    const editOnlyPermissions = await request(
      baseUrl,
      'PATCH',
      `/api/tenants/${tenantId}/members/${memberId}/permissions`,
      {
        token: ownerSignIn.body.accessToken,
        body: {
          canViewEntries: false,
          canAddEntries: false,
          canEditEntries: true,
          canDeleteEntries: false,
        },
      },
    );
    assert.equal(editOnlyPermissions.status, 204);
    const memberCannotViewWithEditOnly = await request(
      baseUrl,
      'GET',
      `/api/parking-sessions/${memberSessionId}`,
      { token: memberSignIn.body.accessToken },
    );
    assert.equal(memberCannotViewWithEditOnly.status, 403);
    const memberCannotAddWithEditOnly = await request(
      baseUrl,
      'POST',
      '/api/parking-sessions',
      {
        token: memberSignIn.body.accessToken,
        body: {
          tenant_id: tenantId,
          plate_number: 'MEMBER-ADD-DENIED-2',
          entry_time: entryTime,
          allowed_duration_value: 60,
          allowed_duration_unit: 'minutes',
          expires_at: expiresAt,
        },
      },
    );
    assert.equal(memberCannotAddWithEditOnly.status, 403);
    const memberCanEditWithEditOnly = await request(
      baseUrl,
      'PATCH',
      `/api/parking-sessions/${memberSessionId}`,
      {
        token: memberSignIn.body.accessToken,
        body: { plate_number: 'MEMBER-EDITED' },
      },
    );
    assert.equal(memberCanEditWithEditOnly.status, 204);
    const memberCannotDeleteWithEditOnly = await request(
      baseUrl,
      'DELETE',
      `/api/parking-sessions/${memberSessionId}`,
      { token: memberSignIn.body.accessToken },
    );
    assert.equal(memberCannotDeleteWithEditOnly.status, 403);

    const deleteOnlyPermissions = await request(
      baseUrl,
      'PATCH',
      `/api/tenants/${tenantId}/members/${memberId}/permissions`,
      {
        token: ownerSignIn.body.accessToken,
        body: {
          canViewEntries: false,
          canAddEntries: false,
          canEditEntries: false,
          canDeleteEntries: true,
        },
      },
    );
    assert.equal(deleteOnlyPermissions.status, 204);
    const memberCannotEditWithDeleteOnly = await request(
      baseUrl,
      'PATCH',
      `/api/parking-sessions/${memberSessionId}`,
      {
        token: memberSignIn.body.accessToken,
        body: { plate_number: 'MEMBER-EDIT-DENIED-2' },
      },
    );
    assert.equal(memberCannotEditWithDeleteOnly.status, 403);
    const memberCannotAddWithDeleteOnly = await request(
      baseUrl,
      'POST',
      '/api/parking-sessions',
      {
        token: memberSignIn.body.accessToken,
        body: {
          tenant_id: tenantId,
          plate_number: 'MEMBER-ADD-DENIED-3',
          entry_time: entryTime,
          allowed_duration_value: 60,
          allowed_duration_unit: 'minutes',
          expires_at: expiresAt,
        },
      },
    );
    assert.equal(memberCannotAddWithDeleteOnly.status, 403);
    const memberCanDeleteWithDeleteOnly = await request(
      baseUrl,
      'DELETE',
      `/api/parking-sessions/${memberSessionId}`,
      { token: memberSignIn.body.accessToken },
    );
    assert.equal(memberCanDeleteWithDeleteOnly.status, 204);

    const memberAudit = await request(
      baseUrl,
      'GET',
      `/api/tenants/${tenantId}/member-audit`,
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(memberAudit.status, 200);
    assert.ok(
      memberAudit.body.items.some(
        (event) => event.action === 'member_permissions_changed',
      ),
    );

    const removedSecondMember = await request(
      baseUrl,
      'DELETE',
      `/api/tenants/${tenantId}/members/${secondMemberId}`,
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(removedSecondMember.status, 204);
    const freedCapacity = await request(
      baseUrl,
      'GET',
      `/api/tenants/${tenantId}/member-capacity`,
      { token: ownerSignIn.body.accessToken },
    );
    assert.equal(freedCapacity.status, 200);
    assert.equal(freedCapacity.body.active_member_count, 1);
    assert.equal(freedCapacity.body.remaining_member_count, 1);

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
    if (memberIds.length > 0) {
      await pool.query('delete from core.users where id = any($1::uuid[])', [
        memberIds,
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
