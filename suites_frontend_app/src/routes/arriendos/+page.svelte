<script lang="ts">
  import { goto } from "$app/navigation";
  import { base } from "$app/paths";
  import { onMount } from "svelte";
  import { get } from "svelte/store";
  import { session } from "$lib/stores/session";
  import { apiFetch } from "$lib/api/client";
  import type { SuiteDetailOrError, SuiteDetail } from "$lib/api/types";
  import { isSuiteDetailError, isSuiteDetail } from "$lib/api/guards";

  type SuiteSummary = {
    id_suite: string;
    capacidad: number;
  };

  let suites: SuiteSummary[] = [];
  let suitesLoading = true;
  let suitesError: string | null = null;

  let selectedSuite: SuiteDetail | null = null;
  let loadingDetail = false;
  let detailError: string | null = null;

  $: suiteSinCupos =
    !!selectedSuite && selectedSuite.cupos_disponibles === 0;

  onMount(async () => {
    suitesLoading = true;
    suitesError = null;

    const { jwt } = get(session);

    if (!jwt) {
      await goto(`${base}/login`);
      return;
    }

    try {
      const res = await apiFetch("/suites_app/suites_leaseholder");

      if (res.status === 401) {
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
        session.clear();
        await goto(`${base}/no-event`);
        return;
      }

      if (res.status === 401) {
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
        throw new Error(firstError.detail || "Error al consultar la suite.");
      } else if (isSuiteDetail(body)) {
        selectedSuite = body;
      } else {
        throw new Error("Respuesta inesperada del servidor.");
      }
    } catch (e) {
      const err = e as Error;
      detailError = err.message ?? "Error inesperado al cargar el detalle";
    } finally {
      loadingDetail = false;
    }
  }

  function goToRegisterGuest() {
    if (!selectedSuite) return;

    const qs = new URLSearchParams({
      id_suite: selectedSuite.id_suite,
      capacidad: String(selectedSuite.capacidad),
      cupos_disponibles: String(selectedSuite.cupos_disponibles),
    });

    goto(`${base}/registrar-invitado?${qs.toString()}`);
  }
</script>

<svelte:head>
  <title>Arriendos</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <div class="top-bar">
    <h1 class="title">Mis suistes recibidas en alquiler</h1>
  </div>

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
              <span
                class="detail-value {suiteSinCupos ? 'detail-value-zero' : ''}"
              >
                {selectedSuite.cupos_disponibles}
              </span>
            </div>
            <div class="detail-row detail-row-column">
              <span class="detail-label">Visitantes inscritos</span>
              {#if selectedSuite.invitados_inscritos?.length}
                <div class="guests-grid">
                  {#each selectedSuite.invitados_inscritos as guest}
                    <div class="guest-pill">
                      <span class="guest-id">{guest}</span>
                    </div>
                  {/each}
                </div>
              {:else}
                <span class="detail-value">Sin visitantes</span>
              {/if}
            </div>
          </div>
          <div class="detail-actions">
            <button
              class="btn-primary"
              type="button"
              on:click={goToRegisterGuest}
              disabled={suiteSinCupos}
              aria-disabled={suiteSinCupos}
              title={suiteSinCupos
                ? "No puedes registrar invitados: no hay cupos disponibles en esta suite."
                : "Registrar invitado en esta suite"}
            >
              Registrar visitante
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
  .page {
    min-height: 100vh;
    padding: 1.5rem;
    max-width: 1100px;
    margin: 0 auto;
  }

  .top-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 0.75rem;
    margin-bottom: 1.5rem;
  }

  .title {
    font-size: 1.8rem;
    font-weight: 700;
    margin: 0;
    text-align: left;
    color: var(--color-success);
  }

  .btn-nav {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.65rem 1.1rem 0.65rem 0.75rem;
    border-radius: 1rem;
    border: 1px solid #c0ddd4;
    background: linear-gradient(135deg, #edf7f2 0%, #e0f2e9 100%);
    color: var(--color-text-main);
    cursor: pointer;
    box-shadow: 0 4px 12px rgba(0, 89, 64, 0.12);
    transition:
      transform 0.15s ease,
      box-shadow 0.15s ease,
      border-color 0.15s ease;
    white-space: nowrap;
    text-align: left;
  }

  .btn-nav:hover {
    transform: translateY(-2px);
    border-color: var(--color-primary);
    box-shadow: 0 8px 20px rgba(0, 89, 64, 0.20);
  }

  .btn-nav:active {
    transform: translateY(0);
  }

  .btn-nav__icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2.4rem;
    height: 2.4rem;
    border-radius: 0.75rem;
    background: #009933;
    color: #f5fff8;
    flex-shrink: 0;
    box-shadow: 0 4px 12px rgba(0, 153, 51, 0.45);
  }

  .btn-nav__icon svg {
    width: 1.35rem;
    height: 1.35rem;
  }

  .btn-nav__body {
    display: flex;
    flex-direction: column;
    gap: 0.1rem;
  }

  .btn-nav__label {
    font-size: 0.92rem;
    font-weight: 700;
    color: var(--color-text-main);
    line-height: 1.2;
  }

  .btn-nav__sub {
    font-size: 0.72rem;
    color: var(--color-text-muted);
    font-weight: 400;
    line-height: 1.2;
  }

  .btn-nav__arrow {
    margin-left: auto;
    font-size: 1.4rem;
    color: #009933;
    line-height: 1;
    padding-left: 0.25rem;
  }

  .error {
    color: #fca5a5;
    text-align: center;
  }

  .empty {
    color: var(--color-success);
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
    background: #ffffff;
    border-radius: 1rem;
    padding: 1rem 1.2rem;
    box-shadow: 0 4px 12px rgba(0, 89, 64, 0.10);
    border: 1px solid #d1e8e0;
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
    box-shadow: 0 10px 24px rgba(0, 89, 64, 0.18);
    border-color: var(--color-primary);
    background: #edf7f2;
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
    color: var(--color-success);
    margin: 0;
  }

  .card-id {
    font-size: 1.6rem;
    font-weight: 700;
    color: var(--color-text-main);
    margin: 0;
  }

  .card-capacity {
    font-size: 0.85rem;
    color: var(--color-text-muted);
    margin: 0.1rem 0 0.2rem 0;
  }

  .card-capacity strong {
    color: var(--color-success);
  }

  .card-sub {
    font-size: 0.8rem;
    color: var(--color-text-muted);
    margin: 0.3rem 0 0 0;
  }

  .detail-panel {
    background: #ffffff;
    border-radius: 1rem;
    padding: 1rem 1.2rem;
    border: 1px solid #d1e8e0;
    box-shadow: 0 4px 12px rgba(0, 89, 64, 0.10);
  }

  .detail-title {
    font-size: 1.1rem;
    margin-top: 0;
    margin-bottom: 1rem;
    font-weight: 600;
    color: var(--color-success);
  }

  .detail-loading {
    color: var(--color-success);
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
    border-bottom: 1px solid #e5f0ea;
  }

  .detail-row:last-child {
    border-bottom: none;
  }

  .detail-label {
    font-size: 0.85rem;
    color: var(--color-success);
  }

  .detail-value {
    font-size: 0.95rem;
    font-weight: 500;
    color: var(--color-text-main);
  }

  .detail-value-zero {
    color: #ff6b6b;
    font-weight: 700;
  }

  .hint {
    font-size: 0.9rem;
    color: var(--color-text-muted);
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
    background: var(--color-primary);
    color: #ffffff;
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 4px 12px rgba(0, 89, 64, 0.28);
    transition:
      transform 0.12s ease,
      box-shadow 0.12s ease,
      background 0.12s ease;
  }

  .btn-primary:hover:enabled {
    transform: translateY(-1px);
    box-shadow: 0 8px 20px rgba(0, 89, 64, 0.40);
    background: #009933;
  }

  .btn-primary:active:enabled {
    transform: translateY(0);
    box-shadow: 0 4px 10px rgba(0, 89, 64, 0.30);
  }

  .btn-primary:disabled {
    opacity: 0.55;
    cursor: not-allowed;
    box-shadow: 0 6px 15px rgba(0, 0, 0, 0.3);
  }

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
    background: #edf7f2;
    border-radius: 999px;
    padding: 0.3rem 0.5rem;
    border: 1px solid #c0ddd4;
    box-shadow: 0 2px 6px rgba(0, 89, 64, 0.10);
    text-align: center;
  }

  .guest-id {
    font-size: 0.8rem;
    font-weight: 500;
    color: var(--color-success);
    letter-spacing: 0.02em;
  }

  @media (max-width: 768px) {
    .page {
      padding: 1rem;
    }

    .title {
      font-size: 1.4rem;
    }

    .layout {
      grid-template-columns: minmax(0, 1fr);
      gap: 1rem;
    }

    .grid {
      grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
      max-height: 50vh;
      overflow-y: auto;
      padding-right: 0.25rem;
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

    .detail-panel {
      margin-top: 0.5rem;
    }
  }
</style>
