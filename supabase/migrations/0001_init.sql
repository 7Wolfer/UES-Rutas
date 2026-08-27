-- UES Rutas · esquema inicial (Supabase / Postgres)
-- Espeja los modelos de `lib/data/models.dart`. Todavía NO se usa desde la app
-- (fase actual = seed local en assets/seed/). Sirve como referencia y como
-- primer migration cuando se conecte Supabase.

-- ---------------------------------------------------------------------------
-- Catálogo del campus
-- ---------------------------------------------------------------------------

create table if not exists edificios (
  id          text primary key,
  clave       text not null,               -- "A", "B", "BIB"  → "EDIFICIO A"
  nombre      text not null,
  descripcion text not null default '',
  -- rect del mapa ilustrativo mientras no haya planos: [left, top, w, h]
  rect        double precision[] not null,
  niveles     int[] not null default '{0}',
  creado_en   timestamptz not null default now()
);

create type tipo_espacio as enum ('aula', 'oficina', 'servicio', 'edificio', 'exterior');

create table if not exists espacios (
  id           text primary key,
  tipo         tipo_espacio not null,
  nombre       text not null,
  edificio_id  text references edificios(id) on delete set null,
  nivel        int not null default 0,
  -- coordenadas del mapa ilustrativo; migrar a geography(Point) con PostGIS
  punto_x      double precision not null,
  punto_y      double precision not null,
  categoria    text not null default 'aula',
  accesible    boolean not null default false,
  numero_aula  text,
  descripcion  text not null default '',
  actualizado_en timestamptz not null default now()
);
create index if not exists espacios_edificio_idx on espacios(edificio_id, nivel);

create table if not exists docentes (
  id                  text primary key,
  nombre              text not null,
  departamento        text not null default '',
  correo              text not null default '',
  oficina_espacio_id  text references espacios(id) on delete set null,
  foto_url            text,
  actualizado_en      timestamptz not null default now()
);

create table if not exists asignaciones (
  id           bigint generated always as identity primary key,
  docente_id   text not null references docentes(id) on delete cascade,
  espacio_id   text not null references espacios(id) on delete restrict,
  materia      text not null,
  grupo        text not null default '',
  dia          int not null check (dia between 1 and 7),   -- 1 = lunes
  hora_inicio  int not null,
  min_inicio   int not null default 0,
  hora_fin     int not null,
  min_fin      int not null default 0
);
create index if not exists asignaciones_docente_idx on asignaciones(docente_id);
create index if not exists asignaciones_espacio_idx on asignaciones(espacio_id);

-- ---------------------------------------------------------------------------
-- Grafo de ruteo peatonal
-- ---------------------------------------------------------------------------

create table if not exists nodos_ruta (
  id          text primary key,
  punto_x     double precision not null,
  punto_y     double precision not null,
  nivel       int not null default 0,
  espacio_id  text references espacios(id) on delete set null
);

create type tipo_arista as enum
  ('exterior', 'pasillo', 'escalera', 'rampa', 'elevador', 'puerta');

create table if not exists aristas_ruta (
  id      bigint generated always as identity primary key,
  a       text not null references nodos_ruta(id) on delete cascade,
  b       text not null references nodos_ruta(id) on delete cascade,
  tipo    tipo_arista not null default 'pasillo'
);

-- ---------------------------------------------------------------------------
-- Puntos QR (posición indoor — fase posterior)
-- ---------------------------------------------------------------------------

create table if not exists puntos_qr (
  id          text primary key,
  nodo_id     text references nodos_ruta(id) on delete set null,
  nivel       int not null default 0,
  codigo      text not null unique
);

-- ---------------------------------------------------------------------------
-- Roles y perfiles (panel admin — fase posterior)
-- ---------------------------------------------------------------------------

create type rol_usuario as enum
  ('visitante', 'alumno', 'docente', 'admin_edificio', 'super_admin');

create table if not exists perfiles (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  rol          rol_usuario not null default 'alumno',
  edificio_id  text references edificios(id) on delete set null,  -- para admin_edificio
  docente_id   text references docentes(id) on delete set null,
  creado_en    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
-- Lectura pública del catálogo (la app se usa sin cuenta).
-- Escritura solo para roles administrativos.

alter table edificios     enable row level security;
alter table espacios      enable row level security;
alter table docentes      enable row level security;
alter table asignaciones  enable row level security;
alter table nodos_ruta    enable row level security;
alter table aristas_ruta  enable row level security;
alter table perfiles      enable row level security;

create policy "catálogo visible para todos" on edificios    for select using (true);
create policy "catálogo visible para todos" on espacios     for select using (true);
create policy "catálogo visible para todos" on docentes     for select using (true);
create policy "catálogo visible para todos" on asignaciones for select using (true);
create policy "grafo visible para todos"    on nodos_ruta   for select using (true);
create policy "grafo visible para todos"    on aristas_ruta for select using (true);

create or replace function es_admin() returns boolean language sql stable as $$
  select exists (
    select 1 from perfiles
    where user_id = auth.uid()
      and rol in ('admin_edificio', 'super_admin')
  );
$$;

create policy "solo admin edita" on edificios    for all using (es_admin()) with check (es_admin());
create policy "solo admin edita" on espacios     for all using (es_admin()) with check (es_admin());
create policy "solo admin edita" on docentes     for all using (es_admin()) with check (es_admin());
create policy "solo admin edita" on asignaciones for all using (es_admin()) with check (es_admin());

create policy "cada quien ve su perfil" on perfiles
  for select using (user_id = auth.uid() or es_admin());

-- Pendiente: Auth Hook "before user created" para restringir el registro al
-- dominio institucional (@ues.mx) o validar contra la API de control escolar.
