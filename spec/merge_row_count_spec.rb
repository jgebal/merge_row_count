require_relative 'spec_helper'

def measure_time
  start = Time.now
  yield
  Time.now - start
end

def init_rows(how_many)
  plsql.execute <<-SQL
  INSERT INTO emp
   SELECT rownum, 'emp '||rownum
     FROM DUAL
     CONNECT BY LEVEL <= #{how_many}
  SQL
end

def merge_rows_no_update_count(ins,upd,del)
  merge_rows(ins,upd,del, true, false)
end

def merge_rows_no_insert_count(ins,upd,del)
  merge_rows(ins,upd,del, false)
end

def merge_rows(ins,upd,del, ins_counter = true, upd_counter = true)
  sql = <<-SQL
      BEGIN
        MERGE INTO emp dst
        USING (SELECT rownum as id, 'emp '||rownum as first_name
                FROM dual
               CONNECT BY LEVEL <=#{ins+upd+del}
              ) src
          ON (src.id = dst.id)
        WHEN MATCHED THEN
          UPDATE
            SET dst.first_name = src.first_name
          #{upd_counter ? 'WHERE merge_row_count.upd() > 0' : ''}
          DELETE
           WHERE src.id <= #{del}
             #{del>0 ? 'AND merge_row_count.del() > 0' : ''}
        WHEN NOT MATCHED THEN
          INSERT (dst.id, dst.first_name)
          VALUES (src.id, src.first_name)
          #{ins_counter ? 'WHERE merge_row_count.ins() > 0' : ''}
        ;
        :row_count := SQL%ROWCOUNT;
      END;
  SQL
  cursor = plsql.connection.parse(sql)
  cursor.bind_param(":row_count", nil, :data_type => 'NUMBER', :in_out => 'OUT')
  cursor.exec
  cursor[":row_count"]
end

describe 'merge_row_count' do

  before(:all) do
    plsql.execute <<-SQL
      CREATE TABLE emp(id INTEGER PRIMARY KEY, first_name VARCHAR2(50))
    SQL
  end

  after(:all) do
    plsql.execute <<-SQL
      DROP TABLE emp
    SQL
  end

  describe 'for single merge with insert/update/delete statement' do

    it 'returns number of rows inserted/updated/deleted' do
      ins,upd,del = [3,2,1]
      init_rows(upd+del)
      merge_rows(ins,upd,del)
      expect( plsql.merge_row_count.get_inserted ).to eq ins
      expect( plsql.merge_row_count.get_updated ).to eq upd
      expect( plsql.merge_row_count.get_deleted ).to eq del
    end

  end

  describe 'for multiple merge with insert/update/delete statement' do

    before(:each) do
      @ins,@upd,@del = [3,2,1]
      init_rows(@upd+@del)
      merge_rows(@ins,@upd,@del)
    end

    it 'returns number of rows inserted' do
      expect( plsql.merge_row_count.get_inserted ).to eq @ins
    end

    it 'returns number of rows updated' do
      expect( plsql.merge_row_count.get_updated ).to eq @upd
    end

    it 'returns number of rows deleted' do
      expect( plsql.merge_row_count.get_deleted ).to eq @del
    end

  end

  describe 'with SQL%ROWCOUNT but no insert counter used' do

    before(:each) do
      @ins,@upd,@del = [3,2,1]
      init_rows(@upd+@del)
      @rows_merged = merge_rows_no_insert_count(@ins,@upd,@del)
    end

    it 'returns number of rows inserted' do
      expect( plsql.merge_row_count.get_inserted(@rows_merged) ).to eq @ins
    end

    it 'returns number of rows updated' do
      expect( plsql.merge_row_count.get_updated(@rows_merged) ).to eq @upd
    end

    it 'returns number of rows deleted' do
      expect( plsql.merge_row_count.get_deleted(@rows_merged) ).to eq @del
    end

  end

  describe 'with SQL%ROWCOUNT but no update counter used' do

    before(:each) do
      @ins,@upd,@del = [3,2,1]
      init_rows(@upd+@del)
      @rows_merged = merge_rows_no_update_count(@ins,@upd,@del)
    end

    it 'returns number of rows inserted' do
      expect( plsql.merge_row_count.get_inserted(@rows_merged) ).to eq @ins
    end

    it 'returns number of rows updated' do
      expect( plsql.merge_row_count.get_updated(@rows_merged) ).to eq @upd
    end

    it 'returns number of rows deleted' do
      expect( plsql.merge_row_count.get_deleted(@rows_merged) ).to eq @del
    end
  end

  describe 'performance is better without counters' do

    it 'merge is much faster without insert counter used when many rows inserted' do
      ins,upd,del = [100000,2,1]
      init_rows(upd+del)
      without_insert_counter_time = measure_time{ merge_rows_no_insert_count(ins,upd,del) }
      with_insert_counter_time = measure_time{ merge_rows(ins,upd,del) }
      expect( without_insert_counter_time ).to be < with_insert_counter_time
    end

    it 'merge is much faster without update counter used when many rows updated' do
      ins,upd,del = [2,100000,1]
      init_rows(upd+del)
      without_update_counter_time = measure_time{ merge_rows_no_update_count(ins,upd,del) }
      with_update_counter_time = measure_time{ merge_rows(ins,upd,del) }
      expect( without_update_counter_time ).to be < with_update_counter_time
    end

  end

end

