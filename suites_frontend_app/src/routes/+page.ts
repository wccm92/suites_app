// src/routes/+page.ts
import type { PageLoad } from './$types';

type Suite = {
  id_suite: string;
};

export const load: PageLoad = async ({ fetch }) => {
  const res = await fetch('/api/suites'); // si tienes un backend externo, cambias aquí
  if (!res.ok) {
    return {
      suites: [] as Suite[],
      error: 'No se pudieron cargar las suites'
    };
  }

  const suites: Suite[] = await res.json();
  return { suites, error: null };
};