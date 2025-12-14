// src/routes/+page.ts
import type { PageLoad } from './$types';

export const load: PageLoad = async () => {
  // Toda la lógica de autenticación y carga de suites
  // se hace ahora del lado del cliente en +page.svelte (onMount).
  return {};
};
