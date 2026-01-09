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
    border: 1px solid #027c68;
    background: #001f1f;
    color: #b0e892;
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.35);
  }

  .logout-btn:hover {
    border-color: #009933;
    background: #014040;
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