<script lang="ts">
  import { goto } from "$app/navigation";
  import { base } from "$app/paths";
  import { page } from "$app/stores";
  import { get } from "svelte/store";
  import { session } from "$lib/stores/session";

  // ── Suite params (desde la query string) ──────────────────────────────
  let suiteId = "";
  let capacidad = 0;
  let cuposDisponiblesRaw: string | null = null;
  let cuposDisponiblesNum = 0;
  let cuposDisponiblesSafe = 0;

  $: suiteId = $page.url.searchParams.get("id_suite") ?? "";
  $: capacidad = Number($page.url.searchParams.get("capacidad") ?? "0");
  $: cuposDisponiblesRaw = $page.url.searchParams.get("cupos_disponibles");
  $: cuposDisponiblesNum = Number(cuposDisponiblesRaw ?? "0");
  $: cuposDisponiblesSafe =
    Number.isFinite(cuposDisponiblesNum) && cuposDisponiblesNum > 0
      ? cuposDisponiblesNum
      : 0;

  // ── Navegación ────────────────────────────────────────────────────────
  function getHomeRoute(): string {
    const { jwt } = get(session);
    if (!jwt) return `${base}/`;
    try {
      const payload = JSON.parse(atob(jwt.split(".")[1]));
      if (payload?.profile === "leaseholder") return `${base}/arriendos`;
    } catch {}
    return `${base}/`;
  }

  function handleBack() {
    goto(getHomeRoute());
  }
</script>

<svelte:head>
  <title>Gestionar suite</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<main class="page">
  <section class="form-container">
    <div class="step-heading">
      <h1 class="step-title">Gestionar suite</h1>
    </div>

    <!-- ── Suite meta ─────────────────────────────────────────────────── -->
    <div class="suite-meta">
      <span class="suite-id-label">Suite: <strong>{suiteId || "—"}</strong></span>
      <div class="suite-stats">
        <span class="stat-pill">
          Capacidad: <strong>{capacidad}</strong>
        </span>
        <span class="stat-pill {cuposDisponiblesSafe === 0 ? 'stat-pill--zero' : ''}">
          Cupos disponibles: <strong>{cuposDisponiblesSafe}</strong>
        </span>
      </div>
    </div>

    <!-- ── Contenido (pendiente de lógica) ────────────────────────────── -->
    <div class="placeholder">
      <p class="placeholder-text">
        Desde aquí podrás gestionar la suite. Las opciones estarán disponibles próximamente.
      </p>
    </div>

    <div class="step-actions">
      <button type="button" class="btn-back" on:click={handleBack}>
        Volver
      </button>
    </div>
  </section>
</main>

<style>
  .form-container {
    width: min(680px, 100%);
    margin: 0 auto;
    padding: 1.5rem 1.6rem 1.8rem;
    display: flex;
    flex-direction: column;
    gap: 1.2rem;
  }

  .step-heading {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.75rem;
  }

  .step-title {
    margin: 0;
    font-size: clamp(1.3rem, 1.05rem + 1vw, 1.7rem);
    font-weight: 700;
    color: var(--color-text-main);
  }

  /* ── Suite meta ───────────────────────────────────────────────────── */
  .suite-meta {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: 0.6rem;
    padding: 0.75rem 0.9rem;
    background: #edf7f2;
    border: 1px solid #c8e6d8;
    border-radius: var(--radius-lg);
  }

  .suite-id-label {
    font-size: 0.95rem;
    color: var(--color-text-main);
  }

  .suite-stats {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .stat-pill {
    display: inline-flex;
    align-items: center;
    padding: 0.3rem 0.8rem;
    border-radius: 999px;
    background: #ffffff;
    border: 1px solid #c0ddd4;
    font-size: 0.85rem;
    color: var(--color-text-muted);
  }

  .stat-pill strong {
    margin-left: 0.3rem;
    color: var(--color-text-main);
    font-weight: 700;
  }

  .stat-pill--zero {
    background: #fff5f5;
    border-color: var(--color-error-soft);
    color: var(--color-error);
  }

  .stat-pill--zero strong {
    color: var(--color-error);
  }

  /* ── Placeholder ──────────────────────────────────────────────────── */
  .placeholder {
    padding: 2rem 1rem;
    text-align: center;
    border: 1px dashed #c8e6d8;
    border-radius: var(--radius-lg);
    background: #f9fdfb;
  }

  .placeholder-text {
    margin: 0;
    font-size: 0.95rem;
    color: var(--color-text-muted);
  }

  /* ── Acciones ─────────────────────────────────────────────────────── */
  .step-actions {
    display: flex;
    justify-content: flex-start;
  }

  .btn-back {
    padding: 0.5rem 1.3rem;
    border-radius: var(--radius-pill);
    border: 1px solid #c0ddd4;
    background: #ffffff;
    color: var(--color-primary);
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    transition:
      background 0.12s ease,
      border-color 0.12s ease;
  }

  .btn-back:hover {
    background: #edf7f2;
    border-color: var(--color-primary);
  }

  @media (max-width: 768px) {
    .form-container {
      padding: 1.2rem 1rem 1.4rem;
    }

    .suite-meta {
      flex-direction: column;
      align-items: flex-start;
    }

    .step-actions {
      justify-content: stretch;
    }

    .btn-back {
      width: 100%;
      text-align: center;
    }
  }
</style>
