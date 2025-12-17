export type SuiteDetail = {
    id_suite: string;
    capacidad: number;
    cupos_disponibles: number;
    invitados_inscritos: string[];
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