use fusiondata_context::ctx::CtxW;
use prost_types::FieldMask;
use tonic::{Request, Response, Status};
use ultimate_core::component::Component;
use ultimate_grpc::GrpcServiceIntercepted;

use crate::{
  pb::fusion_iam::v1::{
    AssignPermmissionToRolesRequest, CreatePermissionRequest, DeletePermissionRequest, DeletePermissionResponse, Empty,
    GetPermissionRequest, PagePermissionRequest, PagePermissionResponse, PermissionDto, PermissionResponse,
    UpdatePermissionRequest,
    permission_server::{Permission, PermissionServer},
  },
  util::grpc::interceptor::auth_interceptor,
};

use super::{PermissionFilters, PermissionSvc};

#[derive(Clone, Component)]
pub struct PermissionRpc {
  #[component]
  permission_svc: PermissionSvc,
}

impl PermissionRpc {
  pub fn into_rpc(self) -> GrpcServiceIntercepted<PermissionServer<PermissionRpc>> {
    PermissionServer::with_interceptor(self, auth_interceptor)
  }

  async fn fetch_permission(
    &self,
    ctx: &CtxW,
    field_mask: FieldMask,
    id: i64,
  ) -> Result<Response<PermissionResponse>, Status> {
    let permission = if field_mask.paths.is_empty() {
      let permission = self.permission_svc.find_by_id(ctx, id).await?.into();
      Some(permission)
    } else {
      None
    };
    Ok(Response::new(PermissionResponse { id, permission }))
  }
}

#[tonic::async_trait]
impl Permission for PermissionRpc {
  async fn create(&self, request: Request<CreatePermissionRequest>) -> Result<Response<PermissionResponse>, Status> {
    let (_, exts, request) = request.into_parts();
    let ctx = (&exts).try_into()?;
    let field_mask = request.field_mask.unwrap_or_default();
    let req = request.dto.ok_or(Status::invalid_argument("dto is required"))?.into();
    let id = self.permission_svc.create(ctx, req).await?;
    self.fetch_permission(ctx, field_mask, id).await
  }

  async fn update(&self, request: Request<UpdatePermissionRequest>) -> Result<Response<PermissionResponse>, Status> {
    let (_, exts, request) = request.into_parts();
    let ctx = (&exts).try_into()?;
    let field_mask = request.field_mask.unwrap_or_default();
    let req = request.dto.ok_or(Status::invalid_argument("dto is required"))?.into();

    self.permission_svc.update_by_id(ctx, request.id, req).await?;
    self.fetch_permission(ctx, field_mask, request.id).await
  }

  async fn delete(
    &self,
    request: Request<DeletePermissionRequest>,
  ) -> Result<Response<DeletePermissionResponse>, Status> {
    let (_, exts, request) = request.into_parts();
    let ctx = (&exts).try_into()?;

    self.permission_svc.delete_by_id(ctx, request.id).await?;
    Ok(Response::new(DeletePermissionResponse {}))
  }

  async fn find(&self, request: Request<GetPermissionRequest>) -> Result<Response<PermissionDto>, Status> {
    let (_, exts, request) = request.into_parts();
    let ctx = (&exts).try_into()?;

    let res = self.permission_svc.find_by_id(ctx, request.id).await?;
    Ok(Response::new(res.into()))
  }

  async fn page(&self, request: Request<PagePermissionRequest>) -> Result<Response<PagePermissionResponse>, Status> {
    let (_, exts, request) = request.into_parts();
    let ctx = (&exts).try_into()?;
    let filter =
      PermissionFilters { filter: request.filter.into_iter().map(|v| v.into()).collect(), ..Default::default() };

    let res = self.permission_svc.page(ctx, filter, request.pagination.unwrap_or_default()).await?;
    Ok(Response::new(res.into()))
  }

  async fn assign_role(&self, request: Request<AssignPermmissionToRolesRequest>) -> Result<Response<Empty>, Status> {
    let (_, exts, request) = request.into_parts();
    let ctx = (&exts).try_into()?;

    self.permission_svc.assign_roles(ctx, request.permission_id, request.role_ids).await?;
    Ok(Response::new(Empty {}))
  }
}
