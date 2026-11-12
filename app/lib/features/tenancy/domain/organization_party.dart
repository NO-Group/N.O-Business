import '../../../core/pdf/commercial_pdf.dart';
import 'models.dart';

/// The organization as it appears in the "From" block of printed documents.
PdfParty sellerParty(Organization organization, {String? workspaceName}) {
  final legalName = organization.legalName;
  return PdfParty(
    name: legalName != null && legalName.trim().isNotEmpty ? legalName : organization.name,
    lines: [
      ?organization.address,
      ?organization.phone,
      ?organization.email,
      if (organization.taxId != null) 'Tax ID: ${organization.taxId}',
      if (workspaceName != null) 'Branch: $workspaceName',
    ],
  );
}
