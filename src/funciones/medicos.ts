"use server";

import { crearClienteAdmin } from "@/lib/supabase/admin";
import { crearClienteServidor } from "@/lib/supabase/servidor";
import type { DatosMedico, DatosNuevoMedico, Medico, Resultado } from "./tipos";
import { esAdministrador, fallo, limpiar, mensajeError, ok } from "./utilidades";

/** Cualquier usuario logueado. Los inactivos sólo los ve el administrador. */
export async function listarMedicos(
  filtros: { especialidad_id?: string; incluir_inactivos?: boolean } = {},
): Promise<Resultado<Medico[]>> {
  const supabase = await crearClienteServidor();
  const { data, error } = await supabase.rpc("listar_medicos", {
    p_especialidad_id: filtros.especialidad_id ?? null,
    p_incluir_inactivos: filtros.incluir_inactivos ?? false,
  });
  return error ? fallo(mensajeError(error)) : ok(data as Medico[]);
}

/** Sólo administrador. Crea el usuario de acceso y la ficha del médico. */
export async function crearMedico(datos: DatosNuevoMedico): Promise<Resultado<{ perfil_id: string }>> {
  if (!(await esAdministrador())) return fallo("No tenés permisos para realizar esta acción.");

  const { correo_electronico, contrasena, ...personales } = datos;
  if (!personales.nombre_completo?.trim()) return fallo("El nombre es obligatorio.");
  if (contrasena.length < 6) return fallo("La contraseña debe tener al menos 6 caracteres.");

  const { data, error } = await crearClienteAdmin().auth.admin.createUser({
    email: correo_electronico.trim(),
    password: contrasena,
    email_confirm: true,
    app_metadata: { rol: "MEDICO" },
    user_metadata: limpiar(personales),
  });
  if (error) {
    return fallo(
      error.message.includes("Database error")
        ? "No se pudo crear el médico: verificá que el DNI y la matrícula no estén registrados."
        : error.message,
    );
  }
  return ok({ perfil_id: data.user.id });
}

/** Sólo administrador. esta_activo: false desactiva la agenda y el acceso al sistema. */
export async function actualizarMedico(
  medicoId: string,
  datos: Partial<DatosMedico> & { esta_activo?: boolean },
): Promise<Resultado> {
  if (!(await esAdministrador())) return fallo("No tenés permisos para realizar esta acción.");

  const supabase = await crearClienteServidor();
  const { data: medico } = await supabase
    .from("medicos")
    .select("perfil_id")
    .eq("id", medicoId)
    .maybeSingle();
  if (!medico) return fallo("Médico no encontrado.");

  const { nombre_completo, telefono, esta_activo, ...ficha } = datos;

  const cambiosPerfil = limpiar({ nombre_completo, telefono, esta_activo });
  if (Object.keys(cambiosPerfil).length) {
    const { error } = await supabase.from("perfiles").update(cambiosPerfil).eq("id", medico.perfil_id);
    if (error) return fallo(mensajeError(error));
  }

  const cambiosMedico = limpiar({ ...ficha, esta_activo });
  if (Object.keys(cambiosMedico).length) {
    const { error } = await supabase.from("medicos").update(cambiosMedico).eq("id", medicoId);
    if (error) return fallo(mensajeError(error));
  }

  return ok(null);
}
