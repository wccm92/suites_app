<script lang="ts">
  import { goto } from "$app/navigation";
  import { base } from "$app/paths";
  import { onMount } from "svelte";
  import { get } from "svelte/store";
  import { session } from "$lib/stores/session";
  import { apiFetch } from "$lib/api/client";

  type SuiteSummary = {
    id_suite: string;
    capacidad: number;
  };

  let suites: SuiteSummary[] = [];
  let loading = true;
  let error: string | null = null;

  onMount(async () => {
    const { jwt } = get(session);

    if (!jwt) {
      await goto(`${base}/login`);
      return;
    }

    try {
      const res = await apiFetch("/suites_app/suites");

      if (res.status === 401) {
        session.clear();
        await goto(`${base}/login`);
        return;
      }

      if (!res.ok) {
        error = "No se pudo obtener el listado de suites.";
        return;
      }

      const body = (await res.json()) as
        | SuiteSummary[]
        | { suites: SuiteSummary[] };

      suites = Array.isArray(body) ? body : body.suites;
    } catch (e) {
      const err = e as Error;
      error = err.message ?? "Error inesperado al cargar el listado de suites.";
    } finally {
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>Arriendos</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <h1 class="title">Arriendos</h1>

  {#if loading}
    <p class="loading">Cargando suites...</p>
  {:else if error}
    <p class="error">{error}</p>
  {:else if suites.length === 0}
    <p class="empty">No hay suites disponibles.</p>
  {:else}
    <section class="grid">
      {#each suites as suite, index}
        <article class="card">
          <span class="badge">Suite #{index + 1}</span>
          <p class="card-label">ID Suite</p>
          <p class="card-id">{suite.id_suite}</p>
          <p class="card-capacity">
            Capacidad: <strong>{suite.capacidad}</strong> personas
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

  .title {
    font-size: 1.8rem;
    font-weight: 700;
    margin-bottom: 1.5rem;
    color: var(--color-success);
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
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
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

  .badge {
    align-self: flex-start;
    font-size: 0.75rem;
    padding: 0.15rem 0.6rem;
    border-radius: 999px;
    background: #009933;
    color: #f5fff8;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .card-label {
    font-size: 0.85rem;
    color: var(--color-success);
    margin: 0.2rem 0 0 0;
    font-weight: 500;
  }

  .card-id {
    font-size: 1.5rem;
    font-weight: 700;
    color: #ffffff;
    margin: 0;
  }

  .card-capacity {
    font-size: 0.85rem;
    color: #e0f5dd;
    margin: 0;
  }

  .card-capacity strong {
    color: var(--color-success);
  }

  @media (max-width: 768px) {
    .page {
      padding: 1rem;
    }

    .title {
      font-size: 1.4rem;
    }

    .grid {
      grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
    }

    .card-id {
      font-size: 1.2rem;
    }
  }
</style>
