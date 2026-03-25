<script lang="ts">
  import '$lib/styles/brand-theme.css';
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { page } from '$app/stores';
  import { session } from '$lib/stores/session';

  // Ocultar en /login (considera base = '' en local y '/suites' en prod)
  $: isLogin =
    $page.url.pathname === `${base}/login` ||
    $page.url.pathname === `${base}/login/`;

  async function logout() {
    session.clear(); // borra JWT del localStorage (app_session)
    await goto(`${base}/login`);
  }
</script>

{#if !isLogin}
  <button class="logout-btn" type="button" on:click={logout}>
    Cerrar sesión
  </button>
{/if}

<slot />

<style>
  .logout-btn {
    position: fixed;
    top: 12px;
    right: 12px;
    z-index: 9999;

    padding: 0.45rem 0.9rem;
    border-radius: 999px;
    border: 1px solid #c0ddd4;
    background: #ffffff;
    color: var(--color-primary);
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 4px 14px rgba(0, 89, 64, 0.14);
    transition: background 0.15s ease, border-color 0.15s ease;
  }

  .logout-btn:hover {
    border-color: var(--color-primary);
    background: #edf7f2;
  }

  @media (max-width: 768px) {
    .logout-btn {
      top: 10px;
      right: 10px;
      padding: 0.4rem 0.75rem;
      font-size: 0.85rem;
    }
  }
</style>