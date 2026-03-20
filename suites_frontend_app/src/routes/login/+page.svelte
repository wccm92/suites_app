<script lang="ts">
  import { goto } from "$app/navigation";
  import { base } from "$app/paths";
  import { onMount } from "svelte";
  import { get } from "svelte/store";
  import { session } from "$lib/stores/session";
  import { apiFetch } from "$lib/api/client";

  let username = "";
  let password = "";
  let loading = false;
  let loadingLeaseholder = false;
  let error = "";

  onMount(async () => {
    // 1) Verificar si hay evento
    try {
      const eventRes = await apiFetch("/suites_app/get-event", { auth: false });

      if (!eventRes.ok) {
        await goto(`${base}/no-event`);
        return;
      }
    } catch (e) {
      console.error("Error consultando /get-event:", e);
      // Si falla, preferimos mostrar login que romper
    }

    // 2) Si ya hay JWT, validar sesión con backend
    const { jwt } = get(session);
    if (!jwt) return;

    try {
      const res = await apiFetch("/suites_app/validate-session");
      if (res.status === 200) {
        await goto(`${base}/`);
      } else if (res.status === 401) {
        session.clear();
        error = "Tu sesión ha expirado, por favor inicia sesión de nuevo.";
      } else {
        console.warn("Respuesta inesperada validate-session:", res.status);
      }
    } catch (e) {
      console.error("Error validando sesión:", e);
    }
  });

  async function handleSubmit(event: Event) {
    event.preventDefault();
    error = "";
    loading = true;

    try {
      if (!username || !password) {
        error = "Usuario y contraseña son obligatorios.";
        return;
      }

      const res = await apiFetch("/suites_app/login", {
        auth: false,
        method: "POST",
        body: JSON.stringify({ username, password }),
      });

      if (!res.ok) {
        const json = (await res.json()) as {
          errors: {
            title: string;
            http_status: number;
            detail: string;
            code: string;
          }[];
        };

        const code = json.errors[0]?.code;

        if (code == "01") {
          error = "Credenciales inválidas";
          return;
        }
        if (code == "02") {
          error = "Usuario bloqueado";
          return;
        }
        error = json.errors[0]?.detail ?? "Error al iniciar sesión.";
        return;
      }

      const body = (await res.json()) as { token: string };

      if (!body.token) {
        error = "El servidor no devolvió un token de autenticación.";
        return;
      }

      session.setJwt(body.token);
      password = "";
      await goto(`${base}/`);
    } catch (e) {
      const err = e as Error;
      error = err.message ?? "Error inesperado al intentar autenticar.";
    } finally {
      loading = false;
    }
  }

  async function handleLeaseholderLogin() {
    error = "";
    loadingLeaseholder = true;

    try {
      if (!username || !password) {
        error = "Usuario y contraseña son obligatorios.";
        return;
      }

      const res = await apiFetch("/suites_app/login_leaseholder", {
        auth: false,
        method: "POST",
        body: JSON.stringify({ username, password }),
      });

      if (!res.ok) {
        const json = (await res.json()) as {
          errors: {
            title: string;
            http_status: number;
            detail: string;
            code: string;
          }[];
        };

        const code = json.errors[0]?.code;

        if (code == "01") {
          error = "Credenciales inválidas";
          return;
        }
        if (code == "02") {
          error = "Usuario bloqueado";
          return;
        }
        error = json.errors[0]?.detail ?? "Error al iniciar sesión.";
        return;
      }

      const body = (await res.json()) as { token: string };

      if (!body.token) {
        error = "El servidor no devolvió un token de autenticación.";
        return;
      }

      session.setJwt(body.token);
      password = "";
      await goto(`${base}/arriendos`);
    } catch (e) {
      const err = e as Error;
      error = err.message ?? "Error inesperado al intentar autenticar.";
    } finally {
      loadingLeaseholder = false;
    }
  }

  function goToForgotPassword() {
    goto(`${base}/forgot-password`);
  }
</script>

<svelte:head>
  <title>Login</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <section class="form-container">
    <h1 class="title">Iniciar sesión</h1>
    <p class="subtitle">Autentícate para gestionar las suites del evento.</p>

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

      <button type="submit" class="btn-primary" disabled={loading || loadingLeaseholder}>
        {#if loading}
          Autenticando...
        {:else}
          Ingresar como propietario
        {/if}
      </button>

      <div class="divider"><span>o</span></div>

      <button
        type="button"
        class="btn-secondary"
        disabled={loading || loadingLeaseholder}
        on:click={handleLeaseholderLogin}
      >
        {#if loadingLeaseholder}
          Autenticando...
        {:else}
          Ingresar como arrendatario
        {/if}
      </button>

      <button
        type="button"
        class="btn-link-forgot"
        on:click={goToForgotPassword}
      >
        Olvidé mi contraseña
      </button>
      <!-- 👇 AQUÍ VA EL ESCUDO (debajo de "Olvidé mi contraseña") -->
      <div class="login-shield">
        <img
          src={`${base}/images/main_logo_v2.png`}
          alt="Escudo Deportivo Cali"
        />
      </div>
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
    background: var(--color-surface);
    border-radius: 1rem;
    padding: 1.5rem 1.7rem;
    border: 1px solid var(--color-primary);
    box-shadow: 0 12px 25px rgba(0, 0, 0, 0.55);
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
    border: 1px solid var(--color-primary);
    background: var(--color-surface-soft);
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
    background: var(--color-primary);
    color: var(--color-text-main);
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

  .divider {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    color: var(--color-text-muted);
    font-size: 0.8rem;
    margin: 0.1rem 0;
  }

  .divider::before,
  .divider::after {
    content: '';
    flex: 1;
    height: 1px;
    background: var(--color-primary);
  }

  .btn-secondary {
    padding: 0.6rem 1rem;
    border-radius: 999px;
    border: none;
    background: var(--color-primary);
    color: var(--color-text-main);
    font-size: 0.95rem;
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 10px 25px rgba(0, 51, 51, 0.6);
    transition:
      transform 0.12s ease,
      box-shadow 0.12s ease,
      background 0.12s ease;
  }

  .btn-secondary:hover:enabled {
    transform: translateY(-1px);
    box-shadow: 0 14px 30px rgba(0, 51, 51, 0.85);
    background: #009933;
  }

  .btn-secondary:active:enabled {
    transform: translateY(0);
    box-shadow: 0 8px 18px rgba(0, 51, 51, 0.9);
  }

  .btn-secondary:disabled {
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

  .btn-link-forgot {
    margin-top: 0.6rem;
    border: none;
    background: transparent;
    font-size: 0.85rem;
    color: var(--color-success);
    cursor: pointer;
    text-decoration: underline;
    align-self: flex-start;
    padding: 0;
  }

  .btn-link-forgot:hover {
    color: #e0ffd0;
  }

  .form-container {
    display: flex;
    flex-direction: column;
    min-height: calc(
      100vh - 3rem
    ); /* 3rem ≈ padding vertical de .page (1.5rem arriba + abajo) */
  }

  .form {
    flex: 1;
    display: flex;
    flex-direction: column;
  }

  .login-shield {
    margin-top: 0.75rem; /* “justo debajo” del link */
    padding-bottom: 0.5rem; /* separa un poco del borde inferior */
    display: flex;
    justify-content: center;
  }

  .login-shield img {
    width: min(220px, 70%);
    height: auto;
    opacity: 0.95;
  }
</style>
