<script lang="ts">
  import { goto } from "$app/navigation";
  import { base } from "$app/paths";
  import { page } from "$app/stores";
  import { onDestroy, onMount } from "svelte";
  import { browser } from "$app/environment";
  import { apiFetch } from "$lib/api/client";

  let suiteId = "";
  let capacidad = 0;

  let cuposDisponiblesRaw: string | null = null;
  let cuposDisponiblesNum = 0;
  let cuposDisponiblesSafe = 0;

  let cedula = "";
  let error = "";

  let invitados: string[] = [];

  // Modal simple (errores, mensajes generales)
  let showModal = false;
  let modalMessage = "";

  // 🔹 Nuevo: modal de confirmación final
  let showConfirmFinal = false;

  // 🔹 Nuevo: modal de resultado del registro masivo
  let showResultModal = false;
  let resultMessage = "";
  let isSubmittingFinal = false;

  // Derivados
  let totalAgregados = 0;
  let restantes = 0;
  let cuposInvalidos = false;

  // Params desde la pantalla anterior (reactivos)
  $: suiteId = $page.url.searchParams.get("id_suite") ?? "";
  $: capacidad = Number($page.url.searchParams.get("capacidad") ?? "0");

  // cupos_disponibles raw + safe (si viene vacío/NaN/<=0 => 0)
  $: cuposDisponiblesRaw = $page.url.searchParams.get("cupos_disponibles");
  $: cuposDisponiblesNum = Number(cuposDisponiblesRaw ?? "0");
  $: cuposDisponiblesSafe =
    Number.isFinite(cuposDisponiblesNum) && cuposDisponiblesNum > 0
      ? cuposDisponiblesNum
      : 0;

  // Derivados
  $: totalAgregados = invitados.length;
  $: restantes = Math.max(0, cuposDisponiblesSafe - totalAgregados);

  // ✅ bandera: cupos inválidos o 0 => bloquear "+"
  $: cuposInvalidos = cuposDisponiblesSafe === 0;

  // ---------- Helpers de modal (simple / confirm / result) ----------

  function openModal(message: string) {
    modalMessage = message;
    showModal = true;
  }

  function closeModal() {
    showModal = false;
    modalMessage = "";
  }

  function openConfirmFinal() {
    showConfirmFinal = true;
  }

  function closeConfirmFinal() {
    showConfirmFinal = false;
  }

  function openResultModal(message: string) {
    resultMessage = message;
    showResultModal = true;
  }

  function closeResultModal() {
    showResultModal = false;
    resultMessage = "";
    setTimeout(() => goto(`${base}/`), 300);
  }

  function onKeyDown(e: KeyboardEvent) {
    if (e.key !== "Escape") return;

    if (showConfirmFinal) {
      // Escape en confirmación final → cerrar confirm
      closeConfirmFinal();
      return;
    }

    if (showResultModal) {
      // Escape en resultado final → comportarse como cerrar
      closeResultModal();
      return;
    }

    if (showModal) {
      closeModal();
    }
  }

  onMount(() => {
    if (!browser) return;
    window.addEventListener("keydown", onKeyDown);
  });

  onDestroy(() => {
    if (!browser) return;
    window.removeEventListener("keydown", onKeyDown);
  });

  // ---------- Lógica de cédula / lista local ----------

  function sanitizeCedula(value: string): string {
    const digitsOnly = value.replace(/\D/g, "");
    return digitsOnly.slice(0, 10);
  }

  function handleCedulaInput(event: Event) {
    const target = event.target as HTMLInputElement;
    const original = target.value;
    const sanitized = sanitizeCedula(original);

    cedula = sanitized;

    if (original !== sanitized) {
      error =
        "Solo se permiten números (0-9), sin espacios, letras ni caracteres especiales. Máximo 10 dígitos.";
    } else {
      error = "";
    }
  }

  function isValidCedula(value: string) {
    if (!value) return "La cédula es obligatoria.";
    if (value.length < 6)
      return "La cédula debe tener entre 6 y 10 dígitos.";
    if (!/^\d+$/.test(value))
      return "La cédula debe contener únicamente números.";
    return "";
  }

  // 🔹 Validación por cédula contra backend (se mantiene como antes)
  async function addInvitado() {
    error = "";

    // Seguridad básica: si no hay suiteId, no seguimos
    if (!suiteId) {
      openModal(
        "No se pudo identificar la suite seleccionada. Vuelve al listado y entra de nuevo."
      );
      return;
    }

    // 1) Validar cupos/local antes de pegarle al backend
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

    // 2) Validar formato de cédula (frontend)
    const validation = isValidCedula(cedula);
    if (validation) {
      error = validation;
      return;
    }

    // 3) Validar duplicados en la lista local
    if (invitados.includes(cedula)) {
      openModal("Esta cédula ya fue agregada.");
      return;
    }

    // 4) Llamar al API para validar el invitado
    try {
      const res = await apiFetch("/suites_app/validate_guest", {
        method: "POST",
        body: JSON.stringify({
          id_suite: suiteId,
          invitado: cedula
        })
      });

      if (res.status === 200) {
        // ✅ Válida → se agrega a la lista
        invitados = [...invitados, cedula];
        cedula = "";
        return;
      }

      let detalle =
        "No se pudo registrar el visitante. Inténtalo nuevamente.";

      try {
        const body = (await res.json()) as {
          errors?: {
            title?: string;
            http_status?: number;
            detail?: string;
            code?: string;
          }[];
        };

        const firstDetail = body?.errors?.[0]?.detail;
        if (firstDetail) {
          detalle = firstDetail;
        }
      } catch {
        // Si falla el parseo del JSON, usamos el mensaje genérico
      }

      openModal(detalle);
    } catch (e) {
      openModal(
        "No fue posible comunicarse con el servidor. Verifica tu conexión e inténtalo de nuevo."
      );
    }
  }

  function removeInvitado(value: string) {
    invitados = invitados.filter((x) => x !== value);
  }

  function handleBack() {
    goto(`${base}/`);
  }

  // ---------- Confirmación y registro masivo de visitantes ----------

  function confirmRegistro() {
    if (invitados.length === 0) return;
    // Mostrar modal de confirmación
    openConfirmFinal();
  }

  async function handleConfirmYes() {
    if (!suiteId) {
      // Algo raro: suiteId vacío → mostramos error normal
      closeConfirmFinal();
      openModal(
        "No se pudo identificar la suite seleccionada. Vuelve al listado y entra de nuevo."
      );
      return;
    }

    if (invitados.length === 0) {
      closeConfirmFinal();
      openModal("No hay visitantes para registrar.");
      return;
    }

    isSubmittingFinal = true;

    try {
      const res = await apiFetch("/suites_app/register_guests", {
        method: "POST",
        body: JSON.stringify({
          id_suite: suiteId,
          invitados
        })
      });

      if (!res.ok) {
        // Intentamos parsear error estándar
        let detalle =
          "No se pudo completar el registro de visitantes. Inténtalo nuevamente.";

        try {
          const body = (await res.json()) as {
            errors?: {
              title?: string;
              http_status?: number;
              detail?: string;
              code?: string;
            }[];
          };
          const firstDetail = body?.errors?.[0]?.detail;
          if (firstDetail) detalle = firstDetail;
        } catch {
          // si falla el JSON, usamos el genérico
        }

        closeConfirmFinal();
        openModal(detalle);
        return;
      }

      // OK → parseamos el resultado del registro
      const body = (await res.json()) as {
        successful_registrations?: string[];
        not_registered_blocked?: string[];
        not_registered_already_suites?: string[];
      };

      const okList = body.successful_registrations ?? [];
      const blockedList = body.not_registered_blocked ?? [];
      const alreadySuitesList = body.not_registered_already_suites ?? [];

      let msg = "";

      if (okList.length > 0) {
        msg +=
          "Los siguientes visitantes fueron registrados exitosamente:\n\n" +
          okList.join("\n") +
          "\n\n";
      }

      if (blockedList.length > 0) {
        msg +=
          "Los siguientes visitantes no fueron registrados debido a que están reportados por Logística:\n\n" +
          blockedList.join("\n") +
          "\n\n";
      }

      if (alreadySuitesList.length > 0) {
        msg +=
          "Los siguientes visitantes no fueron registrados porque ya se encuentran en otras suites para este evento:\n\n" +
          alreadySuitesList.join("\n") +
          "\n\n";
      }

      if (!msg) {
        msg =
          "La operación de registro se completó, pero no se devolvieron detalles específicos.";
      }

      // Cerramos confirm y abrimos modal de resultado
      closeConfirmFinal();
      openResultModal(msg.trim());

      // (Opcional) limpiar la lista local para que no se vuelvan a mandar
      invitados = [];
    } catch (e) {
      closeConfirmFinal();
      openModal(
        "No fue posible comunicarse con el servidor para confirmar el registro. Inténtalo nuevamente."
      );
    } finally {
      isSubmittingFinal = false;
    }
  }

  function handleConfirmNo() {
    closeConfirmFinal();
  }
</script>

<svelte:head>
  <title>Registrar visitante</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <section class="form-container">
    <!-- Header -->
    <div class="header-row">
      <button type="button" class="link-back" on:click={handleBack}>
        ← Volver al listado de suites
      </button>

      <div class="suite-meta">
        <p class="suite-subtitle">
          Suite: <strong>{suiteId || "—"}</strong>
        </p>

        <div class="suite-stats">
          <div class="stat">
            <span class="stat-label">Capacidad suite:</span>
            <span class="stat-value"> {capacidad || 0} </span>
          </div>
          <div class="stat">
            <span class="stat-label">Cupos disponibles:</span>
            <span
              class="stat-value {cuposDisponiblesSafe === 0 ? 'stat-zero' : ''}"
            >
              {cuposDisponiblesSafe}
            </span>
          </div>
        </div>
      </div>
    </div>

    <h1 class="title">Registrar visitante</h1>
    <p class="subtitle">Ingrese las cédulas de los visitantes a esta suite</p>

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
          aria-label="Agregar invitado"
          title={cuposInvalidos ? "Cupos no disponibles" : "Agregar"}
        >
          +
        </button>
      </div>

      {#if error}
        <p class="error">{error}</p>
      {/if}
    </div>

    <!-- Invitados agregados -->
    <div class="added-block">
      <h2 class="section-title">visitantes agregados</h2>

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
                title="Eliminar"
              >
                ×
              </button>
            </div>
          {/each}
        </div>
      {:else}
        <p class="hint">Aún no has agregado visitantes.</p>
      {/if}

      <!-- Resumen dinámico -->
      <div class="summary-box" aria-live="polite">
        <p class="summary-line">
          Ha agregado <strong>[ {totalAgregados} ]</strong> visitante(s) en
          esta suite,
        </p>
        <p class="summary-line">
          aún puede agregar hasta <strong>[ {restantes} ]</strong> visitante(s)
          más
        </p>
      </div>
    </div>

    <!-- Confirmar -->
    <div class="actions">
      <button
        type="button"
        class="btn-confirm"
        on:click={confirmRegistro}
        disabled={invitados.length === 0}
      >
        Confirmar registro de visitantes(s)
      </button>
    </div>
  </section>

  <!-- Overlay compartido -->
  {#if showModal || showConfirmFinal || showResultModal}
    <div class="modal-overlay" on:click={() => {
      // Solo cerramos los que son "cerrables" con click fuera
      if (showConfirmFinal) {
        closeConfirmFinal();
      } else if (showResultModal) {
        closeResultModal();
      } else if (showModal) {
        closeModal();
      }
    }}></div>
  {/if}

  <!-- Modal simple (errores / mensajes) -->
  {#if showModal}
    <section class="modal" role="dialog" aria-modal="true" aria-label="Mensaje">
      <p class="modal-text">{modalMessage}</p>

      <button type="button" class="btn-primary" on:click={closeModal}>
        Entendido
      </button>
    </section>
  {/if}

  <!-- Modal de confirmación final -->
  {#if showConfirmFinal}
    <section
      class="modal"
      role="dialog"
      aria-modal="true"
      aria-label="Confirmar registro"
    >
      <p class="modal-text">
        ¿Está seguro que desea registrar estos visitantes? Esta acción no se
        puede deshacer.
      </p>

      <div class="modal-actions">
        <button
          type="button"
          class="btn-secondary"
          on:click={handleConfirmNo}
          disabled={isSubmittingFinal}
        >
          No
        </button>
        <button
          type="button"
          class="btn-primary"
          on:click={handleConfirmYes}
          disabled={isSubmittingFinal}
        >
          {#if isSubmittingFinal}
            Registrando...
          {:else}
            Sí
          {/if}
        </button>
      </div>
    </section>
  {/if}

  <!-- Modal de resultado final -->
  {#if showResultModal}
    <section
      class="modal"
      role="dialog"
      aria-modal="true"
      aria-label="Resultado registro visitantes"
    >
      <p class="modal-text" style="white-space: pre-line;">
        {resultMessage}
      </p>

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
    background: var(--color-surface);
    border-radius: 1rem;
    padding: 1.5rem 1.7rem;
    border: 1px solid var(--color-primary);
    box-shadow: 0 12px 25px rgba(0, 0, 0, 0.55);
  }

  .header-row {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 1rem;
    margin-bottom: 0.75rem;
  }

  .link-back {
    border: none;
    background: transparent;
    color: var(--color-success);
    cursor: pointer;
    font-size: 0.95rem;
    padding: 0;
    white-space: nowrap;
  }

  .link-back:hover {
    text-decoration: underline;
  }

  .suite-meta {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 0.35rem;
  }

  .suite-subtitle {
    margin: 0;
    font-size: 1.35rem;
    font-weight: 700;
    color: var(--color-text-muted);
    white-space: nowrap;
  }

  .suite-subtitle strong {
    color: var(--color-success);
  }

  .suite-stats {
    display: grid;
    gap: 0.25rem;
  }

  .stat {
    display: flex;
    gap: 0.5rem;
    justify-content: flex-end;
    align-items: baseline;
  }

  .stat-label {
    color: var(--color-success);
    font-size: 0.9rem;
    font-weight: 600;
  }

  .stat-value {
    color: var(--color-success);
    font-size: 1rem;
    font-weight: 800;
  }

  .title {
    font-size: 1.6rem;
    font-weight: 800;
    margin: 0.4rem 0 0.25rem 0;
    color: var(--color-success);
  }

  .subtitle {
    font-size: 0.95rem;
    color: var(--color-text-muted);
    margin: 0 0 1.2rem 0;
  }

  .field {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
    margin-bottom: 1rem;
  }

  .label {
    font-size: 0.95rem;
    font-weight: 700;
    color: #e6fff5;
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
    border: 1px solid var(--color-primary);
    background: var(--color-surface-soft);
    color: #e6fff5;
    font-size: 1rem;
    outline: none;
  }

  .input::placeholder {
    color: #8fbcae;
  }

  .input:focus {
    border-color: #009933;
    box-shadow: 0 0 0 1px #009933;
  }

  .btn-add {
    width: 52px;
    height: 44px;
    border-radius: 0.9rem;
    border: 1px solid var(--color-primary);
    background: var(--color-surface);
    color: var(--color-success);
    font-size: 1.6rem;
    font-weight: 900;
    cursor: pointer;
    box-shadow: 0 10px 20px rgba(0, 0, 0, 0.25);
    transition:
      transform 0.12s ease,
      background 0.12s ease,
      border-color 0.12s ease;
  }

  .btn-add:hover {
    transform: translateY(-1px);
    border-color: #009933;
    background: #014040;
  }

  .error {
    color: #fca5a5;
    font-size: 0.9rem;
    margin: 0.2rem 0 0 0;
  }

  .added-block {
    margin-top: 1rem;
  }

  .section-title {
    margin: 0 0 0.65rem 0;
    font-size: 1.05rem;
    color: var(--color-success);
    font-weight: 800;
  }

  .chips {
    display: flex;
    flex-wrap: wrap;
    gap: 0.6rem;
    margin-bottom: 1rem;
  }

  .chip {
    display: inline-flex;
    align-items: center;
    gap: 0.55rem;
    border-radius: 999px;
    border: 1px solid var(--color-primary);
    background: var(--color-surface-soft);
    padding: 0.45rem 0.65rem 0.45rem 0.85rem;
    box-shadow: 0 8px 18px rgba(0, 0, 0, 0.25);
  }

  .chip-text {
    font-weight: 800;
    color: var(--color-success);
    letter-spacing: 0.02em;
  }

  .chip-remove {
    width: 28px;
    height: 28px;
    border-radius: 999px;
    border: 1px solid var(--color-primary);
    background: var(--color-surface);
    color: #e6fff5;
    cursor: pointer;
    font-size: 1.2rem;
    line-height: 1;
    display: grid;
    place-items: center;
    transition:
      transform 0.12s ease,
      background 0.12s ease,
      border-color 0.12s ease;
  }

  .chip-remove:hover {
    transform: scale(1.05);
    border-color: #009933;
    background: #014040;
  }

  .hint {
    margin: 0;
    color: var(--color-text-muted);
    font-size: 0.95rem;
  }

  .summary-box {
    border: 1px solid var(--color-primary);
    background: rgba(0, 38, 38, 0.55);
    border-radius: 1rem;
    padding: 0.9rem 1rem;
  }

  .summary-line {
    margin: 0;
    color: var(--color-success);
    font-size: 1.05rem;
    font-weight: 700;
  }

  .summary-line + .summary-line {
    margin-top: 0.25rem;
  }

  .actions {
    margin-top: 1.25rem;
    display: flex;
    justify-content: center;
  }

  .btn-confirm {
    padding: 0.85rem 1.2rem;
    border-radius: 1rem;
    border: 1px solid var(--color-primary);
    background: transparent;
    color: var(--color-success);
    font-weight: 900;
    font-size: 1.05rem;
    cursor: pointer;
    min-width: min(420px, 100%);
    transition:
      transform 0.12s ease,
      background 0.12s ease,
      border-color 0.12s ease;
  }

  .btn-confirm:hover:enabled {
    transform: translateY(-1px);
    border-color: #009933;
    background: rgba(1, 64, 64, 0.6);
  }

  .btn-confirm:disabled {
    opacity: 0.55;
    cursor: default;
  }

  /* Modal */
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
    padding: 1.1rem 1.1rem 1rem;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.65);
    z-index: 9999;
  }

  .modal-text {
    margin: 0 0 0.9rem 0;
    color: #e6fff5;
    font-size: 1rem;
    line-height: 1.35;
  }

  .btn-primary {
    width: 100%;
    padding: 0.7rem 1rem;
    border-radius: 999px;
    border: none;
    background: var(--color-primary);
    color: var(--color-text-main);
    font-size: 1rem;
    font-weight: 800;
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

  .btn-secondary {
    flex: 1;
    padding: 0.7rem 1rem;
    border-radius: 999px;
    border: 1px solid var(--color-primary);
    background: transparent;
    color: var(--color-success);
    font-size: 1rem;
    font-weight: 700;
    cursor: pointer;
  }

  .btn-secondary:hover:enabled {
    background: rgba(1, 64, 64, 0.6);
  }

  .modal-actions {
    display: flex;
    gap: 0.75rem;
    margin-top: 0.8rem;
  }

  /* Responsive */
  @media (max-width: 640px) {
    .page {
      padding: 1rem;
    }

    .form-container {
      padding: 1.2rem 1.2rem;
    }

    .title {
      font-size: 1.35rem;
    }

    .suite-subtitle {
      font-size: 1.1rem;
    }

    .stat-label {
      font-size: 0.85rem;
    }

    .stat-value {
      font-size: 0.95rem;
    }

    .modal-actions {
      flex-direction: column-reverse;
    }

    .btn-primary,
    .btn-secondary {
      width: 100%;
    }
  }

  @media (max-width: 420px) {
    .header-row {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.6rem;
    }

    .suite-meta {
      align-items: flex-end;
      width: 100%;
    }

    .cedula-row {
      grid-template-columns: 1fr 52px;
    }
  }

  .btn-add:disabled {
    opacity: 0.45;
    cursor: not-allowed;
    filter: grayscale(0.4);
    transform: none;
  }

  .stat-zero {
    color: #ff6b6b;
    font-weight: 900;
  }
</style>