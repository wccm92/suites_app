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
  import type { GuestStatus, SuiteDetail } from "$lib/api/types";
  import {
    DOC_MAX,
    normalizarDesdeEvento,
    normalizarDocumento,
    validarDocumento,
  } from "$lib/documento";

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

  // Solo el propietario (profile === "owner") puede gestionar abonados
  let isOwner = false;

  // Valores mostrados: los frescos del backend si ya cargó, si no los del query
  $: capacidadShown = suiteDetail?.capacidad ?? capacidadParam;
  $: cuposShown = suiteDetail?.cupos_disponibles ?? Math.max(0, cuposParam);

  // Estado por visitante (abonado / ingresó al evento). `null` = no disponible:
  // las filas muestran "—" en vez de un "No" que podría ser falso.
  let guestStatus: Map<string, GuestStatus> | null = null;

  // Filas: cada invitado adulto con su cantidad de amparados (menores de siete años)
  // y su estado como abonado / ingreso al evento.
  $: guests = suiteDetail?.invitados_inscritos ?? [];
  $: rows = guests.map((g) => {
    const status = guestStatus?.get(g.invitado);
    return {
      invitado: g.invitado,
      amparados: g.amparados ?? 0,
      abonado: guestStatus ? (status?.abonado ?? false) : null,
      ingreso: guestStatus ? (status?.ingreso_evento ?? false) : null,
    };
  });

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

  // ── Modal "Registrar amparados" (contador con cupos dinámicos) ────────
  let amparadoPromptOpen = false;
  let amparadoNuevoInvitado = "";
  let amparadoCount = 0;
  let amparadoSubmitting = false;

  // Cupos que quedarían libres según el conteo elegido en el modal.
  // Cada amparado consume un cupo (misma regla que el registro de visitantes).
  $: amparadoRestantes = Math.max(0, cuposShown - amparadoCount);
  $: amparadoSinCupos = amparadoRestantes <= 0;

  function incAmparado() {
    if (amparadoSinCupos) return;
    amparadoCount += 1;
  }

  function decAmparado() {
    if (amparadoCount <= 0) return;
    amparadoCount -= 1;
  }

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

  function goToManageAbonados() {
    if (!suiteId) return;
    const qs = new URLSearchParams({ id_suite: suiteId });
    goto(`${base}/gestionar-abonados?${qs.toString()}`);
  }

  async function handleUnauthorized() {
    session.clear();
    await goto(`${base}/login`);
  }

  async function handleNotFound() {
    session.clear();
    await goto(`${base}/no-event`);
  }

  // ── Carga del estado de los visitantes (abonado / ingreso) ───────────
  // Complementa el detalle: si falla, el listado se sigue mostrando sin estos datos.
  async function loadGuestStatus() {
    try {
      const res = await apiFetch(`/suites_app/guests_status/${suiteId}`);
      if (!res.ok) {
        guestStatus = null;
        return;
      }
      const body = (await res.json().catch(() => ({}))) as {
        invitados?: GuestStatus[];
      };
      guestStatus = new Map(
        (body?.invitados ?? [])
          .filter((g) => typeof g?.invitado === "string")
          .map((g) => [g.invitado, g])
      );
    } catch {
      guestStatus = null;
    }
  }

  // ── Carga del detalle de la suite ─────────────────────────────────────
  async function loadSuite() {
    if (!browser || !suiteId) return;
    loading = true;
    loadError = "";
    loadGuestStatus();
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
    isOwner = session.getProfile() === "owner";
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

      // Cualquier respuesta no exitosa (500, etc.) o marcada como error de negocio
      // se muestra como aviso; nunca como éxito.
      if (!res.ok || body?.title === "error") {
        showMessage(body?.detail ?? "No se pudo eliminar el visitante.");
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
    const cedula = normalizarDocumento(nuevaCedula);
    const errorDoc = validarDocumento(cedula);
    if (errorDoc) {
      replaceError = errorDoc;
      return;
    }
    nuevaCedula = cedula;

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

      // Error de negocio: cierra el modal y muestra el aviso.
      if (body?.title === "error") {
        replaceOpen = false;
        showMessage(body.detail ?? "Ocurrió un error.");
        return;
      }

      // Fallo del servidor (500, etc.): mantener el modal abierto para reintentar.
      if (!res.ok) {
        replaceError =
          body?.detail ?? "No se pudo reemplazar el visitante. Inténtalo de nuevo.";
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

  // ── Flujo: Registrar amparados (register_amparado) ────────────────────
  function openAmparadoPrompt(nuevoInvitado: string) {
    amparadoNuevoInvitado = nuevoInvitado;
    amparadoCount = 0;
    amparadoPromptOpen = true;
  }

  function declineAmparado() {
    amparadoPromptOpen = false;
    loadSuite();
  }

  async function acceptAmparado() {
    // Sin amparados elegidos: no hay nada que registrar, cerramos y refrescamos.
    if (amparadoCount <= 0) {
      declineAmparado();
      return;
    }

    // Cada amparado se materializa como un UUID aleatorio generado en el front.
    const amparados = Array.from({ length: amparadoCount }, () =>
      crypto.randomUUID()
    );

    amparadoSubmitting = true;
    try {
      const res = await apiFetch("/suites_app/register_amparado", {
        method: "POST",
        body: JSON.stringify({
          id_suite: suiteId,
          invitado: amparadoNuevoInvitado,
          amparados,
        }),
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

      if (!res.ok || body?.title === "error") {
        amparadoPromptOpen = false;
        showMessage(
          body?.detail ?? "No se pudieron registrar los amparados.",
          false,
          () => loadSuite()
        );
        return;
      }

      amparadoPromptOpen = false;
      showMessage(
        body.detail ?? "Amparados registrados correctamente",
        true,
        () => loadSuite()
      );
    } catch {
      amparadoPromptOpen = false;
      showMessage("Error inesperado al registrar los amparados.", false, () =>
        loadSuite()
      );
    } finally {
      amparadoSubmitting = false;
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
      {#if isOwner}
        <button
          type="button"
          class="btn-abonados"
          on:click={goToManageAbonados}
          title="Gestionar abonados de esta suite"
        >
          <svg
            class="btn-abonados__icon"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="M2 9a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v2a2 2 0 0 0 0 4v2a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-2a2 2 0 0 0 0-4z" />
            <path d="M13 5v2" />
            <path d="M13 17v2" />
            <path d="M13 11v2" />
          </svg>
          Abonados
        </button>
      {/if}
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
          <span class="col-head col-head--adulto">Adulto</span>
          <span class="col-head col-head--amparado">Amparados</span>
          <span class="col-head col-head--abonado">Abonado</span>
          <span class="col-head col-head--ingreso">Ingresó al evento</span>
          <span class="col-head col-head--actions" aria-hidden="true"></span>
        </div>

        {#each rows as row (row.invitado)}
          <div class="guest-row">
            <div class="cell cell--adulto">
              <span class="cell-label">Adulto</span>
              <span class="pill pill--adulto">{row.invitado}</span>
            </div>

            <div class="cell cell--amparado">
              <span class="cell-label">Amparados</span>
              {#if row.amparados > 0}
                <span class="pill pill--amparado">
                  <svg
                    class="pill-icon"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    aria-hidden="true"
                  >
                    <circle cx="12" cy="7" r="4" />
                    <path d="M5.5 21a6.5 6.5 0 0 1 13 0" />
                  </svg>
                  {row.amparados}
                  {row.amparados === 1 ? "amparado" : "amparados"}
                </span>
              {:else}
                <span class="amparado-none">Sin amparados</span>
              {/if}
            </div>

            <!-- En escritorio el encabezado da el contexto ("Sí"/"No"); en móvil
                 no hay encabezados, así que el valor se describe solo. -->
            <div class="cell cell--abonado">
              {#if row.abonado === null}
                <span class="flag-unknown" title="No disponible">—</span>
              {:else if row.abonado}
                <span class="flag flag--si">
                  <svg
                    class="pill-icon"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2.4"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    aria-hidden="true"
                  >
                    <polyline points="20 6 9 17 4 12" />
                  </svg>
                  <span class="desk-only">Sí</span>
                  <span class="mobile-only">Abonado</span>
                </span>
              {:else}
                <span class="flag flag--no">
                  <span class="desk-only">No</span>
                  <span class="mobile-only">No abonado</span>
                </span>
              {/if}
            </div>

            <div class="cell cell--ingreso">
              {#if row.ingreso === null}
                <span class="flag-unknown" title="No disponible">—</span>
              {:else}
                <span
                  class="ingreso {row.ingreso ? 'ingreso--on' : 'ingreso--off'}"
                  title={row.ingreso ? "Ingresó al evento" : "Aún no ingresa al evento"}
                >
                  <span class="light" aria-hidden="true"></span>
                  <span class="mobile-only">{row.ingreso ? "Ingresó" : "Sin ingreso"}</span>
                  <span class="sr-only">{row.ingreso ? "Sí" : "No"}</span>
                </span>
              {/if}
            </div>

            <div class="cell cell--actions">
              <button
                type="button"
                class="btn-quitar"
                on:click={() => quitarInvitado(row.invitado)}
                disabled={processing}
              >
                Quitar
              </button>
              <button
                type="button"
                class="btn-reemplazar"
                on:click={() => openReplace(row.invitado)}
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
      placeholder="Ej: 1234567890 o AB123456"
      bind:value={nuevaCedula}
      on:input={(e) => (nuevaCedula = normalizarDesdeEvento(e))}
      maxlength={DOC_MAX}
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

<!-- ── Modal: Registrar amparados (contador con cupos dinámicos) ───────── -->
{#if amparadoPromptOpen}
  <div class="modal-overlay" role="presentation"></div>
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="amparado-prompt-title">
    <h3 class="modal-title" id="amparado-prompt-title">Registrar amparados</h3>
    <p class="modal-text">
      Indica cuántos amparados (menores de siete años) llevará
      <strong>{amparadoNuevoInvitado}</strong>. Cada amparado ocupa un cupo de la
      suite.
    </p>

    <div class="cupos-badge {amparadoSinCupos ? 'cupos-badge--zero' : ''}">
      Quedan <strong>{amparadoRestantes}</strong>
      {amparadoRestantes === 1 ? "cupo libre" : "cupos libres"}
    </div>

    <div class="amparado-stepper">
      <button
        type="button"
        class="stepper-btn"
        on:click={decAmparado}
        disabled={amparadoCount === 0 || amparadoSubmitting}
        aria-label="Quitar un amparado"
      >
        −
      </button>
      <span class="stepper-value">{amparadoCount}</span>
      <button
        type="button"
        class="stepper-btn"
        on:click={incAmparado}
        disabled={amparadoSinCupos || amparadoSubmitting}
        aria-label="Agregar un amparado"
        title={amparadoSinCupos
          ? "No quedan cupos disponibles en la suite."
          : "Agregar un amparado"}
      >
        +
      </button>
    </div>

    <div class="modal-actions">
      <button
        class="modal-btn-secondary"
        type="button"
        on:click={declineAmparado}
        disabled={amparadoSubmitting}
      >
        Omitir
      </button>
      <button
        class="modal-btn-primary"
        type="button"
        on:click={acceptAmparado}
        disabled={amparadoCount === 0 || amparadoSubmitting}
      >
        {amparadoSubmitting ? "Registrando…" : "Registrar"}
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

  .btn-abonados {
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    padding: 0.5rem 1rem;
    border-radius: 999px;
    border: none;
    background: var(--color-primary);
    color: #ffffff;
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
    box-shadow: 0 4px 12px rgba(0, 89, 64, 0.28);
    transition:
      transform 0.12s ease,
      box-shadow 0.12s ease,
      background 0.12s ease;
  }

  .btn-abonados__icon {
    width: 1.05em;
    height: 1.05em;
    flex-shrink: 0;
  }

  .btn-abonados:hover {
    transform: translateY(-1px);
    background: #009933;
    box-shadow: 0 8px 20px rgba(0, 89, 64, 0.40);
  }

  .btn-abonados:active {
    transform: translateY(0);
    box-shadow: 0 4px 10px rgba(0, 89, 64, 0.30);
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
    /* Abonado, Ingresó y acciones van con ancho fijo para que sean idénticas en
       el encabezado y en las filas; así las dos columnas 1fr (Adulto/Amparados)
       se alinean verticalmente con sus respectivos encabezados. */
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) 6rem 7.5rem 12rem;
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

  .col-head--abonado,
  .col-head--ingreso {
    color: var(--color-primary);
    line-height: 1.2;
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
    gap: 0.35rem;
    background: #fdf3e7;
    border: 1px solid #e6b980;
    color: #b3701a;
  }

  .pill-icon {
    width: 0.95em;
    height: 0.95em;
    flex-shrink: 0;
  }

  .amparado-none {
    font-size: 0.82rem;
    font-weight: 500;
    color: var(--color-text-muted);
  }

  /* ── Flag "Abonado": el "Sí" destaca (relleno), el "No" queda discreto ── */
  .flag {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.3rem 0.75rem;
    border-radius: 999px;
    font-size: 0.82rem;
    white-space: nowrap;
  }

  .flag--si {
    background: var(--color-primary);
    color: #ffffff;
    font-weight: 700;
    box-shadow: 0 3px 10px rgba(0, 89, 64, 0.28);
  }

  .flag--no {
    padding: 0.3rem 0.6rem;
    color: var(--color-text-soft);
    font-weight: 500;
  }

  .flag-unknown {
    color: var(--color-text-soft);
  }

  /* ── Luz "Ingresó al evento": encendida (verde con brillo) vs apagada ── */
  .ingreso {
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    font-size: 0.82rem;
    white-space: nowrap;
  }

  .light {
    width: 1.05rem;
    height: 1.05rem;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .ingreso--on {
    color: #15803d;
    font-weight: 700;
  }

  .ingreso--on .light {
    background: radial-gradient(circle at 35% 35%, #bbf7d0 0, #22c55e 45%, #16a34a 100%);
    box-shadow:
      0 0 0 3px rgba(34, 197, 94, 0.18),
      0 0 12px 2px rgba(34, 197, 94, 0.65);
    animation: light-pulse 2.2s ease-in-out infinite;
  }

  .ingreso--off {
    color: var(--color-text-soft);
    font-weight: 500;
  }

  .ingreso--off .light {
    background: #e4ebe8;
    border: 1px solid #cdd8d3;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
  }

  @keyframes light-pulse {
    0%,
    100% {
      box-shadow:
        0 0 0 3px rgba(34, 197, 94, 0.18),
        0 0 12px 2px rgba(34, 197, 94, 0.65);
    }
    50% {
      box-shadow:
        0 0 0 5px rgba(34, 197, 94, 0.1),
        0 0 18px 4px rgba(34, 197, 94, 0.45);
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .ingreso--on .light {
      animation: none;
    }
  }

  .mobile-only {
    display: none;
  }

  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
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

  /* Badge de cupos disponibles dentro del modal de amparados */
  .cupos-badge {
    display: inline-block;
    margin: 0 0 1rem 0;
    padding: 0.35rem 0.9rem;
    border-radius: 999px;
    background: #edf7f2;
    border: 1px solid #c8e6d8;
    color: var(--color-primary);
    font-size: 0.85rem;
    font-weight: 600;
  }

  .cupos-badge strong {
    font-weight: 800;
  }

  .cupos-badge--zero {
    background: #fff5f5;
    border-color: var(--color-error-soft);
    color: var(--color-error);
  }

  /* Contador +/- de amparados */
  .amparado-stepper {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 1.1rem;
    margin: 0.25rem 0 0.75rem;
  }

  .stepper-btn {
    width: 2.6rem;
    height: 2.6rem;
    border-radius: 50%;
    border: 1px solid #c0ddd4;
    background: #ffffff;
    color: var(--color-primary);
    font-size: 1.4rem;
    font-weight: 700;
    line-height: 1;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    transition:
      background 0.12s ease,
      border-color 0.12s ease,
      transform 0.12s ease;
  }

  .stepper-btn:hover:enabled {
    background: #edf7f2;
    border-color: var(--color-primary);
    transform: translateY(-1px);
  }

  .stepper-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .stepper-value {
    min-width: 2.5rem;
    text-align: center;
    font-size: 1.5rem;
    font-weight: 800;
    color: var(--color-text-main);
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

  /* ── Responsive: listado como tarjetas compactas ──────────────────────
     Con 5 columnas la tabla deja de caber antes de los 768px, así que el
     listado pasa a tarjetas desde 860px. En vez de apilar una fila con
     etiqueta por dato (5 filas por visitante), cada tarjeta va en 2 filas:
       [ cédula            luz de ingreso ]
       [ amparados          flag abonado  ]
       [        Quitar | Reemplazar       ]
     Los valores se describen solos ("Abonado", "Ingresó"), sin etiquetas. */
  @media (max-width: 860px) {
    .guests-head {
      display: none;
    }

    .guest-row {
      grid-template-columns: minmax(0, 1fr) auto;
      grid-template-areas:
        "adulto ingreso"
        "amparado abonado"
        "actions actions";
      gap: 0.55rem 0.75rem;
      padding: 0.8rem 0.9rem;
    }

    .cell--adulto {
      grid-area: adulto;
    }

    .cell--amparado {
      grid-area: amparado;
    }

    .cell--abonado {
      grid-area: abonado;
    }

    .cell--ingreso {
      grid-area: ingreso;
    }

    .cell--actions {
      grid-area: actions;
    }

    .cell {
      justify-content: flex-start;
    }

    .cell--abonado,
    .cell--ingreso {
      justify-content: flex-end;
    }

    .cell-label {
      display: none;
    }

    .mobile-only {
      display: inline;
    }

    .desk-only {
      display: none;
    }

    /* "No abonado" / "Sin ingreso" quedan como texto pequeño y discreto */
    .flag--no {
      padding: 0;
      font-size: 0.78rem;
    }

    .ingreso--off {
      font-size: 0.78rem;
    }

    .cell--actions {
      justify-content: stretch;
      padding-top: 0.55rem;
      border-top: 1px solid #e3eee9;
    }

    .cell--actions .btn-quitar,
    .cell--actions .btn-reemplazar {
      flex: 1;
      padding: 0.55rem 0.9rem;
      text-align: center;
    }
  }

  /* ── Responsive ───────────────────────────────────────────────────── */
  @media (max-width: 768px) {
    .form-container {
      padding: 1.2rem 1rem 1.4rem;
    }

    /* El título y el botón de abonados se apilan a lo ancho */
    .step-heading {
      flex-direction: column;
      align-items: stretch;
    }

    .btn-abonados {
      width: 100%;
      justify-content: center;
    }

    .suite-meta {
      flex-direction: column;
      align-items: flex-start;
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
