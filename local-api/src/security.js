import {
  createHash,
  createHmac,
  randomBytes,
  timingSafeEqual,
  scrypt,
} from 'node:crypto';
import { promisify } from 'node:util';

const deriveKey = promisify(scrypt);
const scryptParameters = { N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };
const keyLength = 64;

export function generateTemporaryPassword() {
  return randomBytes(24).toString('base64url');
}

export async function hashPassword(password) {
  const salt = randomBytes(16);
  const key = await deriveKey(password, salt, keyLength, scryptParameters);
  return [
    'scrypt',
    scryptParameters.N,
    scryptParameters.r,
    scryptParameters.p,
    salt.toString('base64url'),
    key.toString('base64url'),
  ].join('$');
}

export async function verifyPassword(password, storedHash) {
  if (typeof password !== 'string' || typeof storedHash !== 'string') {
    return false;
  }

  const [algorithm, n, r, p, saltText, keyText, ...extra] =
    storedHash.split('$');
  if (
    algorithm !== 'scrypt' ||
    n !== String(scryptParameters.N) ||
    r !== String(scryptParameters.r) ||
    p !== String(scryptParameters.p) ||
    extra.length !== 0 ||
    !/^[A-Za-z0-9_-]+$/.test(saltText ?? '') ||
    !/^[A-Za-z0-9_-]+$/.test(keyText ?? '')
  ) {
    return false;
  }

  const salt = Buffer.from(saltText, 'base64url');
  const expected = Buffer.from(keyText, 'base64url');
  if (salt.length !== 16 || expected.length !== keyLength) {
    return false;
  }

  const actual = await deriveKey(password, salt, keyLength, scryptParameters);
  return timingSafeEqual(expected, actual);
}

export function hashAccessToken(token) {
  return createHash('sha256').update(token).digest('hex');
}

export function signPhotoUrl(secret, photoPath, expiresAt) {
  return createHmac('sha256', secret)
    .update(`${photoPath}\n${expiresAt}`)
    .digest('base64url');
}

export function verifyPhotoUrlSignature(
  secret,
  photoPath,
  expiresAt,
  signature,
) {
  if (!/^[A-Za-z0-9_-]{43}$/.test(signature ?? '')) {
    return false;
  }

  const expected = Buffer.from(
    signPhotoUrl(secret, photoPath, expiresAt),
    'base64url',
  );
  const actual = Buffer.from(signature, 'base64url');
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}
