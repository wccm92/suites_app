import type { SuiteDetailOrError, SuiteDetail, SuiteDetailError, ErrorItem } from '$lib/api/types';

export function isSuiteDetailError(body: unknown): body is SuiteDetailError {
  const b = body as any;

  return (
    b &&
    typeof b === 'object' &&
    Array.isArray(b.errors) &&
    b.errors.length > 0 &&
    typeof b.errors[0]?.code === 'string'
  );
}

export function isSuiteDetail(body: any): body is SuiteDetail {
  return (
    body &&
    typeof body === 'object' &&
    typeof body.id_suite === 'string' &&
    typeof body.capacidad === 'string'
  );
}