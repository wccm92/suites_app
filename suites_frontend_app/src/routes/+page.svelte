<script lang="ts">
  import { goto } from "$app/navigation";
  import { base } from "$app/paths";
  import { onMount } from "svelte";
  import { get } from "svelte/store";
  import { session } from "$lib/stores/session";
  import { apiFetch } from "$lib/api/client";
  import type { SuiteDetailOrError, SuiteDetail, SuiteDetailError, ErrorItem } from '$lib/api/types';
  import { isSuiteDetailError, isSuiteDetail } from '$lib/api/guards';

  type SuiteSummary = {
    id_suite: string;
    capacidad: number;
  };

  // Estado para el listado de suites
  let suites: SuiteSummary[] = [];
  let suitesLoading = true;
  let suitesError: string | null = null;


  let selectedSuite: SuiteDetail | null = null;
  let loadingDetail = false;
  let detailError: string | null = null;

  // 1) Revisamos JWT en localStorage (via store session)
  // 2) Si no hay JWT → login
  // 3) Si hay JWT → llamar /suites_app/suites
  onMount(async () => {
    suitesLoading = true;
    suitesError = null;

    const { jwt } = get(session);

    // 1.1 -> Si no está el jwt o está en null → login
    if (!jwt) {
      await goto(`${base}/login`);
      return;
    }

    try {
      const res = await apiFetch("/suites_app/suites");

      if (res.status === 401) {
        // 2.1 -> Si 401, limpiar sesión y mandar a login
        session.clear();
        await goto(`${base}/login`);
        return;
      }

      if (!res.ok) {
        suitesError = "No se pudo obtener el listado de suites.";
        return;
      }

      const body = (await res.json()) as
        | SuiteSummary[]
        | { suites: SuiteSummary[] };

      suites = Array.isArray(body) ? body : body.suites;
    } catch (e) {
      const err = e as Error;
      suitesError =
        err.message ?? "Error inesperado al cargar el listado de suites.";
    } finally {
      suitesLoading = false;
    }
  });

  async function handleSelectSuite(id: string) {
    loadingDetail = true;
    detailError = null;
    selectedSuite = null;

    try {
      const res = await apiFetch(`/suites_app/suites/${id}`);

      if (res.status === 404) {
        // Extra: si 404 aquí, limpiamos sesión y mandamos a la pantalla de no-event
        session.clear();
        await goto(`${base}/no-event`);
        return;
      }

      if (res.status === 401) {
        // Extra: si 401 aquí, limpiamos sesión y mandamos a login
        session.clear();
        await goto(`${base}/login`);
        return;
      }

      if (!res.ok) {
        throw new Error("No se pudo obtener el detalle de la suite");
      }

      const body = (await res.json()) as unknown as SuiteDetailOrError;
      if (isSuiteDetailError(body)) {
        const firstError = body.errors[0];
        throw new Error(firstError.detail || 'Error al consultar la suite.');
      } else if (isSuiteDetail(body)) {
        const suite = body;
        selectedSuite = suite;
      }

    } catch (e) {
      const err = e as Error;
      detailError = err.message ?? "Error inesperado al cargar el detalle";
    } finally {
      loadingDetail = false;
    }
  }

  function goToRegisterGuest() {
    goto(`${base}/registrar-invitado`);
  }
</script>

<svelte:head>
  <title>Suites</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <h1 class="title">Listado de Suites</h1>

  {#if suitesError}
    <p class="error">{suitesError}</p>
  {:else if suitesLoading}
    <p class="detail-loading">Cargando suites...</p>
  {:else if suites.length === 0}
    <p class="empty">No hay suites disponibles.</p>
  {:else}
    <section class="layout">
      <!-- GRID DE SUITES -->
      <section class="grid">
        {#each suites as suite, index}
          <article
            class="card"
            on:click={() => handleSelectSuite(suite.id_suite)}
          >
            <span class="badge">Suite #{index + 1}</span>
            <h2 class="card-title">ID Suite</h2>
            <p class="card-id">{suite.id_suite}</p>

            <p class="card-capacity">
              Capacidad: <strong>{suite.capacidad}</strong> personas
            </p>

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
          <!-- ... tu HTML actual de detalle ... -->
          <div class="detail-card">
            <!-- filas de detalle -->
          </div>
          <div class="detail-actions">
            <button
              class="btn-primary"
              type="button"
              on:click={goToRegisterGuest}
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
    /* Fondo en tonos verde oscuro */
    background: radial-gradient(
      circle at top,
      #027c68 0,
      #069747 55%,
      #001a1a 100%
    );
    color: #e6fff5;
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
    color: #b0e892;
  }

  .error {
    color: #fca5a5;
    text-align: center;
  }

  .empty {
    color: #b0e892;
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
    background: #069747;
    border-radius: 1rem;
    padding: 1rem 1.2rem;
    box-shadow: 0 12px 25px rgba(0, 0, 0, 0.5);
    border: 1px solid #027c68;
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
    box-shadow: 0 18px 35px rgba(0, 0, 0, 0.65);
    border-color: #009933;
    background: #014040;
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

  .card-title {
    font-size: 0.9rem;
    font-weight: 500;
    color: #b0e892;
    margin: 0;
  }

  .card-id {
    font-size: 1.6rem;
    font-weight: 700;
    color: #ffffff;
    margin: 0;
  }

  .card-capacity {
    font-size: 0.85rem;
    color: #e0f5dd;
    margin: 0.1rem 0 0.2rem 0;
  }

  .card-capacity strong {
    color: #b0e892;
  }

  .card-sub {
    font-size: 0.8rem;
    color: #c8e6d8;
    margin: 0.3rem 0 0 0;
  }

  .detail-panel {
    background: #001f1f;
    border-radius: 1rem;
    padding: 1rem 1.2rem;
    border: 1px solid #027c68;
    box-shadow: 0 12px 25px rgba(0, 0, 0, 0.55);
  }

  .detail-title {
    font-size: 1.1rem;
    margin-top: 0;
    margin-bottom: 1rem;
    font-weight: 600;
    color: #b0e892;
  }

  .detail-loading {
    color: #b0e892;
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
    border-bottom: 1px solid #027c68;
  }

  .detail-row:last-child {
    border-bottom: none;
  }

  .detail-label {
    font-size: 0.85rem;
    color: #b0e892;
  }

  .detail-value {
    font-size: 0.95rem;
    font-weight: 500;
    color: #f5fff9;
  }

  .hint {
    font-size: 0.9rem;
    color: #c8e6d8;
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
    background: #027c68;
    color: #f5fff9;
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 10px 25px rgba(0, 51, 51, 0.6);
    transition:
      transform 0.12s ease,
      box-shadow 0.12s ease,
      background 0.12s ease;
  }

  .btn-primary:hover {
    transform: translateY(-1px);
    box-shadow: 0 14px 30px rgba(0, 51, 51, 0.85);
    background: #009933;
  }

  .btn-primary:active {
    transform: translateY(0);
    box-shadow: 0 8px 18px rgba(0, 51, 51, 0.9);
  }

  /* Que esta fila se apile en columna para el grid de invitados */
  .detail-row-column {
    flex-direction: column;
    align-items: flex-start;
  }

  .guests-grid {
    margin-top: 0.35rem;
    width: 100%;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(80px, 1fr));
    gap: 0.4rem;
  }

  .guest-pill {
    background: #014040;
    border-radius: 999px;
    padding: 0.3rem 0.5rem;
    border: 1px solid #027c68;
    box-shadow: 0 4px 10px rgba(0, 0, 0, 0.5);
    text-align: center;
  }

  .guest-id {
    font-size: 0.8rem;
    font-weight: 500;
    color: #b0e892;
    letter-spacing: 0.02em;
  }

  /* Mobile-first */
  @media (max-width: 768px) {
    .page {
      padding: 1rem;
    }

    .title {
      font-size: 1.4rem;
    }

    /* Layout en una sola columna */
    .layout {
      grid-template-columns: minmax(0, 1fr);
      gap: 1rem;
    }

    /* ✅ La grilla de suites se convierte en cajoncitos más compactos
     y con scroll propio para NO empujar el detalle hacia abajo */
    .grid {
      grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
      max-height: 50vh; /* ocupan como máximo media pantalla */
      overflow-y: auto; /* la lista scrollea dentro de sí misma */
      padding-right: 0.25rem; /* pequeño espacio para que no corte el scroll */
    }

    .card {
      padding: 0.7rem 0.8rem;
      border-radius: 0.75rem;
      gap: 0.25rem;
    }

    .badge {
      font-size: 0.7rem;
      padding: 0.1rem 0.5rem;
    }

    .card-title {
      font-size: 0.8rem;
    }

    .card-id {
      font-size: 1.2rem;
    }

    .card-capacity {
      font-size: 0.8rem;
    }

    .card-sub {
      font-size: 0.75rem;
    }

    /* Panel de detalle inmediatamente debajo y siempre visible
     porque la grilla ya no crece infinito */
    .detail-panel {
      margin-top: 0.5rem;
    }
  }
</style>
