/// Permission keys, mirroring the `public.permissions` catalogue in the
/// database (supabase/migrations/…_platform_core.sql).
///
/// The app uses these only to decide what to *show*. Every one of them is
/// enforced again by row-level security and the RPCs, so hiding a button is
/// never what protects the data.
abstract final class Permissions {
  static const orgManage = 'org.manage';
  static const workspacesManage = 'workspaces.manage';
  static const membersRead = 'members.read';
  static const membersManage = 'members.manage';
  static const rolesManage = 'roles.manage';
  static const auditRead = 'audit.read';
  static const reportsView = 'reports.view';

  static const customersRead = 'customers.read';
  static const customersWrite = 'customers.write';
  static const customersDelete = 'customers.delete';

  static const catalogRead = 'catalog.read';
  static const catalogWrite = 'catalog.write';
  static const catalogDelete = 'catalog.delete';
  static const inventoryRead = 'inventory.read';
  static const inventoryAdjust = 'inventory.adjust';

  static const salesRead = 'sales.read';
  static const salesCreate = 'sales.create';
  static const salesVoid = 'sales.void';

  static const quotationsRead = 'quotations.read';
  static const quotationsWrite = 'quotations.write';
  static const invoicesRead = 'invoices.read';
  static const invoicesWrite = 'invoices.write';
  static const invoicesVoid = 'invoices.void';
  static const paymentsRecord = 'payments.record';

  static const documentsRead = 'documents.read';
  static const documentsWrite = 'documents.write';
  static const documentsDelete = 'documents.delete';
}
