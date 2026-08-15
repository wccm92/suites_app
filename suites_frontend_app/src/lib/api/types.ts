export type InvitadoInscrito = {
    /** Cédula del invitado adulto (ya no llega prefijada con '0'). */
    invitado: string;
    /** Cantidad de amparados (menores de siete años) asociados a este invitado. */
    amparados: number;
};

export type SuiteDetail = {
    id_suite: string;
    capacidad: number;
    cupos_disponibles: number;
    invitados_inscritos: InvitadoInscrito[];
    suite_alquilada: boolean;
};


export type ErrorItem = {
    title: string;
    http_status: number;
    detail: string;
    code: string;
};

export type SuiteDetailError = {
    errors: ErrorItem[];
};

export type SuiteDetailOrError = SuiteDetail | SuiteDetailError;

export type Parqueadero = {
    id_parqueadero: string;
    estado: 'habilitado' | 'deshabilitado';
};

export type ParqueaderosResponse = {
    parqueadero: Parqueadero[];
};