ALTER SESSION SET PLSQL_WARNINGS = 'ENABLE:ALL';

ALTER SESSION SET PLSQL_CODE_TYPE = NATIVE;
ALTER SESSION SET PLSQL_OPTIMIZE_LEVEL = 3;

CREATE OR REPLACE PACKAGE BODY merge_row_count IS

/**
 * Copyright (c) 2015 Jacek Gêbal (https://github.com/jgebal)
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

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
$IF DBMS_DB_VERSION.VER_LE_11=FALSE $THEN
    PRAGMA UDF;
$END
    BEGIN
      modify_counter( g_inserted_rows );
      RETURN g_inserted_rows;
    END;

  FUNCTION upd RETURN INTEGER IS
$IF DBMS_DB_VERSION.VER_LE_11=FALSE $THEN
    PRAGMA UDF;
$END
    BEGIN
      modify_counter( g_updated_rows );
      RETURN g_updated_rows;
    END;

  FUNCTION del RETURN INTEGER IS
$IF DBMS_DB_VERSION.VER_LE_11=FALSE $THEN
    PRAGMA UDF;
$END
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
