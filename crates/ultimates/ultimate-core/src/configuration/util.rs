use std::{env, path::Path};

use config::{Config, ConfigBuilder, Environment, File, FileFormat, builder::DefaultState};
use log::trace;
use tracing::debug;
use ultimate_common::runtime;

use super::ConfigureResult;

/// 加载配置
///
/// [crate::RunModel]
pub fn load_config() -> ConfigureResult<Config> {
  let mut b = Config::builder().add_source(load_default_source());

  // load from default files, if exists
  b = load_from_files(&["app.toml".to_string(), "app.yaml".to_string(), "app.yml".to_string()], b);

  // load from profile files, if exists
  let profile_files = if let Ok(profiles_active) = env::var("ULTIMATE__PROFILES__ACTIVE") {
    vec![
      format!("app-{profiles_active}.toml"),
      format!("app-{profiles_active}.yaml"),
      format!("app-{profiles_active}.yml"),
    ]
  } else {
    vec![]
  };
  debug!("Load profile files: {:?}", profile_files);
  b = load_from_files(&profile_files, b);

  // load from file of env, if exists
  if let Ok(file) = std::env::var("ULTIMATE_CONFIG_FILE") {
    let path = Path::new(&file);
    if path.exists() {
      b = b.add_source(File::from(path));
    }
  }

  b = add_enviroment(b);

  let c = b.build()?;

  trace!("Load config file: {}", c.cache);

  Ok(c)
}

fn load_from_files(files: &[String], mut b: ConfigBuilder<DefaultState>) -> ConfigBuilder<DefaultState> {
  for file in files {
    if let Ok(path) = runtime::cargo_manifest_dir().map(|dir| dir.join("resources").join(file)) {
      if path.exists() {
        b = b.add_source(File::from(path));
        break;
      }
    }
  }

  for file in files {
    let path = Path::new(file);
    if path.exists() {
      b = b.add_source(File::from(path));
      break;
    }
  }

  b
}

pub fn load_default_source() -> File<config::FileSourceString, FileFormat> {
  let text = include_str!("default.toml");
  File::from_str(text, FileFormat::Toml)
}

pub fn add_enviroment(b: ConfigBuilder<DefaultState>) -> ConfigBuilder<DefaultState> {
  let mut env = Environment::default();
  env = env.separator("__");
  b.add_source(env)
}
