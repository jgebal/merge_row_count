CREATE OR REPLACE PACKAGE BODY merge_row_count IS

  GC_RESET_VALUE  PLS_INTEGER := NULL;
  g_updated_rows  PLS_INTEGER := GC_RESET_VALUE;
  g_inserted_rows PLS_INTEGER := GC_RESET_VALUE;
  g_deleted_rows  PLS_INTEGER := GC_RESET_VALUE;
  g_need_reset    BOOLEAN := FALSE;


  PROCEDURE reset_counters IS
    BEGIN
      g_updated_rows  := GC_RESET_VALUE;
      g_inserted_rows := GC_RESET_VALUE;
      g_deleted_rows  := GC_RESET_VALUE;
    END;

  PROCEDURE modify_counter( counter IN OUT NOCOPY PLS_INTEGER ) IS
    BEGIN
       IF g_need_reset THEN
         g_need_reset := FALSE;
         reset_counters();
       END IF;
      counter := COALESCE( counter + 1, 1 );
    END;

  FUNCTION ins RETURN INTEGER IS
    BEGIN
      modify_counter( g_inserted_rows );
      RETURN g_inserted_rows;
    END;

  FUNCTION upd RETURN INTEGER IS
    BEGIN
      modify_counter( g_updated_rows );
      RETURN g_updated_rows;
    END;

  FUNCTION del RETURN INTEGER IS
    BEGIN
      modify_counter( g_deleted_rows );
      RETURN g_deleted_rows;
    END;

  FUNCTION get_inserted( sql_row_count INTEGER DEFAULT NULL ) RETURN INTEGER IS
    BEGIN
      g_need_reset := TRUE;
      RETURN COALESCE( g_inserted_rows, sql_row_count - g_updated_rows );
    END;

  FUNCTION get_updated( sql_row_count INTEGER DEFAULT NULL ) RETURN INTEGER IS
    BEGIN
      g_need_reset := TRUE;
      RETURN COALESCE( g_updated_rows, sql_row_count - g_inserted_rows ) - COALESCE( g_deleted_rows, 0 );
    END;

  FUNCTION get_deleted( sql_row_count INTEGER DEFAULT NULL ) RETURN INTEGER IS
    BEGIN
      g_need_reset := TRUE;
      RETURN COALESCE( g_deleted_rows, 0 );
    END;

END;
/
