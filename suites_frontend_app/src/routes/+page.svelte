<script lang="ts">
  import { goto } from "$app/navigation";

  export let data: {
    suites: { id_suite: string }[];
    error: string | null;
  };

  type SuiteDetail = {
    id_suite: string;
    capacidad: string;
    cupos_disponibles: string;
    invitados_inscritos: string[];
  };

  let selectedSuite: SuiteDetail | null = null;
  let loadingDetail = false;
  let detailError: string | null = null;

  async function handleSelectSuite(id: string) {
    loadingDetail = true;
    detailError = null;
    selectedSuite = null;

    try {
      const res = await fetch(`/api/suites/${id}`);

      if (!res.ok) {
        throw new Error("No se pudo obtener el detalle de la suite");
      }

      const suite: SuiteDetail = await res.json();
      selectedSuite = suite;
    } catch (e) {
      const err = e as Error;
      detailError = err.message ?? "Error inesperado al cargar el detalle";
    } finally {
      loadingDetail = false;
    }
  }
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
    <section class="layout">
      <!-- GRID DE SUITES -->
      <section class="grid">
        {#each data.suites as suite, index}
          <article
            class="card"
            on:click={() => handleSelectSuite(suite.id_suite)}
          >
            <span class="badge">Suite #{index + 1}</span>
            <h2 class="card-title">ID Suite</h2>
            <p class="card-id">{suite.id_suite}</p>
            <p class="card-sub">Toca para ver detalle</p>
          </article>
        {/each}
      </section>

      <!-- PANEL DE DETALLE -->
      <section class="detail-panel">
        <h2 class="detail-title">Detalle de la suite</h2>

        {#if loadingDetail}
          <p class="detail-loading">Cargando detalle...</p>
        {:else if detailError}
          <p class="error">{detailError}</p>
        {:else if selectedSuite}
          <div class="detail-card">
            <div class="detail-row">
              <span class="detail-label">ID Suite</span>
              <span class="detail-value">{selectedSuite.id_suite}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Capacidad</span>
              <span class="detail-value">{selectedSuite.capacidad}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Cupos disponibles</span>
              <span class="detail-value">{selectedSuite.cupos_disponibles}</span
              >
            </div>
            <div class="detail-row">
              <span class="detail-label">Invitados inscritos</span>
              <span class="detail-value">
                {#if selectedSuite.invitados_inscritos.length > 0}
                  {selectedSuite.invitados_inscritos.join(", ")}
                {:else}
                  Ninguno
                {/if}
              </span>
            </div>
          </div>
          <div class="detail-actions">
            <button
              class="btn-primary"
              type="button"
              on:click={() => goto("/registrar-invitado")}
            >
              Registrar invitado
            </button>
          </div>
        {:else}
          <p class="hint">Selecciona una suite para ver su detalle.</p>
        {/if}
      </section>
    </section>
  {/if}
</main>

<style>
  :global(body) {
    margin: 0;
    font-family:
      system-ui,
      -apple-system,
      BlinkMacSystemFont,
      "Segoe UI",
      sans-serif;
    background: #0f172a;
    color: #e5e7eb;
  }

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

  .layout {
    display: grid;
    grid-template-columns: minmax(0, 3fr) minmax(0, 2fr);
    gap: 1.5rem;
    align-items: flex-start;
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
    transition:
      transform 0.15s ease,
      box-shadow 0.15s ease,
      border-color 0.15s ease,
      background 0.15s ease;
    cursor: pointer;
  }

  .card:hover {
    transform: translateY(-3px);
    box-shadow: 0 18px 35px rgba(15, 23, 42, 0.9);
    border-color: #4b5563;
    background: #020617;
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

  .card-sub {
    font-size: 0.8rem;
    color: #9ca3af;
    margin: 0.3rem 0 0 0;
  }

  .detail-panel {
    background: #020617;
    border-radius: 1rem;
    padding: 1rem 1.2rem;
    border: 1px solid #1f2937;
    box-shadow: 0 12px 25px rgba(15, 23, 42, 0.7);
  }

  .detail-title {
    font-size: 1.1rem;
    margin-top: 0;
    margin-bottom: 1rem;
    font-weight: 600;
  }

  .detail-loading {
    color: #93c5fd;
  }

  .detail-card {
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
  }

  .detail-row {
    display: flex;
    justify-content: space-between;
    gap: 0.5rem;
    padding: 0.4rem 0;
    border-bottom: 1px solid #1f2937;
  }

  .detail-row:last-child {
    border-bottom: none;
  }

  .detail-label {
    font-size: 0.85rem;
    color: #9ca3af;
  }

  .detail-value {
    font-size: 0.95rem;
    font-weight: 500;
    color: #e5e7eb;
  }

  .hint {
    font-size: 0.9rem;
    color: #9ca3af;
  }

  /* Mobile-first: que respire bien en smartphones */
  @media (max-width: 768px) {
    .page {
      padding: 1rem;
    }

    .title {
      font-size: 1.4rem;
    }

    .layout {
      grid-template-columns: minmax(0, 1fr);
    }

    .detail-panel {
      margin-top: 0.5rem;
    }

    .card {
      padding: 0.8rem 1rem;
    }

    .card-id {
      font-size: 1.4rem;
    }
  }

    .detail-actions {
    margin-top: 1rem;
    display: flex;
    justify-content: flex-end;
  }

  .btn-primary {
    padding: 0.5rem 1rem;
    border-radius: 999px;
    border: none;
    background: #1d4ed8;
    color: #f9fafb;
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 10px 25px rgba(37, 99, 235, 0.4);
    transition: transform 0.12s ease, box-shadow 0.12s ease,
      background 0.12s ease;
  }

  .btn-primary:hover {
    transform: translateY(-1px);
    box-shadow: 0 14px 30px rgba(37, 99, 235, 0.6);
    background: #1e40af;
  }

  .btn-primary:active {
    transform: translateY(0);
    box-shadow: 0 8px 18px rgba(30, 64, 175, 0.7);
  }
</style>
