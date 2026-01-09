<svelte:head>
  <title>Sin eventos disponibles</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <section class="box">
    <h1 class="title">Sin eventos disponibles</h1>
    <p class="text">
      En este momento no hay ningún evento activo para gestionar suites.
      Por favor, inténtalo más tarde o contacta al administrador.
    </p>
  </section>
</main>

<style>

  .page {
    min-height: 100vh;
    display: flex;
    justify-content: center;
    padding: 1.5rem;
  }

  .box {
    width: 100%;
    max-width: 480px;
    background: var(--color-surface);
    border-radius: 1rem;
    padding: 1.5rem 1.7rem;
    border: 1px solid var(--color-primary);
    box-shadow: 0 12px 25px rgba(0, 0, 0, 0.55);
    text-align: center;
  }

  .title {
    font-size: 1.5rem;
    font-weight: 700;
    margin: 0 0 0.75rem;
    color: var(--color-success);
  }

  .text {
    font-size: 0.95rem;
    color: var(--color-text-muted);
    margin: 0;
  }
</style>