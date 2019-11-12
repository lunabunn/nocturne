import nocturne.Parser;

class Main {
    public static function main() {
        trace(Parser.fromString("if (a == !b and !c == d) message(a, b, c, d)"));
        // TODO Implement DOT binary operator (highest precedence)
    }
}