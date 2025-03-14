use ultimate::{
  configuration::SecurityConfig,
  security::{jose::JwtPayload, SecurityUtils},
  DataError, Result,
};

pub fn make_token(sc: &SecurityConfig, uid: i64) -> Result<String> {
  let mut payload = JwtPayload::new();
  payload.set_subject(uid.to_string());

  let token =
    SecurityUtils::encrypt_jwt(sc.pwd(), payload).map_err(|_e| DataError::unauthorized("Failed generate token"))?;
  Ok(token)
}
