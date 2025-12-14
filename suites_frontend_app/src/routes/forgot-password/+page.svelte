<script lang="ts">
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';

  let email = '';
  let error = '';
  let successMessage = '';

  function handleBack() {
    goto(`${base}/login`);
  }

  function handleSubmit(event: Event) {
    event.preventDefault();
    error = '';
    successMessage = '';

    if (!email) {
      error = 'El correo es obligatorio.';
      return;
    }

    // Validación muy básica de formato de correo
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      error = 'Por favor ingresa un correo electrónico válido.';
      return;
    }

    // 🚨 IMPORTANTE:
    // Aquí NO llamamos a ningún API real.
    // Solo dejamos el botón "hueco", sin consumo de backend.
    // En el futuro aquí se conectará el endpoint de envío de contraseña temporal.

    successMessage =
      'Si el correo está registrado, recibirás un mensaje con instrucciones para restablecer tu contraseña.';
  }
</script>

<svelte:head>
  <title>Restablecer contraseña</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <section class="form-container">
    <button type="button" class="link-back" on:click={handleBack}>
      ← Volver al login
    </button>

    <h1 class="title">Restablecer contraseña</h1>
    <p class="subtitle">
      Ingresa el correo electrónico con el que te registraste. Te enviaremos
      una contraseña temporal o un enlace para restablecer tu acceso.
    </p>

    <form class="form" on:submit|preventDefault={handleSubmit}>
      <div class="field">
        <label for="email" class="label">Correo electrónico</label>
        <input
          id="email"
          name="email"
          type="email"
          class="input"
          bind:value={email}
          autocomplete="email"
          placeholder="ejemplo@correo.com"
        />
      </div>

      {#if error}
        <p class="error">{error}</p>
      {/if}

      <button type="submit" class="btn-primary">
        Restablecer mi contraseña
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
    background: radial-gradient(
      circle at top,
      #027c68 0,
      #003333 55%,
      #001a1a 100%
    );
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
    max-width: 420px;
    background: #001f1f;
    border-radius: 1rem;
    padding: 1.5rem 1.7rem;
    border: 1px solid #027c68;
    box-shadow: 0 12px 25px rgba(0, 0, 0, 0.55);
  }

  .link-back {
    border: none;
    background: transparent;
    color: #c8e6d8;
    cursor: pointer;
    font-size: 0.85rem;
    margin-bottom: 0.75rem;
    padding: 0;
  }

  .link-back:hover {
    text-decoration: underline;
  }

  .title {
    font-size: 1.6rem;
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
    margin-top: 0.5rem;
  }

  .field {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }

  .label {
    font-size: 0.9rem;
    font-weight: 500;
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

  .error {
    color: #fca5a5;
    font-size: 0.8rem;
    margin: 0;
  }

  .success {
    color: #b0e892;
    font-size: 0.85rem;
    margin-top: 0.6rem;
  }

  .btn-primary {
    margin-top: 0.4rem;
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