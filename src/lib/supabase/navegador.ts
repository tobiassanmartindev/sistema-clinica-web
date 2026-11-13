import { createBrowserClient } from "@supabase/ssr";

/** Cliente de Supabase para componentes de cliente. */
export function crearClienteNavegador() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
