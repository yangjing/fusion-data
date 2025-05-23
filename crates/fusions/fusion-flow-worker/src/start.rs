use ultimate_core::{application::Application, timer::TimerPlugin};

use crate::worker::JobWorker;

pub async fn fusion_flow_worker_start() -> ultimate_core::Result<()> {
  Application::builder().add_plugin(TimerPlugin).run().await?;
  let app = Application::global();
  let worker: JobWorker = app.component();

  worker.run_loop().await.unwrap();

  Ok(())
}
