// Tipos compartidos. Los campos de datos usan los mismos nombres que la base.

export type Rol = "ADMINISTRADOR" | "MEDICO" | "PACIENTE";
export type EstadoTurno = "PENDIENTE" | "CONFIRMADO" | "ATENDIDO" | "CANCELADO" | "AUSENTE";
export type Genero = "FEMENINO" | "MASCULINO" | "OTRO" | "NO_ESPECIFICADO";

/** Toda función devuelve un resultado en lugar de lanzar errores esperables. */
export type Resultado<T = null> = { ok: true; datos: T } | { ok: false; error: string };

export interface UsuarioActual {
  id: string;
  nombre_completo: string;
  correo_electronico: string | null;
  telefono: string | null;
  rol: Rol;
  /** id en la tabla medicos (sólo rol MEDICO). */
  medico_id: string | null;
  /** id en la tabla pacientes (sólo rol PACIENTE). */
  paciente_id: string | null;
}

export interface Especialidad {
  id: string;
  nombre: string;
  descripcion: string | null;
  esta_activa: boolean;
}

export interface Medico {
  id: string;
  perfil_id: string;
  nombre_completo: string;
  especialidad_id: string | null;
  especialidad: string | null;
  numero_matricula: string | null;
  /** dni, correo y teléfono sólo llegan si quien consulta es administrador. */
  dni: string | null;
  correo_electronico: string | null;
  telefono: string | null;
  esta_activo: boolean;
}

export interface Paciente {
  id: string;
  perfil_id: string;
  nombre_completo: string;
  correo_electronico: string | null;
  telefono: string | null;
  dni: string | null;
  fecha_nacimiento: string | null;
  genero: Genero | null;
  direccion: string | null;
  nombre_obra_social: string | null;
  numero_afiliado: string | null;
  esta_activo: boolean;
}

export interface HorarioMedico {
  id: string;
  medico_id: string;
  /** 0 = domingo ... 6 = sábado */
  dia_semana: number;
  /** "HH:MM:SS" */
  hora_inicio: string;
  hora_fin: string;
  /** minutos */
  duracion_turno: number;
  esta_activo: boolean;
}

export interface HorarioDisponible {
  fecha_inicio: string;
  fecha_fin: string;
}

export interface Turno {
  id: string;
  fecha_inicio: string;
  fecha_fin: string;
  estado: EstadoTurno;
  motivo: string | null;
  paciente_id: string;
  paciente_nombre: string;
  paciente_dni: string | null;
  medico_id: string;
  medico_nombre: string;
  especialidad: string | null;
  tiene_consulta: boolean;
}

export interface Consulta {
  id: string;
  fecha_consulta: string;
  motivo: string | null;
  diagnostico: string | null;
  tratamiento: string | null;
  medicacion: string | null;
  observaciones: string | null;
  turno_id: string | null;
  medico_id: string;
  medico_nombre: string;
  especialidad: string | null;
}

// ---- Datos de entrada ----

export interface DatosPaciente {
  nombre_completo: string;
  telefono?: string;
  dni?: string;
  fecha_nacimiento?: string;
  genero?: Genero;
  direccion?: string;
  nombre_obra_social?: string;
  numero_afiliado?: string;
}

export interface DatosNuevoPaciente extends DatosPaciente {
  correo_electronico: string;
  contrasena: string;
}

export interface DatosMedico {
  nombre_completo: string;
  telefono?: string;
  especialidad_id?: string;
  dni?: string;
  numero_matricula?: string;
}

export interface DatosNuevoMedico extends DatosMedico {
  correo_electronico: string;
  contrasena: string;
}

export interface FiltrosTurnos {
  desde?: string;
  hasta?: string;
  estado?: EstadoTurno;
  medico_id?: string;
  paciente_id?: string;
}

export interface DatosConsulta {
  diagnostico: string;
  tratamiento?: string;
  medicacion?: string;
  observaciones?: string;
  motivo?: string;
}
