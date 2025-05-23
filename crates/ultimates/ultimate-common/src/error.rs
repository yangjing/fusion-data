use thiserror::Error;

pub type Result<T> = core::result::Result<T, Error>;

#[derive(Debug, Error)]
pub enum Error {
  // -- Base64
  #[error("Decode base64 fail, string is {0}")]
  FailToB64uDecode(String),

  #[error("Parse date fail, data is {0}")]
  DateFailParse(String),

  #[error("Key fail.")]
  KeyFail,

  #[error("Password not match.")]
  PwdNotMatching,

  #[error("Missing env: {0}")]
  MissingEnv(&'static str),

  #[error("Wrong format: {0}")]
  WrongFormat(&'static str),
}

impl From<chrono::ParseError> for Error {
  fn from(value: chrono::ParseError) -> Self {
    Error::DateFailParse(value.to_string())
  }
}
