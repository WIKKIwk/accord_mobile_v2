import '../../../core/native_usb_printer.dart';
import '../models/raw_material_split_models.dart';

UsbRpsPrintRequest rawMaterialSplitPrintRequest(RawSplitRoll output) =>
    UsbRpsPrintRequest(
      epc: output.barcode,
      itemCode: output.itemCode,
      itemName: output.labelName,
      warehouse: output.warehouse,
      printer: 'godex',
      printMode: 'label',
      grossQty: double.parse(output.grossKg ?? output.kg),
      tareEnabled: output.grossKg != null,
      tareKg: double.parse(output.bobinaKg ?? '0'),
      unit: 'kg',
      labelKind: 'material_product',
    );
