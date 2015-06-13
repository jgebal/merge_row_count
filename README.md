# Merge row count
A simple utility PL/SQL Package to allow counting of rows inserted/updated/deleted by merge operation in Oracle.

# The need for package
Oracle does not provide functionality for obtaining number of rows that were 
- inserted
- updated
- deleted

when using a MERGE operation to do it all.

This simple utility is to fill the gap in the functionality.

Be aware that using the utility to count the data processed will have slight, but negative impact on the performance of Merge operation. This is due to the fact of overhead of SQL - PL/SQL context switching. 

# Usage samples

You need to call the counter functions on MERGE block, to count the rows processed.

```sql
BEGIN
  MERGE INTO emp dst
    USING (SELECT * FROM employees) src
       ON (src.id = dst.id)
    WHEN MATCHED THEN
      UPDATE
         SET src.first_name = dst.first_name
       WHERE merge_row_count.upd() > 0
      DELETE
       WHERE src.id = :delete_filter
         AND merge_row_count.del() > 0
    WHEN NOT MATCHED THEN
      INSERT (id, first_name)
      VALUES (src.id, src.first_name)
       WHERE merge_row_count.ins() > 0;
  DBMS_OUTPUT.PUT_LINE( merge_row_count.get_inserted() );
  DBMS_OUTPUT.PUT_LINE( merge_row_count.get_updated() );
  DBMS_OUTPUT.PUT_LINE( merge_row_count.get_deleted() );
END;
```

For performance reasons it's better to have your merge statements make as little PLSQL context switching as possible. You may call the merge operation wit a counter used only on the part that is likely to process less rows.
If your code is suppose to mainly update existing rows and sometimes insert new rows it might be better to use calls only to `merge_row_count.ins()`

```sql
BEGIN
  MERGE INTO emp dst
    USING (SELECT * FROM employees) src
       ON (src.id = dst.id)
    WHEN MATCHED THEN
      UPDATE
         SET src.first_name = dst.first_name
    WHEN NOT MATCHED THEN
      INSERT (id, first_name)
      VALUES (src.id, src.first_name)
       WHERE merge_row_count.ins() > 0;
  DBMS_OUTPUT.PUT_LINE( merge_row_count.get_inserted(SQL%ROWCOUNT) );
  DBMS_OUTPUT.PUT_LINE( merge_row_count.get_updated(SQL%ROWCOUNT) );
END;
```

If your code is suppose to mainly insert new rows and sometimes update existing rows it might be better to use calls only to `merge_row_count.upd()`

```sql
BEGIN
  MERGE INTO emp dst
    USING (SELECT * FROM employees) src
       ON (src.id = dst.id)
    WHEN MATCHED THEN
      UPDATE
         SET src.first_name = dst.first_name
       WHERE merge_row_count.upd() > 0
    WHEN NOT MATCHED THEN
      INSERT (id, first_name)
      VALUES (src.id, src.first_name);
  DBMS_OUTPUT.PUT_LINE( merge_row_count.get_inserted(SQL%ROWCOUNT) );
  DBMS_OUTPUT.PUT_LINE( merge_row_count.get_updated(SQL%ROWCOUNT) );
END;
```
