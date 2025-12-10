import type { RequestHandler } from '@sveltejs/kit';

type SuiteDetail = {
  id_suite: string;
  capacidad: string;
  cupos_disponibles: string;
  invitados_inscritos: string[];
};

const suitesDetails: Record<string, SuiteDetail> = {
  '1243': {
    id_suite: '1243',
    capacidad: '15',
    cupos_disponibles: '2',
    invitados_inscritos: ['124', '456', '789']
  },
  '124': {
    id_suite: '124',
    capacidad: '10',
    cupos_disponibles: '5',
    invitados_inscritos: ['111', '222']
  },
  '345': {
    id_suite: '345',
    capacidad: '20',
    cupos_disponibles: '0',
    invitados_inscritos: ['999', '888', '777', '666']
  }
};

export const GET: RequestHandler = async ({ params }) => {
  const id = params.id;

  // 🔹 Aquí calmamos a TypeScript
  if (!id) {
    return new Response(
      JSON.stringify({ error: 'ID de suite no especificado' }),
      {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }

  const suite = suitesDetails[id];

  if (!suite) {
    return new Response(
      JSON.stringify({ error: 'Suite no encontrada' }),
      {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }

  return new Response(JSON.stringify(suite), {
    status: 200,
    headers: {
      'Content-Type': 'application/json'
    }
  });
};