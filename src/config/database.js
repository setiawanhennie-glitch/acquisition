import 'dotenv/config';
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';

const dbConfig = {
  url: process.env.DATABASE_URL,
};

if (process.env.NODE_ENV === 'development') {
  dbConfig.url = process.env.DATABASE_URL_LOCAL
    || 'postgres://postgres:postgres@localhost:54322/postgres';
}

const sql = postgres(dbConfig.url);
const db = drizzle(sql);

export { db, sql };