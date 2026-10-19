import { Pool } from 'pg';

import {
  generateTemporaryPassword,
  hashPassword,
} from '../src/security.js';

const email = (process.env.PARKING_LOCAL_ADMIN_EMAIL ?? 'local-admin@parking.test')
  .trim()
  .toLowerCase();
const pool = new Pool({
  connectionString: process.env.PARKING_LOCAL_DATABASE_URL,
  max: 1,
  connectionTimeoutMillis: 5000,
  application_name: 'parking-local-admin-seed',
});

try {
  const existing = await pool.query(
    'select id from core.users where lower(email) = $1',
    [email],
  );
  if (existing.rows[0] != null) {
    console.log('The local Super Admin already exists; its password was not changed.');
  } else {
    const temporaryPassword = generateTemporaryPassword();
    const passwordHash = await hashPassword(temporaryPassword);
    const client = await pool.connect();
    try {
      await client.query('begin');
      const inserted = await client.query(
        `insert into core.users (
           email, password_hash, requires_password_change
         )
         values ($1, $2, true)
         on conflict do nothing
         returning id`,
        [email, passwordHash],
      );
      const userId = inserted.rows[0]?.id;
      if (userId == null) {
        await client.query('rollback');
        console.log('The local Super Admin already exists; its password was not changed.');
      } else {
        await client.query(
          'insert into core.super_admins (user_id) values ($1)',
          [userId],
        );
        await client.query('commit');
        console.log(`Local Super Admin email: ${email}`);
        console.log(`One-time local password: ${temporaryPassword}`);
        console.log('Change this password at the first sign-in.');
      }
    } catch (error) {
      await client.query('rollback').catch(() => {});
      throw error;
    } finally {
      client.release();
    }
  }
} finally {
  await pool.end();
}
