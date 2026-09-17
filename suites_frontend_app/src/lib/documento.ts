/**
 * Validación y normalización de documentos de identidad.
 *
 * Un documento NO es siempre numérico: pasaportes y cédulas de extranjería llevan
 * letras. Antes cada pantalla tenía su propia copia de `/^\d{6,10}$/`, así que un
 * pasaporte se rechazaba en las cuatro y con mensajes distintos.
 *
 * Los límites (3 a 30 caracteres) son los que ya aplica el backend en los changesets
 * de `visitante` y `abonado` (`validate_length(min: 3, max: 30)`). Se replican aquí a
 * propósito: validar en el front más estricto que en el back produce documentos que la
 * API aceptaría y la pantalla rechaza, sin ninguna forma de que el usuario lo entienda.
 */

export const DOC_MIN = 3;
export const DOC_MAX = 30;

/**
 * Deja el documento en su forma canónica: sin espacios ni símbolos, y en mayúsculas.
 *
 * Las mayúsculas no son cosmética. El backend compara los documentos tal cual llegan
 * —la lista negra, el control de "ya registrado" y la clave primaria de `visitante` son
 * comparaciones exactas—, así que "ab1234" y "AB1234" serían dos personas distintas:
 * la misma persona podría registrarse dos veces, o esquivar la lista negra cambiando la
 * caja de una letra. Normalizar en la entrada lo evita de raíz.
 */
export function normalizarDocumento(valor: string): string {
  return valor
    .replace(/[^a-zA-Z0-9]/g, "")
    .toUpperCase()
    .slice(0, DOC_MAX);
}

/** Mensaje de error del documento, o cadena vacía si es válido. */
export function validarDocumento(valor: string): string {
  if (!valor) return "El documento es obligatorio.";
  if (valor.length < DOC_MIN)
    return `El documento debe tener entre ${DOC_MIN} y ${DOC_MAX} caracteres.`;
  if (valor.length > DOC_MAX)
    return `El documento no puede superar los ${DOC_MAX} caracteres.`;
  if (!/^[A-Z0-9]+$/.test(valor))
    return "El documento solo puede contener letras y números, sin espacios ni símbolos.";
  return "";
}

/** Aviso para cuando la normalización tuvo que descartar algo de lo tecleado. */
export const MENSAJE_CARACTERES_NO_VALIDOS =
  "Solo se permiten letras y números, sin espacios ni caracteres especiales.";

/**
 * Valor normalizado de un `<input>`, para usar directamente en `on:input`.
 *
 * Corregir mientras se escribe —y no solo al enviar— es lo que evita que alguien teclee
 * un documento con espacios o en minúsculas, lo vea tal cual en pantalla y crea que así
 * quedó registrado.
 */
export function normalizarDesdeEvento(event: Event): string {
  return normalizarDocumento((event.target as HTMLInputElement).value);
}
