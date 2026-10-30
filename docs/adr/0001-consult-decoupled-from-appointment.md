# 图文问诊与到院预约独立

- 图文问诊免费发起，不占号源、不走预约支付。

- “建议到院”保存为 `SUGGEST` 消息，由前端引导另行挂号，不自动建预约或病历。

代码依据：`ConsultService.create/send`、`frontend/src/components/ConsultPanel.vue`。

当前 `sql/01_schema.sql` 仍有 `consult_session.appointment_id` 与对应唯一索引，`AppointmentVo` 仍有 `sessionId`；删除原文“这些字段已删除”的断言。这些遗留声明不证明新建会话依赖预约，也不作为本次规则清理的数据库迁移任务。
