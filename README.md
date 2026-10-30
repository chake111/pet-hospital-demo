# 🐾 宠物医院在线预约与图文问诊系统 (Pet Hospital Management & Telemedicine System)

[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.5.x-brightgreen.svg?logo=springboot)](https://spring.io/projects/spring-boot)
[![Vue](https://img.shields.io/badge/Vue.js-3.5.x-4FC08D.svg?logo=vue.js)](https://vuejs.org/)
[![Vite](https://img.shields.io/badge/Vite-5.4.x-646CFF.svg?logo=vite)](https://vitejs.dev/)
[![Element Plus](https://img.shields.io/badge/Element%20Plus-2.8.x-409EFF.svg?logo=elementplus)](https://element-plus.org/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1.svg?logo=mysql)](https://www.mysql.com/)
[![WebSocket](https://img.shields.io/badge/Protocol-WebSocket%20Native-010101.svg)](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)
[![OpenAPI](https://img.shields.io/badge/OpenAPI-Springdoc%203.0-6BA539.svg?logo=swagger)](https://swagger.io/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> 🎓 **本科毕业设计优秀成果展示仓**  
> 本仓库包含系统**全套架构设计图、33 张高精度业务界面截图、完整接口文档、数据库脚本与数据模型、9 篇架构决策记录（ADR），以及 5.5 万字毕业设计论文定稿 PDF**。

---

## 📖 目录

- [一、项目背景与设计定位](#一项目背景与设计定位)
- [二、核心功能与业务闭环](#二核心功能与业务闭环)
- [三、核心工程亮点与技术选型](#三核心工程亮点与技术选型)
- [四、系统架构与核心时序图](#四系统架构与核心时序图)
- [五、数据库设计与数据模型](#五数据库设计与数据模型)
- [六、系统界面全景预览（33张实拍截图）](#六系统界面全景预览33张实拍截图)
- [七、接口规范与文档](#七接口规范与文档)
- [八、毕业设计论文交付件](#八毕业设计论文交付件)
- [九、仓库目录结构说明](#九仓库目录结构说明)

---

## 一、项目背景与设计定位

传统宠物医疗通常存在**线下排队拥挤、就诊前信息不对称、宠物应激反应严重、线上咨询与线下挂号割裂**等痛点。

本项目针对**单家综合性宠物医院自用场景**，设计并研发了一套基于 **Vue 3 + Spring Boot 3 + MySQL 8** 的一体化预约与在线问诊系统：
1. **就诊前轻量化初筛**：提供免费、不限次的双向实时图文问诊，医生在线研判病情，给出针对性护理建议；
2. **线上精准分流挂号**：医生在问诊会话中可“一键发送建议到院卡片”，患宠主人点击即可直达该医生的挂号排班日历，快速锁号；
3. **就诊全流程数字化**：构建涵盖 **预约挂号 ➔ 模拟支付 ➔ 到院候诊 ➔ 医生同屏接诊开立电子病历 ➔ 诊后三维评价与公开回复** 的端到端业务闭环。

---

## 二、核心功能与业务闭环

系统面向三类角色（宠物主人、接诊医生、系统管理员），形成两套有机联动的业务主线：

```
                    ┌──────────────────────────────────────────────┐
                    │            宠物主人发起线上图文问诊             │
                    └──────────────────────┬───────────────────────┘
                                           │ WebSocket 实时沟通
                                           ▼
                    ┌──────────────────────────────────────────────┐
                    │       医生在线预诊 ➔ 发送「建议到院卡片」        │
                    └──────────────────────┬───────────────────────┘
                                           │ 点击卡片直达医生主页
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                线下门诊全流程闭环                                │
│                                                                                 │
│   选医生/号源 ──> 挂号下单 ──> 模拟支付 ──> 到院候诊 ──> 医生接诊开立病历 ──> 诊后三维评价  │
│      ▲              │            │                         │              │     │
│   排班管理      号源防超卖    超时取消退号               影像挂载/锁定     公开显隐治理 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1. 宠物主人端（移动端适配 / 窄屏 430px）
- **账号与多宠物档案**：手机号快速注册登录，维护多只宠物的品种、体征、过敏史与绝育状况；
- **找医生与智能筛选**：按科室快速导航，支持综合得分、评价数、接诊量多维度排序；
- **精准号源预约**：展示医生未来 7~30 天号源日历，分时段精确锁号；
- **模拟快捷支付**：支持 30 分钟支付倒计时，超时订单由定时任务自动清扫并无损退还号源；
- **实时图文问诊**：基于原生 WebSocket 建立会话，支持患部高清图传、全会话大图轮播、消息送达与已读回执；
- **诊后电子病历与评价**：随时查阅历史门诊病历（含诊断处方与检查影像），就诊后进行三维打分与图文评价。

### 2. 医生接诊端（PC 端宽屏 1440px）
- **实时问诊工作台**：集中处理待接诊、进行中会话；在聊天界面支持一键推送「建议到院卡片」；
- **问诊小结结案**：结束线上问诊时留存书面小结（线上指导意见），明确医疗免责声明；
- **门诊接诊一体化**：接诊工作台左侧展示患者信息与历史病历，右侧同屏录入主诉、体征检查、诊断、用药处方与医嘱；
- **排班与评价交互**：查看个人出诊排班表，公开回复患者评价。

### 3. 后台管理端（PC 端宽屏 1440px）
- **全院运营看板**：挂号量、问诊量、好评率、今日就诊统计与收入可视化大屏；
- **号源与排班中枢**：支持单日排班细粒度调整、整周排班批量生成与停诊冻结保护；
- **基础医疗治理**：科室管理、医生执业信息维护、用户管理、宠物档案管理；
- **内容与合规追溯**：评价显隐合规审核、全院问诊记录只读追溯、医院公告科普发布。

---

## 三、核心工程亮点与技术选型

### 1. 技术栈版本矩阵

| 层次 | 核心技术 / 组件 | 版本 | 说明 |
| :--- | :--- | :--- | :--- |
| **前端架构** | Vue.js | `3.5.x` | 响应式 Composition API、单工程双端路由隔离 |
| **构建工具** | Vite | `5.4.x` | 极速热重载，代理 `/api` 联调 |
| **UI 组件库** | Element Plus | `2.8.x` | 定制化医疗柔和色彩系统、高密度数据表格 |
| **状态管理** | Pinia | `2.x` | 模块化存储登录态、用户信息与未读消息角标 |
| **后端框架** | Spring Boot | `3.5.x` | 现代化 Java 17 企业级服务底座 |
| **持久层** | MyBatis-Plus | `3.5.x` | 简化单表 CRUD，统一逻辑删除与分页规范 |
| **双向通信** | Spring WebSocket | 原生 JSR-356 | 文本/图片帧协议、会话保活、状态心跳 |
| **安全认证** | JJWT | `0.12.x` | HMAC-SHA 多级密钥适配，无状态 Token |
| **数据库** | MySQL | `8.0` | InnoDB 存储引擎，utf8mb4，全业务逻辑外键 |
| **接口规范** | springdoc-openapi | `2.8.x` | OpenAPI 3.0 规范，Swagger UI 在线交互 |

### 2. 关键技术亮点

#### ⚡ 号源防超卖：乐观条件锁方案
未引入笨重的分布式锁组件，采用极简且性能极佳的数据库单行条件更新方案，在单个数据库事务中消除超卖：
```sql
UPDATE doctor_schedule 
SET remaining_slots = remaining_slots - 1 
WHERE id = #{scheduleId} AND remaining_slots > 0;
```
若影响行数为 0 则即刻抛出业务异常「当前时段号源已满」，抗并发能力经压测验证无超卖漏卖。

#### 🔒 Token 版本化治理（Token Versioning）
针对传统 JWT 无法在服务端主动撤回的痛点，设计了**轻量化令牌版本字段**（`token_version`）：
- 每次签发 JWT 时将用户当前 `token_version` 打入 Payload；
- `AccountGuard` 拦截器在每个请求比对 Token 中的版本号与数据库当前版本号；
- **用户修改密码时在同一事务中使 `token_version + 1`**，历史签发的所有令牌即刻瞬间失效；管理员封禁账号亦即刻生效。

#### 🔄 原生 WebSocket 实时通信与状态追踪
- 采用原生 WebSocket 握手拦截器（`WsHandshakeInterceptor`）在握手期完成 JWT 校验与身份绑定；
- 设计会话注册表（`SessionRegistry`），支持心跳保活、双向送达回执（DELIVERED）、已读回执（READ）及医生在线状态动态广播；
- 彻底解耦问诊会话与挂号工单，实现零费用的图文健康咨询。

---

## 四、系统架构与核心时序图

### 1. 系统总体架构图
系统采用严密的分层架构，各层权责分明：

![系统总体架构图](docs/diagrams/figure-4-1-system-architecture.png)

- **表现层**：Vue 3 单工程，根据路由前缀自适应适配移动端 Narrow 布局（430px）与后台 Admin 宽屏布局（1440px）；
- **网关与网络层**：Nginx 反向代理统一网关出口，Vite 开发期无缝代理，统一 `/api` 与 `/ws` 端点；
- **应用控制层**：Spring Boot 3 REST 控制器与 WebSocket 处理器，结合 `HandlerInterceptor` 进行双端隔离；
- **业务服务层**：预约服务、排班服务、问诊服务、病历服务、评价服务、看板统计服务；
- **数据存储层**：MySQL 8 存储 12 张核心业务表，本地静态资源目录持久化上传图像。

---

### 2. 核心业务流程与时序图

#### ① 门诊预约挂号全流程时序图
![门诊预约挂号时序图](docs/diagrams/figure-4-5-appointment-booking-sequence.png)

#### ② 图文问诊实时消息交互时序图
![图文问诊实时消息时序图](docs/diagrams/figure-4-6-consult-message-sequence.png)

#### ③ 预约工单状态流转状态机
![工单状态流转图](docs/diagrams/figure-4-8-appointment-state-flow.png)

---

## 五、数据库设计与数据模型

系统采用 MySQL 8.0，设计有 12 张核心业务表。全面采用逻辑外键以保障高并发下的写入性能，配合全局逻辑删除（`is_deleted`）保障医疗数据可追溯。

### 1. 业务陈氏 ER 模型 (Chen's ER Diagram)
![业务陈氏ER图](docs/diagrams/figure-4-7-business-chen.png)

### 2. 核心数据表清单

| 表名 | 模块职责 | 核心字段说明 |
| :--- | :--- | :--- |
| `sys_user` | 宠物主人账号 | `username`, `password_hash`, `phone`, `token_version`, `status` |
| `pet` | 患宠健康档案 | `user_id`, `name`, `species`, `breed`, `weight`, `is_neutered` |
| `department` | 医院科室体系 | `name`, `code`, `icon`, `sort_order`, `status` |
| `doctor` | 执业医生信息 | `dept_id`, `name`, `title`, `specialty`, `consult_fee`, `bio` |
| `doctor_schedule`| 出诊排班号源 | `doctor_id`, `schedule_date`, `time_slot`, `total_slots`, `remaining_slots` |
| `appointment` | 门诊预约工单 | `order_no`, `user_id`, `doctor_id`, `pet_id`, `status`, `pay_status` |
| `medical_record` | 电子病历 | `appointment_id`, `chief_complaint`, `diagnosis`, `prescription` |
| `doctor_review` | 就诊三维评价 | `appointment_id`, `doctor_id`, `attitude_score`, `skill_score`, `reply` |
| `consult_session`| 图文问诊会话 | `session_no`, `user_id`, `doctor_id`, `pet_id`, `status`, `summary` |
| `consult_message`| 问诊图文消息 | `session_id`, `sender_type`, `msg_type`, `content`, `is_read` |
| `admin_user` | 管理员与医生工号| `username`, `role` (`ADMIN`/`DOCTOR`), `doctor_id`, `token_version` |
| `notice` | 医院公告与科普 | `title`, `content`, `category`, `publish_by`, `status` |

> 完整 SQL 建表语句详见 [sql/01_schema.sql](sql/01_schema.sql)，演示种子数据详见 [sql/02_data.sql](sql/02_data.sql)。完整数据模型文档详见 [docs/database/数据模型.md](docs/database/数据模型.md)。

---

## 六、系统界面全景预览（33张实拍截图）

系统前后端经过严格联调，以下均为系统实际运行截图：

### 1. 宠物主人端（移动端适配 430px）

| 01-用户登录 | 02-用户注册 | 03-移动端首页 | 04-找医生列表 |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/01-client-login.png" width="200"/> | <img src="docs/screenshots/02-client-register.png" width="200"/> | <img src="docs/screenshots/03-client-home.png" width="200"/> | <img src="docs/screenshots/04-client-doctors.png" width="200"/> |

| 05-医生主页与排班 | 06-选号下单 | 07-宠物档案列表 | 08-我的预约工单 |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/05-client-doctor.png" width="200"/> | <img src="docs/screenshots/06-client-booking.png" width="200"/> | <img src="docs/screenshots/07-client-pets.png" width="200"/> | <img src="docs/screenshots/08-client-orders.png" width="200"/> |

| 09-我的问诊会话 | 10-实时在线问诊室 | 11-电子病历详情 | 12-发起图文问诊 |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/09-client-consult.png" width="200"/> | <img src="docs/screenshots/10-client-consultroom.png" width="200"/> | <img src="docs/screenshots/11-client-records.png" width="200"/> | <img src="docs/screenshots/12-client-consult-new.png" width="200"/> |

| 13-模拟快捷支付 | 14-诊后三维评价 |
|:---:|:---:|
| <img src="docs/screenshots/13-client-pay.png" width="200"/> | <img src="docs/screenshots/14-client-review.png" width="200"/> |

---

### 2. 医生接诊端（PC 端宽屏 1440px）

| 30-医生问诊会话列表 | 31-门诊接诊同屏工作台 |
|:---:|:---:|
| <img src="docs/screenshots/30-doctor-consult.png" width="450"/> | <img src="docs/screenshots/31-doctor-workbench.png" width="450"/> |

| 32-医生端实时诊室（发送建议到院卡片） | 35-医生个人出诊排班表 |
|:---:|:---:|
| <img src="docs/screenshots/32-doctor-consultroom.png" width="450"/> | <img src="docs/screenshots/35-doctor-my-schedule.png" width="450"/> |

| 36-问诊小结结案录入 |
|:---:|
| <img src="docs/screenshots/36-doctor-summary.png" width="450"/> |

---

### 3. 后台管理端（PC 端宽屏 1440px）

| 20-管理后台登录 | 21-全院综合数据看板 |
|:---:|:---:|
| <img src="docs/screenshots/20-admin-login.png" width="450"/> | <img src="docs/screenshots/21-admin-dashboard.png" width="450"/> |

| 22-预约门诊工单管理 | 23-全院排班号源矩阵 |
|:---:|:---:|
| <img src="docs/screenshots/22-admin-appointments.png" width="450"/> | <img src="docs/screenshots/23-admin-schedule.png" width="450"/> |

| 24-医生执业信息管理 | 25-全院电子病历档案检索 |
|:---:|:---:|
| <img src="docs/screenshots/24-admin-doctors.png" width="450"/> | <img src="docs/screenshots/25-admin-records.png" width="450"/> |

| 26-评价审核与显隐治理 | 27-医院科普与公告发布 |
|:---:|:---:|
| <img src="docs/screenshots/26-admin-reviews.png" width="450"/> | <img src="docs/screenshots/27-admin-notices.png" width="450"/> |

| 28-用户账号管理 | 29-全院宠物档案档案库 |
|:---:|:---:|
| <img src="docs/screenshots/28-admin-users.png" width="450"/> | <img src="docs/screenshots/29-admin-pets.png" width="450"/> |

| 33-全院问诊记录只读追溯 | 41-排班时段停诊与号源状态 |
|:---:|:---:|
| <img src="docs/screenshots/33-admin-consult-records.png" width="450"/> | <img src="docs/screenshots/41-admin-schedule-stopped-slot.png" width="450"/> |

| 42-排班调整冻结保护提示 |
|:---:|
| <img src="docs/screenshots/42-admin-schedule-adjust-frozen.png" width="450"/> |

---

## 七、接口规范与文档

所有后端 REST 接口挂载在 `/api` 根路径下。

### 1. 统一响应格式
```json
{
  "code": 200,
  "msg": "ok",
  "data": { ... }
}
```
- `code = 200`：操作成功；
- `code = 400`：业务规则校验不满足（如号源已售罄、重复预约等）；
- `code = 401`：未登录或 Token 失效，前端自动清除缓存并重定向；
- `code = 403`：跨角色越权访问被拦截。

### 2. 接口文档详见
完整接口设计、请求体样例、鉴权规则与 WebSocket 帧协议详见：  
👉 **[docs/api/接口文档.md](docs/api/接口文档.md)**

---

## 八、毕业设计论文交付件

本项目作为本科毕业设计作品，具备高完整度的学术与工程文档交付体系：

- **论文题目**：《基于 Spring Boot 与 Vue 的宠物医院预约问诊系统的设计与实现》
- **字数规模**：全篇约 5.5 万字，格式完全符合本科毕业论文规范（含中英文摘要、目录、绪论、关键技术、需求分析、系统设计、系统实现、系统测试、总结与展望、参考文献、致谢）；
- **配图标准**：包含 40 余张规范的 UML 用例图、时序图、陈氏 ER 模型图、架构图与高保真运行截图；
- **论文定稿 PDF 下载**：  
  👉 **[docs/thesis/基于Spring Boot与Vue的宠物医院预约问诊系统的设计与实现.pdf](docs/thesis/基于Spring%20Boot与Vue的宠物医院预约问诊系统的设计与实现.pdf)**

---

## 九、仓库目录结构说明

```
pet-hospital-demo/
├── README.md                           # 本说明文档（含架构图、截图全景与工程总结）
├── LICENSE                             # 开源授权协议（MIT）
├── sql/
│   ├── 01_schema.sql                   # 12 张核心业务表建表脚本
│   └── 02_data.sql                     # 贴近真实业务的脱敏种子数据
└── docs/
    ├── api/
    │   └── 接口文档.md                 # 完整 RESTful 与 WebSocket 接口约定
    ├── database/
    │   └── 数据模型.md                 # 详细字段字典、索引设计与关联分析
    ├── adr/                            # 9 篇架构决策演进记录 (Architecture Decision Records)
    │   ├── 0001-consult-decoupled-from-appointment.md
    │   ├── 0002-missed-means-abandoned-not-absent.md
    │   ├── 0004-medical-record-lock-not-unique-key.md
    │   └── ...
    ├── diagrams/                       # 架构图、时序图、ER 图等原始矢量与高清位图 (19张)
    ├── screenshots/                    # 完整 33 张系统高保真运行截图 (PNG)
    └── thesis/
        └── 基于Spring Boot与Vue的宠物医院预约问诊系统的设计与实现.pdf  # 5.5万字毕业论文定稿 PDF
```

---

## 📄 License

本项目遵循 [MIT License](LICENSE) 开源协议。
