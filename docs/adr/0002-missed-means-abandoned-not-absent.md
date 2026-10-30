# 未到诊只处理已支付且逾期仍待接诊的预约

- 每日 00:30 对已支付、就诊日期已过且仍待接诊的预约标记未到诊。
- 到期以医院时区 Asia/Shanghai 的就诊日结束为界；服务启动时补扫，取消和接诊在事务内按相同日期规则复核。

- 已接诊预约保持原状态，由医生结束就诊；未支付预约由超时取消处理。

- 标记未到诊不退号、不退款。

- 未到诊预约不能新写或修订病历。

代码依据：`AppointmentSweepTask.markMissed`、`AppointmentMapper.selectStaleVisitIds`、`AppointmentService.markMissedOne`、`MedicalRecordService.saveOrUpdateForAppointment`。原先扫描已接诊预约、允许未到诊补病历的规则已删除；历史数据可能仍留有旧机制生成的病历，不能据此扩大当前写入范围。
