<script lang="ts">
  import { goto } from "$app/navigation";
  import { base } from "$app/paths";
  import { page } from "$app/stores";
  import { onDestroy } from "svelte";

  // Params desde la pantalla anterior
  $: suiteId = $page.url.searchParams.get("id_suite") ?? "";
  $: capacidad = Number($page.url.searchParams.get("capacidad") ?? "0");
  $: cuposDisponibles = Number($page.url.searchParams.get("cupos_disponibles") ?? "0");

  // Form / estado
  let cedula = "";
  let error = "";

  // Lista de invitados agregados
  let invitados: string[] = [];

  // Modal
  let showModal = false;
  let modalMessage = "";

  // Derivados
  $: totalAgregados = invitados.length;
  $: restantes = Math.max(0, cuposDisponibles - totalAgregados);

  function openModal(message: string) {
    modalMessage = message;
    showModal = true;
  }

  function closeModal() {
    showModal = false;
    modalMessage = "";
  }

  function onKeyDown(e: KeyboardEvent) {
    if (e.key === "Escape" && showModal) closeModal();
  }

  window.addEventListener("keydown", onKeyDown);
  onDestroy(() => window.removeEventListener("keydown", onKeyDown));

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
    if (value.length !== 10) return "La cédula debe tener exactamente 10 dígitos.";
    if (!/^\d+$/.test(value)) return "La cédula debe contener únicamente números.";
    return "";
  }

  function addInvitado() {
    error = "";

    // 1) Validación de cupos
    if (cuposDisponibles > 0 && totalAgregados >= cuposDisponibles) {
      openModal("Ya se ha alcanzado el máximo de invitados a registrar para esta suite");
      return;
    }

    // 2) Validación de cédula
    const validation = isValidCedula(cedula);
    if (validation) {
      error = validation;
      return;
    }

    // 3) Duplicados
    if (invitados.includes(cedula)) {
      openModal("Esta cédula ya fue agregada.");
      return;
    }

    invitados = [...invitados, cedula];
    cedula = "";
  }

  function removeInvitado(value: string) {
    invitados = invitados.filter((x) => x !== value);
  }

  function handleBack() {
    goto(`${base}/`);
  }

  function confirmRegistro() {
    // 🚨 Aún sin API: dejamos el botón listo pero sin backend real.
    // Más adelante aquí harías el POST usando:
    // const payload = { id_suite: suiteId, invitados };
    openModal("Registro listo (simulado). Aquí luego conectaremos la API de confirmación.");
  }
</script>

<svelte:head>
  <title>Registrar invitado</title>
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
        <p class="suite-subtitle">Suite: <strong>{suiteId || "—"}</strong></p>

        <div class="suite-stats">
          <div class="stat">
            <span class="stat-label">Capacidad suite:</span>
            <span class="stat-value"> {capacidad || 0} </span>
          </div>
          <div class="stat">
            <span class="stat-label">Cupos disponibles:</span>
            <span class="stat-value"> {cuposDisponibles || 0} </span>
          </div>
        </div>
      </div>
    </div>

    <h1 class="title">Registrar invitado</h1>
    <p class="subtitle">Ingrese las cédulas de los invitados a esta suite</p>

    <!-- Input + botón (+) -->
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
          aria-label="Agregar invitado"
          title="Agregar"
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
      <h2 class="section-title">Invitados agregados</h2>

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
        <p class="hint">Aún no has agregado invitados.</p>
      {/if}

      <!-- Resumen dinámico -->
      <div class="summary-box" aria-live="polite">
        <p class="summary-line">
          Ha agregado <strong>[ {totalAgregados} ]</strong> invitado(s) en esta suite,
        </p>
        <p class="summary-line">
          aún puede agregar hasta <strong>[ {restantes} ]</strong> invitado(s) más
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
        Confirmar registro de invitados(s)
      </button>
    </div>
  </section>

  <!-- Modal -->
  {#if showModal}
    <div class="modal-overlay" on:click={closeModal}></div>

    <section class="modal" role="dialog" aria-modal="true" aria-label="Mensaje">
      <p class="modal-text">{modalMessage}</p>

      <button type="button" class="btn-primary" on:click={closeModal}>
        Entendido
      </button>
    </section>
  {/if}
</main>

<style>
  :global(body) {
    margin: 0;
    font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    background: radial-gradient(circle at top, #027c68 0, #069747 55%, #001a1a 100%);
    color: #e6fff5;
  }

  .page {
    min-height: 100vh;
    display: flex;
    justify-content: center;
    padding: 1.5rem;
  }

  .form-container {
    width: 100%;
    max-width: 820px;
    background: #001f1f;
    border-radius: 1rem;
    padding: 1.5rem 1.7rem;
    border: 1px solid #027c68;
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
    color: #b0e892;
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
    color: #c8e6d8;
    white-space: nowrap;
  }

  .suite-subtitle strong {
    color: #b0e892;
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
    color: #b0e892;
    font-size: 0.9rem;
    font-weight: 600;
  }

  .stat-value {
    color: #b0e892;
    font-size: 1rem;
    font-weight: 800;
  }

  .title {
    font-size: 1.6rem;
    font-weight: 800;
    margin: 0.4rem 0 0.25rem 0;
    color: #b0e892;
  }

  .subtitle {
    font-size: 0.95rem;
    color: #c8e6d8;
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
    border: 1px solid #027c68;
    background: #002626;
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
    border: 1px solid #027c68;
    background: #001f1f;
    color: #b0e892;
    font-size: 1.6rem;
    font-weight: 900;
    cursor: pointer;
    box-shadow: 0 10px 20px rgba(0, 0, 0, 0.25);
    transition: transform 0.12s ease, background 0.12s ease, border-color 0.12s ease;
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
    color: #b0e892;
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
    border: 1px solid #027c68;
    background: #002626;
    padding: 0.45rem 0.65rem 0.45rem 0.85rem;
    box-shadow: 0 8px 18px rgba(0, 0, 0, 0.25);
  }

  .chip-text {
    font-weight: 800;
    color: #b0e892;
    letter-spacing: 0.02em;
  }

  .chip-remove {
    width: 28px;
    height: 28px;
    border-radius: 999px;
    border: 1px solid #027c68;
    background: #001f1f;
    color: #e6fff5;
    cursor: pointer;
    font-size: 1.2rem;
    line-height: 1;
    display: grid;
    place-items: center;
    transition: transform 0.12s ease, background 0.12s ease, border-color 0.12s ease;
  }

  .chip-remove:hover {
    transform: scale(1.05);
    border-color: #009933;
    background: #014040;
  }

  .hint {
    margin: 0;
    color: #c8e6d8;
    font-size: 0.95rem;
  }

  .summary-box {
    border: 1px solid #027c68;
    background: rgba(0, 38, 38, 0.55);
    border-radius: 1rem;
    padding: 0.9rem 1rem;
  }

  .summary-line {
    margin: 0;
    color: #b0e892;
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
    border: 1px solid #027c68;
    background: transparent;
    color: #b0e892;
    font-weight: 900;
    font-size: 1.05rem;
    cursor: pointer;
    min-width: min(420px, 100%);
    transition: transform 0.12s ease, background 0.12s ease, border-color 0.12s ease;
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
    background: #001f1f;
    border: 1px solid #027c68;
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
    background: #027c68;
    color: #f5fff9;
    font-size: 1rem;
    font-weight: 800;
    cursor: pointer;
    box-shadow: 0 10px 25px rgba(0, 51, 51, 0.6);
    transition: transform 0.12s ease, box-shadow 0.12s ease, background 0.12s ease;
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
</style>