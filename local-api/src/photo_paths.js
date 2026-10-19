import path from 'node:path';

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const fileNamePattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$/;

export function parsePhotoPath(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const parts = value.split('/');
  if (
    parts.length !== 3 ||
    !uuidPattern.test(parts[0]) ||
    !uuidPattern.test(parts[1]) ||
    !fileNamePattern.test(parts[2]) ||
    parts[2] === '.' ||
    parts[2] === '..'
  ) {
    return null;
  }

  return { userId: parts[0], sessionId: parts[1], fileName: parts[2] };
}

export function resolvePhotoPath(storageRoot, photoPath) {
  const parts = parsePhotoPath(photoPath);
  if (parts == null) {
    return null;
  }

  const root = path.resolve(storageRoot);
  const target = path.resolve(root, parts.userId, parts.sessionId, parts.fileName);
  if (!target.startsWith(`${root}${path.sep}`)) {
    return null;
  }

  return target;
}

export function photoContentType(photoPath) {
  const lowerPath = photoPath.toLowerCase();
  if (lowerPath.endsWith('.png')) {
    return 'image/png';
  }
  if (lowerPath.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
