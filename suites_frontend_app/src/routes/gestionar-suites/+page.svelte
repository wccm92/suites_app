<script lang="ts">
  import { goto } from "$app/navigation";
  import { base } from "$app/paths";
  import { page } from "$app/stores";
  import { onMount } from "svelte";
  import { get } from "svelte/store";
  import { browser } from "$app/environment";
  import { apiFetch } from "$lib/api/client";
  import { session } from "$lib/stores/session";
  import { isSuiteDetail, isSuiteDetailError } from "$lib/api/guards";
  import type { SuiteDetail } from "$lib/api/types";

  // ── Suite params (desde la query string) ──────────────────────────────
  let suiteId = "";
  let capacidadParam = 0;
  let cuposParam = 0;

  $: suiteId = $page.url.searchParams.get("id_suite") ?? "";
  $: capacidadParam = Number($page.url.searchParams.get("capacidad") ?? "0");
  $: cuposParam = Number($page.url.searchParams.get("cupos_disponibles") ?? "0");

  // ── Estado del detalle de la suite ────────────────────────────────────
  let suiteDetail: SuiteDetail | null = null;
  let loading = true;
  let loadError = "";
  let processing = false; // deshabilita acciones mientras hay una petición en curso

  // Valores mostrados: los frescos del backend si ya cargó, si no los del query
  $: capacidadShown = suiteDetail?.capacidad ?? capacidadParam;
  $: cuposShown = suiteDetail?.cupos_disponibles ?? Math.max(0, cuposParam);

  // Filas: cada adulto (cédula sin '0' inicial) alineado con su amparado ('0' + cédula)
  $: guests = suiteDetail?.invitados_inscritos ?? [];
  $: amparadosSet = new Set(guests.filter((g) => g.startsWith("0")));
  $: rows = guests
    .filter((g) => !g.startsWith("0"))
    .map((adulto) => ({
      adulto,
      amparado: amparadosSet.has(`0${adulto}`) ? `0${adulto}` : null,
    }));

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

  // ── Modal de reemplazo ────────────────────────────────────────────────
  let replaceOpen = false;
  let replaceAdulto = "";
  let nuevaCedula = "";
  let replaceError = "";
  let replaceSubmitting = false;

  // ── Modal "¿Registrar amparados?" ─────────────────────────────────────
  let amparadoPromptOpen = false;
  let amparadoNuevoInvitado = "";

  // ── Navegación / sesión ───────────────────────────────────────────────
  function getHomeRoute(): string {
    const { jwt } = get(session);
    if (!jwt) return `${base}/`;
    try {
      const payload = JSON.parse(atob(jwt.split(".")[1]));
      if (payload?.profile === "leaseholder") return `${base}/arriendos`;
    } catch {}
    return `${base}/`;
  }

  function handleBack() {
    goto(getHomeRoute());
  }

  async function handleUnauthorized() {
    session.clear();
    await goto(`${base}/login`);
  }

  async function handleNotFound() {
    session.clear();
    await goto(`${base}/no-event`);
  }

  // ── Carga del detalle de la suite ─────────────────────────────────────
  async function loadSuite() {
    if (!browser || !suiteId) return;
    loading = true;
    loadError = "";
    try {
      const res = await apiFetch(`/suites_app/suites/${suiteId}`);

      if (res.status === 401) {
        await handleUnauthorized();
        return;
      }
      if (res.status === 404) {
        session.clear();
        await goto(`${base}/no-event`);
        return;
      }
      if (!res.ok) {
        loadError = "No se pudo obtener el detalle de la suite.";
        return;
      }

      const body = (await res.json()) as unknown;
      if (isSuiteDetailError(body)) {
        loadError = body.errors[0]?.detail ?? "Error al consultar la suite.";
        return;
      }
      if (isSuiteDetail(body)) {
        suiteDetail = body;
      } else {
        loadError = "Respuesta inesperada del servidor.";
      }
    } catch (e) {
      loadError = (e as Error).message ?? "Error inesperado al cargar la suite.";
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
    loadSuite();
  });

  // ── Acción: Quitar (delete_guest) ─────────────────────────────────────
  async function quitarInvitado(adulto: string) {
    if (processing) return;
    processing = true;
    try {
      const res = await apiFetch("/suites_app/delete_guest", {
        method: "POST",
        body: JSON.stringify({ id_suite: suiteId, invitado: adulto }),
      });

      if (res.status === 401) {
        await handleUnauthorized();
        return;
      }
      if (res.status === 404) {
        await handleNotFound();
        return;
      }

      const body = (await res.json().catch(() => ({}))) as {
        title?: string;
        detail?: string;
      };

      if (body?.title === "error") {
        showMessage(body.detail ?? "Ocurrió un error.");
        return;
      }

      showMessage("Visitante eliminado exitosamente", true, () => loadSuite());
    } catch {
      showMessage("Error inesperado al eliminar el visitante.");
    } finally {
      processing = false;
    }
  }

  // ── Acción: Reemplazar (replace_guest) ────────────────────────────────
  function openReplace(adulto: string) {
    replaceAdulto = adulto;
    nuevaCedula = "";
    replaceError = "";
    replaceOpen = true;
  }

  function cancelReplace() {
    replaceOpen = false;
    replaceError = "";
  }

  async function confirmReplace() {
    const cedula = nuevaCedula.trim();
    if (!/^\d{6,10}$/.test(cedula)) {
      replaceError = "Ingresa una cédula válida (6 a 10 dígitos).";
      return;
    }

    replaceSubmitting = true;
    replaceError = "";
    try {
      const res = await apiFetch("/suites_app/replace_guest", {
        method: "POST",
        body: JSON.stringify({
          id_suite: suiteId,
          invitado: replaceAdulto,
          nuevo_invitado: cedula,
        }),
      });

      if (res.status === 401) {
        await handleUnauthorized();
        return;
      }
      if (res.status === 404) {
        replaceOpen = false;
        await handleNotFound();
        return;
      }

      const body = (await res.json().catch(() => ({}))) as {
        title?: string;
        detail?: string;
      };

      if (body?.title === "error") {
        replaceOpen = false;
        showMessage(body.detail ?? "Ocurrió un error.");
        return;
      }

      // Éxito: cerrar modal de reemplazo, mostrar éxito y luego preguntar por amparados
      replaceOpen = false;
      showMessage("Visitante reemplazado exitosamente", true, () =>
        openAmparadoPrompt(cedula)
      );
    } catch {
      replaceError = "Error inesperado al reemplazar el visitante.";
    } finally {
      replaceSubmitting = false;
    }
  }

  // ── Flujo: ¿Registrar amparados? (register_amparado) ──────────────────
  function openAmparadoPrompt(nuevoInvitado: string) {
    amparadoNuevoInvitado = nuevoInvitado;
    amparadoPromptOpen = true;
  }

  function declineAmparado() {
    amparadoPromptOpen = false;
    loadSuite();
  }

  async function acceptAmparado() {
    amparadoPromptOpen = false;
    const amparado = `0${amparadoNuevoInvitado}`;
    processing = true;
    try {
      const res = await apiFetch("/suites_app/register_amparado", {
        method: "POST",
        body: JSON.stringify({ id_suite: suiteId, amparado }),
      });

      if (res.status === 401) {
        await handleUnauthorized();
        return;
      }
      if (res.status === 404) {
        await handleNotFound();
        return;
      }

      const body = (await res.json().catch(() => ({}))) as {
        title?: string;
        detail?: string;
      };

      if (body?.title === "error") {
        showMessage(body.detail ?? "Ocurrió un error.", false, () => loadSuite());
        return;
      }

      showMessage("Amparado registrado exitosamente", true, () => loadSuite());
    } catch {
      showMessage("Error inesperado al registrar el amparado.", false, () =>
        loadSuite()
      );
    } finally {
      processing = false;
    }
  }
</script>

<svelte:head>
  <title>Gestionar suite</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <section class="form-container">
    <div class="step-heading">
      <h1 class="step-title">Gestionar suite</h1>
    </div>

    <!-- ── Suite meta ─────────────────────────────────────────────────── -->
    <div class="suite-meta">
      <span class="suite-id-label">Suite: <strong>{suiteId || "—"}</strong></span>
      <div class="suite-stats">
        <span class="stat-pill">
          Capacidad: <strong>{capacidadShown}</strong>
        </span>
        <span class="stat-pill {cuposShown === 0 ? 'stat-pill--zero' : ''}">
          Cupos disponibles: <strong>{cuposShown}</strong>
        </span>
      </div>
    </div>

    <!-- ── Listado de invitados ───────────────────────────────────────── -->
    {#if loading}
      <p class="state-text">Cargando visitantes…</p>
    {:else if loadError}
      <p class="state-text state-text--error">{loadError}</p>
    {:else if rows.length === 0}
      <p class="state-text">Esta suite no tiene visitantes inscritos.</p>
    {:else}
      <div class="guests">
        <div class="guests-head">
          <span class="col-head col-head--adulto">Adultos</span>
          <span class="col-head col-head--amparado">Amparados</span>
          <span class="col-head col-head--actions" aria-hidden="true"></span>
        </div>

        {#each rows as row (row.adulto)}
          <div class="guest-row">
            <div class="cell cell--adulto">
              <span class="cell-label">Adulto</span>
              <span class="pill pill--adulto">{row.adulto}</span>
            </div>

            <div class="cell cell--amparado {row.amparado ? '' : 'cell--empty'}">
              {#if row.amparado}
                <span class="cell-label">Amparado</span>
                <span class="pill pill--amparado">{row.amparado}</span>
              {/if}
            </div>

            <div class="cell cell--actions">
              <button
                type="button"
                class="btn-quitar"
                on:click={() => quitarInvitado(row.adulto)}
                disabled={processing}
              >
                Quitar
              </button>
              <button
                type="button"
                class="btn-reemplazar"
                on:click={() => openReplace(row.adulto)}
                disabled={processing}
              >
                Reemplazar
              </button>
            </div>
          </div>
        {/each}
      </div>
    {/if}

    <div class="step-actions">
      <button type="button" class="btn-back" on:click={handleBack}>
        Volver
      </button>
    </div>
  </section>
</main>

<!-- ── Modal: Reemplazar visitante ────────────────────────────────────── -->
{#if replaceOpen}
  <div class="modal-overlay" on:click={cancelReplace} role="presentation"></div>
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="replace-modal-title">
    <h3 class="modal-title" id="replace-modal-title">Reemplazar visitante</h3>
    <p class="modal-text">
      Ingresa la cédula del nuevo visitante que reemplazará a
      <strong>{replaceAdulto}</strong>.
    </p>
    <label class="modal-label" for="nueva-cedula">Nueva cédula</label>
    <input
      id="nueva-cedula"
      class="modal-input"
      type="text"
      inputmode="numeric"
      placeholder="Ej: 1234567890"
      bind:value={nuevaCedula}
      maxlength={10}
    />
    {#if replaceError}
      <p class="modal-error">{replaceError}</p>
    {/if}
    <div class="modal-actions">
      <button
        class="modal-btn-secondary"
        type="button"
        on:click={cancelReplace}
        disabled={replaceSubmitting}
      >
        Cancelar
      </button>
      <button
        class="modal-btn-primary"
        type="button"
        on:click={confirmReplace}
        disabled={replaceSubmitting}
      >
        {replaceSubmitting ? "Procesando…" : "Reemplazar"}
      </button>
    </div>
  </div>
{/if}

<!-- ── Modal: ¿Registrar amparados? ───────────────────────────────────── -->
{#if amparadoPromptOpen}
  <div class="modal-overlay" role="presentation"></div>
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="amparado-prompt-title">
    <h3 class="modal-title" id="amparado-prompt-title">Registrar amparados</h3>
    <p class="modal-text">
      ¿Deseas registrar amparados para este nuevo visitante?
    </p>
    <div class="modal-actions">
      <button class="modal-btn-secondary" type="button" on:click={declineAmparado}>
        No
      </button>
      <button class="modal-btn-primary" type="button" on:click={acceptAmparado}>
        Sí
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

  .stat-pill--zero {
    background: #fff5f5;
    border-color: var(--color-error-soft);
    color: var(--color-error);
  }

  .stat-pill--zero strong {
    color: var(--color-error);
  }

  /* ── Estados ──────────────────────────────────────────────────────── */
  .state-text {
    margin: 0.5rem 0;
    text-align: center;
    font-size: 0.95rem;
    color: var(--color-text-muted);
  }

  .state-text--error {
    color: var(--color-error);
  }

  /* ── Listado de invitados ─────────────────────────────────────────── */
  .guests {
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
  }

  .guests-head,
  .guest-row {
    display: grid;
    /* La 3ª columna (acciones) va con ancho fijo para que sea idéntica en el
       encabezado y en las filas; así las dos columnas 1fr (Adultos/Amparados)
       se alinean verticalmente con sus respectivos encabezados. */
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) 14rem;
    align-items: center;
    gap: 0.75rem;
  }

  .guests-head {
    padding: 0 0.9rem;
  }

  .col-head {
    font-size: 0.9rem;
    font-weight: 700;
    text-align: center;
  }

  .col-head--adulto {
    color: var(--color-primary-light);
  }

  .col-head--amparado {
    color: var(--color-accent);
  }

  .guest-row {
    padding: 0.6rem 0.9rem;
    border: 1px dashed #c8d8d0;
    border-radius: var(--radius-lg);
    background: #fbfefc;
  }

  .cell {
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 0;
  }

  .cell--actions {
    justify-content: flex-end;
    gap: 0.5rem;
  }

  .cell-label {
    display: none;
  }

  .pill {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    max-width: 100%;
    padding: 0.4rem 0.9rem;
    border-radius: 999px;
    font-size: 0.9rem;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .pill--adulto {
    background: #edf7f2;
    border: 1px solid #9bd3b8;
    color: var(--color-primary);
  }

  .pill--amparado {
    background: #fdf3e7;
    border: 1px solid #e6b980;
    color: #b3701a;
  }

  .btn-quitar,
  .btn-reemplazar {
    padding: 0.4rem 0.9rem;
    border-radius: 999px;
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
    transition:
      background 0.12s ease,
      border-color 0.12s ease,
      transform 0.12s ease;
  }

  .btn-quitar {
    border: 1px solid var(--color-error-soft);
    background: #fff5f5;
    color: var(--color-error);
  }

  .btn-quitar:hover:enabled {
    background: #ffe9e9;
    transform: translateY(-1px);
  }

  .btn-reemplazar {
    border: 1px solid #c0ddd4;
    background: #ffffff;
    color: var(--color-primary);
  }

  .btn-reemplazar:hover:enabled {
    background: #edf7f2;
    border-color: var(--color-primary);
    transform: translateY(-1px);
  }

  .btn-quitar:disabled,
  .btn-reemplazar:disabled {
    opacity: 0.5;
    cursor: not-allowed;
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
    transition:
      background 0.12s ease,
      border-color 0.12s ease;
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
    border: 1px solid #c0ddd4;
    background: #f5faf7;
    color: var(--color-text-main);
    font-size: 1rem;
    outline: none;
    box-sizing: border-box;
    transition: border-color 0.15s ease;
  }

  .modal-input:focus {
    border-color: var(--color-primary);
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

  .modal-btn-primary:disabled {
    opacity: 0.55;
    cursor: not-allowed;
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

  .modal-btn-secondary:disabled {
    opacity: 0.55;
    cursor: not-allowed;
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

    /* En móvil las columnas se apilan verticalmente */
    .guests-head {
      display: none;
    }

    .guest-row {
      grid-template-columns: 1fr;
      gap: 0.6rem;
      padding: 0.9rem;
    }

    .cell {
      justify-content: flex-start;
      gap: 0.6rem;
    }

    .cell--empty {
      display: none;
    }

    .cell-label {
      display: inline-block;
      min-width: 5.5rem;
      font-size: 0.78rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.04em;
      color: var(--color-text-muted);
    }

    .cell--actions {
      justify-content: stretch;
      margin-top: 0.2rem;
    }

    .cell--actions .btn-quitar,
    .cell--actions .btn-reemplazar {
      flex: 1;
      padding: 0.55rem 0.9rem;
      text-align: center;
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
