// src/lib/stores/session.ts
import { writable } from 'svelte/store';
import { browser } from '$app/environment';

type Session = {
  jwt: string | null;
};

const STORAGE_KEY = 'app_session';

function createSessionStore() {
  let initial: Session = { jwt: null };

  if (browser) {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        initial = JSON.parse(saved) as Session;
      }
    } catch {
      // ignorar errores de JSON / localStorage
    }
  }

  const { subscribe, set, update } = writable<Session>(initial);

  if (browser) {
    subscribe((value) => {
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(value));
      } catch {
        // si falla localStorage no pasa nada
      }
    });
  }

  return {
    subscribe,
    set,
    update,
    setJwt(jwt: string | null) {
      update((s) => ({ ...s, jwt }));
    },
    clear() {
      set({ jwt: null });
      if (browser) {
        localStorage.removeItem(STORAGE_KEY);
      }
    },
    /**
     * Decodifica el payload del JWT activo y devuelve el claim `profile`.
     * Devuelve null si no hay sesión o el token no es decodificable.
     */
    getProfile(): string | null {
      let jwt: string | null = null;
      const unsub = subscribe((s) => (jwt = s.jwt));
      unsub();
      if (!jwt) return null;
      try {
        const payload = JSON.parse(atob((jwt as string).split('.')[1]));
        return typeof payload?.profile === 'string' ? payload.profile : null;
      } catch {
        return null;
      }
    }
  };
}

export const session = createSessionStore();