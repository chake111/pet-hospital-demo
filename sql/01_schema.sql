-- =====================================================================
--  宠物医院预约问诊系统 (单家宠物医院自用版)  pet_clinic
--  01 建表脚本   MySQL 8.0 / InnoDB / utf8mb4
--  执行: mysql -u root -p < 01_schema.sql
--
--  实体关系概览:
--    sys_user 1─N pet; department 1─N doctor 1─N doctor_schedule
--    到院门诊主线: sys_user / pet / doctor / doctor_schedule 各 1─N appointment
--      appointment 1─0..1 medical_record、1─0..1 doctor_review（一单至多一份有效病历、至多一条评价）
--    图文问诊另成一线，不经过预约单: sys_user / pet / doctor 各 1─N consult_session 1─N consult_message
--    admin_user: role=DOCTOR 时 1─1 doctor；1─N notice（发布留痕 publish_by）
-- =====================================================================

DROP DATABASE IF EXISTS `pet_clinic`;
CREATE DATABASE `pet_clinic` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `pet_clinic`;

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. sys_user  注册用户（宠物主人）
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `sys_user`;
CREATE TABLE `sys_user` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键',
  `username`        VARCHAR(50)   NOT NULL                COMMENT '登录账号',
  `password`        VARCHAR(100)  NOT NULL                COMMENT 'BCrypt 密码',
  `nickname`        VARCHAR(50)            DEFAULT NULL   COMMENT '昵称',
  `avatar`          VARCHAR(255)           DEFAULT NULL   COMMENT '头像',
  `phone`           VARCHAR(20)            DEFAULT NULL   COMMENT '手机号',
  `email`           VARCHAR(100)           DEFAULT NULL   COMMENT '邮箱',
  `gender`          TINYINT                DEFAULT 0      COMMENT '性别 0未知 1男 2女',
  `birthday`        DATE                   DEFAULT NULL   COMMENT '生日',
  `city`            VARCHAR(50)            DEFAULT NULL   COMMENT '所在城市',
  `address`         VARCHAR(255)           DEFAULT NULL   COMMENT '联系地址',
  `status`          TINYINT       NOT NULL DEFAULT 1      COMMENT '状态 0禁用 1正常',
  `token_version`   INT           NOT NULL DEFAULT 1      COMMENT '令牌版本，改密递增，旧令牌版本落后即失效',
  `remark`          VARCHAR(500)           DEFAULT NULL   COMMENT '备注',
  `last_login_time` DATETIME               DEFAULT NULL   COMMENT '最后登录时间',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         TINYINT       NOT NULL DEFAULT 0      COMMENT '逻辑删除 0未删 1已删',
  `active_phone`    VARCHAR(20) GENERATED ALWAYS AS (IF(`deleted` = 0, NULLIF(TRIM(`phone`), ''), NULL)) STORED,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`),
  UNIQUE KEY `uk_active_phone` (`active_phone`),
  KEY `idx_phone` (`phone`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '注册用户(宠物主人)';

-- ---------------------------------------------------------------------
-- 2. pet  宠物档案
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `pet`;
CREATE TABLE `pet` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id`         BIGINT        NOT NULL                COMMENT '主人 sys_user.id',
  `name`            VARCHAR(50)   NOT NULL                COMMENT '宠物昵称',
  `species`         VARCHAR(20)   NOT NULL DEFAULT '猫'   COMMENT '物种 猫/狗/兔/鸟/爬行/其他',
  `breed`           VARCHAR(50)            DEFAULT NULL   COMMENT '品种',
  `gender`          TINYINT                DEFAULT 0      COMMENT '性别 0未知 1公 2母',
  `birthday`        DATE                   DEFAULT NULL   COMMENT '出生日期',
  `age_month`       INT                    DEFAULT 0      COMMENT '月龄(冗余,便于列表展示)',
  `weight`          DECIMAL(6,2)           DEFAULT NULL   COMMENT '体重 kg',
  `color`           VARCHAR(30)            DEFAULT NULL   COMMENT '毛色',
  `is_neutered`     TINYINT       NOT NULL DEFAULT 0      COMMENT '是否绝育 0否 1是',
  `vaccine_status`  TINYINT       NOT NULL DEFAULT 0      COMMENT '疫苗 0未接种 1部分 2已完成',
  `deworm_flag`     TINYINT       NOT NULL DEFAULT 0      COMMENT '近期是否驱虫 0否 1是',
  `avatar`          VARCHAR(255)           DEFAULT NULL   COMMENT '宠物照片',
  `allergy`         VARCHAR(255)           DEFAULT NULL   COMMENT '过敏史',
  `medical_history` VARCHAR(500)           DEFAULT NULL   COMMENT '既往病史',
  `remark`          VARCHAR(500)           DEFAULT NULL   COMMENT '备注',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         TINYINT       NOT NULL DEFAULT 0      COMMENT '逻辑删除',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '宠物档案';

-- ---------------------------------------------------------------------
-- 3. department  科室
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `department`;
CREATE TABLE `department` (
  `id`          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
  `name`        VARCHAR(50)  NOT NULL                COMMENT '科室名称',
  `code`        VARCHAR(30)  NOT NULL                COMMENT '科室编码',
  `icon`        VARCHAR(255)          DEFAULT NULL   COMMENT '图标(emoji 或 URL)',
  `description` VARCHAR(500)          DEFAULT NULL   COMMENT '科室简介',
  `sort`        INT          NOT NULL DEFAULT 0      COMMENT '排序',
  `status`      TINYINT      NOT NULL DEFAULT 1      COMMENT '状态 0停用 1正常',
  `create_time` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`     TINYINT      NOT NULL DEFAULT 0      COMMENT '逻辑删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code` (`code`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '科室';

-- ---------------------------------------------------------------------
-- 4. doctor  医生(院内员工花名册, 非入驻制)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `doctor`;
CREATE TABLE `doctor` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键',
  `name`             VARCHAR(50)   NOT NULL                COMMENT '姓名',
  `avatar`           VARCHAR(255)           DEFAULT NULL   COMMENT '头像',
  `gender`           TINYINT                DEFAULT 0      COMMENT '性别 0未知 1男 2女',
  `phone`            VARCHAR(20)            DEFAULT NULL   COMMENT '联系电话',
  `title`            VARCHAR(50)            DEFAULT NULL   COMMENT '职称 主任医师/副主任医师/主治医师/住院医师/助理医师',
  `department_id`    BIGINT        NOT NULL                COMMENT '所属科室 department.id',
  `specialty`        VARCHAR(500)           DEFAULT NULL   COMMENT '擅长领域, 逗号分隔',
  `introduction`     TEXT                                  DEFAULT NULL COMMENT '个人简介',
  `work_years`       INT                    DEFAULT 0      COMMENT '从业年限',
  `consultation_fee` DECIMAL(10,2) NOT NULL DEFAULT 0.00   COMMENT '问诊费',
  `rating`           DECIMAL(2,1)  NOT NULL DEFAULT 5.0    COMMENT '综合评分 0.0-5.0(评价聚合回填)',
  `review_count`     INT           NOT NULL DEFAULT 0      COMMENT '评价数',
  `appointment_count` INT          NOT NULL DEFAULT 0      COMMENT '累计完成接诊数',
  `online_status`    TINYINT       NOT NULL DEFAULT 0      COMMENT '在线状态 0离线 1在线(WebSocket 维护)',
  `status`           TINYINT       NOT NULL DEFAULT 1      COMMENT '状态 0停诊 1正常',
  `sort`             INT           NOT NULL DEFAULT 0      COMMENT '排序',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`          TINYINT       NOT NULL DEFAULT 0      COMMENT '逻辑删除',
  PRIMARY KEY (`id`),
  KEY `idx_department_id` (`department_id`),
  KEY `idx_status` (`status`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '医生(院内员工)';

-- ---------------------------------------------------------------------
-- 5. admin_user  后台账号(管理员 / 医生)
--    医生用 role=DOCTOR + doctor_id 绑定到 doctor 表, 登录后进接诊工作台
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `admin_user`;
CREATE TABLE `admin_user` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
  `username`        VARCHAR(50)  NOT NULL                COMMENT '登录账号',
  `password`        VARCHAR(100) NOT NULL                COMMENT 'BCrypt 密码',
  `real_name`       VARCHAR(50)           DEFAULT NULL   COMMENT '真实姓名',
  `avatar`          VARCHAR(255)          DEFAULT NULL   COMMENT '头像',
  `phone`           VARCHAR(20)           DEFAULT NULL   COMMENT '联系电话',
  `email`           VARCHAR(100)          DEFAULT NULL   COMMENT '邮箱',
  `role`            VARCHAR(20)  NOT NULL DEFAULT 'DOCTOR' COMMENT '角色 ADMIN/DOCTOR',
  `doctor_id`       BIGINT                DEFAULT NULL   COMMENT 'role=DOCTOR 时绑定 doctor.id',
  `status`          TINYINT      NOT NULL DEFAULT 1      COMMENT '状态 0禁用 1正常',
  `token_version`   INT          NOT NULL DEFAULT 1      COMMENT '令牌版本，改密递增，旧令牌版本落后即失效',
  `last_login_time` DATETIME              DEFAULT NULL   COMMENT '最后登录时间',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         TINYINT      NOT NULL DEFAULT 0      COMMENT '逻辑删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`),
  KEY `idx_doctor_id` (`doctor_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '后台账号';

-- ---------------------------------------------------------------------
-- 6. doctor_schedule  医生排班 + 号源池
--    防超卖: UPDATE doctor_schedule SET remain_num = remain_num - 1
--            WHERE id = ? AND remain_num > 0
--    以影响行数 == 1 判定抢号成功(依赖数据库行锁, 无需 Redis)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `doctor_schedule`;
CREATE TABLE `doctor_schedule` (
  `id`          BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键',
  `doctor_id`   BIGINT      NOT NULL                COMMENT 'doctor.id',
  `work_date`   DATE        NOT NULL                COMMENT '出诊日期',
  `period`      TINYINT     NOT NULL                COMMENT '时段 1上午 2下午 3夜间',
  `start_time`  TIME        NOT NULL                COMMENT '时段开始',
  `end_time`    TIME        NOT NULL                COMMENT '时段结束',
  `total_num`   INT         NOT NULL DEFAULT 20     COMMENT '号源总数',
  `remain_num`  INT         NOT NULL DEFAULT 20     COMMENT '剩余号源',
  `last_queue_no` INT       NOT NULL DEFAULT 0      COMMENT '已发放的最大排队序号，只增不减、取消不回收',
  `status`      TINYINT     NOT NULL DEFAULT 1      COMMENT '状态 0停诊 1正常',
  `create_time` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_doctor_date_period` (`doctor_id`, `work_date`, `period`),
  KEY `idx_work_date` (`work_date`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '医生排班与号源';

-- ---------------------------------------------------------------------
-- 7. appointment  预约订单
--    状态机  0待接诊 ──支付──> 0待接诊 ──医生接诊──> 1已接诊 ──结束──> 2已完成
--            0 ──用户、责任医生或管理员取消──> 3已取消(退号；已支付则标记退款)
--            0 且未支付 ──支付超时──> 3已取消(退号)
--            0 且已支付、已过就诊日期 ──每日00:30清扫──> 4未到诊(不退号、不退款)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `appointment`;
CREATE TABLE `appointment` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键',
  `order_no`         VARCHAR(32)   NOT NULL                COMMENT '预约单号',
  `user_id`          BIGINT        NOT NULL                COMMENT 'sys_user.id',
  `pet_id`           BIGINT        NOT NULL                COMMENT 'pet.id',
  `doctor_id`        BIGINT        NOT NULL                COMMENT 'doctor.id',
  `department_id`    BIGINT        NOT NULL                COMMENT 'department.id',
  `schedule_id`      BIGINT                 DEFAULT NULL   COMMENT 'doctor_schedule.id',
  `consult_type`     TINYINT       NOT NULL DEFAULT 1      COMMENT '1在线图文问诊 2到院门诊',
  `appointment_date` DATE          NOT NULL                COMMENT '预约日期',
  `period`           TINYINT       NOT NULL DEFAULT 1      COMMENT '时段 1上午 2下午 3夜间',
  `start_time`       TIME                   DEFAULT NULL   COMMENT '时段开始',
  `end_time`         TIME                   DEFAULT NULL   COMMENT '时段结束',
  `queue_no`         INT                    DEFAULT NULL   COMMENT '排队序号',
  `symptom`          TEXT                                  DEFAULT NULL COMMENT '症状描述',
  `images`           VARCHAR(1000)          DEFAULT NULL   COMMENT '症状图片 URL, 逗号分隔',
  `amount`           DECIMAL(10,2) NOT NULL DEFAULT 0.00   COMMENT '应付金额',
  `pay_status`       TINYINT       NOT NULL DEFAULT 0      COMMENT '0未支付 1已支付 2已退款',
  `pay_time`         DATETIME               DEFAULT NULL   COMMENT '支付时间',
  `pay_type`         VARCHAR(20)            DEFAULT NULL   COMMENT '支付方式 ALIPAY/WECHAT/MOCK',
  `status`           TINYINT       NOT NULL DEFAULT 0      COMMENT '0待接诊 1已接诊 2已完成 3已取消 4未到诊',
  `accept_time`      DATETIME               DEFAULT NULL   COMMENT '医生接诊时间',
  `finish_time`      DATETIME               DEFAULT NULL   COMMENT '完成时间',
  `cancel_reason`    VARCHAR(255)           DEFAULT NULL   COMMENT '取消原因',
  `cancel_time`      DATETIME               DEFAULT NULL   COMMENT '取消时间',
  `cancel_by`        VARCHAR(20)            DEFAULT NULL   COMMENT '取消方 USER/DOCTOR/ADMIN/SYSTEM',
  `is_reviewed`      TINYINT       NOT NULL DEFAULT 0      COMMENT '是否已评价 0否 1是',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`          TINYINT       NOT NULL DEFAULT 0      COMMENT '逻辑删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_doctor_date` (`doctor_id`, `appointment_date`),
  KEY `idx_schedule` (`schedule_id`),
  KEY `idx_status` (`status`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '预约订单(到院门诊)';

-- ---------------------------------------------------------------------
-- 8. consult_session  问诊会话(图文问诊免费发起, 不建订单)
--    管理员处置(无效关闭/违规屏蔽)走 moderate_* 四列, 与 status 的诊疗生命周期正交;
--    moderate_status 非 0 时参与方视同会话不存在(管理员审计视图仍可见)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `consult_session`;
CREATE TABLE `consult_session` (
  `id`                BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
  `appointment_id`    BIGINT                DEFAULT NULL   COMMENT 'appointment.id, 历史图文单遗留; 独立会话为 NULL',
  `user_id`           BIGINT       NOT NULL                COMMENT 'sys_user.id',
  `doctor_id`         BIGINT       NOT NULL                COMMENT 'doctor.id',
  `pet_id`            BIGINT       NOT NULL                COMMENT 'pet.id',
  `symptom`           VARCHAR(500) NOT NULL DEFAULT ''     COMMENT '症状描述',
  `images`            VARCHAR(1000)         DEFAULT NULL   COMMENT '症状图片',
  `summary`           TEXT                                 DEFAULT NULL COMMENT '问诊小结(医生结束时填写, 线上只建议不确诊)',
  `status`            TINYINT      NOT NULL DEFAULT 0      COMMENT '0待接诊 1进行中 2已结束',
  `moderate_status`   TINYINT      NOT NULL DEFAULT 0      COMMENT '管理员处置 0正常 1无效关闭 2违规屏蔽(非0即参与方不可见)',
  `moderate_reason`   VARCHAR(255)          DEFAULT NULL   COMMENT '处置原因',
  `moderate_by`       BIGINT                DEFAULT NULL   COMMENT '处置人 admin_user.id',
  `moderate_time`     DATETIME              DEFAULT NULL   COMMENT '处置时间',
  `last_message`      VARCHAR(255)          DEFAULT NULL   COMMENT '最后一条消息摘要',
  `last_message_time` DATETIME              DEFAULT NULL   COMMENT '最后消息时间',
  `user_unread`       INT          NOT NULL DEFAULT 0      COMMENT '用户侧未读数',
  `doctor_unread`     INT          NOT NULL DEFAULT 0      COMMENT '医生侧未读数',
  `start_time`        DATETIME              DEFAULT NULL   COMMENT '开始接诊时间',
  `end_time`          DATETIME              DEFAULT NULL   COMMENT '会话结束时间',
  `create_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_appointment_id` (`appointment_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_doctor_status` (`doctor_id`, `status`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '问诊会话';

-- ---------------------------------------------------------------------
-- 9. consult_message  问诊聊天消息(只追加, 不删除; 管理员屏蔽会更新 hidden 三列)
--    屏蔽用显式业务列而不是 deleted: 全局逻辑删除会让管理员审计视图也读不到被屏蔽行
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `consult_message`;
CREATE TABLE `consult_message` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
  `session_id`    BIGINT       NOT NULL                COMMENT 'consult_session.id',
  `sender_id`     BIGINT       NOT NULL                COMMENT '发送者ID, 系统消息为0',
  `sender_role`   VARCHAR(10)  NOT NULL                COMMENT 'USER/DOCTOR/SYSTEM',
  `sender_name`   VARCHAR(50)           DEFAULT NULL   COMMENT '发送者名称',
  `sender_avatar` VARCHAR(255)          DEFAULT NULL   COMMENT '发送者头像',
  `msg_type`      VARCHAR(10)  NOT NULL DEFAULT 'TEXT' COMMENT 'TEXT/IMAGE/SYSTEM/SUGGEST(建议到院)',
  `content`       TEXT         NOT NULL                COMMENT '消息内容(图片时为URL)',
  `is_read`       TINYINT      NOT NULL DEFAULT 0      COMMENT '0未读 1已读',
  `hidden`        TINYINT      NOT NULL DEFAULT 0      COMMENT '0正常 1已屏蔽(参与方不可见, 管理员仍可见)',
  `hidden_reason` VARCHAR(255)          DEFAULT NULL   COMMENT '屏蔽原因',
  `hidden_by`     BIGINT                DEFAULT NULL   COMMENT '处置人 admin_user.id',
  `hidden_time`   DATETIME              DEFAULT NULL   COMMENT '屏蔽时间',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '发送时间',
  PRIMARY KEY (`id`),
  KEY `idx_session_time` (`session_id`, `create_time`),
  KEY `idx_session_read` (`session_id`, `is_read`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '问诊聊天消息';

-- ---------------------------------------------------------------------
-- 10. medical_record  病历 / 处方
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `medical_record`;
CREATE TABLE `medical_record` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
  `record_no`       VARCHAR(32)  NOT NULL                COMMENT '病历编号',
  `appointment_id`  BIGINT       NOT NULL                COMMENT 'appointment.id',
  `user_id`         BIGINT       NOT NULL                COMMENT 'sys_user.id',
  `pet_id`          BIGINT       NOT NULL                COMMENT 'pet.id',
  `doctor_id`       BIGINT       NOT NULL                COMMENT 'doctor.id',
  `department_id`   BIGINT       NOT NULL                COMMENT 'department.id',
  `visit_date`      DATE         NOT NULL                COMMENT '就诊日期',
  `chief_complaint` VARCHAR(500)          DEFAULT NULL   COMMENT '主诉',
  `physical_exam`   VARCHAR(500)          DEFAULT NULL   COMMENT '体格检查',
  `diagnosis`       VARCHAR(500) NOT NULL                COMMENT '诊断结论',
  `prescription`    TEXT                                 DEFAULT NULL COMMENT '处方/用药建议',
  `treatment`       VARCHAR(500)          DEFAULT NULL   COMMENT '处置措施',
  `advice`          VARCHAR(500)          DEFAULT NULL   COMMENT '医嘱',
  `next_visit_date` DATE                  DEFAULT NULL   COMMENT '建议复诊日期',
  `images`          VARCHAR(1000)         DEFAULT NULL   COMMENT '检查图片',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         TINYINT      NOT NULL DEFAULT 0      COMMENT '逻辑删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_record_no` (`record_no`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_pet_id` (`pet_id`),
  KEY `idx_appointment` (`appointment_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '病历处方';

-- ---------------------------------------------------------------------
-- 11. doctor_review  医生评价
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `doctor_review`;
CREATE TABLE `doctor_review` (
  `id`             BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
  `appointment_id` BIGINT       NOT NULL                COMMENT 'appointment.id',
  `user_id`        BIGINT       NOT NULL                COMMENT 'sys_user.id',
  `doctor_id`      BIGINT       NOT NULL                COMMENT 'doctor.id',
  `department_id`  BIGINT       NOT NULL                COMMENT 'department.id',
  `rating`         TINYINT      NOT NULL DEFAULT 5      COMMENT '综合评分 1-5',
  `attitude_score` TINYINT      NOT NULL DEFAULT 5      COMMENT '服务态度 1-5',
  `effect_score`   TINYINT      NOT NULL DEFAULT 5      COMMENT '诊疗效果 1-5',
  `content`        VARCHAR(500)          DEFAULT NULL   COMMENT '评价内容',
  `images`         VARCHAR(1000)         DEFAULT NULL   COMMENT '晒图',
  `is_anonymous`   TINYINT      NOT NULL DEFAULT 0      COMMENT '是否匿名 0否 1是',
  `reply`          VARCHAR(500)          DEFAULT NULL   COMMENT '医生回复',
  `reply_time`     DATETIME              DEFAULT NULL   COMMENT '回复时间',
  `status`         TINYINT      NOT NULL DEFAULT 1      COMMENT '0隐藏 1显示',
  `create_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`        TINYINT      NOT NULL DEFAULT 0      COMMENT '逻辑删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_appointment_id` (`appointment_id`),
  KEY `idx_doctor_id` (`doctor_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '医生评价';

-- ---------------------------------------------------------------------
-- 12. notice  公告 / 养宠科普
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `notice`;
CREATE TABLE `notice` (
  `id`           BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
  `title`        VARCHAR(100) NOT NULL                COMMENT '标题',
  `cover`        VARCHAR(255)          DEFAULT NULL   COMMENT '封面图',
  `summary`      VARCHAR(255)          DEFAULT NULL   COMMENT '摘要',
  `content`      TEXT                                 DEFAULT NULL COMMENT '正文',
  `type`         TINYINT      NOT NULL DEFAULT 1      COMMENT '1公告 2活动 3养宠科普',
  `top_flag`     TINYINT      NOT NULL DEFAULT 0      COMMENT '是否置顶 0否 1是',
  `status`       TINYINT      NOT NULL DEFAULT 1      COMMENT '0草稿 1已发布 2下架',
  `view_count`   INT          NOT NULL DEFAULT 0      COMMENT '阅读量',
  `publish_time` DATETIME              DEFAULT NULL   COMMENT '首次发布时间(下架后重新发布不刷新)',
  `publish_by`   BIGINT                DEFAULT NULL   COMMENT '首次发布人 admin_user.id; 草稿为 NULL',
  `create_time`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`      TINYINT      NOT NULL DEFAULT 0      COMMENT '逻辑删除',
  PRIMARY KEY (`id`),
  KEY `idx_status_type` (`status`, `type`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '公告科普';
