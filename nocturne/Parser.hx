package nocturne;

using haxe.EnumTools.EnumValueTools;

enum Tokens {
    L_PAREN; R_PAREN;
    L_CURLY; R_CURLY;
    MINUS; PLUS; DIVIDE; MULTIPLY;
    DOT; COMMA; EOF;

    EQUAL; MINUS_EQUAL; PLUS_EQUAL;
    DIV_EQUAL; MULT_EQUAL;
    
    EQUAL_EQUAL;
    GREATER; GREATER_EQUAL;
    LESS; LESS_EQUAL;

    FUN; IF; ELSE; ELSIF;
    WHILE; NOT; AND; OR; TRUE; FALSE;
    SYMBOL; STRING; NUMBER;

    SEMICOLON;
}

class Token {
    public var type: Tokens;
    public var value: Literal;

    public function new(type: Tokens, value: Literal=null) {
        this.type = type;
        this.value = value;
    }

    function toString() {
        return '{"type":${type.getName()},"value":${haxe.Json.stringify(value)}}';
    }
}

class StringIterator {
    public var index: Int = -1;
    public var string: String;

    public function new(string: String) {
        this.string = string;
    }

    inline public function hasNext(): Bool {
        return index < string.length - 1;
    }

    inline public function setIndex(index: Int) {
        this.index = index;
    }

    inline public function next(): String {
        return string.charAt(++index);
    }

    inline public function peek(n: Int=1): String {
        return string.charAt(index + n);
    }

    inline public function isPeek(char: String, n: Int=1) {
        return (peek(n) == char);
    }

    inline public function isEat(char: String) {
        if (peek() == char) {
            index++;
            return true;
        }
        return false;
    }
}

class TokenIterator {
    public var index: Int = -1;
    public var tokens: Array<Token>;

    public function new(tokens: Array<Token>) {
        this.tokens = tokens;
    }

    inline public function hasNext(): Bool {
        return index < tokens.length - 1;
    }

    inline public function setIndex(index: Int) {
        this.index = index;
    }

    inline public function next(): Token {
        return tokens[++index];
    }

    inline public function peek(n: Int=1): Token {
        return (index + n >= tokens.length)? null:tokens[index + n];
    }

    inline public function isPeek(type: Tokens, n: Int=1) {
        return (index + n >= tokens.length)? false:(peek(n).type == type);
    }

    inline public function isEat(type: Tokens) {
        if (hasNext() && peek().type == type) {
            index++;
            return true;
        }
        return false;
    }
}

interface ASTNode {} 
interface Expr extends ASTNode {}
interface Literal extends Expr {}
interface Stmt extends ASTNode {}

class NumberLiteral implements Literal {
    public var value: Float;

    public inline function new(value: Float)
        this.value = value;
    
    public inline function toString(): String
        return Std.string(value);
}

class StringLiteral implements Literal {
    public var value: String;
    
    public inline function new(value: String)
        this.value = value;
    
    public inline function toString(): String
        return '"$value"';
}

class BooleanLiteral implements Literal {
    public var value: Bool;

    public inline function new(value: Bool) {
        this.value = value;
    }

    public inline function toString(): String
        return Std.string(value);
}

class SymbolLiteral implements Literal {
    public var value: String;
    
    public inline function new(value: String)
        this.value = value;
    
    public inline function toString(): String
        return value;
}

class UnaryExpression implements Expr {
    public var op: Tokens;
    public var operand: Expr;

    public function new(op: Tokens, operand: Expr) {
        this.op = op;
        this.operand = operand;
    }

    public inline function toString(): String
        return '(${op.getName()} $operand)';
}

class BinaryExpression implements Expr {
    public var op: Tokens;
    public var left: Expr;
    public var right: Expr;

    public function new(op: Tokens, left: Expr, right: Expr) {
        this.op = op;
        this.left = left;
        this.right = right;
    }

    public inline function toString(): String
        return '($left ${op.getName()} $right)';
}

class FuncCallExpression implements Expr {
    public var funcSymbol: SymbolLiteral;
    public var args: Array<Expr>;

    public function new(funcSymbol: SymbolLiteral, args:Array<Expr>) {
        this.funcSymbol = funcSymbol;
        this.args = args;
    }

    public inline function toString(): String {
        var str = '${funcSymbol.value}(';
        for (arg in args) {
            str += '$arg, ';
        }
        str = str.substr(0, str.length - 2);
        str += ')';
        return str;
    }
}

class CompoundStmt implements Stmt {
    public var statements: Array<Stmt>;

    public function new(?statements: Array<Stmt>)
        this.statements = statements;
    
    public inline function toString(): String {
        var str = "{\n";
        for (statement in statements) {
            str += '\t$statement\n';
        }
        str += "}";
        return str;
    }
}

class ExprStmt implements Stmt {
    public var expression: Expr;

    public function new(expression: Expr)
        this.expression = expression;
    
    public inline function toString(): String
        return cast expression;
}

class IfStmt implements Stmt {
    public var expression: Expr;
    public var statement: Stmt;
    public var elsifStmts: Array<ElsifStmt>;
    public var elseStmt: ElseStmt;

    public function new(expression: Expr, statement: Stmt, elsifStmts: Array<ElsifStmt>, elseStmt: ElseStmt) {
        this.expression = expression;
        this.statement = statement;
        this.elsifStmts = elsifStmts;
        this.elseStmt = elseStmt;
    }

    public inline function toString(): String {
        var str = 'if ($expression) $statement';
        for (elsifStmt in elsifStmts)
            str += '\n$elsifStmt';
        if (elseStmt != null)
            str += '\n$elseStmt';
        return str;
    }
}

class ElsifStmt implements Stmt {
    public var expression: Expr;
    public var statement: Stmt;

    public function new(expression: Expr, statement: Stmt) {
        this.expression = expression;
        this.statement = statement;
    }

    public inline function toString(): String
        return 'elsif ($expression) $statement';
}

class ElseStmt implements Stmt {
    public var statement: Stmt;

    public function new(statement: Stmt)
        this.statement = statement;
    
    public inline function toString(): String
        return 'else $statement';
}

class Parser {
    static var numberRegexp = ~/^[0-9]*(\.[0-9]*)?[0-9]/g;
    static var identifierRegexp = ~/^[a-zA-Z_]+/g;

    public static inline function fromString(str: String) {
        return parse(lex(str));
    }

    public static inline function fromTokens(tokens: Array<Token>) {
        return parse(tokens);
    }

    static function lex(str: String): Array<Token> {
        var tokens = new Array<Token>();
        var siter = new StringIterator(str);
        for (char in siter) {
            switch (char) {
                case "#":
                    while (!siter.isEat("\n"))
                        siter.next();
                case "(": tokens.push(new Token(Tokens.L_PAREN));
                case ")": tokens.push(new Token(Tokens.R_PAREN));
                case "{": tokens.push(new Token(Tokens.L_CURLY));
                case "}": tokens.push(new Token(Tokens.R_CURLY));
                case "!": tokens.push(new Token(Tokens.NOT));
                case "-":
                    if (siter.isEat("="))
                        tokens.push(new Token(Tokens.MINUS_EQUAL));
                    else
                        tokens.push(new Token(Tokens.MINUS));
                case "+":
                    if (siter.isEat("="))
                        tokens.push(new Token(Tokens.PLUS_EQUAL));
                    else
                        tokens.push(new Token(Tokens.PLUS));
                case "/":
                    if (siter.isEat("="))
                        tokens.push(new Token(Tokens.DIV_EQUAL));
                    else
                        tokens.push(new Token(Tokens.DIVIDE));
                case "*":
                    if (siter.isEat("="))
                        tokens.push(new Token(Tokens.MULTIPLY));
                    else
                        tokens.push(new Token(Tokens.MULT_EQUAL));
                case ".":
                    if (numberRegexp.match(str)) {
                        tokens.push(new Token(Tokens.NUMBER, new NumberLiteral(Std.parseFloat(numberRegexp.matched(0)))));
                        siter.index += numberRegexp.matchedPos().len;
                    } else {
                        tokens.push(new Token(Tokens.DOT));
                    }
                case ",": tokens.push(new Token(Tokens.COMMA)); 
                case "=":
                    if (siter.isEat("="))
                        tokens.push(new Token(Tokens.EQUAL_EQUAL));
                    else
                        tokens.push(new Token(Tokens.EQUAL));
                case ">":
                    if (siter.isEat("="))
                        tokens.push(new Token(Tokens.GREATER_EQUAL));
                    else
                        tokens.push(new Token(Tokens.GREATER));
                case "<":
                    if (siter.isEat("="))
                        tokens.push(new Token(Tokens.LESS_EQUAL));
                    else
                        tokens.push(new Token(Tokens.LESS));
                case "\"":
                    var value = "";
                    while (siter.hasNext()) {
                        var char = siter.next();
                        
                        if (char == "\"")
                            break;
                        
                        if (char == "\\") {
                            var nextChar = siter.next();
                            switch (nextChar) {
                                case "\n": continue;
                                case "\\": value += "\\";
                                case "\"": value += "\"";
                                case "\'": value += "\'";
                                case "\r": value += "\r";
                                case "\t": value += "\t";
                                default: value += nextChar;
                            }
                        } else {
                            value += char;
                        }
                    }
                    tokens.push(new Token(Tokens.STRING, new StringLiteral(value)));
                case "\n": tokens.push(new Token(Tokens.SEMICOLON));
                case ";": tokens.push(new Token(Tokens.SEMICOLON));
                case " ":
                case "\r":
                case "\t":
                default:
                    if (numberRegexp.match(str.substr(siter.index))) {
                        tokens.push(new Token(Tokens.NUMBER, new NumberLiteral(Std.parseFloat(numberRegexp.matched(0)))));
                        siter.index += numberRegexp.matchedPos().len - 1;
                        continue;
                    }
                    
                    if (identifierRegexp.match(str.substr(siter.index))) {
                        switch (identifierRegexp.matched(0).toLowerCase()) {
                            case "fun": tokens.push(new Token(Tokens.FUN));
                            case "if": tokens.push(new Token(Tokens.IF));
                            case "else": tokens.push(new Token(Tokens.ELSE));
                            case "elsif": tokens.push(new Token(Tokens.ELSIF));
                            case "while": tokens.push(new Token(Tokens.WHILE));
                            case "and": tokens.push(new Token(Tokens.AND));
                            case "or": tokens.push(new Token(Tokens.OR));
                            case "true": tokens.push(new Token(Tokens.TRUE));
                            case "false": tokens.push(new Token(Tokens.FALSE));
                            default: tokens.push(new Token(Tokens.SYMBOL, new SymbolLiteral(identifierRegexp.matched(0))));
                        }
                        siter.index += identifierRegexp.matchedPos().len - 1;
                        continue;
                    }
                    
                    throw('Nocturne >> Found unknown token ${char}');
            }
        }
        tokens.push(new Token(Tokens.EOF));
        return tokens;
    }

    static function parse(tokens: Array<Token>): CompoundStmt {
        var titer = new TokenIterator(tokens);
        var program = new CompoundStmt([]);
        while (!titer.isEat(Tokens.EOF)) {
            program.statements.push(statement(titer));
        }
        return program;
    }

    static function statement(titer: TokenIterator): Stmt {
        var token: Token;
        switch ((token = titer.peek()).type) {
            case Tokens.IF:
                return ifStmt(titer);
            default:
                var expr: Expr;
                if ((expr = orExpr(titer)) != null)
                    return new ExprStmt(expr);
                throw('Nocturne >> Expected start of statement, found unexpected token ${token}');
        }
    }

    static function ifStmt(titer: TokenIterator): IfStmt {
        var condition: Expr;
        titer.isEat(Tokens.IF);
        if (titer.isEat(Tokens.L_PAREN)) {
            condition = orExpr(titer);
            if (titer.isEat(Tokens.R_PAREN)) {
                return new IfStmt(condition, statement(titer), elsifStmts(titer), elseStmt(titer));
            } else {
                throw('Nocturne >> Expected right parenthesis after if condition expression, found unexpected token ${titer.next()}');
            }
        } else {
            throw('Nocturne >> Expected left parenthesis after if, found unexpected token ${titer.next()}');
        }
    }

    static function elsifStmts(titer: TokenIterator): Array<ElsifStmt> {
        var elsifStmts = [];
        var condition: Expr;
        while (titer.isEat(Tokens.ELSIF)) {
            if (titer.isEat(Tokens.L_PAREN)) {
                condition = orExpr(titer);
                if (titer.isEat(Tokens.R_PAREN)) {
                    elsifStmts.push(new ElsifStmt(condition, statement(titer)));
                } else {
                    throw('Nocturne >> Expected right parenthesis after elsif condition expression, found unexpected token ${titer.next()}');
                }
            } else {
                throw('Nocturne >> Expected left parenthesis after elsif, found unexpected token ${titer.next()}');
            }
        }
        return elsifStmts;
    }

    static function elseStmt(titer: TokenIterator): ElseStmt {
        if (titer.isEat(Tokens.ELSE)) {
            return new ElseStmt(statement(titer));
        }
        return null;
    }

    static function orExpr(titer: TokenIterator): Expr {
        var expr = andExpr(titer);

        while (titer.isEat(Tokens.OR)) {
            var right = andExpr(titer);
            expr = new BinaryExpression(Tokens.OR, expr, right);
        }                                    

        return expr;
    }

    static function andExpr(titer: TokenIterator): Expr {
        var expr = comparisonExpr(titer);

        while (titer.isEat(Tokens.AND)) {
            var right = comparisonExpr(titer);
            expr = new BinaryExpression(Tokens.AND, expr, right);
        }                                    

        return expr;
    }

    static function comparisonExpr(titer: TokenIterator): Expr {
        var expr = notExpr(titer);
        
        while (titer.isPeek(Tokens.EQUAL_EQUAL) || titer.isPeek(Tokens.LESS_EQUAL) || titer.isPeek(Tokens.GREATER_EQUAL) || titer.isPeek(Tokens.LESS) || titer.isPeek(Tokens.GREATER)) {
            var op = titer.next().type;
            var right = notExpr(titer);
            expr = new BinaryExpression(op, expr, right);
        }

        return expr;
    }

    static function notExpr(titer: TokenIterator): Expr {
        var not = false;
        
        while (titer.isEat(Tokens.NOT)) {
            not = !not;
        }

        var expr = not? new UnaryExpression(Tokens.NOT, setExpr(titer)):setExpr(titer);                      

        return expr;
    }

    static function setExpr(titer: TokenIterator): Expr {
        if (titer.isPeek(Tokens.SYMBOL) && (titer.isPeek(Tokens.EQUAL, 2) || titer.isPeek(Tokens.PLUS_EQUAL, 2) || titer.isPeek(Tokens.MINUS_EQUAL, 2) || titer.isPeek(Tokens.MULT_EQUAL, 2) || titer.isPeek(Tokens.DIV_EQUAL, 2))) {
            var symbol = titer.next().value;
            var op = titer.next().type;
            var right = setExpr(titer);
            return new BinaryExpression(op, symbol, right);
        }
        return plusMinusExpr(titer);
    }

    static function plusMinusExpr(titer: TokenIterator): Expr {
        var expr = multDivExpr(titer);
        
        while (titer.isPeek(Tokens.PLUS) || titer.isPeek(Tokens.MINUS)) {
            var op = titer.next().type;
            var right = multDivExpr(titer);
            expr = new BinaryExpression(op, expr, right);
        }

        return expr;
    }

    static function multDivExpr(titer: TokenIterator): Expr {
        var expr = negateExpr(titer);
        
        while (titer.isPeek(Tokens.MULTIPLY) || titer.isPeek(Tokens.DIVIDE)) {
            var op = titer.next().type;
            var right = negateExpr(titer);
            expr = new BinaryExpression(op, expr, right);
        }

        return expr;
    }

    static function negateExpr(titer: TokenIterator): Expr {
        if (titer.isEat(Tokens.MINUS)) {
            return new UnaryExpression(Tokens.MINUS, groupedFuncCallExpr(titer));
        }
        return groupedFuncCallExpr(titer);
    }

    static function groupedFuncCallExpr(titer: TokenIterator): Expr {
        if (titer.isPeek(Tokens.SYMBOL)) {
            var symbol: SymbolLiteral = cast titer.next().value;
            if (titer.isEat(Tokens.L_PAREN)) {
                var args = new Array<Expr>();
                var expr: Expr;
                if ((expr = orExpr(titer)) != null) {
                    args.push(expr);
                    while (titer.isEat(Tokens.COMMA)) {
                        args.push(orExpr(titer));
                    }
                }
                titer.isEat(Tokens.R_PAREN);
                return new FuncCallExpression(symbol, args);
            } else {
                return symbol;
            }
        } else if (titer.isEat(Tokens.L_PAREN)) {
            var expr = orExpr(titer);
            titer.isEat(Tokens.R_PAREN);
            return expr;
        } else if (titer.isPeek(Tokens.NUMBER)) {
            return titer.next().value;
        } else {
            return null;
        }
    }
}