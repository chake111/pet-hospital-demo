# 病历的一单一份由预约行锁维持

- 写病历先在事务内锁定预约行，再查找有效病历并新增或修订。

- 当前保持 `appointment_id` 普通索引，不把“只加唯一键”当作并发修复。

- 后台不删除病历，更正由所属医生在原预约上修订。

- “一单一份”指一份有效病历。

代码依据：`MedicalRecordService.saveOrUpdateForAppointment/requireStaffAppointmentLocked`、`AdminRecordController.remove`、`sql/01_schema.sql` 的 `medical_record` 索引。原文关于管理员可以删除、删除后重写的操作规则已删除；当前删除接口明确返回业务 403。
