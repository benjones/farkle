///Data structures for the game and functions that operate on it
module farkle;

import std.conv : to;
import std.algorithm : map, filter, find;
import std.range;

import vibe.http.websockets : WebSocket;
import vibe.data.json;
import vibe.core.log;

import sumtype;

struct Die {

    int showing;
    bool held; 
}

enum FirstTurnMinScore = 500;



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

    void sendMessage(Json message){
        ws.send(message.toString);
    }
}

///roll the dice, these are the ones that are held now
struct Roll {
    int[] newHolds;
}

///keep the score from this turn + the held dice
struct Stay {
    int[] toHold;
}

///roll all 6 dice
struct NewRoll{}

///Let it ride!
struct Steal{}


alias Move = SumType!(Roll, Stay, NewRoll, Steal);

struct LabeledScore {
    int score;
    int diceUsed;
    string description;

    
    @safe pure nothrow:
    LabeledScore opBinary(string op)(LabeledScore other) if(op == "+"){
        auto maybeAnd = other.description.length > 0 ? " and " : "";
        return LabeledScore(score + other.score, diceUsed + other.diceUsed,
                            description ~ maybeAnd ~ other.description);
    }
}

struct Farkle {
    @safe:
    private{
        Die[6] dice;
        Player[] players;
        size_t whoseTurn;
        int turnScore;
        LabeledScore[] scoringDice;
        bool startOfTurn;
        LabeledScore lastScore; //last score for held dice.  Todo use scoringDice.back
        LabeledScore showingScore; //score on the dice that are showing
    }

    //for serialization
    Json toJson(){
        auto ret = Json.emptyObject;
        ret["type"] = "gameState";
        ret["dice"] = dice.serializeToJson;
        ret["players"] = players.serializeToJson;
        ret["whoseTurn"] = whoseTurn;
        ret["turnScore"] = turnScore;
        ret["lastScore"] = lastScore.serializeToJson;
        ret["scoringMoves"] = scoringDice.serializeToJson;
        ret["showingScore"] = showingScore.serializeToJson;
        return ret;
    }
    static Json fromJson(Json src){
        assert(false, "not supported");
    }
    

    ulong numPlayers() pure @safe nothrow{
        return players.length;
    }
    
    void addPlayer(Player p) {
        import std.array : insertInPlace;
        import std.range : empty;
        if(players.empty){
            players = [p];
            initializeGame();
        } else {
            players.insertInPlace(whoseTurn + 1, p);
        }
        logInfo("players: %s", players.map!(a => a.toJson));
        logInfo("it's " ~ to!string(whoseTurn) ~ "'s turn");
        logInfo("sending them: %s ", this.toJson);

        sendUpdatesToPlayers();
    }
    
    bool removePlayer(WebSocket socket){
        import std.array : replaceInPlace;
        auto found = players.find!(a => a.ws is socket);
        auto index = players.length - found.length;
        if(found.empty){
            return false; //not here
        }
        if(index < whoseTurn){
            --whoseTurn; //skip this player
        }
        players.replaceInPlace(index, index + 1, cast(Player[])[]);
        logInfo("players: %s", players.map!(a => a.toJson));
        logInfo("it's " ~ to!string(whoseTurn) ~ "'s turn");
        if(players.empty){
            initializeGame();
            return true;
        } else {
            assert(whoseTurn <= players.length);
            if(whoseTurn == players.length){
                whoseTurn = 0;
            }
        }
        sendUpdatesToPlayers();
        return true;
    }

    void initializeGame() nothrow{
        whoseTurn = 0;
        startOfTurn = true;
        foreach(ref die; dice){
            die.held = false;
        }
    }

    void messageAllPlayers(Json message){
        logInfo("messaging everyone: %s", message.toString);
        foreach(p; players){
            p.sendMessage(message);
        }
    }

    void messageActivePlayer(Json message){
        logInfo("messaging active player: %s", message.toString);
        players[whoseTurn].sendMessage(message);
    }


    void sendUpdatesToPlayers(){
        messageAllPlayers(this.toJson);
        players[whoseTurn].sendMessage(legalMoves);
    }
    
    Player getPlayer(WebSocket socket) nothrow pure{
        return players.find!(a => a.ws is socket).front;
    }

    bool isMyTurn(WebSocket socket) nothrow pure{
        return players[whoseTurn].ws is socket;
    }

    Json legalMoves(){
        import std.algorithm : count;
        
        auto ret = Json.emptyObject;
        ret["type"] = "yourTurn";
        ret["legalMoves"] = Json.emptyArray;
        //TODO, be more accurate here
        if(!startOfTurn && dice[].count!(a => a.held) < 5){
            ret["legalMoves"] ~= "Roll";
        }
        if(legalStay){
            ret["legalMoves"] ~= "Stay";
        }
        if(legalNewRoll){
            ret["legalMoves"] ~= "NewRoll";
        }
        if(legalSteal){
            ret["legalMoves"] ~= "Steal";
        }
        return ret;
    }

    int[] rollFreeDice(){
        import std.random : uniform;
        foreach(ref die; dice){
            if(!die.held){
                die.showing = uniform!"[]"(1,6);
            }
        }
        return dice[].filter!(a => !a.held).map!(a => a.showing).array;
    }

        
    void takeAction(Move move){
        move.match!(
                    (Roll r) => roll(r),
                    (Stay s) => stay(s),
                    (NewRoll nr) => newRoll(),
                    (Steal s) => steal()
                    );
    }

    
    void roll(Roll roll){
        logInfo("rolling with holds: %s", roll);
        startOfTurn = false;

        lastScore = scoreDice(roll.newHolds.map!(a => dice[a].showing).array);

        holdDice(roll.newHolds);

        logInfo("heldScore from roll: %s", lastScore);
        turnScore += lastScore.score;
        scoringDice ~= lastScore;

        int[] rolledDice = rollFreeDice;
        
        showingScore = scoreDice(rolledDice);
        
        if(showingScore.score == 0){
            lastScore = showingScore;
            nextPlayer(true);
        }
    }

    void stay(Stay stay){
        logInfo("staying!");
        assert(!startOfTurn);

        lastScore = scoreDice(stay.toHold.map!(a => dice[a].showing).array);
        holdDice(stay.toHold);

        showingScore = scoreRoll;
        
        turnScore += lastScore.score;
        scoringDice ~= lastScore;
        
        players[whoseTurn].score += turnScore;
        nextPlayer(false);
    }

    void newRoll(){
        import std.random : uniform;
        logInfo("newRoll!");

        if(!startOfTurn){
            lastScore = showingScore;
            turnScore += lastScore.score;
            scoringDice ~= lastScore;
        } else {
            turnScore = 0;
            scoringDice = [];
        }

        startOfTurn = false;
        
        foreach(ref die; dice){
            die.held = false;
            die.showing = die.showing = uniform!"[]"(1,6);
        }
        showingScore = scoreRoll();
        if(showingScore.score == 0){
            lastScore = showingScore;
            nextPlayer(true);
        }

    }

    void steal(){
        assert(startOfTurn);
        logInfo("stealing!");
        startOfTurn = false;
        auto rolledDice = rollFreeDice;

        showingScore = scoreDice(rolledDice);
        if(showingScore.score == 0){
            lastScore = showingScore;
            nextPlayer(true);
        }
        
    }
    
    nothrow:
    bool isLegalMove(Move move){
        bool ret = move.match!(
                    (Roll r) => legalRoll(r),
                    (Stay s) => legalStay(),
                    (NewRoll nr) => legalNewRoll(),
                    (Steal s) => legalSteal()
                           );
        logInfo("was the move legal? %s", ret);
        return ret;
    }

    bool legalRoll(Roll roll){
        auto heldScore = scoreDice(roll.newHolds.map!(a => dice[a].showing).array);
        return heldScore.score > 0;
    }

    bool legalStay(){

        int[] showingDice = dice[].filter!(a => !a.held).map!(a => a.showing).array;
        const showingScore = scoreDice(showingDice);
        return !startOfTurn &&
            (players[whoseTurn].score >= FirstTurnMinScore ||
             (turnScore + showingScore.score) >= FirstTurnMinScore);
    }

    bool legalNewRoll(){
        if(startOfTurn) return true;
        int[] showingDice = dice[].filter!(a => !a.held).map!(a => a.showing).array;
        const showingScore = scoreDice(showingDice);
        return showingScore.diceUsed == showingDice.length;
    }

    bool legalSteal(){
        import std.algorithm : count;

        return startOfTurn &&
            lastScore.score > 0 &&
            (dice[].count!(a => a.held) < 6);
    }

    void nextPlayer(bool farkled){
        whoseTurn = (whoseTurn +1) % players.length;
        startOfTurn = true;
        if(farkled){
            scoringDice = [];
            turnScore = 0;
        }
    }

    void holdDice(int[] toHold){
        foreach(hold; toHold){
            dice[hold].held = true;
        }
    }

    LabeledScore scoreRoll(){
        import std.array;
        
        int[] toScore = dice[].filter!(x => !x.held).map!(x => x.showing).array;

        return scoreDice(toScore);
    }

    LabeledScore scoreDice(int[] toScore){
        import std.algorithm;
        import std.array;
        import std.conv : to;
        import std.stdio;

        if(toScore.empty){
            return LabeledScore(0, 0, "no dice to score");
        }
                
        sort(toScore);
        auto groups = toScore.group.array.sort!((a, b) => a[1] > b[1]);

        static LabeledScore onesAndFives(T)(T gs){
            LabeledScore ret;
            foreach(g; gs){
                if(g[0] == 1){
                    ret.score += 100*g[1];
                    ret.diceUsed += g[1];
                    auto maybeAnd = ret.description.length > 0 ? " and " : "";
                    ret.description = to!string(g[1]) ~ " 1's" ~ maybeAnd ~ ret.description;
                } else if(g[0] == 5){
                    ret.score += 50*g[1];
                    ret.diceUsed += g[1];
                    auto maybeAnd = ret.description.length > 0 ? " and " : "";
                    ret.description ~= maybeAnd ~ to!string(g[1]) ~ " 5's";
                }
            }
            return ret;
        }
        
        logInfo("groups: %s", groups);
        if(groups.length == 6){
            //straight
            return LabeledScore(3000, 6, "straight");
        } else if(groups[0][1] == 6){
            return LabeledScore(3000, 6, "six " ~ to!string(groups[0][0]) ~ "'s");
        }else if(groups[0][1] == 5){
            return LabeledScore(2000, 5, "five " ~ to!string(groups[0][0]) ~ "'s")
                + onesAndFives(groups[1 .. $]);
        } else if (groups[0][1] == 4){
            if(groups.length > 1 && groups[1][1] == 2){
                return LabeledScore(1500, 6, "three doublets");
            } else {
                return LabeledScore(1000, 4, "four " ~ to!string(groups[0][0]) ~ "'s") +
                    onesAndFives(groups[1 .. $]);
            }
        } else if (groups[0][1] == 3) {
            if(groups.length > 1 && groups[1][1] == 3){
                return LabeledScore(2500, 6, "two triplets");
            } else {
                return LabeledScore(groups[0][0] == 1 ? 300 : 100*groups[0][0],
                                    3,
                                    "three " ~ to!string(groups[0][0]) ~ "'s") +
                    onesAndFives(groups[1 .. $]);
            }
        } else if(groups.length > 2 && groups[2][1] == 2) {
            return LabeledScore(1500, 6, "three doublets");
        } else {
            auto oaf = onesAndFives(groups);
            return oaf.score > 0 ? oaf : LabeledScore(0, 0,
                                                      toScore.length == 6 ? "hard farkle" :
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
                  RollResult([1,2,3,4,5,6], LabeledScore(3000, 6, "straight")),
                  RollResult([2,3,6,5,4,1], LabeledScore(3000, 6, "straight")),
                  RollResult([2,2,2,2,3,2], LabeledScore(2000, 5, "five 2's")),
                  RollResult([1,2,2,2,2,2], LabeledScore(2100, 6, "five 2's and 1 1's")),
                  RollResult([2,3,2,3,2,3], LabeledScore(2500, 6, "two triplets")),
                  RollResult([2,2,2,3,4,4], LabeledScore(200, 3, "three 2's")),
                  RollResult([2,2,2,1,1,4], LabeledScore(400, 5, "three 2's and 2 1's")),
                  RollResult([2,2,2,2,3,3], LabeledScore(1500, 6, "three doublets")),
                  RollResult([2,2,3,3,4,4], LabeledScore(1500, 6, "three doublets")),
                  RollResult([2,2,2,2,3,4], LabeledScore(1000, 4, "four 2's")),
                  RollResult([2,2,2,2,1,5], LabeledScore(1150, 6, "four 2's and 1 1's and 1 5's")),
                  RollResult([1,2,1,5,5,3], LabeledScore(300, 4, "2 1's and 2 5's")),
                  RollResult([2,3,4,6,6,2], LabeledScore(0, 0,  "hard farkle"))
                  ];
    foreach(roll; rolls){
        setRoll(roll.dice);
        writeln("dice: ", roll.dice, " f.scoreRoll: ", f.scoreRoll, " expected: ", roll.expected);
        assert(f.scoreRoll == roll.expected);
    }
    writeln("6 die rolls all good");
    auto partialRolls = [
                         RollResult([1,1,1], LabeledScore(300, 3, "three 1's")),
                         RollResult([5], LabeledScore(50, 1, "1 5's")),
                         RollResult([5, 5, 1], LabeledScore(200, 3, "1 1's and 2 5's")),
                         RollResult([4, 4, 4, 1], LabeledScore(500, 4, "three 4's and 1 1's")),
                         RollResult([2,3,4,6], LabeledScore(0, 0, "farkle")),
                         RollResult([2,3,4,6,2], LabeledScore(0, 0, "pretty bad farkle"))
                         ];
    foreach(roll; partialRolls){
        writeln("dice: ", roll.dice, " f.scoreRoll: ", f.scoreDice(roll.dice), " expected: ", roll.expected);
        assert(f.scoreDice(roll.dice) == roll.expected);
    }

    import vibe.data.json;
    writeln(f.toJson);
    
}
