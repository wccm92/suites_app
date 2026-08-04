// src/lib/api/client.ts
import { get } from 'svelte/store';
import { session } from '$lib/stores/session';
import { USE_MOCKS, mockFetch } from '$lib/api/mocks';

// Ajusta esto cuando tengas URL real del backend
const BACKEND_BASE_URL = ''; // ejemplo

type ApiOptions = RequestInit & {
  auth?: boolean; // si quieres marcar si requiere o no JWT (por defecto true)
};

export async function apiFetch(path: string, options: ApiOptions = {}) {
  const { auth = true, ...rest } = options;

  // Mocks (mientras no exista el backend). Si el path no está mockeado
  // devuelve null y seguimos con el fetch real.
  if (USE_MOCKS) {
    const mocked = await mockFetch(path, rest);
    if (mocked) return mocked;
  }

  const { jwt } = get(session);

  const headers = new Headers(rest.headers ?? {});
  if (!headers.has('Content-Type') && rest.body) {
    headers.set('Content-Type', 'application/json');
  }

  if (auth && jwt) {
    headers.set('Authorization', `${jwt}`);
  }

  const res = await fetch(`${BACKEND_BASE_URL}${path}`, {
    ...rest,
    headers
  });

  return res;
}