require 'google_drive'

module Google

  class Spreadsheet

    attr_reader :worksheets, :worksheet

    def initialize(spreadsheet_key, login, password)
      session = GoogleDrive.login(login, password)
      @spreadsheet = session.spreadsheet_by_key(spreadsheet_key)
      @worksheets = @spreadsheet.worksheets
      @worksheet = @worksheets.first
    end

    def use_worksheet_called(title)
      @worksheet = @worksheets.detect { |w| w.title.eql?(title) }
      @worksheet ||= add_worksheet(title)
    end

    def add_worksheet(title)
      @worksheet = @spreadsheet.add_worksheet(title)
    end

    def duplicate_worksheet(title)
      old_worksheet = @worksheet.rows
      new_worksheet = add_worksheet(title)
      new_worksheet.update_cells(1, 1, old_worksheet)
      save_worksheet
      new_worksheet
    end

    def add_column(name)
      column_place = @worksheet.num_cols + 1
      @worksheet[1, column_place] = name
      column_place
    end

    def last_row
      @worksheet.num_rows + 1
    end

    def add_to_worksheet(worksheet, array)
      last_row = self.last_row
      array.each_with_index do |a, i|
        worksheet[last_row, i + 1] = a
      end
    end

    def save_worksheet(ws)
      ws.save
    end

  end
end
