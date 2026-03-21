<script lang="ts">
  import { goto } from "$app/navigation";
  import { base } from "$app/paths";
  import { onMount } from "svelte";
  import { get } from "svelte/store";
  import { session } from "$lib/stores/session";
  import { apiFetch } from "$lib/api/client";
  import type {
    SuiteDetailOrError,
    SuiteDetail,
    SuiteDetailError,
    ErrorItem,
  } from "$lib/api/types";
  import { isSuiteDetailError, isSuiteDetail } from "$lib/api/guards";

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

  // Derivado: indica si la suite seleccionada no tiene cupos
  $: suiteSinCupos =
    !!selectedSuite && selectedSuite.cupos_disponibles === 0;

  // Derivado: indica si la suite ya está alquilada
  $: suiteAlquilada =
    !!selectedSuite && selectedSuite.suite_alquilada === true;

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
        throw new Error(firstError.detail || "Error al consultar la suite.");
      } else if (isSuiteDetail(body)) {
        const suite = body;
        selectedSuite = suite;
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

  // ── Alquilar suite – 3-step modal flow ──────────────────────────────────
  let showRentModal = false;
  let showRentConfirm = false;
  let showRentSuccess = false;
  let cedulaArrendatario = '';
  let rentError = '';
  let isSubmittingRent = false;

  function openRentModal() {
    cedulaArrendatario = '';
    rentError = '';
    showRentModal = true;
  }

  function closeRentModal() {
    showRentModal = false;
  }

  function openRentConfirm() {
    const clean = cedulaArrendatario.trim().replace(/\D/g, '');
    if (clean.length < 6 || clean.length > 10) {
      rentError = 'Ingrese una cédula válida (entre 6 y 10 dígitos).';
      return;
    }
    cedulaArrendatario = clean;
    rentError = '';
    showRentConfirm = true;
  }

  function closeRentConfirm() {
    showRentConfirm = false;
  }

  async function confirmRent() {
    if (!selectedSuite) return;
    isSubmittingRent = true;
    rentError = '';
    try {
      const res = await apiFetch(`/suites_app/rent_suite/${selectedSuite.id_suite}`, {
        method: 'POST',
        body: JSON.stringify({ cedula: cedulaArrendatario }),
      });
      if (res.status === 401) {
        session.clear();
        await goto(`${base}/login`);
        return;
      }
      if (!res.ok) {
        const json = await res.json().catch(() => ({}));
        rentError = (json as any)?.errors?.[0]?.detail ?? 'Error al alquilar la suite.';
        showRentConfirm = false;
        return;
      }
      showRentConfirm = false;
      showRentModal = false;
      showRentSuccess = true;
    } catch {
      rentError = 'Error inesperado al alquilar la suite.';
      showRentConfirm = false;
    } finally {
      isSubmittingRent = false;
    }
  }
</script>

<svelte:head>
  <title>Suites</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <div class="top-bar">
    <h1 class="title">Mis suites</h1>
    <button
      class="btn-nav"
      type="button"
      on:click={() => goto(`${base}/parqueaderos`)}
    >
      <span class="btn-nav__icon">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
          <path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z"/>
        </svg>
      </span>
      <span class="btn-nav__body">
        <span class="btn-nav__label">Ver parqueaderos</span>
        <span class="btn-nav__sub">Consultar disponibilidad</span>
      </span>
      <span class="btn-nav__arrow">›</span>
    </button>
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
              <!-- si no hay cupos, pintamos en rojo -->
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
              class="btn-secondary {suiteAlquilada ? 'btn-rented' : ''}"
              type="button"
              on:click={suiteAlquilada ? undefined : openRentModal}
              disabled={suiteAlquilada}
              aria-disabled={suiteAlquilada}
              title={suiteAlquilada
                ? "Esta suite ya está alquilada."
                : "Alquilar esta suite"}
            >
              {suiteAlquilada ? 'Suite Alquilada' : 'Alquilar suite'}
            </button>
            <button
              class="btn-primary"
              type="button"
              on:click={goToRegisterGuest}
              disabled={suiteSinCupos || suiteAlquilada}
              aria-disabled={suiteSinCupos || suiteAlquilada}
              title={suiteAlquilada
                ? "No puedes registrar invitados: la suite está alquilada."
                : suiteSinCupos
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

<!-- ── Modal 1: Alquilar suite ────────────────────────────────────────── -->
{#if showRentModal && !showRentConfirm && !showRentSuccess}
  <div class="modal-overlay" on:click={closeRentModal} role="presentation"></div>
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="rent-modal-title">
    <h3 class="modal-title" id="rent-modal-title">Alquilar suite</h3>
    <p class="modal-text">
      Esta opción te permite alquilar la suite a una persona de confianza para que esta se encargue
      de inscribir los visitantes para el evento actual. Recuerda que una vez alquilada, no puedes
      modificar e inscribir visitantes.
    </p>
    <label class="modal-label" for="cedula-arrendatario">Cédula del arrendatario</label>
    <input
      id="cedula-arrendatario"
      class="modal-input"
      type="text"
      inputmode="numeric"
      placeholder="Ej: 1234567890"
      bind:value={cedulaArrendatario}
      maxlength={10}
    />
    {#if rentError}
      <p class="modal-error">{rentError}</p>
    {/if}
    <div class="modal-actions">
      <button class="modal-btn-secondary" type="button" on:click={closeRentModal}>Cancelar</button>
      <button class="modal-btn-primary" type="button" on:click={openRentConfirm}>Alquilar</button>
    </div>
  </div>
{/if}

<!-- ── Modal 2: Confirmar ─────────────────────────────────────────────── -->
{#if showRentConfirm}
  <div class="modal-overlay" role="presentation"></div>
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="rent-confirm-title">
    <h3 class="modal-title" id="rent-confirm-title">¿Está seguro?</h3>
    <p class="modal-text">
      ¿Está seguro que desea alquilar esta suite? Esta acción no se puede deshacer.
    </p>
    {#if rentError}
      <p class="modal-error">{rentError}</p>
    {/if}
    <div class="modal-actions">
      <button
        class="modal-btn-secondary"
        type="button"
        on:click={closeRentConfirm}
        disabled={isSubmittingRent}
      >No</button>
      <button
        class="modal-btn-primary"
        type="button"
        on:click={confirmRent}
        disabled={isSubmittingRent}
      >{isSubmittingRent ? 'Procesando...' : 'Sí'}</button>
    </div>
  </div>
{/if}

<!-- ── Modal 3: Éxito ─────────────────────────────────────────────────── -->
{#if showRentSuccess}
  <div class="modal-overlay" role="presentation"></div>
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="rent-success-title">
    <h3 class="modal-title modal-title-success" id="rent-success-title">¡Registro exitoso!</h3>
    <p class="modal-text">La suite ha sido alquilada correctamente.</p>
    <div class="modal-actions">
      <button class="modal-btn-primary" type="button" on:click={() => showRentSuccess = false}>
        Cerrar
      </button>
    </div>
  </div>
{/if}

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
    border: 1px solid var(--color-primary-light);
    background: linear-gradient(135deg, #022e2c 0%, #014040 100%);
    color: var(--color-text-main);
    cursor: pointer;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.55), 0 0 0 0 rgba(0, 153, 51, 0);
    transition:
      transform 0.15s ease,
      box-shadow 0.15s ease,
      border-color 0.15s ease;
    white-space: nowrap;
    text-align: left;
  }

  .btn-nav:hover {
    transform: translateY(-2px);
    border-color: #009933;
    box-shadow: 0 14px 32px rgba(0, 0, 0, 0.7), 0 0 0 3px rgba(0, 153, 51, 0.25);
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
    background: var(--color-primary-light);
    border-radius: 1rem;
    padding: 1rem 1.2rem;
    box-shadow: 0 12px 25px rgba(0, 0, 0, 0.5);
    border: 1px solid var(--color-primary);
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
    color: var(--color-success);
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
    color: var(--color-success);
  }

  .card-sub {
    font-size: 0.8rem;
    color: var(--color-text-muted);
    margin: 0.3rem 0 0 0;
  }

  .detail-panel {
    background: var(--color-surface);
    border-radius: 1rem;
    padding: 1rem 1.2rem;
    border: 1px solid var(--color-primary);
    box-shadow: 0 12px 25px rgba(0, 0, 0, 0.55);
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
    border-bottom: 1px solid var(--color-primary);
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

  /* ✅ valor de cupos en rojo cuando es 0 */
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
    gap: 0.6rem;
    flex-wrap: wrap;
  }

  .btn-secondary {
    padding: 0.5rem 1rem;
    border-radius: 999px;
    border: none;
    background: #009933;
    color: #f5fff8;
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 6px 18px rgba(0, 153, 51, 0.45);
    transition:
      transform 0.12s ease,
      background 0.12s ease,
      box-shadow 0.12s ease;
  }

  .btn-secondary:hover {
    transform: translateY(-1px);
    background: #00b33c;
    box-shadow: 0 10px 25px rgba(0, 153, 51, 0.65);
  }

  .btn-secondary:active {
    transform: translateY(0);
  }

  .btn-secondary.btn-rented {
    background: #7c3a00;
    color: #ffd199;
    box-shadow: 0 6px 18px rgba(180, 80, 0, 0.35);
    cursor: not-allowed;
    opacity: 0.85;
  }

  .btn-secondary.btn-rented:hover {
    transform: none;
    background: #7c3a00;
    box-shadow: 0 6px 18px rgba(180, 80, 0, 0.35);
  }

  .btn-primary {
    padding: 0.5rem 1rem;
    border-radius: 999px;
    border: none;
    background: var(--color-primary);
    color: var(--color-text-main);
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 10px 25px rgba(0, 51, 51, 0.6);
    transition:
      transform 0.12s ease,
      box-shadow 0.12s ease,
      background 0.12s ease;
  }

  /* ✅ solo hover cuando está habilitado */
  .btn-primary:hover:enabled {
    transform: translateY(-1px);
    box-shadow: 0 14px 30px rgba(0, 51, 51, 0.85);
    background: #009933;
  }

  .btn-primary:active:enabled {
    transform: translateY(0);
    box-shadow: 0 8px 18px rgba(0, 51, 51, 0.9);
  }

  .btn-primary:disabled {
    opacity: 0.55;
    cursor: not-allowed;
    box-shadow: 0 6px 15px rgba(0, 0, 0, 0.3);
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
    border: 1px solid var(--color-primary);
    box-shadow: 0 4px 10px rgba(0, 0, 0, 0.5);
    text-align: center;
  }

  .guest-id {
    font-size: 0.8rem;
    font-weight: 500;
    color: var(--color-success);
    letter-spacing: 0.02em;
  }

  /* ── Modal styles ──────────────────────────────────────────────────── */
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.55);
    z-index: 9998;
  }

  .modal {
    position: fixed;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
    width: min(520px, calc(100% - 2rem));
    background: var(--color-surface);
    border: 1px solid var(--color-primary);
    border-radius: 1rem;
    padding: 1.4rem 1.4rem 1.1rem;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.65);
    z-index: 9999;
  }

  .modal-title {
    margin: 0 0 0.75rem 0;
    font-size: 1.15rem;
    font-weight: 700;
    color: var(--color-success);
  }

  .modal-title-success {
    color: #4ade80;
  }

  .modal-text {
    margin: 0 0 1rem 0;
    color: #e6fff5;
    font-size: 0.95rem;
    line-height: 1.5;
  }

  .modal-label {
    display: block;
    font-size: 0.85rem;
    color: var(--color-success);
    margin-bottom: 0.35rem;
  }

  .modal-input {
    width: 100%;
    padding: 0.6rem 0.85rem;
    border-radius: 0.6rem;
    border: 1px solid var(--color-primary);
    background: #012e2e;
    color: var(--color-text-main);
    font-size: 1rem;
    outline: none;
    box-sizing: border-box;
    transition: border-color 0.15s ease;
  }

  .modal-input:focus {
    border-color: #009933;
  }

  .modal-error {
    margin: 0.45rem 0 0 0;
    font-size: 0.85rem;
    color: #ff6b6b;
  }

  .modal-actions {
    display: flex;
    gap: 0.75rem;
    margin-top: 1rem;
    justify-content: flex-end;
  }

  .modal-btn-primary {
    padding: 0.55rem 1.3rem;
    border-radius: 999px;
    border: none;
    background: var(--color-primary);
    color: var(--color-text-main);
    font-size: 0.95rem;
    font-weight: 700;
    cursor: pointer;
    transition: background 0.12s ease, transform 0.12s ease;
  }

  .modal-btn-primary:hover:enabled {
    background: #009933;
    transform: translateY(-1px);
  }

  .modal-btn-primary:disabled {
    opacity: 0.55;
    cursor: not-allowed;
  }

  .modal-btn-secondary {
    padding: 0.55rem 1.3rem;
    border-radius: 999px;
    border: 1px solid var(--color-primary);
    background: transparent;
    color: var(--color-success);
    font-size: 0.95rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.12s ease;
  }

  .modal-btn-secondary:hover:enabled {
    background: rgba(1, 64, 64, 0.6);
  }

  .modal-btn-secondary:disabled {
    opacity: 0.55;
    cursor: not-allowed;
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