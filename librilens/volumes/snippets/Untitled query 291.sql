-- ============================================================
-- TIER 1: No foreign key dependencies
-- ============================================================

create table public.profile (
  prof_id bigint generated always as identity not null,
  prof_firstname text null,
  prof_middlename text null,
  prof_lastname text null,
  prof_address text null,
  prof_date_of_birth date null,
  prof_street_address text null,
  prof_region_info text null,
  prof_postal_code text null,
  prof_updated_at timestamp without time zone null default now(),
  prof_created_at timestamp without time zone not null default now(),
  constraint profile_pkey primary key (prof_id)
) TABLESPACE pg_default;


create table public.department (
  dept_id bigserial not null,
  dept_name text not null,
  dept_is_active boolean null default true,
  dept_created_at timestamp without time zone null default now(),
  dept_created_by bigint null,
  dept_updated_at timestamp without time zone null,
  dept_updated_by bigint null,
  constraint department_pkey primary key (dept_id)
) TABLESPACE pg_default;


create table public.privilege (
  priv_id bigint generated always as identity not null,
  priv_can_view_message boolean not null,
  priv_can_message boolean null,
  priv_can_manage_profile boolean null,
  priv_can_use_canned_mess boolean null,
  priv_can_end_chat boolean null,
  priv_can_transfer boolean null,
  priv_can_manage_dept boolean null,
  priv_can_assign_dept boolean null,
  priv_can_manage_role boolean null,
  priv_can_assign_role boolean null,
  priv_can_create_account boolean null,
  priv_can_manage_auto_reply boolean null,
  priv_created_at timestamp without time zone null default now(),
  priv_created_by bigint null,
  priv_updateed_at timestamp without time zone null default now(),
  priv_updated_by bigint null,
  priv_can_view_dept boolean null default false,
  priv_can_add_dept boolean null default false,
  priv_can_edit_dept boolean null default false,
  priv_can_view_auto_reply boolean null default false,
  priv_can_add_auto_reply boolean null default false,
  priv_can_edit_auto_reply boolean null default false,
  priv_can_delete_auto_reply boolean null default false,
  priv_can_view_macros boolean null default false,
  priv_can_add_macros boolean null default false,
  priv_can_edit_macros boolean null default false,
  priv_can_delete_macros boolean null default false,
  priv_can_view_change_roles boolean null default false,
  priv_can_edit_change_roles boolean null default false,
  priv_can_view_manage_agents boolean null default false,
  priv_can_view_agents_info boolean null default false,
  priv_can_create_agent_account boolean null default false,
  priv_can_edit_manage_agents boolean null default false,
  priv_can_edit_dept_manage_agents boolean null default false,
  priv_can_view_analytics_manage_agents boolean null default false,
  constraint privilage_pkey primary key (priv_id)
) TABLESPACE pg_default;


-- ============================================================
-- TIER 2: Depends on profile, privilege
-- ============================================================

create table public.image (
  img_id bigint generated always as identity not null,
  img_location text not null,
  img_is_current boolean null,
  img_created_at timestamp without time zone null default now(),
  prof_id bigint null,
  constraint image_pkey primary key (img_id),
  constraint image_prof_id_fkey foreign key (prof_id) references profile (prof_id) on update cascade on delete cascade
) TABLESPACE pg_default;


create table public.role (
  role_id bigint generated always as identity not null,
  role_name text not null,
  role_is_active boolean null default true,
  role_created_at timestamp without time zone null default now(),
  role_created_by bigint null,
  role_updated_at timestamp without time zone null,
  role_updated_by bigint null,
  priv_id bigint null,
  constraint role_pkey primary key (role_id),
  constraint role_priv_id_fkey foreign key (priv_id) references privilege (priv_id) on update cascade on delete cascade
) TABLESPACE pg_default;


-- ============================================================
-- TIER 3: Depends on profile, role
-- ============================================================

create table public.client (
  client_id bigserial not null,
  client_country_code text not null,
  client_number text not null,
  client_created_at timestamp without time zone null default now(),
  prof_id bigint null,
  client_updated_at timestamp without time zone null,
  client_is_active boolean null,
  role_id bigint null,
  constraint client_pkey primary key (client_id),
  constraint client_phone_unique unique (client_country_code, client_number),
  constraint client_prof_id_fkey foreign key (prof_id) references profile (prof_id) on update cascade on delete cascade,
  constraint client_role_id_fkey foreign key (role_id) references role (role_id) on update cascade on delete set null
) TABLESPACE pg_default;

create index if not exists idx_client_number on public.client using btree (client_number) TABLESPACE pg_default;


create table public.sys_user (
  sys_user_id bigserial not null,
  sys_user_email text not null,
  sys_user_created_at timestamp without time zone null default now(),
  sys_user_created_by bigint null,
  sys_user_updated_at timestamp without time zone null,
  sys_user_updated_by bigint null,
  sys_user_is_active boolean null default true,
  supabase_user_id uuid null,
  role_id bigint null,
  prof_id bigint null,
  last_seen timestamp with time zone null default now(),
  max_concurrent_chats integer null default 5,
  current_active_chats integer null default 0,
  constraint sys_user_pkey primary key (sys_user_id),
  constraint sys_user_prof_id_fkey foreign key (prof_id) references profile (prof_id) on update cascade on delete cascade,
  constraint sys_user_role_id_fkey foreign key (role_id) references role (role_id) on update cascade on delete cascade
) TABLESPACE pg_default;

create index if not exists idx_sys_user_email on public.sys_user using btree (sys_user_email) TABLESPACE pg_default;


-- ============================================================
-- TIER 4: Depends on client, sys_user, department, role
-- ============================================================

create table public.otp_sms (
  otp_id uuid not null default gen_random_uuid (),
  phone_country_code character varying(10) not null,
  phone_number character varying(20) not null,
  otp_hash text not null,
  expires_at timestamp with time zone not null,
  attempts integer not null default 0,
  verified boolean not null default false,
  created_at timestamp with time zone not null default now(),
  client_id bigint null,
  otp_type text null default 'registration'::text,
  constraint otp_sms_pkey primary key (otp_id),
  constraint otp_sms_phone_number_key unique (phone_number),
  constraint fk_otp_sms_client foreign key (client_id) references client (client_id),
  constraint otp_sms_otp_type_check check (
    (
      otp_type = any (array['registration'::text, 'login'::text])
    )
  )
) TABLESPACE pg_default;

create index if not exists idx_otp_sms_client_id on public.otp_sms using btree (client_id) TABLESPACE pg_default;
create index if not exists idx_otp_sms_phone on public.otp_sms using btree (phone_country_code, phone_number) TABLESPACE pg_default;
create index if not exists idx_otp_sms_created_at on public.otp_sms using btree (created_at) TABLESPACE pg_default;


create table public.auto_reply (
  auto_reply_id bigint not null,
  auto_reply_message text not null,
  auto_reply_is_active boolean null default true,
  auto_reply_created_at timestamp without time zone null default CURRENT_TIMESTAMP,
  auto_reply_created_by bigint null,
  auto_reply_updated_at timestamp without time zone null default CURRENT_TIMESTAMP,
  auto_reply_updated_by bigint null,
  dept_id bigint null,
  constraint auto_reply_pkey primary key (auto_reply_id),
  constraint auto_reply_dept_id_fkey foreign key (dept_id) references department (dept_id) on update cascade on delete cascade
) TABLESPACE pg_default;


create table public.canned_message (
  canned_id bigserial not null,
  canned_message text not null,
  canned_is_active boolean null default true,
  canned_created_at timestamp without time zone null default now(),
  canned_created_by bigint null,
  canned_updated_at timestamp without time zone null,
  canned_updated_by bigint null,
  dept_id bigint null,
  role_id bigint null,
  constraint canned_message_pkey primary key (canned_id),
  constraint canned_message_dept_id_fkey foreign key (dept_id) references department (dept_id) on update cascade on delete cascade,
  constraint canned_message_role_id_fkey foreign key (role_id) references role (role_id) on update cascade on delete cascade
) TABLESPACE pg_default;


create table public.sys_user_department (
  sys_user_id bigint not null,
  dept_id bigint null,
  id bigint generated by default as identity not null,
  constraint sys_user_department_pkey primary key (id),
  constraint sys_user_department_dept_id_fkey foreign key (dept_id) references department (dept_id) on update cascade on delete cascade,
  constraint sys_user_department_sys_user_id_fkey foreign key (sys_user_id) references sys_user (sys_user_id) on update cascade on delete cascade
) TABLESPACE pg_default;


create table public.chat_group (
  chat_group_id bigserial not null,
  client_id bigint not null,
  dept_id bigint null,
  created_at timestamp without time zone null default now(),
  status text null,
  sys_user_id bigint null,
  resolved_at timestamp with time zone null,
  constraint chat_group_pkey primary key (chat_group_id),
  constraint chat_group_client_id_fkey foreign key (client_id) references client (client_id) on update cascade on delete cascade,
  constraint chat_group_dept_id_fkey foreign key (dept_id) references department (dept_id) on update cascade on delete cascade,
  constraint chat_group_sys_user_id_fkey foreign key (sys_user_id) references sys_user (sys_user_id) on update cascade on delete cascade
) TABLESPACE pg_default;

create index if not exists idx_chat_group_status on public.chat_group using btree (status) TABLESPACE pg_default;


-- ============================================================
-- TIER 5: Depends on chat_group, client, sys_user, department
-- ============================================================

create table public.chat (
  chat_id bigserial not null,
  chat_body text null,
  chat_created_at timestamp without time zone null default CURRENT_TIMESTAMP,
  sys_user_id bigint null,
  client_id bigint null,
  chat_group_id bigint null,
  message_type text null default 'text'::text,
  media_url text null,
  media_thumbnail_url text null,
  media_size bigint null,
  media_mime_type text null,
  is_deleted boolean null default false,
  deleted_at timestamp without time zone null,
  chat_delivered_at timestamp without time zone null,
  chat_read_at timestamp without time zone null,
  response_time_seconds integer null,
  previous_customer_message_id bigint null,
  constraint chat_pkey primary key (chat_id),
  constraint chat_chat_group_id_fkey foreign key (chat_group_id) references chat_group (chat_group_id) on update cascade on delete cascade,
  constraint chat_client_id_fkey foreign key (client_id) references client (client_id) on update cascade on delete cascade,
  constraint chat_sys_user_id_fkey foreign key (sys_user_id) references sys_user (sys_user_id) on update cascade on delete cascade,
  constraint chat_message_type_check check (
    (
      message_type = any (
        array[
          'text'::text,
          'image'::text,
          'video'::text,
          'file'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index if not exists idx_chat_chat_group_id on public.chat using btree (chat_group_id) TABLESPACE pg_default;
create index if not exists idx_chat_created_at on public.chat using btree (chat_created_at) TABLESPACE pg_default;
create index if not exists idx_chat_message_type on public.chat using btree (message_type) TABLESPACE pg_default;
create index if not exists idx_chat_delivered_at on public.chat using btree (chat_delivered_at) TABLESPACE pg_default;
create index if not exists idx_chat_read_at on public.chat using btree (chat_read_at) TABLESPACE pg_default;
create index if not exists idx_chat_response_time on public.chat using btree (response_time_seconds) TABLESPACE pg_default;
create index if not exists idx_chat_previous_customer_message on public.chat using btree (previous_customer_message_id) TABLESPACE pg_default;


create table public.chat_feedback (
  feedback_id bigserial not null,
  chat_group_id bigint not null,
  client_id bigint not null,
  rating integer null,
  feedback_text text null,
  chat_duration_seconds integer null,
  message_count integer null,
  created_at timestamp without time zone null default now(),
  constraint chat_feedback_pkey primary key (feedback_id),
  constraint chat_feedback_chat_group_unique unique (chat_group_id),
  constraint chat_feedback_client_id_fkey foreign key (client_id) references client (client_id) on update cascade on delete cascade,
  constraint chat_feedback_chat_group_id_fkey foreign key (chat_group_id) references chat_group (chat_group_id) on update cascade on delete cascade,
  constraint chat_feedback_rating_check check (
    (
      (rating >= 1)
      and (rating <= 5)
    )
  )
) TABLESPACE pg_default;

create index if not exists idx_chat_feedback_chat_group_id on public.chat_feedback using btree (chat_group_id) TABLESPACE pg_default;
create index if not exists idx_chat_feedback_rating on public.chat_feedback using btree (rating) TABLESPACE pg_default;
create index if not exists idx_chat_feedback_created_at on public.chat_feedback using btree (created_at) TABLESPACE pg_default;


create table public.chat_transfer_log (
  transfer_id bigserial not null,
  chat_group_id bigint not null,
  from_agent_id bigint null,
  to_agent_id bigint null,
  from_dept_id bigint null,
  to_dept_id bigint null,
  transferred_at timestamp without time zone null default now(),
  transfer_type text null,
  constraint chat_transfer_log_pkey primary key (transfer_id),
  constraint chat_transfer_log_chat_group_id_fkey foreign key (chat_group_id) references chat_group (chat_group_id) on update cascade on delete cascade,
  constraint chat_transfer_log_from_agent_id_fkey foreign key (from_agent_id) references sys_user (sys_user_id) on update cascade on delete set null,
  constraint chat_transfer_log_to_agent_id_fkey foreign key (to_agent_id) references sys_user (sys_user_id) on update cascade on delete set null,
  constraint chat_transfer_log_from_dept_id_fkey foreign key (from_dept_id) references department (dept_id) on update cascade on delete set null,
  constraint chat_transfer_log_to_dept_id_fkey foreign key (to_dept_id) references department (dept_id) on update cascade on delete set null,
  constraint chat_transfer_log_transfer_type_check check (
    (
      (transfer_type is null)
      or (
        transfer_type = any (
          array[
            'manual'::text,
            'auto_reassign'::text,
            'agent_offline'::text
          ]
        )
      )
    )
  )
) TABLESPACE pg_default;

create index if not exists idx_transfer_chat_group on public.chat_transfer_log using btree (chat_group_id) TABLESPACE pg_default;
create index if not exists idx_transfer_agents on public.chat_transfer_log using btree (from_agent_id, to_agent_id) TABLESPACE pg_default;