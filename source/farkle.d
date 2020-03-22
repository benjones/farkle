///Data structures for the game and functions that operate on it
module farkle;

import std.stdio : writeln;
import std.conv : to;
import std.algorithm : map;
import std.range;

import vibe.http.websockets : WebSocket;
import vibe.data.json;

import sumtype;

struct Die {

    int showing;
    bool held; 
}

struct Player {
    @safe: 
    string name;
    int score;
    WebSocket ws;

    Json toJson(){
        auto ret = Json.emptyObject;
        ret["name"] = name;
        ret["score"] = score.serializeToJson;
        ret["ws"] = ws.toHash;
        return ret;
    }

    static Player fromJson(Json src){
        assert(false, "not supported");
    }
}

///roll the dice, these are the ones that are held now
struct Roll {
    int[] newHolds;
}

///keep the score from this turn so far
struct Stay {}

///roll all 6 dice
struct NewRoll{}

alias Move = SumType!(Roll, Stay, NewRoll);

struct LabeledScore {
    int score;
    string description;
    @safe:
    LabeledScore opBinary(string op)(LabeledScore other) if(op == "+"){
        auto maybeAnd = other.description.length > 0 ? " and " : "";
        return LabeledScore(score + other.score, description ~ maybeAnd ~ other.description);
    }
}

struct Farkle {
    private{
        Die[6] dice;
        Player[] players;
        size_t whoseTurn;
    }

    //for serialization
    Json toJson(){
        auto ret = Json.emptyObject;
        ret["dice"] = dice.serializeToJson;
        ret["players"] = players.serializeToJson;
        ret["whoseTurn"] = whoseTurn;
        return ret;
    }
    static Json fromJson(Json src){
        assert(false, "not supported");
    }
    
    
    void addPlayer(Player p){
        import std.array : insertInPlace;
        import std.range : empty;
        if(players.empty){
            players = [p];
            newTurn();
        } else {
            players.insertInPlace(whoseTurn + 1, p);
        }
        writeln("players: ", players.map!(a => a.toJson));
        writeln("it's " ~ to!string(whoseTurn) ~ "'s turn");
    }
    
    void removePlayer(WebSocket socket){
        import std.algorithm : find;
        import std.array : replaceInPlace;
        auto found = players.find!(a => a.ws == socket);
        auto index = players.length - found.length;
        players.replaceInPlace(index, index + 1, cast(Player[])[]);
        writeln("players: ", players.map!(a => a.toJson));
        writeln("it's " ~ to!string(whoseTurn) ~ "'s turn");
        assert(whoseTurn < players.length);
    }

    Player getPlayer(WebSocket socket){
        import std.algorithm : find;
        return players.find!(a => a.ws == socket).front;
    }

    bool isMyTurn(WebSocket socket){
        return players[whoseTurn].ws == socket;
    }

    void takeAction(Move move){
        move.match!(
                    (Roll r) => roll(r),
                    (Stay s) => stay(),
                    (NewRoll nr) => newRoll()
                    );
    }
    
    void roll(Roll roll){
        import std.random : uniform;
        
        foreach(hold; roll.newHolds){
            dice[hold].held = true;
        }
        foreach(ref die; dice){
            if(!die.held){
                die.showing = uniform!"[]"(1,6);
            }
        }
    }

    void stay(){

    }

    void newRoll(){
        
    }
    
    //start who's turn clean by rolling all 6 dice
    void newTurn(){
        foreach(ref die; dice){
            die.held = false;
        }
        roll(Roll([]));
    }

    
    LabeledScore scoreRoll(){
        import std.algorithm : filter;
        import std.array;
        
        int[] toScore = dice[].filter!(x => !x.held).map!(x => x.showing).array;

        return scoreDice(toScore);
    }

    LabeledScore scoreDice(int[] toScore){
        import std.algorithm;
        import std.array;
        import std.conv : to;
        import std.stdio;

        sort(toScore);
        auto groups = toScore.group.array.sort!((a, b) => a[1] > b[1]);

        static LabeledScore onesAndFives(T)(T gs){
            LabeledScore ret;
            foreach(g; gs){
                if(g[0] == 1){
                    ret.score += 100*g[1];
                    auto maybeAnd = ret.description.length > 0 ? " and " : "";
                    ret.description = to!string(g[1]) ~ " 1's" ~ maybeAnd ~ ret.description;
                } else if(g[0] == 5){
                    ret.score += 50*g[1];
                    auto maybeAnd = ret.description.length > 0 ? " and " : "";
                    ret.description ~= maybeAnd ~ to!string(g[1]) ~ " 5's";
                }
            }
            return ret;
        }
        
        writeln("groups: ", groups);
        if(groups.length == 6){
            //straight
            return LabeledScore(3000, "straight");
        } else if(groups[0][1] == 6){
            return LabeledScore(3000, "six " ~ to!string(groups[0][0]) ~ "'s");
        }else if(groups[0][1] == 5){
            return LabeledScore(2000, "five " ~ to!string(groups[0][0]) ~ "'s")
                + onesAndFives(groups[1 .. $]);
        } else if (groups[0][1] == 4){
            if(groups.length > 1 && groups[1][1] == 2){
                return LabeledScore(1500, "three doublets");
            } else {
                return LabeledScore(1000, "four " ~ to!string(groups[0][0]) ~ "'s") +
                    onesAndFives(groups[1 .. $]);
            }
        } else if (groups[0][1] == 3) {
            if(groups.length > 1 && groups[1][1] == 3){
                return LabeledScore(2500, "two triplets");
            } else {
                return LabeledScore(groups[0][0] == 1 ? 300 : 100*groups[0][0],
                                    "three " ~ to!string(groups[0][0]) ~ "'s") +
                    onesAndFives(groups[1 .. $]);
            }
        } else if(groups.length > 2 && groups[2][1] == 2) {
            return LabeledScore(1500, "three doublets");
        } else {
            auto oaf = onesAndFives(groups);
            return oaf.score > 0 ? oaf : LabeledScore(0, toScore.length == 6 ? "hard farkle" :
                                                      toScore.length == 5 ? "pretty bad farkle" :
                                                      "farkle");
        }


    }
    
    
    bool farkled(){
        return false;
    }
}


unittest {

    import std.stdio;
    
    Farkle f;

    Player p;

    f.addPlayer(p);
    writeln(f.dice);
    foreach(i; 0..6){
        f.roll(Roll([i]));
        writeln(f.dice);
    }


    void setRoll(int[] dice){
        foreach(i, d; dice){
            f.dice[i].held = false;
            f.dice[i].showing = d;
        }
    }

    struct RollResult{
        int[] dice;
        LabeledScore expected;
    }
    
    auto rolls = [
                  RollResult([1,2,3,4,5,6], LabeledScore(3000, "straight")),
                  RollResult([2,3,6,5,4,1], LabeledScore(3000, "straight")),
                  RollResult([2,2,2,2,3,2], LabeledScore(2000, "five 2's")),
                  RollResult([1,2,2,2,2,2], LabeledScore(2100, "five 2's and 1 1's")),
                  RollResult([2,3,2,3,2,3], LabeledScore(2500, "two triplets")),
                  RollResult([2,2,2,3,4,4], LabeledScore(200, "three 2's")),
                  RollResult([2,2,2,1,1,4], LabeledScore(400, "three 2's and 2 1's")),
                  RollResult([2,2,2,2,3,3], LabeledScore(1500, "three doublets")),
                  RollResult([2,2,3,3,4,4], LabeledScore(1500, "three doublets")),
                  RollResult([2,2,2,2,3,4], LabeledScore(1000, "four 2's")),
                  RollResult([2,2,2,2,1,5], LabeledScore(1150, "four 2's and 1 1's and 1 5's")),
                  RollResult([1,2,1,5,5,3], LabeledScore(300, "2 1's and 2 5's")),
                  RollResult([2,3,4,6,6,2], LabeledScore(0, "hard farkle"))
                  ];
    foreach(roll; rolls){
        setRoll(roll.dice);
        writeln("dice: ", roll.dice, " f.scoreRoll: ", f.scoreRoll, " expected: ", roll.expected);
        assert(f.scoreRoll == roll.expected);
    }
    writeln("6 die rolls all good");
    auto partialRolls = [
                         RollResult([1,1,1], LabeledScore(300, "three 1's")),
                         RollResult([5], LabeledScore(50, "1 5's")),
                         RollResult([5, 5, 1], LabeledScore(200, "1 1's and 2 5's")),
                         RollResult([4, 4, 4, 1], LabeledScore(500, "three 4's and 1 1's")),
                         RollResult([2,3,4,6], LabeledScore(0, "farkle")),
                         RollResult([2,3,4,6,2], LabeledScore(0, "pretty bad farkle"))
                         ];
    foreach(roll; partialRolls){
        writeln("dice: ", roll.dice, " f.scoreRoll: ", f.scoreDice(roll.dice), " expected: ", roll.expected);
        assert(f.scoreDice(roll.dice) == roll.expected);
    }

    import vibe.data.json;
    writeln(f.toJson);
    
}
