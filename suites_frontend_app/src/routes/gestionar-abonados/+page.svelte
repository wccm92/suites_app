<script lang="ts">
  import { goto } from "$app/navigation";
  import { base } from "$app/paths";
  import { page } from "$app/stores";
  import { onMount } from "svelte";
  import { get } from "svelte/store";
  import { browser } from "$app/environment";
  import { apiFetch } from "$lib/api/client";
  import { session } from "$lib/stores/session";

  // ── Suite param (desde la query string) ───────────────────────────────
  let suiteId = "";
  $: suiteId = $page.url.searchParams.get("id_suite") ?? "";

  // ── Estado del listado de abonados ────────────────────────────────────
  let abonados: string[] = [];
  let loading = true;
  let loadError = "";

  // Selección para borrado múltiple
  let selected = new Set<string>();
  $: allSelected = abonados.length > 0 && selected.size === abonados.length;

  // ── Registro (uno a uno) ──────────────────────────────────────────────
  let nuevaCedula = "";
  let registerError = "";
  let registrando = false;

  // ── Borrado múltiple ──────────────────────────────────────────────────
  let deleting = false;
  let confirmDeleteOpen = false;

  // ── Modal genérico de mensaje (título + Aceptar) ──────────────────────
  let msgOpen = false;
  let msgText = "";
  let msgSuccess = false;
  let msgOnAccept: (() => void) | null = null;

  function showMessage(
    text: string,
    success = false,
    onAccept: (() => void) | null = null
  ) {
    msgText = text;
    msgSuccess = success;
    msgOnAccept = onAccept;
    msgOpen = true;
  }

  function acceptMessage() {
    msgOpen = false;
    const cb = msgOnAccept;
    msgOnAccept = null;
    if (cb) cb();
  }

  // ── Modal de resumen de borrado ───────────────────────────────────────
  let resultOpen = false;
  let resultDeleted: string[] = [];

  // ── Navegación / sesión ───────────────────────────────────────────────
  function getHomeRoute(): string {
    const profile = session.getProfile();
    if (profile === "leaseholder") return `${base}/arriendos`;
    return `${base}/`;
  }

  function handleBack() {
    const qs = new URLSearchParams({ id_suite: suiteId });
    goto(`${base}/gestionar-suites?${qs.toString()}`);
  }

  async function handleUnauthorized() {
    session.clear();
    await goto(`${base}/login`);
  }

  async function handleNoEvent() {
    session.clear();
    await goto(`${base}/no-event`);
  }

  /**
   * Manejo compartido de respuestas de error (401 / 404) para las APIs de
   * abonados. Devuelve true si ya gestionó la respuesta (redirigió o mostró
   * un aviso) y el llamador debe detenerse.
   *
   * - 401 (código 04 sesión no válida / 09 perfil inválido) → limpiar + /login
   * - 404 código 03 (sin eventos)                           → limpiar + /no-event
   * - 404 código 10/11 (u otro)                             → modal de aviso con `detail`
   */
  async function handleErrorResponse(res: Response): Promise<boolean> {
    if (res.status === 401) {
      await handleUnauthorized();
      return true;
    }
    if (res.status === 404) {
      const body = (await res.json().catch(() => ({}))) as {
        errors?: { detail?: string; code?: string }[];
      };
      const first = body?.errors?.[0];
      if (first?.code === "03") {
        await handleNoEvent();
        return true;
      }
      showMessage(first?.detail ?? "Recurso no encontrado.");
      return true;
    }
    return false;
  }

  // ── Carga del listado de abonados ─────────────────────────────────────
  async function loadAbonados() {
    if (!browser || !suiteId) return;
    loading = true;
    loadError = "";
    try {
      const res = await apiFetch(
        `/suites_app/get_season_ticket_holders/${suiteId}`
      );

      if (res.status === 401) {
        await handleUnauthorized();
        return;
      }
      if (res.status === 404) {
        await handleNoEvent();
        return;
      }
      if (!res.ok) {
        loadError = "No se pudo obtener el listado de abonados.";
        return;
      }

      const body = (await res.json().catch(() => ({}))) as {
        abonados?: { id_abonado: string }[];
      };
      abonados = (body?.abonados ?? [])
        .map((a) => a?.id_abonado)
        .filter((id): id is string => typeof id === "string");
      selected = new Set();
    } catch (e) {
      loadError =
        (e as Error).message ?? "Error inesperado al cargar los abonados.";
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    const { jwt } = get(session);
    if (!jwt) {
      goto(`${base}/login`);
      return;
    }
    // Segunda capa de defensa: la pantalla es exclusiva de propietarios
    if (session.getProfile() !== "owner") {
      goto(getHomeRoute());
      return;
    }
    loadAbonados();
  });

  // ── Acción: Registrar abonado (uno a uno) ─────────────────────────────
  async function registrarAbonado() {
    if (registrando) return;
    const cedula = nuevaCedula.trim();
    if (!/^\d{6,10}$/.test(cedula)) {
      registerError = "Ingresa una cédula válida (6 a 10 dígitos).";
      return;
    }

    registrando = true;
    registerError = "";
    try {
      const res = await apiFetch("/suites_app/register_season_ticket_holder", {
        method: "POST",
        body: JSON.stringify({
          id_suite: suiteId,
          id_season_ticket_holder: cedula,
        }),
      });

      if (await handleErrorResponse(res)) return;

      if (!res.ok) {
        registerError = "No se pudo registrar el abonado.";
        return;
      }

      // Éxito: status 200 y sin valor "error" en el body.detail
      const body = (await res.json().catch(() => ({}))) as { detail?: unknown };
      const detailStr = String(body?.detail ?? "").toLowerCase();
      if (detailStr.includes("error")) {
        showMessage(
          typeof body?.detail === "string"
            ? (body.detail as string)
            : "No se pudo registrar el abonado."
        );
        return;
      }

      nuevaCedula = "";
      showMessage("Abonado registrado exitosamente", true, () => loadAbonados());
    } catch {
      registerError = "Error inesperado al registrar el abonado.";
    } finally {
      registrando = false;
    }
  }

  // ── Selección múltiple ────────────────────────────────────────────────
  function toggleSelect(id: string) {
    const next = new Set(selected);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    selected = next;
  }

  function toggleSelectAll() {
    selected = allSelected ? new Set() : new Set(abonados);
  }

  // ── Acción: Eliminar seleccionados (borrado múltiple) ─────────────────
  function openConfirmDelete() {
    if (selected.size === 0) return;
    confirmDeleteOpen = true;
  }

  function cancelConfirmDelete() {
    confirmDeleteOpen = false;
  }

  async function confirmDelete() {
    confirmDeleteOpen = false;
    if (deleting || selected.size === 0) return;

    deleting = true;
    try {
      const holders = Array.from(selected);
      const res = await apiFetch("/suites_app/delete_season_ticket_holders", {
        method: "POST",
        body: JSON.stringify({
          id_suite: suiteId,
          season_ticket_holders: holders,
        }),
      });

      if (await handleErrorResponse(res)) return;

      if (!res.ok) {
        showMessage("No se pudieron eliminar los abonados.");
        return;
      }

      const body = (await res.json().catch(() => ({}))) as {
        successful_deleted_season_ticket_holders?: string[];
      };
      resultDeleted = body?.successful_deleted_season_ticket_holders ?? holders;
      resultOpen = true;
    } catch {
      showMessage("Error inesperado al eliminar los abonados.");
    } finally {
      deleting = false;
    }
  }

  function acceptResult() {
    resultOpen = false;
    loadAbonados();
  }
</script>

<svelte:head>
  <title>Gestionar abonados</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <section class="form-container">
    <div class="step-heading">
      <h1 class="step-title">Gestionar abonados</h1>
    </div>

    <!-- ── Suite meta ─────────────────────────────────────────────────── -->
    <div class="suite-meta">
      <span class="suite-id-label">Suite: <strong>{suiteId || "—"}</strong></span>
      <div class="suite-stats">
        <span class="stat-pill">
          Abonados: <strong>{loading ? "…" : abonados.length}</strong>
        </span>
      </div>
    </div>

    <!-- ── Registrar abonado ──────────────────────────────────────────── -->
    <div class="register-block">
      <span class="block-title">Registrar abonado</span>
      <p class="block-hint">
        Los abonados son visitantes fijos que siempre estarán presentes en la suite.
      </p>
      <form class="register-row" on:submit|preventDefault={registrarAbonado}>
        <input
          class="register-input"
          type="text"
          inputmode="numeric"
          placeholder="Cédula del abonado (Ej: 1047451430)"
          bind:value={nuevaCedula}
          maxlength={10}
          disabled={registrando}
        />
        <button class="btn-registrar" type="submit" disabled={registrando}>
          {#if registrando}
            Registrando…
          {:else}
            <svg
              class="btn-registrar__icon"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <line x1="12" y1="5" x2="12" y2="19" />
              <line x1="5" y1="12" x2="19" y2="12" />
            </svg>
            Registrar
          {/if}
        </button>
      </form>
      {#if registerError}
        <p class="register-error">{registerError}</p>
      {/if}
    </div>

    <!-- ── Listado de abonados ────────────────────────────────────────── -->
    <div class="list-block">
      <div class="list-head">
        <span class="block-title">Abonados de la suite</span>
        {#if !loading && !loadError && abonados.length > 0}
          <div class="list-head-actions">
            <button type="button" class="btn-select-all" on:click={toggleSelectAll}>
              {allSelected ? "Quitar selección" : "Seleccionar todos"}
            </button>
            <button
              type="button"
              class="btn-eliminar"
              on:click={openConfirmDelete}
              disabled={selected.size === 0 || deleting}
            >
              {deleting ? "Eliminando…" : `Eliminar (${selected.size})`}
            </button>
          </div>
        {/if}
      </div>

      {#if loading}
        <p class="state-text">Cargando abonados…</p>
      {:else if loadError}
        <p class="state-text state-text--error">{loadError}</p>
      {:else if abonados.length === 0}
        <p class="state-text">Esta suite no tiene abonados registrados.</p>
      {:else}
        <div class="abonados-grid">
          {#each abonados as ab (ab)}
            <label class="abonado-pill {selected.has(ab) ? 'is-selected' : ''}">
              <input
                type="checkbox"
                class="abonado-check"
                checked={selected.has(ab)}
                on:change={() => toggleSelect(ab)}
              />
              <span class="abonado-id">{ab}</span>
            </label>
          {/each}
        </div>
      {/if}
    </div>

    <div class="step-actions">
      <button type="button" class="btn-back" on:click={handleBack}>
        Volver
      </button>
    </div>
  </section>
</main>

<!-- ── Modal: Confirmar eliminación ───────────────────────────────────── -->
{#if confirmDeleteOpen}
  <div class="modal-overlay" on:click={cancelConfirmDelete} role="presentation"></div>
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="confirm-delete-title">
    <h3 class="modal-title" id="confirm-delete-title">Eliminar abonados</h3>
    <p class="modal-text">
      ¿Deseas eliminar
      <strong>{selected.size}</strong>
      {selected.size === 1 ? "abonado" : "abonados"} de esta suite?
    </p>
    <div class="modal-actions">
      <button class="modal-btn-secondary" type="button" on:click={cancelConfirmDelete}>
        Cancelar
      </button>
      <button class="modal-btn-danger" type="button" on:click={confirmDelete}>
        Eliminar
      </button>
    </div>
  </div>
{/if}

<!-- ── Modal: Resumen de eliminación ──────────────────────────────────── -->
{#if resultOpen}
  <div class="modal-overlay" role="presentation"></div>
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="result-title">
    <h3 class="modal-title modal-title-success" id="result-title">Listo</h3>
    <p class="modal-text">
      Se {resultDeleted.length === 1 ? "eliminó" : "eliminaron"}
      <strong>{resultDeleted.length}</strong>
      {resultDeleted.length === 1 ? "abonado" : "abonados"}:
    </p>
    <div class="result-grid">
      {#each resultDeleted as id}
        <span class="result-pill">{id}</span>
      {/each}
    </div>
    <div class="modal-actions">
      <button class="modal-btn-primary" type="button" on:click={acceptResult}>
        Aceptar
      </button>
    </div>
  </div>
{/if}

<!-- ── Modal: Mensaje genérico ────────────────────────────────────────── -->
{#if msgOpen}
  <div class="modal-overlay" role="presentation"></div>
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="msg-modal-title">
    <h3 class="modal-title {msgSuccess ? 'modal-title-success' : ''}" id="msg-modal-title">
      {msgSuccess ? "Listo" : "Aviso"}
    </h3>
    <p class="modal-text">{msgText}</p>
    <div class="modal-actions">
      <button class="modal-btn-primary" type="button" on:click={acceptMessage}>
        Aceptar
      </button>
    </div>
  </div>
{/if}

<style>
  .form-container {
    width: min(820px, 100%);
    margin: 0 auto;
    padding: 1.5rem 1.6rem 1.8rem;
    display: flex;
    flex-direction: column;
    gap: 1.2rem;
  }

  .step-heading {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.75rem;
  }

  .step-title {
    margin: 0;
    font-size: clamp(1.3rem, 1.05rem + 1vw, 1.7rem);
    font-weight: 700;
    color: var(--color-text-main);
  }

  /* ── Suite meta ───────────────────────────────────────────────────── */
  .suite-meta {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: 0.6rem;
    padding: 0.75rem 0.9rem;
    background: #edf7f2;
    border: 1px solid #c8e6d8;
    border-radius: var(--radius-lg);
  }

  .suite-id-label {
    font-size: 0.95rem;
    color: var(--color-text-main);
  }

  .suite-stats {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .stat-pill {
    display: inline-flex;
    align-items: center;
    padding: 0.3rem 0.8rem;
    border-radius: 999px;
    background: #ffffff;
    border: 1px solid #c0ddd4;
    font-size: 0.85rem;
    color: var(--color-text-muted);
  }

  .stat-pill strong {
    margin-left: 0.3rem;
    color: var(--color-text-main);
    font-weight: 700;
  }

  /* ── Bloques ──────────────────────────────────────────────────────── */
  .block-title {
    font-size: 1rem;
    font-weight: 700;
    color: var(--color-success);
  }

  .block-hint {
    margin: 0.3rem 0 0.7rem 0;
    font-size: 0.85rem;
    line-height: 1.4;
    color: var(--color-text-muted);
  }

  .register-block {
    display: flex;
    flex-direction: column;
    padding: 1rem 1.1rem 1.1rem;
    border: 1px solid #d1e8e0;
    border-radius: var(--radius-lg);
    background: #ffffff;
  }

  .register-row {
    display: flex;
    gap: 0.6rem;
    align-items: stretch;
  }

  .register-input {
    flex: 1;
    min-width: 0;
    padding: 0.6rem 0.85rem;
    border-radius: 0.6rem;
    border: 1px solid #c0ddd4;
    background: #f5faf7;
    color: var(--color-text-main);
    font-size: 1rem;
    outline: none;
    transition: border-color 0.15s ease;
  }

  .register-input:focus {
    border-color: var(--color-primary);
  }

  .register-input:disabled {
    opacity: 0.6;
  }

  .btn-registrar {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.55rem 1.2rem;
    border-radius: 999px;
    border: none;
    background: var(--color-primary);
    color: #ffffff;
    font-size: 0.9rem;
    font-weight: 700;
    cursor: pointer;
    white-space: nowrap;
    box-shadow: 0 4px 12px rgba(0, 89, 64, 0.28);
    transition: background 0.12s ease, transform 0.12s ease;
  }

  .btn-registrar__icon {
    width: 1.05em;
    height: 1.05em;
    flex-shrink: 0;
  }

  .btn-registrar:hover:enabled {
    background: #009933;
    transform: translateY(-1px);
  }

  .btn-registrar:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .register-error {
    margin: 0.5rem 0 0 0;
    font-size: 0.85rem;
    color: var(--color-error);
  }

  /* ── Listado ──────────────────────────────────────────────────────── */
  .list-block {
    display: flex;
    flex-direction: column;
    gap: 0.8rem;
  }

  .list-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 0.6rem;
  }

  .list-head-actions {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .btn-select-all {
    padding: 0.4rem 0.9rem;
    border-radius: 999px;
    border: 1px solid #c0ddd4;
    background: #ffffff;
    color: var(--color-primary);
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.12s ease, border-color 0.12s ease;
  }

  .btn-select-all:hover {
    background: #edf7f2;
    border-color: var(--color-primary);
  }

  .btn-eliminar {
    padding: 0.4rem 0.9rem;
    border-radius: 999px;
    border: 1px solid var(--color-error-soft);
    background: #fff5f5;
    color: var(--color-error);
    font-size: 0.85rem;
    font-weight: 700;
    cursor: pointer;
    white-space: nowrap;
    transition: background 0.12s ease, transform 0.12s ease;
  }

  .btn-eliminar:hover:enabled {
    background: #ffe9e9;
    transform: translateY(-1px);
  }

  .btn-eliminar:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .state-text {
    margin: 0.5rem 0;
    text-align: center;
    font-size: 0.95rem;
    color: var(--color-text-muted);
  }

  .state-text--error {
    color: var(--color-error);
  }

  .abonados-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
    gap: 0.6rem;
  }

  .abonado-pill {
    display: flex;
    align-items: center;
    gap: 0.55rem;
    padding: 0.55rem 0.85rem;
    border-radius: 999px;
    border: 1px solid #9bd3b8;
    background: #edf7f2;
    cursor: pointer;
    transition: background 0.12s ease, border-color 0.12s ease, box-shadow 0.12s ease;
  }

  .abonado-pill:hover {
    border-color: var(--color-primary);
  }

  .abonado-pill.is-selected {
    background: #d6efe1;
    border-color: var(--color-primary);
    box-shadow: 0 0 0 1px var(--color-primary) inset;
  }

  .abonado-check {
    width: 1.05rem;
    height: 1.05rem;
    flex-shrink: 0;
    accent-color: var(--color-primary);
    cursor: pointer;
  }

  .abonado-id {
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--color-primary);
    font-variant-numeric: tabular-nums;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* ── Acciones ─────────────────────────────────────────────────────── */
  .step-actions {
    display: flex;
    justify-content: flex-start;
  }

  .btn-back {
    padding: 0.5rem 1.3rem;
    border-radius: var(--radius-pill);
    border: 1px solid #c0ddd4;
    background: #ffffff;
    color: var(--color-primary);
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.12s ease, border-color 0.12s ease;
  }

  .btn-back:hover {
    background: #edf7f2;
    border-color: var(--color-primary);
  }

  /* ── Modales ──────────────────────────────────────────────────────── */
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.3);
    z-index: 9998;
    backdrop-filter: blur(2px);
  }

  .modal {
    position: fixed;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
    width: min(520px, calc(100% - 2rem));
    background: #ffffff;
    border: 1px solid #d1e8e0;
    border-radius: 1rem;
    padding: 1.4rem 1.4rem 1.1rem;
    box-shadow: 0 10px 40px rgba(0, 89, 64, 0.18);
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
    color: var(--color-text-main);
    font-size: 0.95rem;
    line-height: 1.5;
  }

  .result-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
    gap: 0.45rem;
    margin: 0 0 0.5rem 0;
    max-height: 220px;
    overflow-y: auto;
  }

  .result-pill {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0.35rem 0.6rem;
    border-radius: 999px;
    background: #edf7f2;
    border: 1px solid #9bd3b8;
    font-size: 0.82rem;
    font-weight: 600;
    color: var(--color-primary);
    font-variant-numeric: tabular-nums;
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
    color: #ffffff;
    font-size: 0.95rem;
    font-weight: 700;
    cursor: pointer;
    transition: background 0.12s ease, transform 0.12s ease;
  }

  .modal-btn-primary:hover:enabled {
    background: #009933;
    transform: translateY(-1px);
  }

  .modal-btn-secondary {
    padding: 0.55rem 1.3rem;
    border-radius: 999px;
    border: 1px solid #c0ddd4;
    background: transparent;
    color: var(--color-primary);
    font-size: 0.95rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.12s ease, border-color 0.12s ease;
  }

  .modal-btn-secondary:hover:enabled {
    background: #edf7f2;
    border-color: var(--color-primary);
  }

  .modal-btn-danger {
    padding: 0.55rem 1.3rem;
    border-radius: 999px;
    border: 1px solid var(--color-error-soft);
    background: #fff5f5;
    color: var(--color-error);
    font-size: 0.95rem;
    font-weight: 700;
    cursor: pointer;
    transition: background 0.12s ease, transform 0.12s ease;
  }

  .modal-btn-danger:hover:enabled {
    background: #ffe9e9;
    transform: translateY(-1px);
  }

  /* ── Responsive ───────────────────────────────────────────────────── */
  @media (max-width: 768px) {
    .form-container {
      padding: 1.2rem 1rem 1.4rem;
    }

    .suite-meta {
      flex-direction: column;
      align-items: flex-start;
    }

    .register-row {
      flex-direction: column;
    }

    .btn-registrar {
      width: 100%;
      justify-content: center;
    }

    .list-head {
      flex-direction: column;
      align-items: flex-start;
    }

    .list-head-actions {
      width: 100%;
    }

    .btn-select-all,
    .btn-eliminar {
      flex: 1;
      text-align: center;
    }

    .abonados-grid {
      grid-template-columns: 1fr;
    }

    .step-actions {
      justify-content: stretch;
    }

    .btn-back {
      width: 100%;
      text-align: center;
    }
  }
</style>
