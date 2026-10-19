import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

import {
  generateTemporaryPassword,
  hashPassword,
  signPhotoUrl,
  verifyPassword,
  verifyPhotoUrlSignature,
} from '../src/security.js';
import { parsePhotoPath, resolvePhotoPath } from '../src/photo_paths.js';
import { readLocalApiConfig } from '../src/server.js';

test('local passwords are securely hashed and verified', async () => {
  const password = generateTemporaryPassword();
  const hash = await hashPassword(password);

  assert.notEqual(hash, password);
  assert.match(hash, /^scrypt\$16384\$8\$1\$/);
  assert.equal(await verifyPassword(password, hash), true);
  assert.equal(await verifyPassword('not-the-password', hash), false);
  assert.equal(await verifyPassword(password, 'invalid'), false);
});

test('signed photo URLs bind the path and expiry', () => {
  const secret = 'a-local-only-signing-secret-with-at-least-32-bytes';
  const photoPath =
    '08d4aef4-08df-4b55-b5d6-b57c9d1f0a34/7a084311-93c2-46b9-a4f5-49256ec7752b/photo.jpg';
  const expiresAt = 1792400000;
  const signature = signPhotoUrl(secret, photoPath, expiresAt);

  assert.equal(
    verifyPhotoUrlSignature(secret, photoPath, expiresAt, signature),
    true,
  );
  assert.equal(
    verifyPhotoUrlSignature(secret, `${photoPath}.other`, expiresAt, signature),
    false,
  );
  assert.equal(
    verifyPhotoUrlSignature(secret, photoPath, expiresAt + 1, signature),
    false,
  );
});

test('photo paths reject traversal and resolve only under storage root', async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'parking-photo-'));
  try {
    const valid =
      '08d4aef4-08df-4b55-b5d6-b57c9d1f0a34/7a084311-93c2-46b9-a4f5-49256ec7752b/vehicle_photo.png';
    assert.equal(parsePhotoPath(valid)?.fileName, 'vehicle_photo.png');
    assert.equal(parsePhotoPath('../private.png'), null);
    assert.equal(parsePhotoPath(`${valid}/extra`), null);
    assert.equal(resolvePhotoPath(root, valid)?.startsWith(root), true);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test('local API configuration refuses remote databases and API hosts', () => {
  const environment = {
    PARKING_LOCAL_DATABASE_URL:
      'postgresql://parking_api:local-secret@127.0.0.1:5432/parking_local',
    PARKING_LOCAL_API_URL: 'http://127.0.0.1:8765',
    PARKING_LOCAL_API_SIGNING_SECRET:
      'a-local-only-signing-secret-with-at-least-32-bytes',
    PARKING_LOCAL_STORAGE_DIR: path.resolve('storage'),
  };

  assert.equal(readLocalApiConfig(environment).host, '127.0.0.1');
  assert.throws(
    () =>
      readLocalApiConfig({
        ...environment,
        PARKING_LOCAL_DATABASE_URL:
          'postgresql://user:secret@db.example.com:5432/parking_local',
      }),
    /loopback host/,
  );
  assert.throws(
    () =>
      readLocalApiConfig({
        ...environment,
        PARKING_LOCAL_API_URL: 'http://api.example.com:8765',
      }),
    /HTTP loopback/,
  );
});
