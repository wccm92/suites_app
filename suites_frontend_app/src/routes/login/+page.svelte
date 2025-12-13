<!-- src/routes/login/+page.svelte -->
<script lang="ts">
  import { goto } from '$app/navigation';
  import { session } from '$lib/stores/session';
  import { apiFetch } from '$lib/api/client';

  let username = '';
  let password = '';
  let loading = false;
  let error = '';

  async function handleSubmit(event: Event) {
    event.preventDefault();
    error = '';
    loading = true;

    try {
      if (!username || !password) {
        error = 'Usuario y contraseña son obligatorios.';
        return;
      }

      // 🔐 Contraseña:
      // - type="password" en el input
      // - no se guarda en ningún store
      // - solo viaja en el body de un POST (y con HTTPS en producción)
      const res = await apiFetch('/auth/login', {
        auth: false, // este endpoint no requiere JWT todavía
        method: 'POST',
        body: JSON.stringify({
          username,
          password
        })
      });

      if (!res.ok) {
        error = 'Credenciales inválidas o error en el servidor.';
        return;
      }

      const body = (await res.json()) as { jwt: string };

      if (!body.jwt) {
        error = 'El servidor no devolvió un token de autenticación.';
        return;
      }

      // Guardamos el JWT en la sesión global
      session.setJwt(body.jwt);

      // Limpiamos la contraseña de memoria
      password = '';

      // Redirigimos a la pantalla principal (ajusta si tu ruta es otra)
      await goto('/');
    } catch (e) {
      const err = e as Error;
      error = err.message ?? 'Error inesperado al intentar autenticar.';
    } finally {
      loading = false;
    }
  }
</script>

<svelte:head>
  <title>Login</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <section class="form-container">
    <h1 class="title">Iniciar sesión</h1>
    <p class="subtitle">
      Ingresa y gestiona tus invitados.
    </p>

    <form class="form" on:submit|preventDefault={handleSubmit}>
      <div class="field">
        <label for="username" class="label">Usuario</label>
        <input
          id="username"
          name="username"
          class="input"
          bind:value={username}
          autocomplete="username"
          placeholder="Tu usuario"
        />
      </div>

      <div class="field">
        <label for="password" class="label">Contraseña</label>
        <input
          id="password"
          name="password"
          type="password"
          class="input"
          bind:value={password}
          autocomplete="current-password"
          placeholder="••••••••"
        />
      </div>

      {#if error}
        <p class="error">{error}</p>
      {/if}

      <button type="submit" class="btn-primary" disabled={loading}>
        {#if loading}
          Autenticando...
        {:else}
          Entrar
        {/if}
      </button>
    </form>
  </section>
</main>

<style>
  :global(body) {
    margin: 0;
    font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI',
      sans-serif;
    background: radial-gradient(circle at top, #027c68 0, #003333 55%, #001a1a 100%);
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
    opacity: 0.7;
    cursor: default;
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