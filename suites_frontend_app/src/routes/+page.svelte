<script lang="ts">
  export let data: {
    suites: { id_suite: string }[];
    error: string | null;
  };
</script>

<svelte:head>
  <title>Suites</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <h1 class="title">Listado de Suites</h1>

  {#if data.error}
    <p class="error">{data.error}</p>
  {:else if data.suites.length === 0}
    <p class="empty">No hay suites disponibles.</p>
  {:else}
    <section class="grid">
      {#each data.suites as suite, index}
        <article class="card">
          <span class="badge">Suite #{index + 1}</span>
          <h2 class="card-title">ID Suite</h2>
          <p class="card-id">{suite.id_suite}</p>
        </article>
      {/each}
    </section>
  {/if}
</main>

<style>
  :global(body) {
    margin: 0;
    font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI',
      sans-serif;
    background: #0f172a;
    color: #e5e7eb;
  }

  .page {
    min-height: 100vh;
    padding: 1.5rem;
    max-width: 960px;
    margin: 0 auto;
  }

  .title {
    font-size: 1.8rem;
    font-weight: 700;
    margin-bottom: 1.5rem;
    text-align: center;
  }

  .error {
    color: #fca5a5;
    text-align: center;
  }

  .empty {
    color: #9ca3af;
    text-align: center;
  }

  .grid {
    display: grid;
    gap: 1rem;
    grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  }

  .card {
    background: #111827;
    border-radius: 1rem;
    padding: 1rem 1.2rem;
    box-shadow: 0 12px 25px rgba(15, 23, 42, 0.7);
    border: 1px solid #1f2937;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
    transition: transform 0.15s ease, box-shadow 0.15s ease,
      border-color 0.15s ease;
  }

  .card:hover {
    transform: translateY(-3px);
    box-shadow: 0 18px 35px rgba(15, 23, 42, 0.9);
    border-color: #4b5563;
  }

  .badge {
    align-self: flex-start;
    font-size: 0.75rem;
    padding: 0.15rem 0.6rem;
    border-radius: 999px;
    background: #1d4ed8;
    color: white;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .card-title {
    font-size: 0.9rem;
    font-weight: 500;
    color: #9ca3af;
    margin: 0;
  }

  .card-id {
    font-size: 1.6rem;
    font-weight: 700;
    color: #f9fafb;
    margin: 0;
  }

  /* Mobile-first: que respire bien en smartphones */
  @media (max-width: 640px) {
    .page {
      padding: 1rem;
    }

    .title {
      font-size: 1.4rem;
    }

    .card {
      padding: 0.8rem 1rem;
    }

    .card-id {
      font-size: 1.4rem;
    }
  }
</style>