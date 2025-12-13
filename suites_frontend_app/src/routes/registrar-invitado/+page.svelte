<script lang="ts">
  import { goto } from '$app/navigation';

  let cedula = '';
  let error = '';
  let successMessage = '';

  function sanitizeCedula(value: string): string {
    // Solo dígitos, máximo 10 caracteres
    const digitsOnly = value.replace(/\D/g, '');
    return digitsOnly.slice(0, 10);
  }

  function handleCedulaInput(event: Event) {
    const target = event.target as HTMLInputElement;
    const original = target.value;

    // Normalizamos el valor
    const sanitized = sanitizeCedula(original);

    cedula = sanitized;
    successMessage = '';

    if (original !== sanitized) {
      error =
        'Solo se permiten números (0-9), sin espacios, letras ni caracteres especiales. Máximo 10 dígitos.';
    } else {
      error = '';
    }
  }

  function handleSubmit(event: Event) {
    event.preventDefault();
    successMessage = '';

    if (!cedula) {
      error = 'La cédula es obligatoria.';
      return;
    }

    if (cedula.length > 10) {
      error = 'La cédula no puede superar los 10 dígitos.';
      return;
    }

    if (!/^\d+$/.test(cedula)) {
      error = 'La cédula debe contener únicamente números.';
      return;
    }

    // En este punto las validaciones pasan
    error = '';
    // De momento no llamamos a ningún API, solo mostramos un mensaje
    successMessage =
      'Invitado agregado (simulado). Aquí luego conectaremos la API.';
  }

  function handleBack() {
    goto('/');
  }
</script>

<svelte:head>
  <title>Registrar invitado</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <section class="form-container">
    <button type="button" class="link-back" on:click={handleBack}>
      ← Volver al listado de suites
    </button>

    <h1 class="title">Registrar invitado</h1>
    <p class="subtitle">
      Ingresa la cédula del invitado siguiendo los requisitos indicados.
    </p>

    <form class="form" on:submit|preventDefault={handleSubmit}>
      <div class="field">
        <label for="cedula" class="label">Cédula</label>
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
        <ul class="requirements">
          <li>Solo números (0-9).</li>
          <li>Sin espacios, letras ni caracteres especiales.</li>
          <li>Máximo 10 dígitos.</li>
        </ul>
        {#if error}
          <p class="error">{error}</p>
        {/if}
      </div>

      <button type="submit" class="btn-primary">
        Agregar invitado
      </button>

      {#if successMessage}
        <p class="success">{successMessage}</p>
      {/if}
    </form>
  </section>
</main>

<style>
  :global(body) {
    margin: 0;
    font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI',
      sans-serif;
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
    max-width: 480px;
    background: #001f1f;
    border-radius: 1rem;
    padding: 1.5rem 1.7rem;
    border: 1px solid #027c68;
    box-shadow: 0 12px 25px rgba(0, 0, 0, 0.55);
  }

  .link-back {
    border: none;
    background: transparent;
    color: #b0e892;
    cursor: pointer;
    font-size: 0.85rem;
    margin-bottom: 0.75rem;
    padding: 0;
  }

  .link-back:hover {
    text-decoration: underline;
  }

  .title {
    font-size: 1.5rem;
    font-weight: 700;
    margin: 0;
    color: #b0e892;
  }

  .subtitle {
    font-size: 0.9rem;
    color: #c8e6d8;
    margin-top: 0.3rem;
    margin-bottom: 1.2rem;
  }

  .form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .field {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }

  .label {
    font-size: 0.9rem;
    font-weight: 500;
    color: #e6fff5;
  }

  .input {
    padding: 0.55rem 0.7rem;
    border-radius: 0.6rem;
    border: 1px solid #027c68;
    background: #002626;
    color: #e6fff5;
    font-size: 0.95rem;
    outline: none;
  }

  .input::placeholder {
    color: #8fbcae;
  }

  .input:focus {
    border-color: #009933;
    box-shadow: 0 0 0 1px #009933;
  }

  .requirements {
    margin: 0.3rem 0 0;
    padding-left: 1rem;
    font-size: 0.75rem;
    color: #b0e892;
    list-style-type: disc;
  }

  .requirements li + li {
    margin-top: 0.1rem;
  }

  .error {
    color: #fca5a5;
    font-size: 0.8rem;
    margin-top: 0.3rem;
  }

  .success {
    color: #b0e892;
    font-size: 0.85rem;
    margin-top: 0.5rem;
  }

  .btn-primary {
    padding: 0.6rem 1rem;
    border-radius: 999px;
    border: none;
    background: #027c68;
    color: #f5fff9;
    font-size: 0.95rem;
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 10px 25px rgba(0, 51, 51, 0.6);
    transition:
      transform 0.12s ease,
      box-shadow 0.12s ease,
      background 0.12s ease;
    margin-top: 0.4rem;
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

  @media (max-width: 640px) {
    .page {
      padding: 1rem;
    }

    .form-container {
      padding: 1.2rem 1.3rem;
    }

    .title {
      font-size: 1.3rem;
    }
  }
</style>
