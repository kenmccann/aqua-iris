select 
  name,
  lastupdate,
  policy ->> 'enabled' as enabled,
  policy ->> 'enforce' as enforced,
  author,
  p.key as control,
  p.value ->> 'enabled' as control_enabled
  from runtime_policies
       ,jsonb_each(policy) p
  where p.value ->> 'enabled' = 'true' AND policy ->> 'enabled' = 'true'
