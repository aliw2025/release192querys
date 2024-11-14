ALTER TABLE bv_eod_report CHANGE customerId tempCustomerId INT(11) NULL DEFAULT NULL;
-- Step 2: Rename customerOrderId to customerId
ALTER TABLE bv_eod_report CHANGE customerOrderId customerId INT(11) NULL DEFAULT NULL;
-- Step 3: Rename tempCustomerId to customerOrderId
ALTER TABLE bv_eod_report CHANGE tempCustomerId customerOrderId INT(11) NULL DEFAULT NULL;


CREATE INDEX idx_customerId ON bv_eod_report(customerId);
CREATE INDEX idx_customerOrderId ON bv_eod_report(customerOrderId);



ALTER TABLE `bv_eod_report`
	ADD COLUMN `customerLvl` VARCHAR(50) NULL DEFAULT NULL;


ALTER TABLE `bv_eod_report`
	ADD COLUMN `baseSalePriceOfPart` DOUBLE NULL DEFAULT NULL;
	

CREATE TABLE `bv_debug_procedures_eod` (
	`id` BIGINT(20) NOT NULL DEFAULT '0',
	`modifiedDate` DATETIME(6) NULL DEFAULT NULL,
	`code` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8_general_ci',
	`description` VARCHAR(1000) NULL DEFAULT NULL COLLATE 'utf8_general_ci'
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
;