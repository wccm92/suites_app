// src/lib/api/mocks.ts
//
// Servicio de mocks MUY sencillo y no intrusivo para simular los llamados a
// las APIs mientras el backend está listo (abonados, suites y registro de
// visitantes / amparados).
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

/** Interruptor global de los mocks. Cambia a `true` para ejercitar los mocks. */
export const USE_MOCKS = false;

// ── "Base de datos" en memoria: abonados (id_suite -> Set de cédulas) ─────
const db = new Map<string, Set<string>>();
db.set("demo", new Set(["1001234567", "1009876543", "1122334455"]));

function suiteSet(idSuite: string): Set<string> {
  let set = db.get(idSuite);
  if (!set) {
    set = new Set<string>();
    db.set(idSuite, set);
  }
  return set;
}

// ── "Base de datos" en memoria: suites y sus invitados ────────────────────
// Cada invitado adulto lleva un CONTEO de amparados (menores de siete años),
// acorde a la nueva forma del API `/suites_app/suites/{id}`.
type MockInvitado = { invitado: string; amparados: number };
type MockSuite = {
  id_suite: string;
  capacidad: number;
  suite_alquilada: boolean;
  invitados: MockInvitado[];
};

const suitesDb = new Map<string, MockSuite>();
suitesDb.set("DEMO1", {
  id_suite: "DEMO1",
  capacidad: 10,
  suite_alquilada: false,
  invitados: [],
});
suitesDb.set("DEMO2", {
  id_suite: "DEMO2",
  capacidad: 6,
  suite_alquilada: false,
  invitados: [{ invitado: "1122334455", amparados: 0 }],
});
suitesDb.set("DEMO3", {
  id_suite: "DEMO3",
  capacidad: 8,
  suite_alquilada: false,
  invitados: [
    { invitado: "1231414212", amparados: 2 },
    { invitado: "1241241241", amparados: 1 },
    { invitado: "1414141414", amparados: 0 },
  ],
});

/** Cupos libres = capacidad − (adultos + amparados). Cada uno ocupa un cupo. */
function cuposDisponibles(s: MockSuite): number {
  const usados = s.invitados.reduce(
    (acc, i) => acc + 1 + (i.amparados ?? 0),
    0
  );
  return Math.max(0, s.capacidad - usados);
}

/** Arma el detalle de una suite con la forma que devuelve el backend. */
function suiteDetail(s: MockSuite) {
  return {
    id_suite: s.id_suite,
    capacidad: s.capacidad,
    cupos_disponibles: cuposDisponibles(s),
    suite_alquilada: s.suite_alquilada,
    invitados_inscritos: s.invitados.map((i) => ({
      invitado: i.invitado,
      amparados: i.amparados,
    })),
  };
}

/** Resúmenes para el listado de suites (owner y leaseholder). */
function suiteSummaries() {
  return Array.from(suitesDb.values()).map((s) => ({
    id_suite: s.id_suite,
    capacidad: s.capacidad,
  }));
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
 * Intercepta los endpoints mockeados. Devuelve un `Response` si el path
 * coincide, o `null` para que `apiFetch` continúe con el fetch real.
 */
export async function mockFetch(
  path: string,
  options: RequestInit = {}
): Promise<Response | null> {
  const body = parseBody(options.body);

  // ── Abonados ────────────────────────────────────────────────────────

  // GET listado de abonados de una suite
  const getMatch = path.match(/^\/suites_app\/get_season_ticket_holders\/(.+)$/);
  if (getMatch) {
    await delay();
    const idSuite = decodeURIComponent(getMatch[1]);
    const abonados = Array.from(suiteSet(idSuite)).map((id_abonado) => ({
      id_abonado,
    }));
    return json({ abonados });
  }

  // POST registrar un abonado
  if (path === "/suites_app/register_season_ticket_holder") {
    await delay();
    const idSuite = String(body?.id_suite ?? "");
    const cedula = String(body?.id_season_ticket_holder ?? "");
    const set = suiteSet(idSuite);
    if (set.has(cedula)) {
      return json({ detail: "error: el abonado ya se encuentra registrado" });
    }
    set.add(cedula);
    return json({ detail: "Abonado registrado exitosamente" });
  }

  // POST eliminar múltiples abonados
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

  // ── Suites ──────────────────────────────────────────────────────────

  // GET listado de suites (owner y leaseholder comparten forma)
  if (
    path === "/suites_app/suites" ||
    path === "/suites_app/suites_leaseholder"
  ) {
    await delay();
    return json(suiteSummaries());
  }

  // GET detalle de una suite (nueva forma: invitados con conteo de amparados)
  const suiteMatch = path.match(/^\/suites_app\/suites\/(.+)$/);
  if (suiteMatch) {
    await delay();
    const id = decodeURIComponent(suiteMatch[1]);
    const s = suitesDb.get(id);
    if (!s) {
      return json(
        {
          errors: [
            {
              title: "error",
              http_status: 404,
              detail: "Suite no encontrada.",
              code: "404",
            },
          ],
        },
        404
      );
    }
    return json(suiteDetail(s));
  }

  // POST alquilar una suite
  const rentMatch = path.match(/^\/suites_app\/rent_suite\/(.+)$/);
  if (rentMatch) {
    await delay();
    const id = decodeURIComponent(rentMatch[1]);
    const s = suitesDb.get(id);
    if (!s) {
      return json({ errors: [{ detail: "Suite no encontrada." }] }, 404);
    }
    if (s.invitados.length > 0) {
      return json(
        { errors: [{ detail: "No se puede alquilar: la suite ya tiene visitantes." }] },
        409
      );
    }
    s.suite_alquilada = true;
    return json({ detail: "Suite alquilada correctamente" });
  }

  // ── Visitantes / amparados ──────────────────────────────────────────

  // POST validar una cédula antes de agregarla (Paso 1 del wizard)
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

  // POST registro de visitantes (multi-amparado, listas planas)
  //   Request: { id_suite, invitados: [ {invitado, amparados:[uuid...]}, ... ] }
  if (path === "/suites_app/register_guests") {
    await delay(500);
    const id = String(body?.id_suite ?? "");
    const s = suitesDb.get(id);
    const invitadosArr: { invitado?: string; amparados?: string[] }[] =
      Array.isArray(body?.invitados) ? body.invitados : [];

    const successful_registrations: string[] = [];
    const not_registered_already_suites: string[] = [];
    const successful_registrations_amparados: {
      sponsor: string;
      amparados: string[];
    }[] = [];

    for (const entry of invitadosArr) {
      const ced = String(entry?.invitado ?? "");
      if (!ced) continue;
      const amparados = Array.isArray(entry?.amparados)
        ? entry.amparados.map(String)
        : [];

      if (ALREADY_IN_SUITES.has(ced)) {
        not_registered_already_suites.push(ced);
        continue;
      }

      successful_registrations.push(ced);
      successful_registrations_amparados.push({ sponsor: ced, amparados });

      // Reflejar en el modelo de la suite para que el detalle se actualice.
      if (s) {
        const existing = s.invitados.find((i) => i.invitado === ced);
        if (existing) existing.amparados += amparados.length;
        else s.invitados.push({ invitado: ced, amparados: amparados.length });
      }
    }

    return json({
      successful_registrations,
      successful_registrations_amparados,
      not_registered_blocked: [],
      not_registered_already_suites,
    });
  }

  // POST registrar amparados a un invitado existente (contador → UUIDs)
  //   Request: { id_suite, invitado, amparados: [uuid...] }
  if (path === "/suites_app/register_amparado") {
    await delay();
    const id = String(body?.id_suite ?? "");
    const invitado = String(body?.invitado ?? "");
    const amparados: string[] = Array.isArray(body?.amparados)
      ? body.amparados.map(String)
      : [];
    const s = suitesDb.get(id);
    const target = s?.invitados.find((i) => i.invitado === invitado);
    if (!s || !target) {
      return json({ title: "error", detail: "No se encontró el invitado en la suite." });
    }
    target.amparados += amparados.length;
    return json({ detail: "Amparados registrados correctamente", title: "success" });
  }

  // POST quitar un visitante de la suite
  if (path === "/suites_app/delete_guest") {
    await delay();
    const id = String(body?.id_suite ?? "");
    const invitado = String(body?.invitado ?? "");
    const s = suitesDb.get(id);
    if (!s) {
      return json({ title: "error", detail: "Suite no encontrada." });
    }
    const before = s.invitados.length;
    s.invitados = s.invitados.filter((i) => i.invitado !== invitado);
    if (s.invitados.length === before) {
      return json({ title: "error", detail: "El visitante no estaba inscrito." });
    }
    return json({ title: "success", detail: "Visitante eliminado exitosamente" });
  }

  // POST reemplazar un visitante por otra cédula
  if (path === "/suites_app/replace_guest") {
    await delay();
    const id = String(body?.id_suite ?? "");
    const invitado = String(body?.invitado ?? "");
    const nuevo = String(body?.nuevo_invitado ?? "");
    const s = suitesDb.get(id);
    const target = s?.invitados.find((i) => i.invitado === invitado);
    if (!s || !target) {
      return json({ title: "error", detail: "No se encontró el visitante a reemplazar." });
    }
    if (s.invitados.some((i) => i.invitado === nuevo)) {
      return json({ title: "error", detail: "La nueva cédula ya está inscrita en la suite." });
    }
    // El nuevo visitante entra sin amparados; el front luego preguntará cuántos.
    target.invitado = nuevo;
    target.amparados = 0;
    return json({ title: "success", detail: "Visitante reemplazado exitosamente" });
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
