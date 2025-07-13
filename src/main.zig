const std = @import("std");
const t = std.testing;

const SudokuError = error{
    NumberOutOfRange,
    NoZeroesLeft,
};

const Sudoku = struct {
    puzzle: [81]u8,
    solution: [81]u8,

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

        pub fn init(allocator: std.mem.Allocator) Queue(T) {
            return Queue(T){
                .list = std.ArrayList(T).init(allocator),
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

pub fn main() !void {
    const file = try std.fs.openFileAbsolute("/home/henne/Downloads/sudoku/sudoku.csv", .{});
    defer file.close();

    try file.seekBy(16);

    const allocator = std.heap.page_allocator;

    var sudokus = std.ArrayList(Sudoku).init(allocator);
    defer sudokus.deinit();

    while (hasBytesLeft(file) and sudokus.items.len < 100) {
        var sudoku = try sudokus.addOne();
        {
            const read_bytes = try file.read(&sudoku.puzzle);
            if (read_bytes != 81) {
                std.debug.print("failed to read puzzle", .{});
                return;
            }
        }

        try file.seekBy(1);

        {
            const read_bytes = try file.read(&sudoku.solution);
            if (read_bytes != 81) {
                std.debug.print("failed to read solution", .{});
                return;
            }
        }

        try file.seekBy(1);

        try convertToNumber(sudoku);
    }

    std.debug.print("Loaded all sudokus, starting to solve...\n", .{});

    const Timing = struct {
        bruteForce: i128,
        smart: i128,
    };

    var solveTimes = std.ArrayList(Timing).init(allocator);
    defer solveTimes.deinit();

    for (sudokus.items) |*value| {
        const timing = try solveTimes.addOne();

        {
            const start = std.time.nanoTimestamp();
            const isSolved = try solveBruteForce(allocator, value);
            if (!isSolved) {
                std.debug.print("Failed to find brute force solution!\n", .{});
            }
            const end = std.time.nanoTimestamp();
            timing.bruteForce = end - start;
        }

        {
            const start = std.time.nanoTimestamp();
            const isSolved = try solveSmart(allocator, value);
            if (!isSolved) {
                std.debug.print("Failed to find smart solution!\n", .{});
            }
            const end = std.time.nanoTimestamp();
            timing.smart = end - start;
        }
    }

    var averageSolveTime = Timing{ .bruteForce = 0, .smart = 0 };
    for (solveTimes.items) |time| {
        averageSolveTime.bruteForce += time.bruteForce;
        averageSolveTime.smart += time.smart;
    }
    averageSolveTime.bruteForce = @divTrunc(averageSolveTime.bruteForce, solveTimes.items.len);
    averageSolveTime.smart = @divTrunc(averageSolveTime.smart, solveTimes.items.len);
    std.debug.print("Average time brute force: {:>10}ns\n", .{averageSolveTime.bruteForce});
    std.debug.print("Average time smart:       {:>10}ns\n", .{averageSolveTime.smart});
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

fn solveBruteForce(allocator: std.mem.Allocator, sudoku_: *Sudoku) !bool {
    var queue = Queue(Sudoku).init(allocator);
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

    pub fn saveNote(self: *Notes, row: u8, col: u8, num: u8) void {
        const idx = index(row, col, num);
        self.data[idx] = num;
    }

    pub fn clearNote(self: *Notes, row: u8, col: u8, num: u8) void {
        const idx = index(row, col, num);
        self.data[idx] = 0;
    }

    pub fn getSingleNote(self: *Notes, row: u8, col: u8) ?u8 {
        var lastNumber: ?u8 = null;
        for (1..10) |num| {
            const idx = index(row, col, @intCast(num));
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

    pub fn updateNotesAfterPlacingNumber(self: *Notes, row: u8, col: u8, num: u8) void {
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

    fn index(row: usize, col: usize, num: u8) u64 {
        return row * 81 + col * 9 + (num - 1);
    }
};

fn solveSmart(_: std.mem.Allocator, sudoku_: *Sudoku) !bool {
    // add all possible numbers to a "notes" data structure
    var notes = Notes{ .data = [_]u8{0} ** (81 * 9) };
    for (1..10) |num| {
        for (0..9) |row| {
            for (0..9) |col| {
                if (sudoku_.puzzle[row * 9 + col] != 0) {
                    continue;
                }

                // check row
                var hasNumInRow = false;
                for (0..9) |checkCol| {
                    if (sudoku_.puzzle[row * 9 + checkCol] == num) {
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
                    if (sudoku_.puzzle[checkRow * 9 + col] == num) {
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
                        if (sudoku_.puzzle[row_ * 9 + col_] == num) {
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

                notes.saveNote(@intCast(row), @intCast(col), @intCast(num));
            }
        }
    }

    var counter: usize = 0;
    while (!sudoku_.isSolved() and counter < 100) {
        // check whether there is a field with a single number noted
        for (0..9) |row| {
            for (0..9) |col| {
                const number = notes.getSingleNote(@intCast(row), @intCast(col)) orelse continue;
                sudoku_.puzzle[row * 9 + col] = number;
                notes.updateNotesAfterPlacingNumber(@intCast(row), @intCast(col), number);
            }
        }

        counter += 1;
    }

    // std.debug.print("{}\n", .{sudoku_});
    // std.debug.print("{}\n", .{notes});

    return sudoku_.isSolved();
}
