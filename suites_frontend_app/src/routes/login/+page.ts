// src/routes/login/+page.ts
import type { PageLoad } from './$types';

export const load: PageLoad = async () => {
  // De momento no hacemos nada del lado del servidor.
  // Toda la lógica de sesión y validación se hace en +page.svelte (onMount, lado navegador).
  return {};
};