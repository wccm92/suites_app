// src/routes/login/+page.ts
import type { PageLoad } from './$types';
import { redirect } from '@sveltejs/kit';
import { apiFetch } from '$lib/api/client';

export const load: PageLoad = async () => {
  const res = await apiFetch('/suites_app/get-event', { auth: false });

  if (!res.ok) {
    throw redirect(307, '/no-event');
  }

  return {};
};