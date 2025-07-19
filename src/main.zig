const std = @import("std");
const t = std.testing;

const SudokuError = error{
    NumberOutOfRange,
    NoZeroesLeft,
};

const Sudoku = struct {
    puzzle: [81]u8 = [_]u8{0} ** 81,
    solution: [81]u8 = [_]u8{0} ** 81,

    pub fn init(file: std.fs.File) !Sudoku {
        var sudoku = Sudoku{};

        {
            const read_bytes = try file.read(&sudoku.puzzle);
            if (read_bytes != 81) {
                std.debug.print("failed to read puzzle", .{});
                return error.InvalidPuzzle;
            }
        }

        // skip comma
        try file.seekBy(1);

        {
            const read_bytes = try file.read(&sudoku.solution);
            if (read_bytes != 81) {
                std.debug.print("failed to read solution", .{});
                return error.InvalidSolution;
            }
        }

        // skip newline
        try file.seekBy(1);

        try convertToNumber(&sudoku);

        return sudoku;
    }

    pub fn copy(self: *const Sudoku) Sudoku {
        var result = Sudoku{
            .puzzle = [_]u8{0} ** 81,
            .solution = [_]u8{0} ** 81,
        };
        for (0..81) |i| {
            result.puzzle[i] = self.puzzle[i];
            result.solution[i] = self.solution[i];
        }
        return result;
    }

    pub fn isSolved(self: *const Sudoku) bool {
        for (self.puzzle, self.solution) |puzzle, solution| {
            if (puzzle != solution) {
                return false;
            }
        }
        return true;
    }

    pub fn isValid(self: *const Sudoku) bool {
        // check rows
        for (0..9) |row| {
            var hasBeenSeen = [_]bool{false} ** 9;
            for (0..9) |col| {
                const value = self.puzzle[row * 9 + col];
                if (value == 0) {
                    continue;
                }

                if (hasBeenSeen[value - 1]) {
                    return false;
                }

                hasBeenSeen[value - 1] = true;
            }
        }

        // check columns
        for (0..9) |col| {
            var hasBeenSeen = [_]bool{false} ** 9;
            for (0..9) |row| {
                const value = self.puzzle[row * 9 + col];
                if (value == 0) {
                    continue;
                }

                if (hasBeenSeen[value - 1]) {
                    return false;
                }

                hasBeenSeen[value - 1] = true;
            }
        }

        // check squares
        for (0..9) |square| {
            var hasBeenSeen = [_]bool{false} ** 9;
            for (0..3) |squareRow| {
                for (0..3) |squareCol| {
                    const row = squareRow + (square / 3) * 3;
                    const col = squareCol + (square % 3) * 3;
                    const value = self.puzzle[row * 9 + col];
                    if (value == 0) {
                        continue;
                    }

                    if (hasBeenSeen[value - 1]) {
                        return false;
                    }

                    hasBeenSeen[value - 1] = true;
                }
            }
        }

        return true;
    }

    pub fn format(
        self: *const Sudoku,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt; // ignore format string for now
        _ = options; // ignore formatting options for now
        try writer.print("main.Sudoku{{\n\t.puzzle = {{\n", .{});
        try printSudoku(writer, self.puzzle);
        try writer.print("\t}},\n\t.solution = {{\n", .{});
        try printSudoku(writer, self.solution);
        try writer.print("\t}},\n}}", .{});
    }

    fn printSudoku(writer: anytype, sudoku: [81]u8) !void {
        for (0..9) |row| {
            if (row % 3 == 0 and row != 0) {
                try writer.print("\t\t---------------------\n", .{});
            }
            try writer.print("\t\t", .{});
            for (0..9) |col| {
                if (col % 3 == 0 and col != 0) {
                    try writer.print("| ", .{});
                }
                try writer.print("{} ", .{sudoku[row * 9 + col]});
            }
            try writer.print("\n", .{});
        }
    }
};

test "Sudoku.isValid" {
    const sudoku = Sudoku{
        .puzzle = [_]u8{
            0, 7, 0, 0, 0, 0, 0, 4, 3, //
            0, 4, 0, 0, 0, 9, 6, 1, 0,
            8, 0, 0, 6, 3, 4, 9, 0, 0,
            0, 9, 4, 0, 5, 2, 0, 0, 0,
            3, 5, 8, 4, 6, 0, 0, 2, 0,
            0, 0, 0, 8, 0, 0, 5, 3, 0,
            0, 8, 0, 0, 7, 0, 0, 9, 1,
            9, 0, 2, 1, 0, 0, 0, 0, 5,
            0, 0, 7, 0, 4, 0, 8, 0, 2,
        },
        .solution = [_]u8{0} ** 81,
    };
    try t.expect(sudoku.isValid());

    var rowError = sudoku.copy();
    rowError.puzzle[0] = 7;
    try t.expect(!rowError.isValid());

    var colError = sudoku.copy();
    colError.puzzle[2 * 9 + 1] = 7;
    try t.expect(!colError.isValid());

    var squareError = sudoku.copy();
    squareError.puzzle[2 * 9 + 2] = 7;
    try t.expect(!squareError.isValid());
}

fn Queue(comptime T: type) type {
    return struct {
        list: std.ArrayList(T),

        pub fn init(gpa: std.mem.Allocator) Queue(T) {
            return Queue(T){
                .list = std.ArrayList(T).init(gpa),
            };
        }

        pub fn deinit(self: *Queue(T)) void {
            self.list.deinit();
        }

        pub fn enqueue(self: *Queue(T), value: T) !void {
            try self.list.append(value);
        }

        pub fn dequeue(self: *Queue(T)) ?T {
            if (self.list.items.len == 0) return null;
            return self.list.orderedRemove(self.list.items.len - 1);
        }

        pub fn isEmpty(self: *Queue(T)) bool {
            return self.list.items.len == 0;
        }
    };
}

pub const SolverError = error{
    OutOfMemory,
};

const Solver = struct {
    name: []const u8,
    solve_func: *const fn (std.mem.Allocator, *Sudoku) SolverError!bool,
    enabled: bool = true,
    average_time_ns: i128 = 0,
};

pub fn main() !void {
    const start_time = std.time.nanoTimestamp();

    const file = try std.fs.openFileAbsolute("/home/henne/Downloads/sudoku/sudoku.csv", .{});
    defer file.close();

    try file.seekFromEnd(0);
    const total_file_size = try file.getPos();
    const header_bytes = 16;
    const bytes_per_sudoku = 81 + 1 + 81 + 1;
    const sudoku_count: i64 = @intCast((total_file_size - header_bytes) / bytes_per_sudoku);
    std.debug.print("Found {} sudokus\n", .{sudoku_count});

    try file.seekTo(0);
    try file.seekBy(16);
    const gpa = std.heap.page_allocator;

    var solvers = [_]Solver{
        .{ .name = "brute_force", .solve_func = solveBruteForce, .enabled = false },
        .{ .name = "single_number_in_cell_notes", .solve_func = solveSingleNumberInCellNotes },
        .{ .name = "single_number_in_row_col_or_square", .solve_func = solveSingleNumberInRowColOrSquare },
    };

    var processed_sudokus: i64 = 0;
    while (hasBytesLeft(file) and processed_sudokus < 1000) {
        const sudoku = try Sudoku.init(file);

        for (&solvers) |*solver| {
            if (!solver.enabled) {
                continue;
            }

            var sudoku_copy = sudoku.copy();
            const start = std.time.nanoTimestamp();
            const isSolved = try solver.solve_func(gpa, &sudoku_copy);
            if (!isSolved) {
                std.debug.print("Failed to find solution for {s}!\n", .{solver.name});
            }

            const end = std.time.nanoTimestamp();
            const time_ns = end - start;
            solver.average_time_ns += @divTrunc(time_ns - solver.average_time_ns, processed_sudokus + 1);
        }

        processed_sudokus += 1;

        const processed_sudokus_f: f32 = @floatFromInt(processed_sudokus);
        const sudoku_count_f: f32 = @floatFromInt(sudoku_count);
        const percent_processed: f32 = processed_sudokus_f / sudoku_count_f * 100.0;
        const processed_sudokus_unsigned: u64 = @intCast(processed_sudokus);
        std.debug.print("Processed {d:>7}/{} ({d:.4}%) sudokus\n", .{ processed_sudokus_unsigned, sudoku_count, percent_processed });
    }

    for (&solvers) |*solver| {
        std.debug.print("Average time {s:>34}: {:>10}ns\n", .{ solver.name, solver.average_time_ns });
    }

    const total_time_ns: f64 = @floatFromInt(std.time.nanoTimestamp() - start_time);
    const total_time_s = total_time_ns / 1000000000.0;
    std.debug.print("Total time:                                      {:>10.3}s\n", .{total_time_s});
}

fn hasBytesLeft(file: std.fs.File) bool {
    const pos = file.getPos() catch {
        return false;
    };
    const endPos = file.getEndPos() catch {
        return false;
    };
    return pos < endPos;
}

fn convertToNumber(sudoku: *Sudoku) SudokuError!void {
    for (&sudoku.puzzle) |*elem| {
        if (elem.* < 48) {
            return error.NumberOutOfRange;
        }
        elem.* -= 48;
    }
    for (&sudoku.solution) |*elem| {
        if (elem.* < 48) {
            return error.NumberOutOfRange;
        }
        elem.* -= 48;
    }
}

fn solveBruteForce(gpa: std.mem.Allocator, sudoku_: *Sudoku) !bool {
    var queue = Queue(Sudoku).init(gpa);
    defer queue.deinit();
    try queue.enqueue(sudoku_.*);

    while (!queue.isEmpty()) {
        const sudoku = queue.dequeue() orelse break;
        if (sudoku.isSolved()) {
            return true;
        }

        var firstZero: i64 = -1;
        for (0.., sudoku.puzzle) |i, value| {
            if (value == 0) {
                firstZero = @intCast(i);
                break;
            }
        }
        if (firstZero < 0) {
            continue;
        }
        const firstZeroIndex: usize = @intCast(firstZero);

        for (1..10) |value| {
            var sudokuCopy = sudoku.copy();
            sudokuCopy.puzzle[firstZeroIndex] = @intCast(value);
            if (!sudoku.isValid()) {
                continue;
            }
            try queue.enqueue(sudokuCopy);
        }
    }

    return false;
}

const Notes = struct {
    data: [81 * 9]u8,

    pub fn init(sudoku: *const Sudoku) Notes {
        var notes = Notes{ .data = [_]u8{0} ** (81 * 9) };
        for (1..10) |num| {
            for (0..9) |row| {
                for (0..9) |col| {
                    if (sudoku.puzzle[row * 9 + col] != 0) {
                        continue;
                    }

                    // check row
                    var hasNumInRow = false;
                    for (0..9) |checkCol| {
                        if (sudoku.puzzle[row * 9 + checkCol] == num) {
                            hasNumInRow = true;
                            break;
                        }
                    }
                    if (hasNumInRow) {
                        continue;
                    }

                    // check col
                    var hasNumInCol = false;
                    for (0..9) |checkRow| {
                        if (sudoku.puzzle[checkRow * 9 + col] == num) {
                            hasNumInCol = true;
                            break;
                        }
                    }
                    if (hasNumInCol) {
                        continue;
                    }

                    // check square
                    var hasNumInSquare = false;
                    const square = (row / 3) * 3 + col / 3;
                    for (0..3) |squareRow| {
                        for (0..3) |squareCol| {
                            const row_ = squareRow + (square / 3) * 3;
                            const col_ = squareCol + (square % 3) * 3;
                            if (sudoku.puzzle[row_ * 9 + col_] == num) {
                                hasNumInSquare = true;
                                break;
                            }
                        }
                        if (hasNumInSquare) {
                            break;
                        }
                    }

                    if (hasNumInSquare) {
                        continue;
                    }

                    notes.saveNote(row, col, num);
                }
            }
        }

        return notes;
    }

    pub fn saveNote(self: *Notes, row: usize, col: usize, num: usize) void {
        const idx = index(row, col, num);
        self.data[idx] = @intCast(num);
    }

    pub fn clearNote(self: *Notes, row: usize, col: usize, num: usize) void {
        const idx = index(row, col, num);
        self.data[idx] = 0;
    }

    pub fn getSingleNote(self: *Notes, row: usize, col: usize) ?u8 {
        var lastNumber: ?u8 = null;
        for (1..10) |num| {
            const idx = index(row, col, num);
            if (self.data[idx] == 0) {
                continue;
            }

            if (lastNumber != null) {
                return null;
            }

            lastNumber = self.data[idx];
        }
        return lastNumber;
    }

    pub fn updateNotesAfterPlacingNumber(self: *Notes, row: usize, col: usize, num: usize) void {
        // clear notes for this cell
        for (1..10) |n| {
            const idx = index(row, col, n);
            self.data[idx] = 0;
        }

        // clear notes for num in same row
        for (0..9) |clearCol| {
            const idx = index(row, clearCol, num);
            self.data[idx] = 0;
        }

        // clear notes for num in same column
        for (0..9) |clearRow| {
            const idx = index(clearRow, col, num);
            self.data[idx] = 0;
        }

        // clear notes for num in same square
        const square = (row / 3) * 3 + col / 3;
        for (0..3) |squareRow| {
            for (0..3) |squareCol| {
                const row_ = squareRow + (square / 3) * 3;
                const col_ = squareCol + (square % 3) * 3;
                const idx = index(row_, col_, num);
                self.data[idx] = 0;
            }
        }
    }

    pub fn hasNote(self: *Notes, row: usize, col: usize, num: usize) bool {
        const idx = index(row, col, num);
        return self.data[idx] != 0;
    }

    fn index(row: usize, col: usize, num: usize) u64 {
        return row * 81 + col * 9 + (num - 1);
    }
};

// Place all numbers which are the only number noted in that cell
fn placeSingleNumbers(notes: *Notes, sudoku: *Sudoku) bool {
    var found_any_number = false;
    while (true) {
        var found_number = false;
        for (0..9) |row| {
            for (0..9) |col| {
                if (sudoku.puzzle[row * 9 + col] != 0) {
                    continue;
                }

                const number = notes.getSingleNote(row, col) orelse continue;
                sudoku.puzzle[row * 9 + col] = number;
                notes.updateNotesAfterPlacingNumber(row, col, number);
                found_number = true;
                found_any_number = true;
            }
        }

        if (!found_number) {
            break;
        }
    }

    return found_any_number;
}

fn solveSingleNumberInCellNotes(gpa: std.mem.Allocator, sudoku: *Sudoku) !bool {
    var notes = Notes.init(sudoku);
    _ = placeSingleNumbers(&notes, sudoku);
    return solveBruteForce(gpa, sudoku);
}

// Place all numbers which are the only numbers of their kind in their row, column or square
fn placeSingleNumberInRowColOrSquare(notes: *Notes, sudoku: *Sudoku) bool {
    while (true) {
        var found_any_number = false;
        for (0..9) |row| {
            for (0..9) |col| {
                if (sudoku.puzzle[row * 9 + col] != 0) {
                    continue;
                }

                for (1..10) |num| {
                    if (!notes.hasNote(row, col, @intCast(num))) {
                        continue;
                    }

                    // check all cells in column
                    var has_in_col = false;
                    for (0..9) |checkRow| {
                        if (row == checkRow) {
                            continue;
                        }

                        if (sudoku.puzzle[checkRow * 9 + col] != 0) {
                            continue;
                        }

                        if (notes.hasNote(checkRow, col, @intCast(num))) {
                            has_in_col = true;
                            break;
                        }
                    }
                    if (!has_in_col) {
                        sudoku.puzzle[row * 9 + col] = @intCast(num);
                        notes.updateNotesAfterPlacingNumber(row, col, num);
                        found_any_number = true;
                        break;
                    }

                    // check all cells in row
                    var has_in_row = false;
                    for (0..9) |checkCol| {
                        if (col == checkCol) {
                            continue;
                        }

                        if (sudoku.puzzle[row * 9 + checkCol] != 0) {
                            continue;
                        }

                        if (notes.hasNote(row, checkCol, @intCast(num))) {
                            has_in_row = true;
                            break;
                        }
                    }
                    if (!has_in_row) {
                        sudoku.puzzle[row * 9 + col] = @intCast(num);
                        notes.updateNotesAfterPlacingNumber(row, col, num);
                        found_any_number = true;
                        break;
                    }

                    // check all cells in square
                    var has_in_square = false;
                    const square = (row / 3) * 3 + col / 3;
                    for (0..3) |squareRow| {
                        for (0..3) |squareCol| {
                            const row_ = squareRow + (square / 3) * 3;
                            const col_ = squareCol + (square % 3) * 3;
                            if (row_ == row and col_ == col) {
                                continue;
                            }

                            if (sudoku.puzzle[row_ * 9 + col_] != 0) {
                                continue;
                            }

                            if (notes.hasNote(row_, col_, @intCast(num))) {
                                has_in_square = true;
                                break;
                            }
                        }
                    }
                    if (!has_in_square) {
                        sudoku.puzzle[row * 9 + col] = @intCast(num);
                        notes.updateNotesAfterPlacingNumber(row, col, num);
                        found_any_number = true;
                        break;
                    }
                }
            }
        }
        if (found_any_number) {
            continue;
        }
        return false;
    }
}

fn solveSingleNumberInRowColOrSquare(gpa: std.mem.Allocator, sudoku: *Sudoku) !bool {
    var notes = Notes.init(sudoku);

    while (true) {
        var found_number = false;
        found_number = found_number or placeSingleNumbers(&notes, sudoku);
        found_number = found_number or placeSingleNumberInRowColOrSquare(&notes, sudoku);
        if (!found_number) {
            break;
        }

        if (sudoku.isSolved()) {
            return true;
        }
    }

    std.debug.print("not fully solved\n", .{});
    return solveBruteForce(gpa, sudoku);
}
