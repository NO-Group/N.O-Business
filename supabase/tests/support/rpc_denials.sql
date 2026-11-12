-- Included by 03_business_flows.test.sql once per unauthorized persona.
-- Expects psql variables: label, org, ws, cust, item, line, inv4, draft_inv,
-- draft_quo, sent_quo, sale2, custom_role, target_membership, open_invitation, ws2.
select tests.throws(format('select public.record_sale(%L, %L, null, %L, %L)', :'org', :'ws', 'cash', :'line'),
  '42501', :'label' || ': record_sale');
select tests.throws(format('select public.void_sale(%L)', :'sale2'), '42501', :'label' || ': void_sale');
select tests.throws(format('select public.adjust_stock(%L, %L, 1, %L)', :'ws', :'item', 'adjustment'),
  '42501', :'label' || ': adjust_stock');
select tests.throws(format('select public.save_quotation(%L, null, %L, %L, null, %L)', :'org', :'ws', :'cust', :'line'),
  '42501', :'label' || ': save_quotation (create)');
select tests.throws(format('select public.save_quotation(%L, %L, %L, %L, null, %L)', :'org', :'draft_quo', :'ws', :'cust', :'line'),
  '42501', :'label' || ': save_quotation (edit)');
select tests.throws(format('select public.set_quotation_status(%L, %L)', :'draft_quo', 'sent'),
  '42501', :'label' || ': set_quotation_status');
select tests.throws(format('select public.delete_quotation(%L)', :'draft_quo'), '42501', :'label' || ': delete_quotation');
select tests.throws(format('select public.convert_quotation_to_invoice(%L)', :'sent_quo'),
  '42501', :'label' || ': convert_quotation_to_invoice');
select tests.throws(format('select public.save_invoice(%L, null, %L, %L, null, %L)', :'org', :'ws', :'cust', :'line'),
  '42501', :'label' || ': save_invoice (create)');
select tests.throws(format('select public.save_invoice(%L, %L, %L, %L, null, %L)', :'org', :'draft_inv', :'ws', :'cust', :'line'),
  '42501', :'label' || ': save_invoice (edit)');
select tests.throws(format('select public.issue_invoice(%L)', :'draft_inv'), '42501', :'label' || ': issue_invoice');
select tests.throws(format('select public.delete_invoice_draft(%L)', :'draft_inv'), '42501', :'label' || ': delete_invoice_draft');
select tests.throws(format('select public.record_invoice_payment(%L, 100, %L)', :'inv4', 'cash'),
  '42501', :'label' || ': record_invoice_payment');
select tests.throws(format('select public.void_invoice(%L)', :'inv4'), '42501', :'label' || ': void_invoice');
select tests.throws(format('select public.save_role(%L, null, %L, %L, array[%L])', :'org', 'Rogue', '', 'customers.read'),
  '42501', :'label' || ': save_role');
select tests.throws(format('select public.delete_role(%L)', :'custom_role'), '42501', :'label' || ': delete_role');
select tests.throws(format('select public.save_role(%L, %L, %L, %L, array[%L])', :'org', :'custom_role', 'Rogue', '', 'customers.read'),
  '42501', :'label' || ': save_role (edit)');
select tests.throws(format('select public.set_member_role(%L, %L)', :'target_membership', :'custom_role'),
  '42501', :'label' || ': set_member_role');
select tests.throws(format('select public.set_member_status(%L, %L)', :'target_membership', 'suspended'),
  '42501', :'label' || ': set_member_status');
select tests.throws(format('select public.remove_member(%L)', :'target_membership'), '42501', :'label' || ': remove_member');
select tests.throws(format('select public.revoke_invitation(%L)', :'open_invitation'), '42501', :'label' || ': revoke_invitation');
select tests.throws(format('select public.invite_member(%L, %L, gen_random_uuid())', :'org', 'x@y.test'),
  '42501', :'label' || ': invite_member');
select tests.throws(format('select public.set_default_workspace(%L)', :'ws2'), '42501', :'label' || ': set_default_workspace');
