// src/lib/api/mocks.ts
//
// Servicio de mocks MUY sencillo y no intrusivo para simular los llamados a
// las APIs de "abonados" y al registro de visitantes (validate_guest /
// register_guests) mientras el backend está listo.
//
// Cómo funciona:
//   - `apiFetch` (en client.ts) llama a `mockFetch(path, options)` solo si
//     `USE_MOCKS` está activo.
//   - Si el path coincide con un endpoint mockeado, devuelve un `Response`
//     real (mismas formas que el backend) y NO se hace la petición de red.
//   - Si no coincide, devuelve `null` y `apiFetch` sigue con el fetch normal.
//
// Para desactivarlo cuando exista el backend: pon USE_MOCKS = false (o borra
// la línea del enganche en client.ts). Ningún componente/página depende de él.

/** Interruptor global de los mocks. Cambia a `false` cuando haya backend real. */
export const USE_MOCKS = false;

// ── "Base de datos" en memoria: id_suite -> Set de cédulas ────────────────
const db = new Map<string, Set<string>>();

// Datos de ejemplo para que el listado no arranque vacío.
db.set("demo", new Set(["1001234567", "1009876543", "1122334455"]));

function suiteSet(idSuite: string): Set<string> {
  let set = db.get(idSuite);
  if (!set) {
    set = new Set<string>();
    db.set(idSuite, set);
  }
  return set;
}

/** Pequeña latencia para simular la red. */
function delay(ms = 350): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Construye un `Response` JSON como los que devolvería el backend. */
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/**
 * Intercepta los endpoints de abonados. Devuelve un `Response` mockeado si el
 * path coincide, o `null` para que `apiFetch` continúe con el fetch real.
 */
export async function mockFetch(
  path: string,
  options: RequestInit = {}
): Promise<Response | null> {
  const body = parseBody(options.body);

  // 1) GET listado de abonados de una suite
  //    /suites_app/get_season_ticket_holders/:idSuite
  const getMatch = path.match(/^\/suites_app\/get_season_ticket_holders\/(.+)$/);
  if (getMatch) {
    await delay();
    const idSuite = decodeURIComponent(getMatch[1]);
    const abonados = Array.from(suiteSet(idSuite)).map((id_abonado) => ({
      id_abonado,
    }));
    return json({ abonados });
  }

  // 2) POST registrar un abonado
  if (path === "/suites_app/register_season_ticket_holder") {
    await delay();
    const idSuite = String(body?.id_suite ?? "");
    const cedula = String(body?.id_season_ticket_holder ?? "");
    const set = suiteSet(idSuite);
    if (set.has(cedula)) {
      // El front trata cualquier `detail` con "error" como fallo.
      return json({ detail: "error: el abonado ya se encuentra registrado" });
    }
    set.add(cedula);
    return json({ detail: "Abonado registrado exitosamente" });
  }

  // 3) POST eliminar múltiples abonados
  if (path === "/suites_app/delete_season_ticket_holders") {
    await delay();
    const idSuite = String(body?.id_suite ?? "");
    const holders: string[] = Array.isArray(body?.season_ticket_holders)
      ? body.season_ticket_holders.map(String)
      : [];
    const set = suiteSet(idSuite);
    const deleted: string[] = [];
    for (const h of holders) {
      if (set.delete(h)) deleted.push(h);
    }
    return json({ successful_deleted_season_ticket_holders: deleted });
  }

  // 4) POST validar una cédula antes de agregarla (Paso 1 del wizard)
  //    Cualquier cédula que NO esté en BLOCKED_CEDULAS se considera válida.
  if (path === "/suites_app/validate_guest") {
    await delay(250);
    const cedula = String(body?.invitado ?? "");
    if (BLOCKED_CEDULAS.has(cedula)) {
      return json(
        { errors: [{ code: "05", detail: "El visitante está reportado por logística." }] },
        409
      );
    }
    return json({ detail: "Visitante válido" });
  }

  // 5) POST registro de visitantes (nuevo shape multi-amparado)
  //    Request: { id_suite, invitados: { "1": {invitado, amparados:[uuid...]}, ... } }
  if (path === "/suites_app/register_guests") {
    await delay(500);
    const invitadosObj =
      body?.invitados && typeof body.invitados === "object"
        ? (body.invitados as Record<string, { invitado?: string; amparados?: string[] }>)
        : {};

    const successful_registrations: string[] = [];
    const not_registered_already_suites: string[] = [];
    const successful_registrations_amparados: Record<
      string,
      { sponsor: string; amparados: string[] }
    > = {};

    let idx = 1;
    for (const entry of Object.values(invitadosObj)) {
      const ced = String(entry?.invitado ?? "");
      if (!ced) continue;
      const amparados = Array.isArray(entry?.amparados)
        ? entry.amparados.map(String)
        : [];

      // Simula rechazo si la cédula ya está "en otra suite" del evento.
      if (ALREADY_IN_SUITES.has(ced)) {
        not_registered_already_suites.push(ced);
        continue;
      }

      successful_registrations.push(ced);
      successful_registrations_amparados[String(idx)] = {
        sponsor: ced,
        amparados,
      };
      idx += 1;
    }

    return json({
      successful_registrations,
      successful_registrations_amparados,
      not_registered_blocked: [],
      not_registered_already_suites,
    });
  }

  // No es un endpoint mockeado → seguir con el fetch real.
  return null;
}

// Cédulas de prueba para forzar caminos de error en el wizard de visitantes.
// (Ajusta libremente mientras pruebas; vacías = todo pasa.)
const BLOCKED_CEDULAS = new Set<string>([]); // reportadas por logística (validate_guest → 409)
const ALREADY_IN_SUITES = new Set<string>([]); // ya registradas en el evento (register_guests)

/** Parsea el body (string JSON) de las peticiones POST de forma segura. */
function parseBody(raw: BodyInit | null | undefined): any {
  if (typeof raw !== "string") return {};
  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
}
