<script lang="ts">
  import { goto } from "$app/navigation";
  import { base } from "$app/paths";
  import { onMount } from "svelte";
  import { get } from "svelte/store";
  import { session } from "$lib/stores/session";
  import { apiFetch } from "$lib/api/client";
  import type { Parqueadero, ParqueaderosResponse } from "$lib/api/types";

  let parqueaderos: Parqueadero[] = [];
  let loading = true;
  let error: string | null = null;

  onMount(async () => {
    const { jwt } = get(session);

    if (!jwt) {
      await goto(`${base}/login`);
      return;
    }

    try {
      const res = await apiFetch("/suites_app/lots");

      if (res.status === 401) {
        session.clear();
        await goto(`${base}/login`);
        return;
      }

      if (res.status === 404) {
        session.clear();
        await goto(`${base}/no-event`);
        return;
      }

      if (!res.ok) {
        error = "No se pudieron cargar los parqueaderos para este perfil.";
        return;
      }

      const body = (await res.json()) as ParqueaderosResponse;
      parqueaderos = body.parqueadero ?? [];
    } catch (e) {
      error = "No se pudieron cargar los parqueaderos para este perfil.";
    } finally {
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>Parqueaderos</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <div class="top-bar">
    <button
      class="btn-back"
      type="button"
      on:click={() => goto(`${base}/`)}
    >
      ← Volver
    </button>
    <h1 class="title">Parqueaderos</h1>
  </div>

  {#if loading}
    <p class="loading">Cargando parqueaderos...</p>
  {:else if error}
    <p class="error">{error}</p>
  {:else if parqueaderos.length === 0}
    <p class="empty">No hay parqueaderos disponibles.</p>
  {:else}
    <section class="grid">
      {#each parqueaderos as p}
        <article class="card {p.estado === 'deshabilitado' ? 'card--disabled' : ''}">
          <span class="badge badge--{p.estado}">
            {p.estado}
          </span>
          <p class="card-label">ID Parqueadero</p>
          <p class="card-id {p.estado === 'deshabilitado' ? 'text-disabled' : ''}">
            {p.id_parqueadero}
          </p>
        </article>
      {/each}
    </section>
  {/if}
</main>

<style>
  .page {
    min-height: 100vh;
    padding: 1.5rem;
    max-width: 1100px;
    margin: 0 auto;
  }

  .top-bar {
    display: flex;
    align-items: center;
    gap: 1rem;
    margin-bottom: 1.5rem;
    flex-wrap: wrap;
  }

  .title {
    font-size: 1.8rem;
    font-weight: 700;
    margin: 0;
    color: var(--color-success);
  }

  .btn-back {
    padding: 0.4rem 0.9rem;
    border-radius: 999px;
    border: 1px solid var(--color-primary-light);
    background: var(--color-surface);
    color: var(--color-text-main);
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.4);
    transition:
      background 0.15s ease,
      border-color 0.15s ease,
      transform 0.12s ease;
    white-space: nowrap;
  }

  .btn-back:hover {
    background: #014040;
    border-color: #009933;
    transform: translateY(-1px);
  }

  .loading,
  .empty {
    color: var(--color-success);
    text-align: center;
  }

  .error {
    color: var(--color-error-soft);
    text-align: center;
    font-weight: 500;
  }

  .grid {
    display: grid;
    gap: 1rem;
    grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  }

  .card {
    background: var(--color-surface);
    border-radius: 1rem;
    padding: 1rem 1.2rem;
    box-shadow: 0 12px 25px rgba(0, 0, 0, 0.5);
    border: 1px solid var(--color-primary);
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  .card--disabled {
    opacity: 0.75;
    border-color: var(--color-error);
  }

  .badge {
    align-self: flex-start;
    font-size: 0.72rem;
    padding: 0.15rem 0.6rem;
    border-radius: 999px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    font-weight: 600;
  }

  .badge--habilitado {
    background: #009933;
    color: #f5fff8;
  }

  .badge--deshabilitado {
    background: #450a0a;
    color: var(--color-error);
    border: 1px solid var(--color-error);
  }

  .card-label {
    font-size: 0.8rem;
    color: var(--color-success);
    margin: 0.25rem 0 0 0;
    font-weight: 500;
  }

  .card-id {
    font-size: 1.5rem;
    font-weight: 700;
    color: #ffffff;
    margin: 0;
  }

  .text-disabled {
    color: var(--color-error);
  }

  @media (max-width: 768px) {
    .page {
      padding: 1rem;
    }

    .title {
      font-size: 1.4rem;
    }

    .grid {
      grid-template-columns: repeat(auto-fill, minmax(130px, 1fr));
    }

    .card-id {
      font-size: 1.2rem;
    }
  }
</style>
