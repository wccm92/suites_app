// src/routes/api/suites/+server.ts
import type { RequestHandler } from '@sveltejs/kit';

export const GET: RequestHandler = async () => {
  const suites = {
    suites: [
      {
        id_suite: '1243',
        capacidad: 12
      },
      {
        id_suite: '124',
        capacidad: 15
      },
      {
        id_suite: '345',
        capacidad: 10
      }
    ]
  };

  return new Response(JSON.stringify(suites), {
    status: 200,
    headers: {
      'Content-Type': 'application/json'
    }
  });
};