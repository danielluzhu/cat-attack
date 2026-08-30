import Foundation

/// Physical layout of a US ANSI Mac keyboard, in "key units".
/// Used to decide whether a group of keycodes is clustered like a paw print.
public enum KeyLayout {
    /// (y, x-offset of first key, keycodes left-to-right)
    private static let rows: [(y: Double, offset: Double, keys: [Int64])] = [
        // ` 1 2 3 4 5 6 7 8 9 0 - =
        (0, 0.0, [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24]),
        // q w e r t y u i o p [ ]
        (1, 1.5, [12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30]),
        // a s d f g h j k l ; '
        (2, 1.75, [0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39]),
        // z x c v b n m , . /
        (3, 2.25, [6, 7, 8, 9, 11, 45, 46, 43, 47, 44]),
    ]

    public static let positions: [Int64: (x: Double, y: Double)] = {
        var map: [Int64: (x: Double, y: Double)] = [:]
        for row in rows {
            for (i, key) in row.keys.enumerated() {
                map[key] = (x: row.offset + Double(i), y: row.y)
            }
        }
        map[51] = (x: 13.3, y: 0)  // delete
        map[48] = (x: 0.3, y: 1)   // tab
        map[42] = (x: 13.6, y: 1)  // backslash
        map[36] = (x: 12.2, y: 2)  // return
        map[49] = (x: 5.0, y: 4)   // space (approximate center)
        return map
    }()

    public static func position(for key: Int64) -> (x: Double, y: Double)? {
        positions[key]
    }

    /// Lowercase letter for a keycode, used to match the unlock phrase.
    public static let letters: [Int64: Character] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
        8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
        16: "y", 17: "t", 31: "o", 32: "u", 34: "i", 35: "p", 37: "l",
        38: "j", 40: "k", 45: "n", 46: "m",
    ]

    public static func letter(for key: Int64) -> Character? {
        letters[key]
    }
}
