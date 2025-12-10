// src/routes/api/suites/+server.ts
import type { RequestHandler } from '@sveltejs/kit';

export const GET: RequestHandler = async () => {
  const suites = [
    { id_suite: '1' },
    { id_suite: '2' },
    { id_suite: '3' }
  ];

  return new Response(JSON.stringify(suites), {
    status: 200,
    headers: {
      'Content-Type': 'application/json'
    }
  });
};