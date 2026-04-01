<script lang="ts">
  import { goto } from "$app/navigation";
  import { base } from "$app/paths";
  import { page } from "$app/stores";
  import { onDestroy, onMount } from "svelte";
  import { get } from "svelte/store";
  import { browser } from "$app/environment";
  import { apiFetch } from "$lib/api/client";
  import { session } from "$lib/stores/session";

  // ── Suite params ──────────────────────────────────────────────────────
  let suiteId = "";
  let capacidad = 0;
  let cuposDisponiblesRaw: string | null = null;
  let cuposDisponiblesNum = 0;
  let cuposDisponiblesSafe = 0;

  $: suiteId = $page.url.searchParams.get("id_suite") ?? "";
  $: capacidad = Number($page.url.searchParams.get("capacidad") ?? "0");
  $: cuposDisponiblesRaw = $page.url.searchParams.get("cupos_disponibles");
  $: cuposDisponiblesNum = Number(cuposDisponiblesRaw ?? "0");
  $: cuposDisponiblesSafe =
    Number.isFinite(cuposDisponiblesNum) && cuposDisponiblesNum > 0
      ? cuposDisponiblesNum
      : 0;

  // ── Step state ────────────────────────────────────────────────────────
  let currentStep: 1 | 2 | 3 = 1;

  // ── Step 1: Visitor list ──────────────────────────────────────────────
  let cedula = "";
  let error = "";
  let invitados: string[] = [];

  $: totalAgregados = invitados.length;
  $: cuposInvalidos = cuposDisponiblesSafe === 0;
  $: restantes = Math.max(0, cuposDisponiblesSafe - totalAgregados);

  // ── Step 2: Niños amparados ───────────────────────────────────────────
  let ninosPorInvitado: Record<string, boolean> = {};

  $: totalNinos = Object.values(ninosPorInvitado).filter(Boolean).length;
  $: restantesConNinos = Math.max(
    0,
    cuposDisponiblesSafe - totalAgregados - totalNinos
  );

  // ── Submission state ──────────────────────────────────────────────────
  let isSubmittingFinal = false;

  // ── Modals ────────────────────────────────────────────────────────────
  let showModal = false;
  let modalMessage = "";
  let showResultModal = false;
  let resultMessage = "";

  function openModal(message: string) {
    modalMessage = message;
    showModal = true;
  }
  function closeModal() {
    showModal = false;
    modalMessage = "";
  }
  function openResultModal(message: string) {
    resultMessage = message;
    showResultModal = true;
  }
  function closeResultModal() {
    showResultModal = false;
    resultMessage = "";
    setTimeout(() => goto(getHomeRoute()), 300);
  }

  function getHomeRoute(): string {
    const { jwt } = get(session);
    if (!jwt) return `${base}/`;
    try {
      const payload = JSON.parse(atob(jwt.split(".")[1]));
      if (payload?.profile === "leaseholder") return `${base}/arriendos`;
    } catch {}
    return `${base}/`;
  }

  // ── Step navigation ───────────────────────────────────────────────────
  function handleBack() {
    if (currentStep === 1) goto(getHomeRoute());
    else if (currentStep === 2) currentStep = 1;
    else currentStep = 2;
  }

  function goToStep2() {
    if (invitados.length === 0) return;
    // Initialise niños map preserving existing selections if user goes back & forward
    const updated: Record<string, boolean> = {};
    for (const id of invitados) {
      updated[id] = ninosPorInvitado[id] ?? false;
    }
    ninosPorInvitado = updated;
    currentStep = 2;
  }

  function goToStep3() {
    currentStep = 3;
  }

  // ── Cedula helpers ────────────────────────────────────────────────────
  function sanitizeCedula(value: string): string {
    return value.replace(/\D/g, "").slice(0, 10);
  }

  function handleCedulaInput(event: Event) {
    const target = event.target as HTMLInputElement;
    const original = target.value;
    const sanitized = sanitizeCedula(original);
    cedula = sanitized;
    error =
      original !== sanitized
        ? "Solo se permiten números (0-9), sin espacios, letras ni caracteres especiales. Máximo 10 dígitos."
        : "";
  }

  function isValidCedula(value: string): string {
    if (!value) return "La cédula es obligatoria.";
    if (value.length < 6) return "La cédula debe tener entre 6 y 10 dígitos.";
    if (!/^\d+$/.test(value))
      return "La cédula debe contener únicamente números.";
    return "";
  }

  async function addInvitado() {
    error = "";

    if (!suiteId) {
      openModal(
        "No se pudo identificar la suite seleccionada. Vuelve al listado y entra de nuevo."
      );
      return;
    }

    if (cuposInvalidos) {
      openModal(
        "No se pudo validar los cupos disponibles de esta suite. Vuelve al listado y selecciona la suite nuevamente."
      );
      return;
    }

    if (totalAgregados >= cuposDisponiblesSafe) {
      openModal(
        "Ya se ha alcanzado el máximo de visitantes a registrar para esta suite"
      );
      return;
    }

    const validation = isValidCedula(cedula);
    if (validation) {
      error = validation;
      return;
    }

    if (invitados.includes(cedula)) {
      openModal("Esta cédula ya fue agregada.");
      return;
    }

    try {
      const res = await apiFetch("/suites_app/validate_guest", {
        method: "POST",
        body: JSON.stringify({ id_suite: suiteId, invitado: cedula }),
      });

      if (res.status === 200) {
        invitados = [...invitados, cedula];
        cedula = "";
        return;
      }

      let detalle =
        "No se pudo registrar el visitante. Inténtalo nuevamente.";
      try {
        const body = (await res.json()) as {
          errors?: { detail?: string }[];
        };
        const firstDetail = body?.errors?.[0]?.detail;
        if (firstDetail) detalle = firstDetail;
      } catch {}

      openModal(detalle);
    } catch {
      openModal(
        "No fue posible comunicarse con el servidor. Verifica tu conexión e inténtalo de nuevo."
      );
    }
  }

  function removeInvitado(value: string) {
    invitados = invitados.filter((x) => x !== value);
  }

  // ── Step 3: Submit ────────────────────────────────────────────────────
  async function submitRegistro() {
    if (!suiteId || invitados.length === 0) return;
    isSubmittingFinal = true;

    try {
      const res = await apiFetch("/suites_app/register_guests", {
        method: "POST",
        body: JSON.stringify({ id_suite: suiteId, invitados }),
      });

      if (!res.ok) {
        let detalle =
          "No se pudo completar el registro de visitantes. Inténtalo nuevamente.";
        try {
          const body = (await res.json()) as {
            errors?: { detail?: string }[];
          };
          const firstDetail = body?.errors?.[0]?.detail;
          if (firstDetail) detalle = firstDetail;
        } catch {}
        openModal(detalle);
        return;
      }

      const body = (await res.json()) as {
        successful_registrations?: string[];
        not_registered_blocked?: string[];
        not_registered_already_suites?: string[];
      };

      const okList = body.successful_registrations ?? [];
      const blockedList = body.not_registered_blocked ?? [];
      const alreadySuitesList = body.not_registered_already_suites ?? [];

      let msg = "";
      if (okList.length > 0)
        msg +=
          "Los siguientes visitantes fueron registrados exitosamente:\n\n" +
          okList.join("\n") +
          "\n\n";
      if (blockedList.length > 0)
        msg +=
          "Los siguientes visitantes no fueron registrados debido a que están reportados por Logística:\n\n" +
          blockedList.join("\n") +
          "\n\n";
      if (alreadySuitesList.length > 0)
        msg +=
          "Los siguientes visitantes no fueron registrados porque ya se encuentran en otras suites para este evento:\n\n" +
          alreadySuitesList.join("\n") +
          "\n\n";
      if (!msg)
        msg =
          "La operación de registro se completó, pero no se devolvieron detalles específicos.";

      invitados = [];
      openResultModal(msg.trim());
    } catch {
      openModal(
        "No fue posible comunicarse con el servidor para confirmar el registro. Inténtalo nuevamente."
      );
    } finally {
      isSubmittingFinal = false;
    }
  }

  // ── Keyboard ──────────────────────────────────────────────────────────
  function onKeyDown(e: KeyboardEvent) {
    if (e.key !== "Escape") return;
    if (showResultModal) { closeResultModal(); return; }
    if (showModal) closeModal();
  }

  onMount(() => { if (browser) window.addEventListener("keydown", onKeyDown); });
  onDestroy(() => { if (browser) window.removeEventListener("keydown", onKeyDown); });
</script>

<svelte:head>
  <title>Registrar visitante</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <section class="form-container">

    <!-- ── Step indicator ─────────────────────────────────────────────── -->
    <nav class="stepper" aria-label="Pasos del registro">
      <div class="step {currentStep === 1 ? 'step--active' : ''} {currentStep > 1 ? 'step--done' : ''}">
        <span class="step-bubble">{currentStep > 1 ? '✓' : '1'}</span>
        <span class="step-label">Registro de visitantes</span>
      </div>
      <span class="step-arrow" aria-hidden="true">›</span>
      <div class="step {currentStep === 2 ? 'step--active' : ''} {currentStep > 2 ? 'step--done' : ''}">
        <span class="step-bubble">{currentStep > 2 ? '✓' : '2'}</span>
        <span class="step-label">Niños amparados</span>
      </div>
      <span class="step-arrow" aria-hidden="true">›</span>
      <div class="step {currentStep === 3 ? 'step--active' : ''}">
        <span class="step-bubble">3</span>
        <span class="step-label">Confirma tu registro</span>
      </div>
    </nav>

    <!-- ── Suite meta ─────────────────────────────────────────────────── -->
    <div class="suite-meta">
      <span class="suite-id-label">Suite: <strong>{suiteId || "—"}</strong></span>
      <div class="suite-stats">
        <span class="stat-pill">
          Capacidad: <strong>{capacidad}</strong>
        </span>
        <span class="stat-pill {cuposDisponiblesSafe === 0 ? 'stat-pill--zero' : ''}">
          Cupos disponibles: <strong>{cuposDisponiblesSafe}</strong>
        </span>
      </div>
    </div>

    <!-- ══ STEP 1 ══════════════════════════════════════════════════════ -->
    {#if currentStep === 1}
      <div class="step-content">
        <div class="step-heading">
          <h1 class="step-title">Registro de visitantes</h1>
          <span class="step-count">1 de 3</span>
        </div>

        <div class="field">
          <label for="cedula" class="label">Cédula</label>
          <div class="cedula-row">
            <input
              id="cedula"
              name="cedula"
              type="text"
              inputmode="numeric"
              autocomplete="off"
              maxlength="10"
              class="input"
              bind:value={cedula}
              on:input={handleCedulaInput}
              placeholder="Ej: 1234567890"
            />
            <button
              type="button"
              class="btn-add"
              on:click={addInvitado}
              disabled={cuposInvalidos}
              aria-disabled={cuposInvalidos}
              aria-label="Agregar visitante"
              title={cuposInvalidos ? "Sin cupos disponibles" : "Agregar"}
            >+</button>
          </div>
          {#if error}
            <p class="error">{error}</p>
          {/if}
        </div>

        <div class="added-block">
          <h2 class="section-title">Visitantes agregados</h2>
          {#if invitados.length > 0}
            <div class="chips">
              {#each invitados as inv}
                <div class="chip">
                  <span class="chip-text">{inv}</span>
                  <button
                    type="button"
                    class="chip-remove"
                    on:click={() => removeInvitado(inv)}
                    aria-label="Eliminar cédula"
                  >×</button>
                </div>
              {/each}
            </div>
          {:else}
            <p class="hint">Aún no has agregado visitantes.</p>
          {/if}

          <div class="cupos-badge" aria-live="polite">
            Quedan <strong>{restantes}</strong> cupo{restantes !== 1 ? 's' : ''} libre{restantes !== 1 ? 's' : ''}
          </div>
        </div>

        <div class="step-actions">
          <button type="button" class="btn-back" on:click={handleBack}>
            ← Atrás
          </button>
          <button
            type="button"
            class="btn-next"
            on:click={goToStep2}
            disabled={invitados.length === 0}
          >
            Siguiente →
          </button>
        </div>
      </div>
    {/if}

    <!-- ══ STEP 2 ══════════════════════════════════════════════════════ -->
    {#if currentStep === 2}
      <div class="step-content">
        <div class="step-heading">
          <h1 class="step-title">Registro de niños amparados (opcional)</h1>
          <span class="step-count">2 de 3</span>
        </div>
        <p class="step-subtitle">
          Marca la casilla de las cédulas que llevarán un niño amparado
        </p>

        <div class="visitors-table">
          <div class="visitors-header">
            <span>Visitante</span>
            <span>Viene con niño amparado</span>
          </div>
          {#each invitados as inv}
            <div class="visitors-row">
              <span class="visitor-cedula">{inv}</span>
              <label class="checkbox-wrap">
                <input
                  type="checkbox"
                  class="checkbox"
                  checked={ninosPorInvitado[inv] ?? false}
                  on:change={(e) => {
                    ninosPorInvitado = {
                      ...ninosPorInvitado,
                      [inv]: (e.target as HTMLInputElement).checked,
                    };
                  }}
                />
              </label>
            </div>
          {/each}
        </div>

        <div class="cupos-badge" aria-live="polite">
          Quedan <strong>{restantesConNinos}</strong> cupo{restantesConNinos !== 1 ? 's' : ''} libre{restantesConNinos !== 1 ? 's' : ''}
        </div>

        <div class="step-actions">
          <button type="button" class="btn-back" on:click={handleBack}>
            ← Atrás
          </button>
          <button type="button" class="btn-next" on:click={goToStep3}>
            Siguiente →
          </button>
        </div>
      </div>
    {/if}

    <!-- ══ STEP 3 ══════════════════════════════════════════════════════ -->
    {#if currentStep === 3}
      <div class="step-content">
        <div class="step-heading">
          <h1 class="step-title">Confirma tu registro</h1>
          <span class="step-count">3 de 3</span>
        </div>
        <p class="step-subtitle">Este es el resumen de tu registro</p>

        <div class="visitors-table">
          <div class="visitors-header">
            <span>Visitantes</span>
            <span>Viene con niño amparado</span>
          </div>
          {#each invitados as inv}
            <div class="visitors-row">
              <span class="visitor-cedula">{inv}</span>
              <span class="nino-tag {ninosPorInvitado[inv] ? 'nino-tag--si' : 'nino-tag--no'}">
                {ninosPorInvitado[inv] ? 'Sí' : 'No'}
              </span>
            </div>
          {/each}
        </div>

        <div class="totals-box">
          <div class="total-row">
            <span class="total-label">Total de adultos a inscribir</span>
            <strong class="total-value">{totalAgregados}</strong>
          </div>
          <div class="total-row">
            <span class="total-label">Total de niños a inscribir</span>
            <strong class="total-value">{totalNinos}</strong>
          </div>
          <div class="total-row total-row--highlight">
            <span class="total-label">Total de inscripciones</span>
            <strong class="total-value">{totalAgregados + totalNinos}</strong>
          </div>
        </div>

        <div class="step-actions">
          <button
            type="button"
            class="btn-back"
            on:click={handleBack}
            disabled={isSubmittingFinal}
          >
            ← Atrás
          </button>
          <button
            type="button"
            class="btn-confirm"
            on:click={submitRegistro}
            disabled={isSubmittingFinal}
          >
            {isSubmittingFinal ? "Registrando..." : "Confirmar registro"}
          </button>
        </div>
      </div>
    {/if}

  </section>

  <!-- ── Modals ───────────────────────────────────────────────────────── -->
  {#if showModal || showResultModal}
    <div
      class="modal-overlay"
      role="presentation"
      on:click={() => {
        if (showResultModal) closeResultModal();
        else closeModal();
      }}
    ></div>
  {/if}

  {#if showModal}
    <section class="modal" role="dialog" aria-modal="true" aria-label="Mensaje">
      <p class="modal-text">{modalMessage}</p>
      <button type="button" class="btn-primary" on:click={closeModal}>
        Entendido
      </button>
    </section>
  {/if}

  {#if showResultModal}
    <section
      class="modal"
      role="dialog"
      aria-modal="true"
      aria-label="Resultado registro visitantes"
    >
      <p class="modal-text" style="white-space: pre-line;">{resultMessage}</p>
      <button type="button" class="btn-primary" on:click={closeResultModal}>
        Volver al listado de suites
      </button>
    </section>
  {/if}
</main>

<style>
  .page {
    min-height: 100vh;
    display: flex;
    justify-content: center;
    padding: 1.5rem;
  }

  .form-container {
    width: 100%;
    max-width: 820px;
    background: #ffffff;
    border-radius: 1rem;
    padding: 1.5rem 1.7rem;
    border: 1px solid #d1e8e0;
    box-shadow: 0 4px 20px rgba(0, 89, 64, 0.1);
    align-self: flex-start;
  }

  /* ── Stepper ─────────────────────────────────────────────────────── */
  .stepper {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 1.4rem;
    flex-wrap: wrap;
  }

  .step {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    opacity: 0.4;
    transition: opacity 0.2s ease;
  }

  .step--active {
    opacity: 1;
  }

  .step--done {
    opacity: 0.65;
  }

  .step-bubble {
    width: 1.8rem;
    height: 1.8rem;
    border-radius: 50%;
    border: 2px solid #c0ddd4;
    background: #ffffff;
    color: var(--color-success);
    font-size: 0.8rem;
    font-weight: 800;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    transition: background 0.2s ease, border-color 0.2s ease, color 0.2s ease;
  }

  .step--active .step-bubble {
    background: var(--color-primary);
    border-color: var(--color-primary);
    color: #ffffff;
    box-shadow: 0 4px 10px rgba(0, 89, 64, 0.35);
  }

  .step--done .step-bubble {
    background: #edf7f2;
    border-color: var(--color-primary);
    color: var(--color-primary);
  }

  .step-label {
    font-size: 0.82rem;
    font-weight: 600;
    color: var(--color-text-main);
    white-space: nowrap;
  }

  .step--active .step-label {
    color: var(--color-success);
  }

  .step-arrow {
    font-size: 1.3rem;
    color: #c0ddd4;
    line-height: 1;
    flex-shrink: 0;
  }

  /* ── Suite meta ──────────────────────────────────────────────────── */
  .suite-meta {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 0.6rem;
    padding: 0.7rem 1rem;
    border-radius: 0.75rem;
    background: linear-gradient(135deg, rgba(0, 89, 64, 0.05), rgba(0, 153, 51, 0.08));
    border: 1px solid rgba(0, 153, 51, 0.15);
    margin-bottom: 1.4rem;
  }

  .suite-id-label {
    font-size: 1rem;
    color: var(--color-text-muted);
    font-weight: 500;
  }

  .suite-id-label strong {
    color: var(--color-success);
    font-weight: 800;
  }

  .suite-stats {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .stat-pill {
    padding: 0.25rem 0.75rem;
    border-radius: 999px;
    background: #ffffff;
    border: 1px solid #c0ddd4;
    font-size: 0.85rem;
    color: var(--color-success);
    font-weight: 500;
  }

  .stat-pill strong {
    font-weight: 800;
  }

  .stat-pill--zero {
    border-color: #fca5a5;
    color: #dc2626;
  }

  /* ── Step content ────────────────────────────────────────────────── */
  .step-content {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .step-heading {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: 0.5rem;
  }

  .step-title {
    font-size: 1.5rem;
    font-weight: 800;
    margin: 0;
    color: var(--color-success);
  }

  .step-count {
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--color-text-muted);
    white-space: nowrap;
  }

  .step-subtitle {
    margin: 0;
    font-size: 0.95rem;
    color: var(--color-text-muted);
  }

  /* ── Step 1: Input ───────────────────────────────────────────────── */
  .field {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  .label {
    font-size: 0.95rem;
    font-weight: 700;
    color: var(--color-text-main);
  }

  .cedula-row {
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 0.6rem;
    align-items: center;
  }

  .input {
    padding: 0.65rem 0.8rem;
    border-radius: 0.8rem;
    border: 1px solid #c0ddd4;
    background: #ffffff;
    color: var(--color-text-main);
    font-size: 1rem;
    outline: none;
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }

  .input::placeholder {
    color: #8a9e95;
  }

  .input:focus {
    border-color: var(--color-primary);
    box-shadow: 0 0 0 2px rgba(0, 89, 64, 0.15);
  }

  .btn-add {
    width: 52px;
    height: 44px;
    border-radius: 0.9rem;
    border: 1px solid #c0ddd4;
    background: #ffffff;
    color: var(--color-primary);
    font-size: 1.6rem;
    font-weight: 900;
    cursor: pointer;
    box-shadow: 0 2px 8px rgba(0, 89, 64, 0.12);
    transition: transform 0.12s ease, background 0.12s ease, border-color 0.12s ease;
  }

  .btn-add:hover:enabled {
    transform: translateY(-1px);
    border-color: var(--color-primary);
    background: #edf7f2;
  }

  .btn-add:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .error {
    color: #fca5a5;
    font-size: 0.9rem;
    margin: 0;
  }

  /* ── Chips ───────────────────────────────────────────────────────── */
  .added-block {
    display: flex;
    flex-direction: column;
    gap: 0.65rem;
  }

  .section-title {
    margin: 0;
    font-size: 1rem;
    color: var(--color-success);
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    font-size: 0.85rem;
  }

  .chips {
    display: flex;
    flex-wrap: wrap;
    gap: 0.6rem;
  }

  .chip {
    display: inline-flex;
    align-items: center;
    gap: 0.55rem;
    border-radius: 999px;
    border: 1px solid #c0ddd4;
    background: #edf7f2;
    padding: 0.45rem 0.65rem 0.45rem 0.85rem;
    box-shadow: 0 2px 6px rgba(0, 89, 64, 0.1);
  }

  .chip-text {
    font-weight: 800;
    color: var(--color-primary);
    letter-spacing: 0.02em;
    font-size: 0.95rem;
  }

  .chip-remove {
    width: 26px;
    height: 26px;
    border-radius: 999px;
    border: 1px solid #e0e0e0;
    background: #ffffff;
    color: var(--color-error);
    cursor: pointer;
    font-size: 1.1rem;
    line-height: 1;
    display: grid;
    place-items: center;
    transition: transform 0.12s ease, background 0.12s ease, border-color 0.12s ease;
  }

  .chip-remove:hover {
    transform: scale(1.05);
    border-color: var(--color-error);
    background: #fee2e2;
  }

  .hint {
    margin: 0;
    color: var(--color-text-muted);
    font-size: 0.95rem;
  }

  .cupos-badge {
    display: inline-flex;
    align-self: flex-start;
    padding: 0.4rem 1rem;
    border-radius: 999px;
    background: #edf7f2;
    border: 1px solid #c0ddd4;
    color: var(--color-success);
    font-size: 0.95rem;
    font-weight: 500;
  }

  .cupos-badge strong {
    margin: 0 0.2rem;
    font-weight: 800;
  }

  /* ── Steps 2 & 3: Table ──────────────────────────────────────────── */
  .visitors-table {
    border: 1px solid #d1e8e0;
    border-radius: 0.75rem;
    overflow: hidden;
  }

  .visitors-header {
    display: grid;
    grid-template-columns: 1fr 1fr;
    padding: 0.6rem 1rem;
    background: linear-gradient(135deg, rgba(0, 89, 64, 0.06), rgba(0, 153, 51, 0.09));
    border-bottom: 1px solid #d1e8e0;
    font-size: 0.82rem;
    font-weight: 700;
    color: var(--color-success);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .visitors-header span:last-child {
    text-align: center;
  }

  .visitors-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    padding: 0.65rem 1rem;
    align-items: center;
    border-bottom: 1px solid #edf7f2;
    transition: background 0.1s ease;
  }

  .visitors-row:last-child {
    border-bottom: none;
  }

  .visitors-row:hover {
    background: #f5faf7;
  }

  .visitor-cedula {
    font-size: 0.95rem;
    font-weight: 600;
    color: var(--color-text-main);
    letter-spacing: 0.02em;
  }

  /* ── Checkbox (Step 2) ───────────────────────────────────────────── */
  .checkbox-wrap {
    display: flex;
    justify-content: center;
    cursor: pointer;
  }

  .checkbox {
    width: 1.25rem;
    height: 1.25rem;
    accent-color: var(--color-primary);
    cursor: pointer;
  }

  /* ── Sí/No tag (Step 3) ──────────────────────────────────────────── */
  .nino-tag {
    display: flex;
    justify-content: center;
    font-size: 0.85rem;
    font-weight: 700;
    padding: 0.2rem 0.75rem;
    border-radius: 999px;
    width: fit-content;
    margin: 0 auto;
  }

  .nino-tag--si {
    background: #dcfce7;
    color: #166534;
    border: 1px solid #86efac;
  }

  .nino-tag--no {
    background: #f5f5f5;
    color: #6b7280;
    border: 1px solid #e0e0e0;
  }

  /* ── Totals box (Step 3) ─────────────────────────────────────────── */
  .totals-box {
    border: 1px solid #d1e8e0;
    border-radius: 0.75rem;
    overflow: hidden;
  }

  .total-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.6rem 1rem;
    border-bottom: 1px solid #edf7f2;
  }

  .total-row:last-child {
    border-bottom: none;
  }

  .total-row--highlight {
    background: linear-gradient(135deg, rgba(0, 89, 64, 0.06), rgba(0, 153, 51, 0.09));
  }

  .total-label {
    font-size: 0.9rem;
    color: var(--color-success);
    font-weight: 500;
  }

  .total-value {
    font-size: 1rem;
    font-weight: 800;
    color: var(--color-text-main);
  }

  .total-row--highlight .total-label,
  .total-row--highlight .total-value {
    color: var(--color-success);
    font-weight: 800;
  }

  /* ── Step actions ────────────────────────────────────────────────── */
  .step-actions {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 0.75rem;
    margin-top: 0.25rem;
    padding-top: 0.75rem;
    border-top: 1px solid #edf7f2;
  }

  .btn-back {
    padding: 0.55rem 1.1rem;
    border-radius: 999px;
    border: 1px solid #c0ddd4;
    background: transparent;
    color: var(--color-primary);
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.12s ease, border-color 0.12s ease;
  }

  .btn-back:hover:enabled {
    background: #edf7f2;
    border-color: var(--color-primary);
  }

  .btn-back:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .btn-next {
    padding: 0.55rem 1.3rem;
    border-radius: 999px;
    border: none;
    background: var(--color-primary);
    color: #ffffff;
    font-size: 0.9rem;
    font-weight: 700;
    cursor: pointer;
    box-shadow: 0 4px 12px rgba(0, 89, 64, 0.28);
    transition: transform 0.12s ease, box-shadow 0.12s ease, background 0.12s ease;
  }

  .btn-next:hover:enabled {
    transform: translateY(-1px);
    box-shadow: 0 8px 20px rgba(0, 89, 64, 0.40);
    background: #009933;
  }

  .btn-next:disabled {
    opacity: 0.45;
    cursor: not-allowed;
    box-shadow: none;
  }

  .btn-confirm {
    padding: 0.6rem 1.5rem;
    border-radius: 999px;
    border: none;
    background: #009933;
    color: #f5fff8;
    font-size: 0.95rem;
    font-weight: 800;
    cursor: pointer;
    box-shadow: 0 6px 18px rgba(0, 153, 51, 0.45);
    transition: transform 0.12s ease, box-shadow 0.12s ease, background 0.12s ease;
  }

  .btn-confirm:hover:enabled {
    transform: translateY(-1px);
    box-shadow: 0 10px 25px rgba(0, 153, 51, 0.65);
    background: #00b33c;
  }

  .btn-confirm:disabled {
    opacity: 0.55;
    cursor: not-allowed;
    box-shadow: none;
  }

  /* ── Modal ───────────────────────────────────────────────────────── */
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
    padding: 1.1rem 1.1rem 1rem;
    box-shadow: 0 10px 40px rgba(0, 89, 64, 0.18);
    z-index: 9999;
  }

  .modal-text {
    margin: 0 0 0.9rem 0;
    color: var(--color-text-main);
    font-size: 1rem;
    line-height: 1.45;
  }

  .btn-primary {
    width: 100%;
    padding: 0.7rem 1rem;
    border-radius: 999px;
    border: none;
    background: var(--color-primary);
    color: #ffffff;
    font-size: 1rem;
    font-weight: 800;
    cursor: pointer;
    box-shadow: 0 4px 12px rgba(0, 89, 64, 0.28);
    transition: transform 0.12s ease, box-shadow 0.12s ease, background 0.12s ease;
  }

  .btn-primary:hover {
    transform: translateY(-1px);
    box-shadow: 0 8px 20px rgba(0, 89, 64, 0.4);
    background: #009933;
  }

  /* ── Responsive ──────────────────────────────────────────────────── */
  @media (max-width: 640px) {
    .page {
      padding: 1rem;
    }

    .form-container {
      padding: 1.2rem;
    }

    .step-title {
      font-size: 1.25rem;
    }

    .stepper {
      gap: 0.35rem;
    }

    .step-label {
      font-size: 0.72rem;
    }
  }

  @media (max-width: 420px) {
    .suite-meta {
      flex-direction: column;
      align-items: flex-start;
    }

    .step-heading {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.1rem;
    }

    .cedula-row {
      grid-template-columns: 1fr 52px;
    }
  }
</style>
