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

    var solveTimes = std.ArrayList(i128).init(allocator);
    defer solveTimes.deinit();

    for (sudokus.items) |*value| {
        const start = std.time.nanoTimestamp();

        const isSolved = try solve(allocator, value);
        if (isSolved) {
            std.debug.print("Found solution!\n", .{});
        } else {
            std.debug.print("Failed to find solution!\n", .{});
        }

        const end = std.time.nanoTimestamp();
        const elapsedNs = try solveTimes.addOne();
        elapsedNs.* = end - start;

        std.debug.print("Elapsed: {}ms\n", .{@divTrunc(elapsedNs.*, 1000000)});
    }

    var averageSolveTime: i128 = 0;
    for (solveTimes.items) |time| {
        averageSolveTime += time;
    }
    averageSolveTime = @divTrunc(averageSolveTime, solveTimes.items.len);
    std.debug.print("Average time: {}ms\n", .{@divTrunc(averageSolveTime, 1000000)});
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

fn solve(allocator: std.mem.Allocator, sudoku_: *Sudoku) !bool {
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
