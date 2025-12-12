// src/routes/+page.ts
import type { PageLoad } from './$types';

export type Suite = {
  id_suite: string;
  capacidad: number;
};

type SuitesResponse = {
  suites: Suite[];
};

export const load: PageLoad = async ({ fetch }) => {
  const res = await fetch('/suites_app/suites');

  if (!res.ok) {
    return {
      suites: [] as Suite[],
      error: 'No se pudieron cargar las suites'
    };
  }

  const payload: SuitesResponse = await res.json();

  return {
    suites: payload.suites,
    error: null
  };
};