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
    }
  };
}

export const session = createSessionStore();