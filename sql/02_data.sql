-- =====================================================================
--  宠物医院预约问诊系统 (单家宠物医院自用版)  pet_clinic
--  02 种子数据脚本   依赖先执行 01_schema.sql
--  执行: mysql -u root -p pet_clinic < 02_data.sql
--
--  演示账号 (密码统一 123456, BCrypt 强度10):
--    用户端   zhangsan / lisi / wangwu / zhaoliu / sunqi   (zhouba 为已禁用示例)
--    管理后台 admin        超级管理员, 可见全部后台菜单
--    管理后台 doctorNN     医生登录位, 与 doctor 表按 id 对应 (doctor01 -> 陈明远)
--
--  数据自洽约定 (重要, 改动本文件时请保持):
--    1) 号源 remain_num 不写死, 由第 12 节按"实际有效订单数"反算,
--       保证 已约数 + 剩余数 == 号源总数, 点开后台不会出现凭空占号.
--    2) 医生 rating / review_count / appointment_count 由真实评价与订单聚合,
--       不手写假分数.
--    3) 全部日期相对 CURDATE() 生成, 任何时候导入当天都有号可约.
--    4) 演示图片(医生/宠物头像、症状照)在 backend/uploads/seed/ 下随仓库跟踪;
--       只导 SQL 没放图时, 页面自动回退首字/占位, 不影响功能.
--    5) 10.3 的"待支付"单在导入约 25 分钟后会被支付超时清扫自动取消 ——
--       答辩/演示当天再导入本文件.
-- =====================================================================

USE `pet_clinic`;
SET NAMES utf8mb4;

-- 明文 123456 -> BCrypt 哈希, 已通过 BCrypt.checkpw 验证
SET @pwd = '$2a$10$0yzLXUNo8OV8t9fBdTlYFumqcM4IBAsInS.neeSzPwQvEtLKjvIGm';

-- =====================================================================
-- 0. 数字辅助表 (0..99), 供排班与历史数据展开使用
-- =====================================================================
DROP TEMPORARY TABLE IF EXISTS `tmp_num`;
CREATE TEMPORARY TABLE `tmp_num` (`n` INT PRIMARY KEY);
INSERT INTO `tmp_num` (`n`)
SELECT x.v FROM (
  SELECT (u.n + t.n * 10 + h.n * 100) AS v
  FROM (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) u,
       (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t,
       (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2) h
) x
WHERE x.v <= 99;

-- 相对今天的日偏移: -45(过去) … +13(未来), 共 59 天
DROP TEMPORARY TABLE IF EXISTS `tmp_days`;
CREATE TEMPORARY TABLE `tmp_days` (`off` INT PRIMARY KEY, `d` DATE);
INSERT INTO `tmp_days` (`off`, `d`)
SELECT n - 45, DATE_ADD(CURDATE(), INTERVAL (n - 45) DAY) FROM `tmp_num` WHERE n <= 58;

-- 三个时段号源模板
DROP TEMPORARY TABLE IF EXISTS `tmp_period`;
CREATE TEMPORARY TABLE `tmp_period` (`p` TINYINT PRIMARY KEY, `s` TIME, `e` TIME, `num` INT);
INSERT INTO `tmp_period` VALUES (1,'08:30:00','12:00:00',20),(2,'13:30:00','17:30:00',20),(3,'18:00:00','21:30:00',12);

-- 医生排班偏好: pref 1=只上午 2=只下午 3=全天三班; off_weekday 1=周一休 … 7=周日休, 0=不休
DROP TEMPORARY TABLE IF EXISTS `tmp_pref`;
CREATE TEMPORARY TABLE `tmp_pref` (`doctor_id` BIGINT PRIMARY KEY, `pref` TINYINT, `off_weekday` INT);
INSERT INTO `tmp_pref` VALUES
(1 ,3,1),(2 ,1,3),(3 ,2,0),(4 ,1,2),(5 ,3,4),(6 ,1,1),
(7 ,2,5),(8 ,1,6),(9 ,3,3),(10,2,0),(11,1,2),(12,3,6);

-- =====================================================================
-- 1. 科室
-- =====================================================================
INSERT INTO `department` (`id`,`name`,`code`,`icon`,`description`,`sort`,`status`) VALUES
(1,'宠物内科','NK','stethoscope','发热、呕吐、腹泻、食欲不振、泌尿及呼吸消化系统疾病诊治',10,1),
(2,'宠物外科','WK','surgery','软组织手术、骨科手术、绝育去势、外伤缝合及肿物切除',20,1),
(3,'宠物皮肤科','PF','skin','皮肤病、真菌感染、螨虫、过敏及脱毛瘙痒诊治',30,1),
(4,'宠物眼科','YK','eye','结膜炎、角膜溃疡、白内障、干眼症及泪痕管理',40,1),
(5,'宠物口腔科','KQ','tooth','牙结石、口臭、牙龈炎、拔牙及口腔清洁',50,1),
(6,'影像检验科','YX','imaging','DR影像、B超、血常规、生化及尿检便检',60,1),
(7,'疫苗接种科','YM','vaccine','猫三联、狂犬、犬四联及体内外驱虫',70,1),
(8,'营养行为科','YY','nutrition','处方粮建议、肥胖管理、行为纠正及幼宠喂养',80,1),
(9,'急诊重症科','JZ','emergency','中毒、车祸、呼吸困难、休克等急重症抢救',90,1),
(10,'异宠专科','YC','exotic','兔子、仓鼠、龙猫、龟类及鸟类诊疗',100,1);

-- =====================================================================
-- 2. 医生 (院内员工花名册, 非入驻制)
--    统计字段先给 0, 第 11 节聚合回填; 唐婉如 status=0 为"停诊"示例
-- =====================================================================
INSERT INTO `doctor`
(`id`,`name`,`avatar`,`gender`,`phone`,`title`,`department_id`,`specialty`,`introduction`,`work_years`,`consultation_fee`,`rating`,`review_count`,`appointment_count`,`status`,`sort`) VALUES
(1 ,'陈明远','/api/uploads/seed/doctor-01.jpg',1,'13800138001','主任医师'  ,1 ,'猫犬肠胃炎,胰腺炎,慢性肾病,内分泌疾病','从事宠物临床诊疗18年，曾任连锁宠物医院医疗总监，擅长疑难内科病例会诊。',18,80.00,5.0,0,0,1,10),
(2 ,'林若初','/api/uploads/seed/doctor-02.jpg',2,'13800138002','副主任医师',1 ,'幼猫腹泻,猫传染性腹膜炎,上呼吸道感染','专注猫科疾病十年，对幼猫哺育及猫科慢性病管理有丰富经验。',12,60.00,5.0,0,0,1,20),
(3 ,'赵启铭','/api/uploads/seed/doctor-03.jpg',1,'13800138003','主任医师'  ,2 ,'骨科手术,关节脱位,软组织肿物切除','外科组组长，累计完成各类手术三千余台，擅长骨科及微创。',16,100.00,5.0,0,0,1,30),
(4 ,'孙浩然','/api/uploads/seed/doctor-04.jpg',1,'13800138004','主治医师'  ,2 ,'绝育去势,外伤缝合,耳血肿处理','外科手术医师，操作细致，注重术中镇痛与术后随访。',7 ,50.00,5.0,0,0,1,40),
(5 ,'黄雅雯','/api/uploads/seed/doctor-05.jpg',2,'13800138005','副主任医师',3 ,'猫癣,螨虫,食物过敏,脂溢性皮炎','皮肤科专科医师，擅长皮肤刮片镜检与过敏性疾病排查。',11,55.00,5.0,0,0,1,50),
(6 ,'吴承宇','/api/uploads/seed/doctor-06.jpg',1,'13800138006','主治医师'  ,4 ,'角膜溃疡,结膜炎,白内障,泪痕管理','眼科专科医师，可开展眼压测量及荧光素染色检查。',8 ,60.00,5.0,0,0,1,60),
(7 ,'郑思琪','/api/uploads/seed/doctor-07.jpg',2,'13800138007','主治医师'  ,5 ,'牙结石超声洁治,牙周炎,滞留乳牙拔除','口腔专科医师，主导院内洁治与口腔护理项目。',6 ,45.00,5.0,0,0,1,70),
(8 ,'马天成','/api/uploads/seed/doctor-08.jpg',1,'13800138008','住院医师'  ,6 ,'DR读片,腹部B超,细胞学检查','影像科医师，负责院内影像与检验报告的出具与解读。',4 ,40.00,5.0,0,0,1,80),
(9 ,'许静怡','/api/uploads/seed/doctor-09.jpg',2,'13800138009','助理医师'  ,7 ,'疫苗程序制定,体内外驱虫,幼宠健康管理','负责疫苗接种与宠物健康档案管理工作。',3 ,25.00,5.0,0,0,1,90),
(10,'何俊豪','/api/uploads/seed/doctor-10.jpg',1,'13800138010','主治医师'  ,9 ,'急重症抢救,中毒处理,休克复苏','急诊值班医师，负责夜间急重症绿色通道。',9 ,90.00,5.0,0,0,1,100),
(11,'刘恋'  ,'/api/uploads/seed/doctor-11.jpg',2,'13800138011','主治医师'  ,10,'兔消化道停滞,仓鼠肿瘤,龟类代谢病','异宠专科医师，省内少数专注异宠的临床医师。',7 ,70.00,5.0,0,0,1,110),
(12,'唐婉如','/api/uploads/seed/doctor-12.jpg',2,'13800138012','住院医师'  ,8 ,'处方粮搭配,肥胖干预,行为问题咨询','营养与行为咨询岗，负责术后康复期的喂养方案制定。',3 ,30.00,5.0,0,0,0,120);

-- =====================================================================
-- 3. 后台账号 (管理员 + 医生登录位)
-- =====================================================================
INSERT INTO `admin_user` (`id`,`username`,`password`,`real_name`,`avatar`,`phone`,`email`,`role`,`doctor_id`,`status`) VALUES
(1,'admin'    ,@pwd,'苏幼薇',NULL,'13900139000','admin@petclinic.cn'  ,'ADMIN',NULL,1),
(2,'service01',@pwd,'前台客服',NULL,'13900139001','service@petclinic.cn','ADMIN',NULL,1);

INSERT INTO `admin_user` (`username`,`password`,`real_name`,`phone`,`role`,`doctor_id`,`status`)
SELECT CONCAT('doctor', LPAD(d.id, 2, '0')), @pwd, d.name, d.phone, 'DOCTOR', d.id, 1
FROM `doctor` d WHERE d.deleted = 0;

-- =====================================================================
-- 4. 注册用户 (宠物主人)
-- =====================================================================
INSERT INTO `sys_user`
(`id`,`username`,`password`,`nickname`,`avatar`,`phone`,`email`,`gender`,`birthday`,`city`,`address`,`status`,`remark`) VALUES
(1,'zhangsan',@pwd,'张三',NULL,'13700137001','zhangsan@example.com',1,'1995-03-18','杭州','西湖区文三路 100 号'    ,1,'猫奴一枚'),
(2,'lisi'    ,@pwd,'李四',NULL,'13700137002','lisi@example.com'    ,2,'1992-07-02','杭州','拱墅区莫干山路 256 号'  ,1,''),
(3,'wangwu'  ,@pwd,'王五',NULL,'13700137003','wangwu@example.com'  ,1,'1988-11-25','杭州','滨江区江南大道 88 号'    ,1,'老客户'),
(4,'zhaoliu' ,@pwd,'赵六',NULL,'13700137004','zhaoliu@example.com' ,2,'1998-01-09','杭州','余杭区文一西路 969 号'  ,1,''),
(5,'sunqi'   ,@pwd,'孙七',NULL,'13700137005','sunqi@example.com'   ,1,'1990-05-30','杭州','萧山区市心路 189 号'    ,1,'养了兔子和龟'),
(6,'zhouba'  ,@pwd,'周八',NULL,'13700137006','zhouba@example.com'  ,2,'1996-09-14','杭州','上城区庆春路 66 号'      ,0,'已禁用账号示例');

-- =====================================================================
-- 5. 宠物档案
--    归属: 张三->1,2  李四->3,4  王五->5,6  赵六->7,8  孙七->9,10
-- =====================================================================
INSERT INTO `pet`
(`id`,`user_id`,`name`,`species`,`breed`,`gender`,`birthday`,`age_month`,`weight`,`color`,`is_neutered`,`vaccine_status`,`deworm_flag`,`avatar`,`allergy`,`medical_history`,`remark`) VALUES
(1 ,1,'布丁','猫'  ,'英国短毛猫',1,'2023-05-20',39,5.80 ,'蓝白'  ,1,2,1,'/api/uploads/seed/pet-01.jpg','无'        ,'2024年曾患胃肠炎'      ,'性格温顺,怕吹风机'),
(2 ,1,'奶糖','猫'  ,'中华田园猫',2,'2024-08-11',13,3.60 ,'三花'  ,0,1,1,'/api/uploads/seed/pet-02.jpg','对海鲜过敏',NULL                    ,'领养的流浪猫'),
(3 ,2,'豆豆','狗'  ,'柯基'      ,1,'2022-02-14',79,12.40,'三色'  ,1,2,1,'/api/uploads/seed/pet-03.jpg','无'        ,'轻度椎间盘问题'        ,'不能上下楼梯'),
(4 ,2,'团子','狗'  ,'萨摩耶'    ,2,'2023-11-03',34,21.00,'纯白'  ,1,2,0,'/api/uploads/seed/pet-04.jpg','无'        ,NULL                    ,'掉毛严重'),
(5 ,3,'阿黄','狗'  ,'金毛寻回犬',1,'2019-06-08',87,31.50,'金黄'  ,1,2,1,'/api/uploads/seed/pet-05.jpg','无'        ,'髋关节发育不良,定期复查','老年犬'),
(6 ,3,'小灰','猫'  ,'俄罗斯蓝猫',2,'2024-01-22',31,4.10 ,'灰色'  ,1,2,1,'/api/uploads/seed/pet-06.jpg','无'        ,NULL                    ,''),
(7 ,4,'球球','兔'  ,'垂耳兔'    ,2,'2024-03-15',30,1.90 ,'灰白'  ,0,0,0,'/api/uploads/seed/pet-07.jpg','无'        ,'曾患消化道停滞'        ,'只吃提摩西草'),
(8 ,4,'胖虎','仓鼠','金丝熊'    ,1,'2025-04-02',5 ,0.12 ,'奶茶色',0,0,0,'/api/uploads/seed/pet-08.jpg','无'        ,NULL                    ,''),
(9 ,5,'旺旺','狗'  ,'柴犬'      ,1,'2023-07-19',38,9.80 ,'赤色'  ,1,2,1,'/api/uploads/seed/pet-09.jpg','无'        ,NULL                    ,'挑食'),
(10,5,'绿豆','龟'  ,'巴西龟'    ,0,'2020-05-01',76,0.85 ,'绿色'  ,0,0,0,'/api/uploads/seed/pet-10.jpg','无'        ,'软壳症病史'            ,'异宠门诊');

-- =====================================================================
-- 6. 排班号源: 过去 45 天 + 未来 14 天
--    remain_num 先等于 total_num, 第 12 节按实际订单反算
-- =====================================================================
INSERT INTO `doctor_schedule`
(`doctor_id`,`work_date`,`period`,`start_time`,`end_time`,`total_num`,`remain_num`,`status`)
SELECT d.id, t.d, tp.p, tp.s, tp.e, tp.num, tp.num, 1
FROM `doctor` d
JOIN `tmp_pref`   pf ON pf.doctor_id = d.id
JOIN `tmp_days`   t  ON t.`off` <= 13
JOIN `tmp_period` tp ON tp.p = (CASE WHEN pf.pref = 3 THEN tp.p ELSE pf.pref END)
WHERE d.status = 1
  AND (pf.off_weekday = 0 OR DAYOFWEEK(t.d) <> pf.off_weekday + 1);

-- =====================================================================
-- 7. 历史预约 (过去 45 天, 挂到真实号源上, 供后台看板曲线与工作台)
--    条数 = tmp_num 上限 99; 状态分布: 大部分已完成, 少量未到诊/已取消(取消不占号)
-- =====================================================================
DROP TEMPORARY TABLE IF EXISTS `tmp_hist_sch`;
CREATE TEMPORARY TABLE `tmp_hist_sch` (`rn` INT PRIMARY KEY AUTO_INCREMENT, `sid` BIGINT, `doc` BIGINT, `wd` DATE, `pd` TINYINT, `st` TIME, `et` TIME);
INSERT INTO `tmp_hist_sch` (`sid`,`doc`,`wd`,`pd`,`st`,`et`)
SELECT s.id, s.doctor_id, s.work_date, s.period, s.start_time, s.end_time
FROM `doctor_schedule` s
WHERE s.work_date < CURDATE() AND s.status = 1
ORDER BY s.work_date, s.doctor_id, s.period;

SET @hsc = (SELECT COUNT(*) FROM `tmp_hist_sch`);

DROP TEMPORARY TABLE IF EXISTS `tmp_userpet`;
CREATE TEMPORARY TABLE `tmp_userpet` (`rn` INT PRIMARY KEY AUTO_INCREMENT, `user_id` BIGINT, `pet_id` BIGINT);
INSERT INTO `tmp_userpet` (`user_id`,`pet_id`)
SELECT p.user_id, p.id
FROM `pet` p JOIN `sys_user` u ON u.id = p.user_id AND u.deleted = 0 AND u.status = 1
WHERE p.deleted = 0
ORDER BY p.user_id, p.id;

SET @upc = (SELECT COUNT(*) FROM `tmp_userpet`);

INSERT INTO `appointment`
(`order_no`,`user_id`,`pet_id`,`doctor_id`,`department_id`,`schedule_id`,`consult_type`,`appointment_date`,`period`,
 `start_time`,`end_time`,`symptom`,`amount`,`pay_status`,`pay_time`,`pay_type`,`status`,`accept_time`,`finish_time`,
 `cancel_reason`,`cancel_time`,`cancel_by`,`is_reviewed`,`create_time`)
SELECT
  CONCAT('H', DATE_FORMAT(hs.wd, '%Y%m%d'), LPAD(k.n, 4, '0')),
  up.user_id, up.pet_id, hs.doc, doc.department_id, hs.sid,
  2,                                   -- 全部到院门诊：图文问诊不建订单
  hs.wd, hs.pd, hs.st, hs.et,
  ELT(1 + (k.n % 6),
      '呕吐腹泻两天，食欲明显下降，精神略差',
      '后背瘙痒脱毛，皮屑增多，疑似猫癣',
      '定期疫苗加强和体内外驱虫复查',
      '口臭明显，牙龈红肿，进食时流涎',
      '昨日起跛行，前肢不敢着地，触之抗拒',
      '腹部B超复查，另请解读血常规报告'),
  doc.consultation_fee,
  CASE WHEN (k.n % 11) = 5 THEN 0 ELSE 1 END,
  CONCAT(hs.wd, ' 08:00:00'),
  ELT(1 + (k.n % 2), 'ALIPAY', 'WECHAT'),
  CASE WHEN (k.n % 11) = 5 THEN 3      -- 已取消
       WHEN (k.n % 17) = 3 THEN 4      -- 未到诊
       ELSE 2 END                      -- 已完成
  ,
  CASE WHEN (k.n % 11) = 5 THEN NULL ELSE CONCAT(hs.wd, ' 09:10:00') END,
  CASE WHEN (k.n % 11) = 5 THEN NULL ELSE CONCAT(hs.wd, ' 10:20:00') END,
  CASE WHEN (k.n % 11) = 5 THEN '临时有事，改约下周' ELSE NULL END,
  CASE WHEN (k.n % 11) = 5 THEN CONCAT(hs.wd, ' 08:40:00') ELSE NULL END,
  CASE WHEN (k.n % 11) = 5 THEN 'USER' ELSE NULL END,
  CASE WHEN (k.n % 11) = 5 THEN 0
       WHEN (k.n % 17) = 3 THEN 0
       WHEN (k.n % 2) = 0  THEN 1 ELSE 0 END,
  CONCAT(hs.wd - INTERVAL 2 DAY, ' 20:15:00')
FROM `tmp_num` k
JOIN `tmp_hist_sch` hs ON hs.rn = 1 + (k.n % @hsc)
JOIN `tmp_userpet`  up ON up.rn = 1 + ((k.n * 7) % @upc)
JOIN `doctor`       doc ON doc.id = hs.doc
WHERE k.n BETWEEN 1 AND 150;

-- =====================================================================
-- 8. 历史病历 (每条已完成/未到诊订单一份, 取消的不生成)
-- =====================================================================
INSERT INTO `medical_record`
(`record_no`,`appointment_id`,`user_id`,`pet_id`,`doctor_id`,`department_id`,`visit_date`,
 `chief_complaint`,`physical_exam`,`diagnosis`,`prescription`,`treatment`,`advice`,`next_visit_date`,`create_time`)
SELECT
  CONCAT('MR', a.order_no), a.id, a.user_id, a.pet_id, a.doctor_id, a.department_id, a.appointment_date,
  a.symptom,
  ELT(1 + (a.id % 4),
      '体温38.6℃，精神中等，腹壁触诊轻度疼痛，肠音亢进',
      '体表多处红斑脱毛，伍德氏灯阳性，皮屑镜检见真菌孢子',
      '体温38.2℃，可视黏膜粉红，心肺听诊未见异常',
      '口腔牙结石III度，牙龈红肿，左上第四前臼齿II度松动'),
  ELT(1 + (a.id % 4), '急性胃肠炎', '小孢子菌感染(癣)', '健康状态良好，可按期免疫', '中度牙周炎'),
  ELT(1 + (a.id % 4),
      '益生菌 1袋 每日2次×7天；禁食6小时后清淡处方粮',
      '特比萘芬喷剂 外用 每日2次×21天；药浴 每周2次',
      '维持原免疫程序；体内外驱虫 每月1次',
      '超声洁治后口服阿莫西林克拉维酸钾×5天；口腔喷雾 每日2次') ,
  ELT(1 + (a.id % 4), '补液 500ml，皮下注射', '药浴 + 局部上药', '疫苗皮下注射 1 剂', '全麻超声洁治 + 抛光'),
  ELT(1 + (a.id % 4),
      '两日内忌零食与牛奶，观察排便，持续呕吐立即复诊',
      '同居家猫犬隔离，梳子毛巾专用，两周后复查镜检',
      '留院观察30分钟无过敏反应方可离开，一周后复查',
      '两周内软食为主，之后每周刷牙三次'),
  DATE_ADD(a.appointment_date, INTERVAL 14 DAY),
  a.finish_time
FROM `appointment` a
WHERE a.deleted = 0 AND a.status IN (2, 4) AND a.order_no LIKE 'H%';

-- =====================================================================
-- 9. 历史评价 (仅 is_reviewed=1 的订单, 一单一评)
-- =====================================================================
INSERT INTO `doctor_review`
(`appointment_id`,`user_id`,`doctor_id`,`department_id`,`rating`,`attitude_score`,`effect_score`,
 `content`,`is_anonymous`,`reply`,`reply_time`,`status`,`create_time`)
SELECT
  a.id, a.user_id, a.doctor_id, a.department_id, r.star, r.att, r.eff, r.txt, r.anon,
  CASE WHEN r.star = 5 THEN '感谢您的信任，祝毛孩子健康～' ELSE NULL END,
  CASE WHEN r.star = 5 THEN DATE_ADD(a.finish_time, INTERVAL 3 HOUR) ELSE NULL END,
  1, DATE_ADD(a.finish_time, INTERVAL 1 HOUR)
FROM `appointment` a
JOIN (
  SELECT 1 AS idx, 5 AS star, 5 AS att, 5 AS eff, 0 AS anon,
         '医生非常耐心，把检查报告一条条讲给我听，用药也写得很清楚。' AS txt
  UNION ALL SELECT 2, 5, 5, 4, 0, '线上问诊很方便，不用抱着猫排队，看完照片给了方案，当天就好转。'
  UNION ALL SELECT 3, 4, 5, 4, 1, '问诊时间略短，不过结论准确，药也不贵，会回购。'
  UNION ALL SELECT 4, 5, 4, 5, 0, '包扎手法利索，价格透明，没有乱开检查。'
  UNION ALL SELECT 5, 3, 4, 3, 1, '等候有点久，其他还行。'
  UNION ALL SELECT 6, 5, 5, 5, 0, '复诊提醒很贴心，客服也会跟进，整体体验很好。'
) r ON r.idx = 1 + (a.id % 6)
WHERE a.deleted = 0 AND a.status = 2 AND a.is_reviewed = 1;

-- =====================================================================
-- 10. 演示中的会话与订单 (今天 / 明天) —— 端到端流程演示用
--     覆盖: 图文会话进行中 / 图文会话待接诊 / 图文会话已结束带小结
--           到院待接诊已付 / 到院待支付 / 已完成带病历评价 / 已取消
-- =====================================================================

-- 刘恋(doctor 11)今起最近的号源做"待接诊"演示单; 她当天休诊时顺延到有号的最近一天
SET @s2 = (SELECT id FROM `doctor_schedule` WHERE doctor_id = 11 AND work_date >= CURDATE() AND status = 1 ORDER BY work_date, period LIMIT 1);
-- 别人名下的一张今日号源做"待支付"演示单
SET @s3 = (SELECT id FROM `doctor_schedule` WHERE work_date = CURDATE() AND status = 1 AND doctor_id <> 11 ORDER BY id LIMIT 1);

-- 10.1 图文问诊 医生已接诊 会话进行中  (主演示会话, 张三 & 布丁 & 刘恋)
--      不建订单：会话独立存在。id=1 是固定演示会话
SET @doc1 = 11;
SET @docname = (SELECT name FROM `doctor` WHERE id = @doc1);

INSERT INTO `consult_session`
(`appointment_id`,`user_id`,`doctor_id`,`pet_id`,`symptom`,`images`,`status`,`last_message`,`last_message_time`,`user_unread`,`doctor_unread`,`start_time`)
VALUES (NULL, 1, @doc1, 1,
        '布丁从昨晚开始呕吐三次，今早不吃东西，喝了水又吐出来，精神比平时差，没有拉稀。想问是否需要立刻来院？',
        NULL, 1, '[建议到院就医] 建议明天到院复诊，空腹来做个腹部检查，点卡片挂号选时段。',
        DATE_SUB(NOW(), INTERVAL 24 MINUTE), 2, 0, DATE_SUB(NOW(), INTERVAL 40 MINUTE));
SET @sess1 = LAST_INSERT_ID();

INSERT INTO `consult_message`
(`session_id`,`sender_id`,`sender_role`,`sender_name`,`sender_avatar`,`msg_type`,`content`,`is_read`,`create_time`) VALUES
(@sess1, 0,'SYSTEM','系统',NULL,'SYSTEM','医生已接诊，会话开始。请勿在会话中发送银行卡号等隐私信息。',1,DATE_SUB(NOW(), INTERVAL 40 MINUTE)),
(@sess1, 1,'USER'  ,'张三' ,NULL,'TEXT'  ,'布丁从昨晚开始呕吐三次，今早不吃东西，喝了水又吐，精神差。',1,DATE_SUB(NOW(), INTERVAL 39 MINUTE)),
(@sess1, 1,'USER'  ,'张三' ,NULL,'TEXT'  ,'另外想问下，昨晚给她换了新粮，会不会是粮的问题？',1,DATE_SUB(NOW(), INTERVAL 38 MINUTE)),
(@sess1, @doc1,'DOCTOR',@docname,NULL,'TEXT','你好，先确认几点：呕吐物里有血丝或没消化的粮吗？最近有没有乱吃线头、塑料袋之类？',1,DATE_SUB(NOW(), INTERVAL 36 MINUTE)),
(@sess1, 1,'USER'  ,'张三' ,NULL,'TEXT'  ,'没有血丝，是半消化的糊状。线头这些应该没有，她平时挺乖。',1,DATE_SUB(NOW(), INTERVAL 34 MINUTE)),
(@sess1, @doc1,'DOCTOR',@docname,NULL,'TEXT','从描述看更像换粮引起的急性胃肠炎。先禁食6小时、少量多次给水，之后喂回原来的粮做过渡。',1,DATE_SUB(NOW(), INTERVAL 33 MINUTE)),
(@sess1, @doc1,'DOCTOR',@docname,NULL,'TEXT','益生菌一次一袋、一天两次，拌少量温水喂。若禁食期间仍持续呕吐、或出现便血、伏卧不动，立刻来急诊。',1,DATE_SUB(NOW(), INTERVAL 32 MINUTE)),
(@sess1, 1,'USER'  ,'张三' ,NULL,'TEXT'  ,'明白了，那换粮是要七八天慢慢掺吗？',1,DATE_SUB(NOW(), INTERVAL 30 MINUTE)),
(@sess1, @doc1,'DOCTOR',@docname,NULL,'TEXT','对，1/4 → 1/2 → 3/4 → 全量，每阶段2-3天，肠胃敏感的猫拖得更慢。',1,DATE_SUB(NOW(), INTERVAL 27 MINUTE)),
(@sess1, 1,'USER'  ,'张三' ,NULL,'TEXT'  ,'好的谢谢医生！',1,DATE_SUB(NOW(), INTERVAL 26 MINUTE)),
(@sess1, @doc1,'DOCTOR',@docname,NULL,'TEXT','好的，按我说的先处理，明天复诊见。',0,DATE_SUB(NOW(), INTERVAL 25 MINUTE)),
(@sess1, @doc1,'DOCTOR',@docname,NULL,'SUGGEST','建议明天到院复诊，空腹来做个腹部检查，点卡片挂号选时段。',0,DATE_SUB(NOW(), INTERVAL 24 MINUTE));

-- 10.2 到院门诊 已支付待接诊  (孙七 & 绿豆 & 刘恋, 异宠复查)
INSERT INTO `appointment`
(`order_no`,`user_id`,`pet_id`,`doctor_id`,`department_id`,`schedule_id`,`consult_type`,`appointment_date`,`period`,
 `start_time`,`end_time`,`symptom`,`amount`,`pay_status`,`pay_time`,`pay_type`,`status`,`is_reviewed`,`create_time`)
SELECT CONCAT('PC', DATE_FORMAT(CURDATE(),'%Y%m%d'), '0002'), 5, 10, s.doctor_id, d.department_id, @s2, 2,
       s.work_date, s.period, s.start_time, s.end_time,
       '绿豆这两天不太下水，背甲边缘摸着发软，之前在异宠门诊看过软壳症，想带来复查一下。',
       d.consultation_fee, 1, NOW(), 'WECHAT', 0, 0, DATE_SUB(NOW(), INTERVAL 20 MINUTE)
FROM `doctor_schedule` s JOIN `doctor` d ON d.id = s.doctor_id WHERE s.id = @s2;

-- 10.3 到院门诊 待支付  (王五 & 小灰)
INSERT INTO `appointment`
(`order_no`,`user_id`,`pet_id`,`doctor_id`,`department_id`,`schedule_id`,`consult_type`,`appointment_date`,`period`,
 `start_time`,`end_time`,`symptom`,`amount`,`pay_status`,`status`,`is_reviewed`,`create_time`)
SELECT CONCAT('PC', DATE_FORMAT(CURDATE(),'%Y%m%d'), '0003'), 3, 6, s.doctor_id, d.department_id, @s3, 2,
       s.work_date, s.period, s.start_time, s.end_time,
       '小灰最近饭量变小，还老躲着人，想约个体检，到院看看有没有问题。',
       d.consultation_fee, 0, 0, 0, DATE_SUB(NOW(), INTERVAL 5 MINUTE)
FROM `doctor_schedule` s JOIN `doctor` d ON d.id = s.doctor_id WHERE s.id = @s3;

-- 10.4 最近一次门诊已完成 带病历与评价  (赵六 & 球球, 异宠专科)
--      挂到刘恋最近一张过去的号源上(她当天休诊时自动前移), 时间戳全部按就诊日推导
SET @s4 = (SELECT id FROM `doctor_schedule` WHERE doctor_id = 11 AND work_date < CURDATE() ORDER BY work_date DESC, period DESC LIMIT 1);
SET @d4 = (SELECT work_date FROM `doctor_schedule` WHERE id = @s4);

INSERT INTO `appointment`
(`order_no`,`user_id`,`pet_id`,`doctor_id`,`department_id`,`schedule_id`,`consult_type`,`appointment_date`,`period`,
 `start_time`,`end_time`,`symptom`,`amount`,`pay_status`,`pay_time`,`pay_type`,`status`,`accept_time`,`finish_time`,`is_reviewed`,`create_time`)
SELECT CONCAT('PC', DATE_FORMAT(@d4,'%Y%m%d'), '0004'), 4, 7, 11, 10, @s4, 2,
       @d4, s.period, s.start_time, s.end_time,
       '球球两天没排便，不吃东西，一直蹲着缩成一团，肚子摸着有点硬。',
       70.00, 1, CONCAT(@d4, ' 08:05:00'), 'ALIPAY', 2,
       CONCAT(@d4, ' 08:40:00'), CONCAT(@d4, ' 09:30:00'), 1,
       CONCAT(@d4 - INTERVAL 1 DAY, ' 21:15:00')
FROM `doctor_schedule` s WHERE s.id = @s4;

SET @a4 = LAST_INSERT_ID();

INSERT INTO `medical_record`
(`record_no`,`appointment_id`,`user_id`,`pet_id`,`doctor_id`,`department_id`,`visit_date`,
 `chief_complaint`,`physical_exam`,`diagnosis`,`prescription`,`treatment`,`advice`,`next_visit_date`,`create_time`)
VALUES
(CONCAT('MR', (SELECT order_no FROM `appointment` WHERE id = @a4)), @a4, 4, 7, 11, 10, @d4,
 '两天未排便且停食，精神沉郁，腹部触诊胃区胀满',
 '体温38.4℃，腹部触诊胃内充满食糜，肠音明显减弱，盲肠叩诊鼓音',
 '兔胃肠道停滞（GI Stasis）',
 '促胃肠动力药 甲氧氯普胺 0.5mg/kg 每日3次；恢复期高纤维流食（草粉糊）每4小时10ml；益生菌 每日2次',
 '皮下补液 100ml；腹部按摩每次5分钟、每日3次；强制饲喂草粉糊',
 '立刻改为无限量提摩西草、减少颗粒粮与零食，增加活动量，每天观察便粒大小；若24小时内无排便立即来院',
 DATE_ADD(@d4, INTERVAL 3 DAY),
 CONCAT(@d4, ' 09:30:00'));

INSERT INTO `doctor_review`
(`appointment_id`,`user_id`,`doctor_id`,`department_id`,`rating`,`attitude_score`,`effect_score`,`content`,`is_anonymous`,`reply`,`reply_time`,`status`,`create_time`)
VALUES
(@a4, 4, 11, 10, 5, 5, 5,
 '刘医生对兔子真的很懂，讲清楚了为什么不能只吃粮，草粉糊喂法也写得很细。球球昨晚开始拉便便了，太感谢！',
 0, '很高兴球球好转了，干草请继续保持无限量供应，三天后带回来复查一下体重。',
 CONCAT(@d4, ' 13:10:00'), 1, CONCAT(@d4, ' 11:10:00'));

-- 10.5 已取消示例  (孙七 & 旺旺) —— 取消不占号, 第 12 节反算时会自动排除
INSERT INTO `appointment`
(`order_no`,`user_id`,`pet_id`,`doctor_id`,`department_id`,`schedule_id`,`consult_type`,`appointment_date`,`period`,
 `start_time`,`end_time`,`symptom`,`amount`,`pay_status`,`status`,`cancel_reason`,`cancel_time`,`cancel_by`,`is_reviewed`,`create_time`)
SELECT CONCAT('PC', DATE_FORMAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY),'%Y%m%d'), '0005'), 5, 9, 3, 2, NULL, 2,
       DATE_ADD(CURDATE(), INTERVAL 1 DAY), 2, '13:30:00','17:30:00',
       '旺旺右后爪走路有点瘸，想约个时间拍个片。',
       100.00, 0, 3, '临时出差，改约下周', DATE_SUB(NOW(), INTERVAL 2 HOUR), 'USER', 0, DATE_SUB(NOW(), INTERVAL 3 HOUR);

-- 10.6 图文问诊 待接诊  (王五 & 小灰, 医生侧"接诊"演示用)
INSERT INTO `consult_session`
(`appointment_id`,`user_id`,`doctor_id`,`pet_id`,`symptom`,`images`,`status`,`user_unread`,`doctor_unread`,`create_time`)
VALUES (NULL, 3, 11, 6,
        '小灰右眼流泪有分泌物大约一周，偶尔用爪子挠眼，想先发照片请您判断一下是否要立刻到院。',
        '/api/uploads/seed/sym-1.jpg', 0, 0, 0, DATE_SUB(NOW(), INTERVAL 12 MINUTE));

-- 10.7 图文问诊 已结束 带问诊小结  (张三 & 奶糖, 两天前)
INSERT INTO `consult_session`
(`appointment_id`,`user_id`,`doctor_id`,`pet_id`,`symptom`,`images`,`summary`,`status`,`last_message`,`last_message_time`,`user_unread`,`doctor_unread`,`start_time`,`end_time`,`create_time`)
VALUES (NULL, 1, 11, 2,
        '奶糖最近老是甩头挠耳，扒开耳朵里黑黑的一层，想先问问是不是耳螨。',
        '/api/uploads/seed/sym-2.jpg',
        '从照片看更像耳螨：先用洗耳液灌洗擦净，再上耳药，一天两次连用两周。两周后到院复查耳道镜检；若出现歪头、转圈请尽快来院。',
        2, '好的，谢谢医生！', DATE_SUB(NOW(), INTERVAL 2 DAY), 0, 0,
        DATE_SUB(NOW(), INTERVAL 2 DAY) - INTERVAL 40 MINUTE, DATE_SUB(NOW(), INTERVAL 2 DAY),
        DATE_SUB(NOW(), INTERVAL 2 DAY) - INTERVAL 50 MINUTE);
SET @sess2 = LAST_INSERT_ID();

INSERT INTO `consult_message`
(`session_id`,`sender_id`,`sender_role`,`sender_name`,`sender_avatar`,`msg_type`,`content`,`is_read`,`create_time`) VALUES
(@sess2, 0,'SYSTEM','系统',NULL,'SYSTEM','医生已接诊，会话开始。请勿在会话中发送银行卡号等隐私信息。',1,DATE_SUB(NOW(), INTERVAL 2 DAY) - INTERVAL 40 MINUTE),
(@sess2, 1,'USER'  ,'张三',NULL,'TEXT','奶糖最近老是甩头，扒开耳朵里面黑黑的，是耳螨吗？',1,DATE_SUB(NOW(), INTERVAL 2 DAY) - INTERVAL 39 MINUTE),
(@sess2, 11,'DOCTOR',@docname,NULL,'TEXT','照片里耳垢是深褐色渣状，耳螨的可能性大。先洗耳液灌洗擦净再上耳药，一天两次连用两周。',1,DATE_SUB(NOW(), INTERVAL 2 DAY) - INTERVAL 36 MINUTE),
(@sess2, 11,'DOCTOR',@docname,NULL,'TEXT','两周后到院复查耳道镜检；若出现歪头、转圈请尽快来院。',1,DATE_SUB(NOW(), INTERVAL 2 DAY) - INTERVAL 35 MINUTE),
(@sess2, 1,'USER'  ,'张三',NULL,'TEXT','好的，谢谢医生！',1,DATE_SUB(NOW(), INTERVAL 2 DAY));

-- =====================================================================
-- 11. 公告与养宠科普
-- =====================================================================
INSERT INTO `notice` (`title`,`cover`,`summary`,`content`,`type`,`top_flag`,`status`,`view_count`,`publish_time`) VALUES
('在线问诊开放时间调整公告',NULL,'工作日晚间在线问诊延长至 21:30',
 '自本月起，本院在线图文问诊服务开放时间调整为：每日上午 08:30-12:00、下午 13:30-17:30、夜间 18:00-21:30。急重症请直接到院或拨打 24 小时急诊电话。',1,1,1,126,DATE_SUB(NOW(), INTERVAL 2 DAY)),
('猫三联与狂犬疫苗接种程序说明',NULL,'首次免疫与年度加强的完整时间表',
 '幼猫首次免疫建议 8 周龄开始，间隔 3-4 周共接种 3 针猫三联，末针后 1 周接种狂犬；此后每 12 个月加强一次。接种前需体温正常、无腹泻呕吐，接种后留院观察 30 分钟。',3,0,1,342,DATE_SUB(NOW(), INTERVAL 6 DAY)),
('换粮别心急：7-10 天过渡法',NULL,'突然换粮是幼猫呕吐腹泻最常见的原因之一',
 '更换主粮请按 1/4 → 1/2 → 3/4 → 全量的节奏，每阶段维持 2-3 天，肠胃敏感个体延长至 10-14 天。过渡期可搭配益生菌，出现软便应立即退回上一比例。',3,0,1,218,DATE_SUB(NOW(), INTERVAL 9 DAY)),
('春季体外驱虫与猫癣高发期提醒',NULL,'螨虫与真菌感染进入高峰期',
 '春季温湿度上升，跳蚤、蜱虫及小孢子菌活跃。建议每月一次体外驱虫，环境每周吸尘，猫砂盆与卧具暴晒。若发现圆形脱毛、皮屑增多、伍德氏灯下发荧光，请及时就诊并隔离。',2,0,1,177,DATE_SUB(NOW(), INTERVAL 14 DAY)),
('院内开展超声洁治限时活动',NULL,'洁治项目 8.8 折，含术前血检',
 '本月口腔专科开展超声洁治限时活动，价格为原价 8.8 折并包含术前血常规与生化筛查。全麻前需禁食 8 小时、禁水 2 小时，老年犬猫额外增加心脏评估。',2,0,1,95,DATE_SUB(NOW(), INTERVAL 20 DAY)),
('草稿：下半年会员体检套餐（未发布）',NULL,'仅管理员可见的草稿状态示例',
 '本条用于演示 status=0 草稿状态，不会出现在用户端列表中。',1,0,0,0,NULL);

-- 已发布的公告补上发布人（苏幼薇 admin_user.id=1）；草稿保持 NULL——从未发布就还没有发布人
UPDATE `notice` SET `publish_by` = 1 WHERE `status` = 1 AND `publish_by` IS NULL;

-- =====================================================================
-- 12. 一致性回填 (前面任何增删订单都会自动反映到这里)
-- =====================================================================

-- 12.1 排队序号: 同一号源内按下单先后编号, 已取消的跳过
--      MySQL 不允许 UPDATE 目标表同时出现在子查询 FROM 中, 故先物化成派生表再 JOIN
UPDATE `appointment` a
JOIN (
  SELECT a1.id, COUNT(b.id) AS qno
  FROM `appointment` a1
  JOIN `appointment` b
    ON b.schedule_id = a1.schedule_id
   AND b.deleted = 0
   AND b.status <> 3
   AND b.id <= a1.id
  WHERE a1.schedule_id IS NOT NULL AND a1.deleted = 0 AND a1.status <> 3
  GROUP BY a1.id
) q ON q.id = a.id
SET a.queue_no = q.qno;

-- 12.2 号源剩余数 = 总数 - 有效占用数 (已取消不占号)
UPDATE `doctor_schedule` s SET s.remain_num = s.total_num - (
  SELECT COUNT(*) FROM `appointment` a
  WHERE a.schedule_id = s.id AND a.deleted = 0 AND a.status <> 3
)
WHERE (s.remain_num <> s.total_num - (
  SELECT COUNT(*) FROM `appointment` a
  WHERE a.schedule_id = s.id AND a.deleted = 0 AND a.status <> 3
));

-- 12.3 医生统计聚合
UPDATE `doctor` d SET
  d.review_count = (SELECT COUNT(*) FROM `doctor_review` r
                    WHERE r.doctor_id = d.id AND r.deleted = 0 AND r.status = 1),
  d.rating = IFNULL((SELECT ROUND(AVG(r.rating), 1) FROM `doctor_review` r
                     WHERE r.doctor_id = d.id AND r.deleted = 0 AND r.status = 1), 5.0),
  d.appointment_count = (SELECT COUNT(*) FROM `appointment` a
                         WHERE a.doctor_id = d.id AND a.deleted = 0 AND a.status = 2);

-- 12.4 排班的发号计数器对齐到该排班历史上发过的最大序号（必须排在 12.1 之后）
--      缺这一步会怎样：DDL 里 last_queue_no 默认 0，而种子里多数号源已有 queue_no=1..n，
--      下一次下单递增进 1 就正好撞上 12.1 已经发给历史预约的号，重号从建库那一刻就存在。
--      与已有库的增量迁移 sql/migrations/20260922_add_schedule_queue_counter.sql 口径一致：
--      含已取消与逻辑删除的预约，只看发过的最大号，绝不改写任何历史 queue_no。
UPDATE `doctor_schedule` s
LEFT JOIN (
  SELECT `schedule_id`, MAX(`queue_no`) AS max_no
  FROM `appointment`
  WHERE `queue_no` IS NOT NULL
  GROUP BY `schedule_id`
) h ON h.schedule_id = s.id
SET s.last_queue_no = IFNULL(h.max_no, 0);

DROP TEMPORARY TABLE IF EXISTS `tmp_num`;
DROP TEMPORARY TABLE IF EXISTS `tmp_days`;
DROP TEMPORARY TABLE IF EXISTS `tmp_period`;
DROP TEMPORARY TABLE IF EXISTS `tmp_pref`;
DROP TEMPORARY TABLE IF EXISTS `tmp_hist_sch`;
DROP TEMPORARY TABLE IF EXISTS `tmp_userpet`;
