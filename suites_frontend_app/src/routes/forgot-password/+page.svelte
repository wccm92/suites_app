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

  .page {
    min-height: 100vh;
    display: flex;
    justify-content: center;
    padding: 1.5rem;
  }

  .form-container {
    width: 100%;
    max-width: 420px;
    background: #ffffff;
    border-radius: 1rem;
    padding: 1.5rem 1.7rem;
    border: 1px solid #d1e8e0;
    box-shadow: 0 4px 20px rgba(0, 89, 64, 0.10);
  }

  .link-back {
    border: none;
    background: transparent;
    color: var(--color-text-muted);
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
    color: var(--color-success);
  }

  .subtitle {
    font-size: 0.9rem;
    color: var(--color-text-muted);
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
    border: 1px solid #c0ddd4;
    background: #f5faf7;
    color: var(--color-text-main);
    font-size: 0.95rem;
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

  .error {
    color: #fca5a5;
    font-size: 0.8rem;
    margin: 0;
  }

  .success {
    color: var(--color-success);
    font-size: 0.85rem;
    margin-top: 0.6rem;
  }

  .btn-primary {
    margin-top: 0.4rem;
    padding: 0.6rem 1rem;
    border-radius: 999px;
    border: none;
    background: var(--color-primary);
    color: #ffffff;
    font-size: 0.95rem;
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 4px 12px rgba(0, 89, 64, 0.28);
    transition:
      transform 0.12s ease,
      box-shadow 0.12s ease,
      background 0.12s ease;
  }

  .btn-primary:hover {
    transform: translateY(-1px);
    box-shadow: 0 8px 20px rgba(0, 89, 64, 0.40);
    background: #009933;
  }

  .btn-primary:active {
    transform: translateY(0);
    box-shadow: 0 4px 10px rgba(0, 89, 64, 0.30);
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