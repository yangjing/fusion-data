create table if not exists annotation_tag_entity (
  id varchar(16) constraint annotation_tag_entity_pk primary key,
  name varchar(24) not null,
  ctime timestamptz not null,
  mtime timestamptz
);

create unique index if not exists annotation_tag_entity_uidx_name on annotation_tag_entity (name);

create table if not exists auth_provider_sync_history (
  id serial constraint auth_provider_sync_history_pk primary key,
  provider_kind varchar(32) not null,
  run_mode text not null,
  status text not null,
  started_at timestamptz not null default current_timestamp,
  ended_at timestamptz not null default current_timestamp,
  scanned integer not null,
  created integer not null,
  updated integer not null,
  disabled integer not null,
  error text
);

create table if not exists credentials_entity (
  id varchar(36) constraint credentials_entity_pk primary key,
  name varchar(128) not null,
  data text not null,
  kind varchar(128) not null,
  ctime timestamptz not null,
  mtime timestamptz,
  is_managed boolean default false not null
);

create index if not exists credentials_entity_idx_kind on credentials_entity (kind);

create table if not exists event_destinations (
  id uuid constraint event_destinations_pk primary key,
  destination jsonb not null,
  ctime timestamptz not null,
  mtime timestamptz
);

create table if not exists installed_packages (
  package_name varchar(214) constraint installed_packages_pk primary key,
  installed_version varchar(50) not null,
  author_name varchar(70),
  author_email varchar(70),
  ctime timestamptz not null,
  mtime timestamptz not null
);

create table if not exists installed_nodes (
  name varchar(200) constraint installed_nodes_pk primary key,
  kind varchar(200) not null,
  latest_version integer default 1 not null,
  package varchar(241) not null constraint installed_nodes_fk_package references installed_packages on update cascade on delete cascade
);

create table if not exists invalid_auth_token (token varchar(512) constraint invalid_auth_token_pk primary key, expires_at timestamptz not null);

create table if not exists migrations (id serial constraint migrations_pk primary key, timestamp bigint not null, name varchar not null);

-- project
create table if not exists project (
  id varchar(36) constraint project_pk primary key,
  name varchar(255) not null,
  kind varchar(36) not null,
  ctime timestamptz not null,
  mtime timestamptz,
  icon json
);

create table if not exists folder (
  id varchar(36) constraint folder_pk primary key,
  name varchar(128) not null,
  parent_folder_id varchar(36) constraint folder_fk_parent_folder references folder on delete cascade,
  project_id varchar(36) not null constraint folder_fk_project references project on delete cascade,
  ctime timestamptz not null,
  mtime timestamptz not null
);

create unique index if not exists folder_uidx_project_id_id on folder (project_id, id);

create table if not exists settings (
  key varchar(255) constraint settings_pk primary key,
  value text not null,
  load_on_startup boolean default false not null
);

create table if not exists shared_credentials (
  credentials_id varchar(36) not null constraint shared_credentials_fk_credentials references credentials_entity on delete cascade,
  project_id varchar(36) not null constraint shared_credentials_fk_project references project on delete cascade,
  role text not null,
  ctime timestamptz not null,
  mtime timestamptz,
  constraint shared_credentials_pk primary key (credentials_id, project_id)
);

-- 标签表
create table if not exists tag_entity (
  id varchar(36) constraint tag_entity_pk primary key,
  name varchar(24) not null,
  ctime timestamptz not null,
  mtime timestamptz
);

create unique index if not exists tag_entity_uidx_name on tag_entity (name);

create table if not exists folder_tag (
  folder_id varchar(36) not null constraint folder_tag_fk_folder references folder on delete cascade,
  tag_id varchar(36) not null constraint folder_tag_fk_tag references tag_entity on delete cascade,
  constraint folder_tag_pk primary key (folder_id, tag_id)
);

-- 用户表
create table if not exists user_entity (
  -- 用户ID，由程序端使用 uuid v7 生成
  id uuid constraint user_pk primary key,
  -- 用户邮箱，全局唯一，登录凭证
  email varchar(255) not null,
  -- 手机号，全局唯一，登录凭证，可选。存储为完整格式（含国家/地区码），如 +8613800138000
  phone varchar(16),
  -- 用户名
  name varchar(32),
  -- 用户密码
  password varchar(255),
  -- 用户个性化设置
  personalization_answers json,
  -- 用户设置（系统）
  settings jsonb,
  -- 用户状态。100:正常, 99:禁用
  status int not null default 100,
  -- 多因素（MFA）认证
  mfa_enabled boolean default false not null,
  mfa_secret text,
  mfa_recovery_codes text,
  -- 用户角色
  role text not null,
  ctime timestamptz not null,
  mtime timestamptz
);

create unique index if not exists user_uidx_email on user_entity (email);

create unique index if not exists user_uidx_phone on user_entity (phone)
where
  phone is not null;

create table if not exists auth_identity (
  user_id uuid constraint auth_identity_fk_user references user_entity,
  provider_id varchar(64) not null,
  provider_kind varchar(32) not null,
  ctime timestamptz not null,
  mtime timestamptz,
  constraint auth_identity_pk primary key (provider_id, provider_kind)
);

-- 项目成员表
create table if not exists project_relation (
  project_id varchar(36) not null constraint project_relation_fk_project references project on delete cascade,
  -- 用户ID，TODO owner？
  user_id uuid not null constraint project_relation_fk_user references user_entity on delete cascade,
  -- TODO 角色(权限)，具备此角色的用户可以访问此项目
  role varchar not null,
  ctime timestamptz not null,
  mtime timestamptz,
  constraint project_relation_pk primary key (project_id, user_id)
);

create index if not exists project_relation_idx_user_id on project_relation (user_id);

create index if not exists project_relation_idx_project_id on project_relation (project_id);

create table if not exists user_api_keys (
  id varchar(36) not null constraint user_api_keys_pk primary key,
  user_id uuid not null constraint user_api_keys_fk_user references user_entity on delete cascade,
  label varchar(100) not null,
  api_key varchar not null,
  ctime timestamptz not null,
  mtime timestamptz,
  scopes jsonb
);

create unique index if not exists user_api_keys_uidx_api_key on user_api_keys (api_key);

create unique index if not exists user_api_keys_uidx_user_id_label on user_api_keys (user_id, label);

create table if not exists variables (
  id varchar(36) constraint variables_pk primary key,
  key varchar(50) not null unique,
  kind varchar(50) default 'string' not null,
  value varchar(255)
);

-- 工作流主表
create table if not exists workflow_entity (
  id varchar(36) constraint workflow_entity_pk primary key,
  name varchar(128) not null,
  active boolean not null,
  -- 工作流节点（步骤）
  nodes jsonb not null,
  -- 工作流节点连接
  connections jsonb not null,
  ctime timestamptz not null,
  mtime timestamptz,
  -- 工作流设置
  settings jsonb,
  -- 工作流静态数据
  static_data jsonb,
  -- 工作流固定数据
  pin_data jsonb,
  -- 工作流版本ID
  version_id char(36),
  -- 工作流触发次数
  trigger_count integer default 0 not null,
  -- 工作流元数据
  meta jsonb,
  parent_folder_id varchar(36) constraint fk_workflow_parent_folder references folder on delete cascade,
  is_archived boolean default false not null
);

create index if not exists workflow_entity_idx_name on workflow_entity (name);

create unique index if not exists pk_workflow_entity_id on workflow_entity (id);

create table if not exists workflows_tags (
  workflow_id varchar(36) not null constraint fk_workflows_tags_workflow_id references workflow_entity on delete cascade,
  tag_id varchar(36) not null constraint fk_workflows_tags_tag_id references tag_entity on delete cascade,
  constraint workflows_tags_pk primary key (workflow_id, tag_id)
);

create index if not exists workflows_tags_idx_workflow_id on workflows_tags (workflow_id);

-- 工作流执行记录表
-- 记录每次工作流执行的详细信息
create table if not exists execution_entity (
  id serial constraint execution_entity_pk primary key,
  workflow_id varchar(36) not null constraint fk_execution_entity_workflow_id references workflow_entity on delete cascade,
  finished boolean not null,
  mode varchar not null,
  -- 重试机制
  retry_of varchar,
  retry_success_id varchar,
  -- 执行开始时间
  started_at timestamptz,
  -- 执行结束时间
  stopped_at timestamptz,
  --
  wait_till timestamptz,
  status varchar not null,
  deleted_at timestamptz,
  ctime timestamptz not null
);

-- 工作流执行数据表。存储工作流执行过程中的数据
create table if not exists execution_data (
  execution_id integer constraint execution_data_pk primary key constraint execution_data_fk references execution_entity on delete cascade,
  -- 包含工作流数据
  workflow_data json not null,
  -- 具体执行数据
  data text not null
);

create index if not exists execution_entity_idx_stopped_at_status_deleted_at on execution_entity (stopped_at, status, deleted_at)
where
  (
    (stopped_at is not null)
    and (deleted_at is null)
  );

create index if not exists idx_execution_entity_wait_till_status_deleted_at on execution_entity (wait_till, status, deleted_at)
where
  (
    (wait_till is not null)
    and (deleted_at is null)
  );

create index if not exists idx_execution_entity_workflow_id_started_at on execution_entity (workflow_id, started_at)
where
  (
    (started_at is not null)
    and (deleted_at is null)
  );

create index if not exists execution_entity_idx_deleted_at on execution_entity (deleted_at);

create table if not exists execution_annotations (
  id serial constraint execution_annotations_pk primary key,
  execution_id integer not null constraint execution_annotations_fk_execution_entity references execution_entity on delete cascade,
  vote varchar(6),
  note text,
  ctime timestamptz not null,
  mtime timestamptz not null
);

create unique index if not exists execution_annotations_uidx_execution_id on execution_annotations (execution_id);

create table if not exists execution_annotation_tags (
  annotation_id integer not null constraint execution_annotation_tags_fk_execution_annotations references execution_annotations on delete cascade,
  tag_id varchar(24) not null constraint execution_annotation_tags_fk_annotation_tag_entity references annotation_tag_entity on delete cascade,
  constraint execution_annotation_tags_pk primary key (annotation_id, tag_id)
);

create index if not exists execution_annotation_tags_idx_tag_id on execution_annotation_tags (tag_id);

create index if not exists execution_annotation_tags_idx_annotation_id on execution_annotation_tags (annotation_id);

create table if not exists execution_metadata (
  id serial constraint execution_metadata_pk primary key,
  execution_id integer not null constraint execution_metadata_fk_execution_entity references execution_entity on delete cascade,
  key varchar(255) not null,
  value text not null
);

create unique index if not exists execution_metadata_uidx_execution_id_key on execution_metadata (execution_id, key);

create table if not exists insights_metadata (
  meta_id serial constraint insights_metadata_pk primary key,
  workflow_id varchar(16) constraint insights_metadata_fk_workflow_entity references workflow_entity on delete set null,
  project_id varchar(36) constraint insights_metadata_fk_project references project on delete set null,
  workflow_name varchar(128) not null,
  project_name varchar(255) not null
);

create table if not exists insights_by_period (
  id serial constraint insights_by_period_pk primary key,
  meta_id integer not null constraint insights_by_period_fk_insights_metadata references insights_metadata on delete cascade,
  kind integer not null,
  value integer not null,
  period_unit integer not null,
  period_start timestamptz default current_timestamp
);

comment on column insights_by_period.kind is '0: time_saved_minutes, 1: runtime_milliseconds, 2: success, 3: failure';

comment on column insights_by_period.period_unit is '0: hour, 1: day, 2: week';

create unique index if not exists insights_by_period_uidx_period_start_type_period_unit_meta_id on insights_by_period (period_start, kind, period_unit, meta_id);

create unique index if not exists insights_metadata_uidx_workflow_id on insights_metadata (workflow_id);

create table if not exists insights_raw (
  id serial constraint insights_raw_pk primary key,
  meta_id integer not null constraint insights_raw_fk_insights_metadata references insights_metadata on delete cascade,
  kind integer not null,
  value integer not null,
  timestamp timestamptz default current_timestamp not null
);

comment on column insights_raw.kind is '0: time_saved_minutes, 1: runtime_milliseconds, 2: success, 3: failure';

create table if not exists processed_data (
  workflow_id varchar(36) not null constraint processed_data_fk_workflow_entity references workflow_entity on delete cascade,
  context varchar(255) not null,
  ctime timestamptz not null,
  mtime timestamptz,
  value text not null,
  constraint processed_data_pk primary key (workflow_id, context)
);

-- 共享工作流表。记录工作流被共享到哪些项目中，以及共享的权限
create table if not exists shared_workflow (
  workflow_id varchar(36) not null constraint shared_workflow_fk_workflow_entity references workflow_entity on delete cascade,
  project_id varchar(36) not null constraint shared_workflow_fk_project references project on delete cascade,
  role text not null,
  ctime timestamptz not null,
  mtime timestamptz,
  constraint shared_workflow_pk primary key (workflow_id, project_id)
);

create table if not exists workflow_history (
  version_id varchar(36) constraint workflow_history_pk primary key,
  workflow_id varchar(36) not null constraint workflow_history_fk_workflow_entity references workflow_entity on delete cascade,
  authors varchar(255) not null,
  ctime timestamptz not null,
  mtime timestamptz,
  nodes json not null,
  connections json not null
);

create index if not exists workflow_history_idx_workflow_id on workflow_history (workflow_id);

create table if not exists workflow_statistics (
  count integer default 0,
  latest_event timestamptz,
  name varchar(128) not null,
  workflow_id varchar(36) not null constraint fk_workflow_statistics_workflow_id references workflow_entity on delete cascade,
  root_count integer default 0,
  constraint workflow_statistics_pk primary key (workflow_id, name)
);

create table if not exists test_definition (
  id varchar(36) constraint test_definition_pk primary key,
  name varchar(255) not null,
  workflow_id varchar(36) not null constraint test_definition_fk_workflow_entity references workflow_entity on delete cascade,
  evaluation_workflow_id varchar(36) constraint test_definition_fk_workflow_entity_evaluation references workflow_entity on delete set null,
  annotation_tag_id varchar(16) constraint test_definition_fk_annotation_tag_entity references annotation_tag_entity on delete set null,
  ctime timestamptz not null,
  mtime timestamptz,
  description text,
  mocked_nodes jsonb default '[]'::jsonb not null
);

create index if not exists test_definition_idx_evaluation_workflow_id on test_definition (evaluation_workflow_id);

create index if not exists test_definition_idx_workflow_id on test_definition (workflow_id);

create table if not exists test_metric (
  id varchar(36) constraint test_metric_pk primary key,
  name varchar(255) not null,
  test_definition_id varchar(36) not null constraint test_metric_fk_test_definition references test_definition on delete cascade,
  ctime timestamptz not null,
  mtime timestamptz not null
);

create index if not exists test_metric_idx_test_definition_id on test_metric (test_definition_id);

create table if not exists test_run (
  id varchar(36) constraint test_run_pk primary key,
  test_definition_id varchar(36) not null constraint test_run_fk_test_definition references test_definition on delete cascade,
  status varchar not null,
  run_at timestamptz,
  completed_at timestamptz,
  metrics json,
  ctime timestamptz not null,
  mtime timestamptz,
  total_cases integer,
  passed_cases integer,
  failed_cases integer,
  error_code varchar(255),
  error_details text,
  constraint test_run_check check (
    case
      when ((status)::text='new'::text) then (total_cases is null)
      when ((status)::text=any (array[('cancelled'::character varying)::text, ('error'::character varying)::text])) then (
        (total_cases is null)
        or (total_cases>=0)
      )
      else (total_cases>=0)
    end
  ),
  constraint test_run_check1 check (
    case
      when ((status)::text='new'::text) then (passed_cases is null)
      when ((status)::text=any (array[('cancelled'::character varying)::text, ('error'::character varying)::text])) then (
        (passed_cases is null)
        or (passed_cases>=0)
      )
      else (passed_cases>=0)
    end
  ),
  constraint test_run_check2 check (
    case
      when ((status)::text='new'::text) then (failed_cases is null)
      when ((status)::text=any (array[('cancelled'::character varying)::text, ('error'::character varying)::text])) then (
        (failed_cases is null)
        or (failed_cases>=0)
      )
      else (failed_cases>=0)
    end
  )
);

create table if not exists test_case_execution (
  id varchar(36) constraint test_case_execution_pk primary key,
  test_run_id varchar(36) not null constraint test_case_execution_fk_test_run references test_run on delete cascade,
  past_execution_id integer constraint test_case_execution_fk_execution_entity references execution_entity on delete set null,
  execution_id integer constraint test_case_execution_fk_execution_entity references execution_entity on delete set null,
  evaluation_execution_id integer constraint test_case_execution_fk_execution_entity_evaluation references execution_entity on delete set null,
  status varchar not null,
  run_at timestamptz,
  completed_at timestamptz,
  error_code varchar,
  error_details json,
  metrics json,
  ctime timestamptz not null,
  mtime timestamptz not null
);

create index if not exists test_case_execution_idx_test_run_id on test_case_execution (test_run_id);

create index if not exists test_run_idx_test_definition_id on test_run (test_definition_id);

create table if not exists webhook_entity (
  webhook_path varchar not null,
  method varchar not null,
  node varchar not null,
  webhook_id varchar,
  path_length integer,
  workflow_id varchar(36) not null constraint fk_webhook_entity_workflow_id references workflow_entity on delete cascade,
  constraint webhook_entity_pk primary key (webhook_path, method)
);

create index if not exists webhook_entity_idx_webhook_id_method_path_length on webhook_entity (webhook_id, method, path_length);
