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
	

    