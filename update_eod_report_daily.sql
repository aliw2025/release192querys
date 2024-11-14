BEGIN
    DECLARE today DATE;
    SET today = DATE_SUB(CURDATE(), INTERVAL 1 DAY);

	IF considerModifyDate = 'Y' then
		DELETE FROM bv_eod_report WHERE customerOrderId IN (
        SELECT customerOrderId FROM bv_customer_order WHERE DATE(modifiedDate) = today
    );
   ELSE 
			DELETE  FROM bv_eod_report; 
	END if;
	
	-- delete return orders if parent orders are modified 
	IF considerModifyDate = 'Y' then
		DELETE FROM bv_eod_report  WHERE returnOrderInd='Y' and customerOrderId IN (
        SELECT co.customerOrderId FROM bv_customer_order co JOIN bv_customer_order pco on co.parentCustomerOrderId = pco.customerOrderId 
 		  AND co.returnOrderInd = 'Y' AND DATE(pco.modifiedDate) = today
    );
    end if;

    -- local
    DROP TEMPORARY TABLE IF EXISTS TempQuery1;
    DROP TEMPORARY TABLE IF EXISTS TempQuery2;
	 DROP TEMPORARY TABLE IF EXISTS TempQuery3;
	 DROP TEMPORARY TABLE IF EXISTS TempQuery4;
	 DROP TEMPORARY TABLE IF EXISTS TempQuery5;
	 DROP TEMPORARY TABLE IF EXISTS TempQuery6;

	 
    CREATE TEMPORARY TABLE TempQuery1 AS
	select 
		bp.partId, 
		bp.bestValuePartNo,
		co.orderNumber, 
		co.totalPrice, 
		cod.discount, 
		(case 
		   when(pid.partPrice IS NOT null) then pid.partPrice
		   when (pid.partPrice IS NULL AND cod.lpoPrice>0)  then cod.lpoPrice 
		   ELSE cod.buyPrice END )* cod.quantity AS buyPrice, 
		((case 
			when (cod.updatedSalePrice > 0 AND cod.updatedSalePrice IS NOT NULL) then cod.updatedSalePrice 
			ELSE cod.salePrice end)) * cod.quantity AS SalePrice,
		cod.quantity, 
		co.discountAmount,
		co.invoiceDate,
		po.poNo, 
		poi.invoiceNumber,
		v.vendorName,
		v.vendorId ,
		co.actionType,
		co.isSpecialOrder,
		l.locationCode,
		co.customerOrderId,
		co.customerId,
		os.orderStatusCode,
		st.deliveryStatusCode,
		co.returnOrderInd,
		null as returnOrderStatus
		from 
		bv_order_status os 
		INNER JOIN bv_customer_order co ON os.orderStatusId = co.orderStatusId AND co.returnOrderInd = 'N' AND os.orderStatusCode IN ('PR','RR','CR') 
		AND co.isSpecialOrder = 'Y' AND co.actionType ='P'
		AND ((considerModifyDate = 'Y' AND DATE(co.modifiedDate) = today) OR considerModifyDate = 'N')
		INNER JOIN bv_customer_order_details cod on co.customerOrderId = cod.customerOrderId
		INNER JOIN bv_cust_order_delivery cd ON cd.customerOrderId = co.customerOrderId
		INNER JOIN bv_delivery_status  st ON cd.deliveryStatusId = st.deliveryStatusId
		inner join bv_location_part_stock lps ON cod.locationPartStockId = lps.locationPartStockId	
		INNER JOIN bv_part bp ON lps.partId = bp.partId 
		INNER JOIN bv_location l ON l.locationId = co.locationId
		INNER JOIN bv_so_special_order so ON so.customerOrderId = co.customerOrderId AND so.customerOrderDetailId = cod.customerOrderDetailId 
		left JOIN bv_po_invoice_detail pid ON pid.poId = so.poId AND pid.poVenPartId = so.poVenPartId AND pid.shippedQty >0 
		left JOIN bv_po po ON po.poId = so.poId and pid.poId = po.poId 
		left JOIN bv_po_invoice poi ON poi.poInvoiceId = pid.poInvoiceId 
		left JOIN bv_po_venpart pvp ON pvp.poVenPartId = so.poVenPartId AND pvp.poId = po.poId
		left JOIN bv_vendor_part vp ON vp.vendorPartId = pvp.vendorPartId
		left JOIN bv_vendor v ON v.vendorId = vp.vendorId;
		
	-- non local interstore
    CREATE TEMPORARY TABLE TempQuery2 AS
   select
   bp.partId, 
    bp.bestValuePartNo, 
   co.orderNumber, 
   co.totalPrice, 
   cod.discount, 
    (case 
   	when (ipo.partPrice IS NOT NULL) then ipo.partPrice* cod.quantity
   	ELSE 	lpsfrom.buyPrice * cod.quantity END) AS buyPrice,
	(case when (cod.updatedSalePrice > 0 AND cod.updatedSalePrice IS NOT NULL) then cod.updatedSalePrice ELSE cod.salePrice end) * cod.quantity as updatedSalePrice, 
	 cod.quantity, 
	 co.discountAmount,
	co.invoiceDate,
 	IFNULL(po.ipoNumber,'-') as poNo, 
	null as invoiceNumber,
	null as vendorName,
	null as vendorId ,
	co.actionType,
	co.isSpecialOrder,
	l.locationCode,
	co.customerOrderId,
	co.customerId,
	os.orderStatusCode,
	st.deliveryStatusCode,
	co.returnOrderInd,
	null as returnOrderStatus
   FROM 
   bv_order_status os 
   INNER JOIN bv_customer_order co ON os.orderStatusId = co.orderStatusId AND co.returnOrderInd = 'N' AND os.orderStatusCode IN ('PR','RR','CR') 
	AND co.isSpecialOrder = 'Y' AND co.actionType ='I'
	AND ((considerModifyDate = 'Y' AND DATE(co.modifiedDate) = today) OR considerModifyDate = 'N')
	INNER JOIN bv_customer_order_details cod on co.customerOrderId = cod.customerOrderId  
	INNER JOIN bv_cust_order_delivery cd ON cd.customerOrderId = co.customerOrderId
	INNER JOIN bv_delivery_status  st ON cd.deliveryStatusId = st.deliveryStatusId
	inner JOIN bv_location_part_stock lps ON cod.locationPartStockId = lps.locationPartStockId
	INNER JOIN bv_part bp ON lps.partId = bp.partId
	INNER JOIN bv_location l ON l.locationId = co.locationId
	inner JOIN bv_so_special_order so ON so.customerOrderId = cod.customerOrderId AND so.customerOrderDetailId = cod.customerOrderDetailId 
	inner JOIN bv_so_interstore_transfer si ON si.soSpecialOrderId = so.soSpecialOrderId  
	inner JOIN bv_part_interstore_transfer t ON si.partInterstoreTransferId = t.partInterstoreTransferId
	INNER JOIN bv_location_part_stock lpsfrom ON lpsfrom.locationPartStockId = t.fromLocationPartStockId
	left JOIN bv_ipo_part ipo ON ipo.partInterstoreTransferId = t.partInterstoreTransferId
	left JOIN bv_ipo po ON ipo.ipoId = po.ipoId AND po.receiveCompleteInd = 'Y';
    

	 -- non local non interstore
    CREATE TEMPORARY TABLE TempQuery3 AS 
    select
		bp.partId as partID, 
		bp.bestValuePartNo , 
		co.orderNumber, 
		co.totalPrice, 
		cod.discount, 
		cod.buyPrice* cod.quantity, 
	   (case when (cod.updatedSalePrice > 0 AND cod.updatedSalePrice IS NOT NULL) then cod.updatedSalePrice ELSE cod.salePrice end) * cod.quantity as updatedSalePrice, 
		cod.quantity, 
		co.discountAmount,
		co.invoiceDate,
		null as poNo, 
		null as invoiceNumber,
		null as vendorName,
		null as vendorId ,
		co.actionType,
		co.isSpecialOrder,
		l.locationCode,
		co.customerOrderId,
		co.customerId,
		os.orderStatusCode,
		st.deliveryStatusCode,
		co.returnOrderInd,
		null as returnOrderStatus
   from 
    bv_order_status os 
    INNER JOIN bv_customer_order co ON os.orderStatusId = co.orderStatusId AND co.returnOrderInd = 'N' AND os.orderStatusCode IN ('PR','RR','CR')
	AND co.isSpecialOrder = 'N' 
	AND ((considerModifyDate = 'Y' AND DATE(co.modifiedDate) = today) OR considerModifyDate = 'N')
	INNER JOIN bv_customer_order_details cod on co.customerOrderId = cod.customerOrderId  
	INNER JOIN bv_cust_order_delivery cd ON cd.customerOrderId = co.customerOrderId
	INNER JOIN bv_delivery_status  st ON cd.deliveryStatusId = st.deliveryStatusId
	inner JOIN bv_location_part_stock lps ON cod.locationPartStockId = lps.locationPartStockId
	INNER JOIN bv_part bp ON lps.partId = bp.partId
	INNER JOIN bv_location l ON l.locationId = co.locationId;
	
	
	-- return of the orders 
	 CREATE TEMPORARY TABLE TempQuery4 AS
	SELECT 
		bp.partId, 
		bp.bestValuePartNo,
		co.orderNumber, 
		co.totalPrice, 
		cod.discount *-1,
		(case 
		   when(pid.partPrice IS NOT null) then pid.partPrice
		   when (pid.partPrice IS NULL AND cod.lpoPrice>0)  then cod.lpoPrice 
		   ELSE cod.buyPrice END )* cod.quantity AS buyPrice, 
		((case 
			when (cod.updatedSalePrice > 0 AND cod.updatedSalePrice IS NOT NULL) then cod.updatedSalePrice 
			ELSE cod.salePrice end)) * cod.quantity AS SalePrice,
		cod.quantity, 
		co.discountAmount,
		pco.invoiceDate,
		po.poNo, 
		poi.invoiceNumber,
		v.vendorName,
		v.vendorId ,
		pco.actionType,
		pco.isSpecialOrder,
		l.locationCode,
		co.customerOrderId,
		co.customerId,
		pos.orderStatusCode orderStatusCode,
		st.deliveryStatusCode orderDeliveryStatus,
		co.returnOrderInd,
		os.orderStatusCode returnOrderStatus
		from 
		bv_order_status os 
		INNER JOIN bv_customer_order co ON os.orderStatusId = co.orderStatusId AND co.isSpecialOrder = 'Y' and co.returnOrderInd = 'Y' AND os.orderStatusCode IN ('PR','RR','CR') 
		INNER JOIN bv_customer_order pco ON pco.customerOrderId = co.parentCustomerOrderId AND pco.isSpecialOrder = 'Y' AND pco.actionType = 'P'
		INNER JOIN bv_customer_order_details cod on co.customerOrderId = cod.customerOrderId
		INNER JOIN bv_customer_order_details pcod ON  pco.customerOrderId = pcod.customerOrderId AND pcod.locationPartStockId = cod.locationPartStockId
		inner JOIN bv_order_status pos ON pos.orderStatusId = pco.orderStatusId	
		AND ( (considerModifyDate = 'Y' AND (DATE(co.modifiedDate) = today OR DATE(pco.modifiedDate) = today )) OR considerModifyDate = 'N')
		INNER JOIN bv_cust_order_delivery cd ON cd.customerOrderId = pco.customerOrderId
		INNER JOIN bv_delivery_status  st ON cd.deliveryStatusId = st.deliveryStatusId
		inner join bv_location_part_stock lps ON cod.locationPartStockId = lps.locationPartStockId	
		INNER JOIN bv_part bp ON lps.partId = bp.partId 
		INNER JOIN bv_location l ON l.locationId = co.locationId
		INNER JOIN bv_so_special_order so ON so.customerOrderId = pco.customerOrderId AND so.customerOrderDetailId = pcod.customerOrderDetailId 
		left JOIN bv_po_invoice_detail pid ON pid.poId = so.poId AND pid.poVenPartId = so.poVenPartId AND pid.shippedQty >0 
		left JOIN bv_po po ON po.poId = so.poId and pid.poId = po.poId 
		left JOIN bv_po_invoice poi ON poi.poInvoiceId = pid.poInvoiceId 
		left JOIN bv_po_venpart pvp ON pvp.poVenPartId = so.poVenPartId AND pvp.poId = po.poId
		left JOIN bv_vendor_part vp ON vp.vendorPartId = pvp.vendorPartId
		left JOIN bv_vendor v ON v.vendorId = vp.vendorId;

	CREATE TEMPORARY TABLE TempQuery5 AS	
	select
	   bp.partId, 
	   bp.bestValuePartNo, 
	   co.orderNumber, 
	   co.totalPrice, 
	   cod.discount *-1, 
    (case 
   	when (ipo.partPrice IS NOT NULL) then ipo.partPrice* cod.quantity
   	ELSE 	lpsfrom.buyPrice * cod.quantity END) AS buyPrice,
	(case when (cod.updatedSalePrice > 0 AND cod.updatedSalePrice IS NOT NULL) then cod.updatedSalePrice ELSE cod.salePrice end) * cod.quantity as updatedSalePrice, 
	 cod.quantity, 
	 co.discountAmount,
	pco.invoiceDate,
 	IFNULL(po.ipoNumber,'-') as poNo, 
	null as invoiceNumber,
	null as vendorName,
	null as vendorId ,
	pco.actionType,
	pco.isSpecialOrder,
	l.locationCode,
	co.customerOrderId,
	co.customerId,
	pos.orderStatusCode orderStatusCode,
	st.deliveryStatusCode orderDeliveryStatus,
	co.returnOrderInd,
	os.orderStatusCode as returnOrderStatus
   FROM 
   bv_order_status os 
   INNER JOIN bv_customer_order co ON os.orderStatusId = co.orderStatusId AND co.returnOrderInd = 'Y' and co.isSpecialOrder='Y' AND os.orderStatusCode IN ('PR','RR','CR') 
	INNER JOIN bv_customer_order pco ON pco.customerOrderId = co.parentCustomerOrderId AND pco.isSpecialOrder = 'Y' AND pco.actionType = 'I'
	INNER JOIN bv_customer_order_details cod on co.customerOrderId = cod.customerOrderId 
	INNER JOIN bv_customer_order_details pcod ON  pco.customerOrderId = pcod.customerOrderId AND pcod.locationPartStockId =cod.locationPartStockId
	inner JOIN bv_order_status pos ON pos.orderStatusId = pco.orderStatusId	
	AND ( (considerModifyDate = 'Y' AND (DATE(co.modifiedDate) = today OR DATE(pco.modifiedDate) = today )) OR considerModifyDate = 'N') 
	INNER JOIN bv_cust_order_delivery cd ON cd.customerOrderId = pco.customerOrderId
	INNER JOIN bv_delivery_status  st ON cd.deliveryStatusId = st.deliveryStatusId
	inner JOIN bv_location_part_stock lps ON cod.locationPartStockId = lps.locationPartStockId
	INNER JOIN bv_part bp ON lps.partId = bp.partId
	INNER JOIN bv_location l ON l.locationId = co.locationId
	inner JOIN bv_so_special_order so ON so.customerOrderId = pco.customerOrderId AND so.customerOrderDetailId = pcod.customerOrderDetailId 
	inner JOIN bv_so_interstore_transfer si ON si.soSpecialOrderId = so.soSpecialOrderId  
	inner JOIN bv_part_interstore_transfer t ON si.partInterstoreTransferId = t.partInterstoreTransferId
	INNER JOIN bv_location_part_stock lpsfrom ON lpsfrom.locationPartStockId = t.fromLocationPartStockId
	left JOIN bv_ipo_part ipo ON ipo.partInterstoreTransferId = t.partInterstoreTransferId
	left JOIN bv_ipo po ON ipo.ipoId = po.ipoId AND po.receiveCompleteInd = 'Y';
	
	CREATE TEMPORARY TABLE TempQuery6 AS
		select
			bp.partId as partID, 
			bp.bestValuePartNo , 
			co.orderNumber, 
			co.totalPrice, 
			cod.discount *-1, 
			cod.buyPrice* cod.quantity, 
		   (case when (cod.updatedSalePrice > 0 AND cod.updatedSalePrice IS NOT NULL) then cod.updatedSalePrice ELSE cod.salePrice end) * cod.quantity as updatedSalePrice, 
			cod.quantity, 
			co.discountAmount,
			pco.invoiceDate,
			null as poNo, 
			null as invoiceNumber,
			null as vendorName,
			null as vendorId ,
			pco.actionType,
			pco.isSpecialOrder,
			l.locationCode,
			co.customerOrderId,
			co.customerId,
			pos.orderStatusCode orderStatusCode,
			st.deliveryStatusCode orderDeliveryStatus,
			co.returnOrderInd,
			os.orderStatusCode as returnOrderStatus
		   from 
			bv_order_status os 
			INNER JOIN bv_customer_order co ON os.orderStatusId = co.orderStatusId AND co.returnOrderInd = 'Y' AND os.orderStatusCode IN ('PR','RR','CR') AND co.isSpecialOrder = 'N' 
			INNER JOIN bv_customer_order pco ON pco.customerOrderId = co.parentCustomerOrderId AND pco.isSpecialOrder = 'N'
			INNER JOIN bv_customer_order_details cod on co.customerOrderId = cod.customerOrderId  
			INNER JOIN bv_customer_order_details pcod ON  pco.customerOrderId = pcod.customerOrderId AND pcod.locationPartStockId =cod.locationPartStockId
				AND ( (considerModifyDate = 'Y' AND (DATE(co.modifiedDate) = today OR DATE(pco.modifiedDate) = today )) OR considerModifyDate = 'N')
			inner JOIN bv_order_status pos ON pos.orderStatusId = pco.orderStatusId	
			INNER JOIN bv_cust_order_delivery cd ON cd.customerOrderId = pco.customerOrderId
			INNER JOIN bv_delivery_status  st ON cd.deliveryStatusId = st.deliveryStatusId
			inner JOIN bv_location_part_stock lps ON pcod.locationPartStockId = lps.locationPartStockId
			INNER JOIN bv_part bp ON lps.partId = bp.partId
			INNER JOIN bv_location l ON l.locationId = co.locationId;
    

-- Drop temporary tables
 
    -- Insert data into the combined_data table
    INSERT INTO bv_eod_report
    SELECT * FROM TempQuery1;
    
    INSERT INTO bv_eod_report
    SELECT * FROM TempQuery2;
	
	 INSERT INTO bv_eod_report
    SELECT * FROM TempQuery3;
	 INSERT INTO bv_eod_report
    SELECT * FROM TempQuery4;
	 INSERT INTO bv_eod_report
    SELECT * FROM TempQuery5;
	 INSERT INTO bv_eod_report
    SELECT * FROM TempQuery6;
		
    -- Drop temporary tables
   DROP TEMPORARY TABLE IF EXISTS TempQuery1;
   DROP TEMPORARY TABLE IF EXISTS TempQuery2;
	DROP TEMPORARY TABLE IF EXISTS TempQuery3;
	DROP TEMPORARY TABLE IF EXISTS TempQuery4;
   DROP TEMPORARY TABLE IF EXISTS TempQuery5;
	DROP TEMPORARY TABLE IF EXISTS TempQuery6;
END