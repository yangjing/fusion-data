use fusiondata::ac::abac::policy::PolicyStatement;
use fusiondata_context::ctx::CtxW;
use ultimate_core::{Result, component::Component};
use uuid::Uuid;

use crate::access_control::{PolicyForCreate, bmc::PolicyBmc};

use super::Policy;

#[derive(Clone, Component)]
pub struct PolicySvc {}

impl PolicySvc {
  pub async fn create(&self, ctx: &CtxW, policy: PolicyStatement, description: Option<String>) -> Result<Uuid> {
    let id = Uuid::now_v7();
    let entity_c = PolicyForCreate { id, description, policy: serde_json::to_value(policy)?, status: Some(100) };
    PolicyBmc::insert(ctx.mm(), entity_c).await?;

    Ok(id)
  }

  pub async fn find_by_id(&self, ctx: &CtxW, id: Uuid) -> Result<Policy> {
    let policy = PolicyBmc::find_by_id(ctx.mm(), id).await?;
    Ok(policy)
  }
}
